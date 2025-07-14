use colored::*;
use indicatif::{ProgressBar, ProgressStyle};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use walkdir::{DirEntry, WalkDir};

pub mod cache;
pub use cache::Cache;

/// Returns `true` if the entry is a regular file (not a directory or symlink).
///
/// This filter ensures we only aggregate actual file sizes.
pub fn is_file(entry: &DirEntry) -> bool {
    entry.file_type().is_file()
}

/// Traverse `base` recursively, summing file sizes into each ancestor directory up to `base`.
///
/// # Arguments
///
/// * `base` - Root path to start scanning. All file sizes under this path
///   are aggregated for each directory from the file's parent up to `base`.
///
/// # Returns
///
/// A `HashMap<PathBuf, u64>` mapping each directory path to the total size (in bytes)
/// of all files within that directory subtree.
///
/// # Example
///
/// ```rust
/// use std::path::Path;
/// use rudu::compute_dir_sizes;
/// let sizes = compute_dir_sizes(Path::new("/tmp/mydir"));
/// println!("Size of /tmp/mydir: {} bytes", sizes[Path::new("/tmp/mydir")]);
/// ```
pub fn compute_dir_sizes(base: &Path) -> HashMap<PathBuf, u64> {
    let (sizes, _) = compute_dir_sizes_with_progress(base, true);
    sizes
}

/// Compute directory sizes with caching support
pub fn compute_dir_sizes_with_cache(
    base: &Path,
    quiet: bool,
    use_cache: bool,
    max_cache_age_hours: u64,
) -> (HashMap<PathBuf, u64>, usize) {
    if use_cache {
        if let Ok(cache) = Cache::new() {
            // Try to retrieve from cache first
            if let Ok(Some(cached_entry)) = cache.retrieve(base, max_cache_age_hours * 3600) {
                if !quiet {
                    eprintln!("🚀 {} {}", "Using cached results for".bright_green().bold(), base.display().to_string().bright_white());
                }
                return (cached_entry.sizes, cached_entry.total_files);
            }

            // Check if we can use a parent directory's cache for this subdirectory
            if let Some(parent) = base.parent() {
                if let Ok(Some(parent_cache)) = cache.retrieve(parent, max_cache_age_hours * 3600) {
                    if let Some((filtered_sizes, file_count)) = cache.can_use_for_subdir(&parent_cache, base) {
                        if !quiet {
                            eprintln!("🚀 {} {}", "Using parent cache for".bright_green().bold(), base.display().to_string().bright_white());
                        }
                        return (filtered_sizes, file_count);
                    }
                }
            }

            // No cache hit, compute normally and store in cache
            let (sizes, total_files) = compute_dir_sizes_with_progress_internal(base, quiet);

            // Store in cache
            if let Err(e) = cache.store(base, &sizes, total_files) {
                if !quiet {
                    eprintln!("⚠️  Warning: Failed to store cache: {e}");
                }
            } else if !quiet {
                eprintln!("💾 {} {}", "Cached results for".bright_blue(), base.display().to_string().bright_white());
            }

            (sizes, total_files)
        } else {
            // Cache creation failed, fall back to normal computation
            compute_dir_sizes_with_progress_internal(base, quiet)
        }
    } else {
        compute_dir_sizes_with_progress_internal(base, quiet)
    }
}

pub fn compute_dir_sizes_with_progress(base: &Path, quiet: bool) -> (HashMap<PathBuf, u64>, usize) {
    compute_dir_sizes_with_progress_internal(base, quiet)
}

fn compute_dir_sizes_with_progress_internal(base: &Path, quiet: bool) -> (HashMap<PathBuf, u64>, usize) {
    let mut sizes: HashMap<PathBuf, u64> = HashMap::new();
    let mut seen_inodes = HashMap::new(); // Track inodes to avoid double-counting hardlinks

    // Setup counting progress indicator (only if not quiet)
    let counting_pb = if !quiet {
        let pb = ProgressBar::new_spinner();
        pb.set_style(
            ProgressStyle::default_spinner()
                .template("{spinner:.green} Counting files... {pos} found")
                .unwrap()
                .tick_chars("⠁⠂⠄⡀⢀⠠⠐⠈ "),
        );
        pb.enable_steady_tick(std::time::Duration::from_millis(100));
        Some(pb)
    } else {
        None
    };

    // Collect all files with counting progress
    let mut files = Vec::new();
    for entry in WalkDir::new(base)
        .follow_links(false)
        .into_iter()
        .filter_map(Result::ok)
        .filter(is_file)
    {
        files.push(entry);
        if let Some(ref pb) = counting_pb {
            pb.set_position(files.len() as u64);
        }
    }

    // Finish counting progress
    if let Some(pb) = counting_pb {
        pb.finish_with_message(format!("Found {} files", files.len()));
    }

    if files.is_empty() {
        // Ensure the base directory is present even if empty
        sizes.entry(base.to_path_buf()).or_insert(0);
        return (sizes, 0);
    }

    // Setup processing progress bar (only if not quiet)
    let processing_pb = if !quiet {
        let pb = ProgressBar::new(files.len() as u64);
        pb.set_style(
            ProgressStyle::default_bar()
                .template("{spinner:.green} Processing [{elapsed_precise}] [{bar:40.cyan/blue}] {pos}/{len} files ({eta})")
                .unwrap()
                .progress_chars("#>-"),
        );
        Some(pb)
    } else {
        None
    };

    // Process files with progress
    for (i, entry) in files.iter().enumerate() {
        if let Ok(metadata) = entry.metadata() {
            let mut file_size = metadata.len();

            // Check for hardlinks to avoid double-counting (Unix only)
            #[cfg(unix)]
            {
                use std::os::unix::fs::MetadataExt;
                let inode = metadata.ino();
                let device = metadata.dev();
                let key = (device, inode);

                // If this inode has multiple links, only count it once
                if metadata.nlink() > 1 {
                    if let std::collections::hash_map::Entry::Vacant(e) = seen_inodes.entry(key) {
                        e.insert(true);
                    } else {
                        // Skip this file, we've already counted it
                        file_size = 0;
                    }
                }
            }

            // Only process if we have a size to add
            if file_size > 0 {
                let mut current = entry.path();

                // Bubble up file size to each ancestor directory
                while let Some(parent) = current.parent() {
                    if !parent.starts_with(base) {
                        break;
                    }
                    *sizes.entry(parent.to_path_buf()).or_default() += file_size;
                    current = parent;
                }
            }
        }

        // Update progress
        if let Some(ref pb) = processing_pb {
            pb.set_position((i + 1) as u64);
        }
    }

    if let Some(pb) = processing_pb {
        pb.finish_with_message("Processing complete!");
    }

    // Ensure the base directory is present even if empty
    sizes.entry(base.to_path_buf()).or_insert(0);
    (sizes, files.len())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::tempdir;

    #[test]
    fn test_empty_dir() {
        let dir = tempdir().unwrap();
        let sizes = compute_dir_sizes(dir.path());
        // Only the root dir should be present with size 0
        assert_eq!(sizes.len(), 1);
        assert_eq!(sizes.get(dir.path()), Some(&0));
    }

    #[test]
    fn test_single_file() {
        let dir = tempdir().unwrap();
        let file_path = dir.path().join("test.txt");
        std::fs::write(file_path, "hello").unwrap(); // 5 bytes

        let sizes = compute_dir_sizes(dir.path());
        assert_eq!(sizes.get(dir.path()), Some(&5));
    }

    #[test]
    fn test_nested_dirs() {
        let dir = tempdir().unwrap();
        let a = dir.path().join("a");
        let b = a.join("b");
        fs::create_dir_all(&b).unwrap();

        let file_path_1 = a.join("foo.txt");
        std::fs::write(file_path_1, "abcd").unwrap(); // 4 bytes

        let file_path_2 = b.join("bar.txt");
        std::fs::write(file_path_2, "xyz").unwrap(); // 3 bytes

        let sizes = compute_dir_sizes(dir.path());
        // root: 7 bytes, a: 7 bytes, a/b: 3 bytes
        assert_eq!(sizes.get(dir.path()), Some(&7));
        assert_eq!(sizes.get(&a), Some(&7));
        assert_eq!(sizes.get(&b), Some(&3));
    }

    #[test]
    fn test_cache_functionality() {
        let dir = tempdir().unwrap();
        let file_path = dir.path().join("test.txt");
        std::fs::write(file_path, "hello world").unwrap(); // 11 bytes

        // First scan without cache
        let (sizes1, files1) = compute_dir_sizes_with_cache(dir.path(), true, false, 24);
        assert_eq!(sizes1.get(dir.path()), Some(&11));
        assert_eq!(files1, 1);

        // Second scan with cache enabled - should produce same results
        let (sizes2, files2) = compute_dir_sizes_with_cache(dir.path(), true, true, 24);
        assert_eq!(sizes2.get(dir.path()), Some(&11));
        assert_eq!(files2, 1);

        // Results should be identical
        assert_eq!(sizes1, sizes2);
        assert_eq!(files1, files2);
    }

    #[test]
    fn test_cache_store_and_retrieve() {
        let dir = tempdir().unwrap();
        let cache_dir = tempdir().unwrap();

        // Create a temporary cache in the test directory
        let cache = Cache::with_dir(cache_dir.path().to_path_buf()).unwrap();

        let mut test_sizes = HashMap::new();
        test_sizes.insert(dir.path().to_path_buf(), 100);

        // Store in cache
        cache.store(dir.path(), &test_sizes, 5).unwrap();

        // Retrieve from cache
        let retrieved = cache.retrieve(dir.path(), 3600).unwrap();
        assert!(retrieved.is_some());

        let entry = retrieved.unwrap();
        assert_eq!(entry.sizes, test_sizes);
        assert_eq!(entry.total_files, 5);
        assert_eq!(entry.base_path, dir.path());
    }

    #[test]
    fn test_cache_expiry() {
        let dir = tempdir().unwrap();
        let cache_dir = tempdir().unwrap();

        let cache = Cache::with_dir(cache_dir.path().to_path_buf()).unwrap();

        let mut test_sizes = HashMap::new();
        test_sizes.insert(dir.path().to_path_buf(), 100);

        // Store in cache
        cache.store(dir.path(), &test_sizes, 5).unwrap();

        // First, verify it's retrievable with a long max age
        let retrieved_valid = cache.retrieve(dir.path(), 3600).unwrap();
        assert!(retrieved_valid.is_some());

        // Store again for the expiry test
        cache.store(dir.path(), &test_sizes, 5).unwrap();

        // Wait for at least 1 second to ensure timestamp difference
        std::thread::sleep(std::time::Duration::from_secs(1));

        // Try to retrieve with 0 max age (should be expired since we waited 1 second)
        let retrieved = cache.retrieve(dir.path(), 0).unwrap();
        assert!(retrieved.is_none());
    }
}
