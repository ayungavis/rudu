use colored::*;
use crossbeam_channel::bounded;
use dashmap::DashMap;
pub use rayon::prelude::*; // Re-export for main.rs
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};
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
    let (sizes, _, _) = compute_dir_sizes_with_progress(base, true);
    sizes
}

/// Compute directory sizes with caching support
pub fn compute_dir_sizes_with_cache(
    base: &Path,
    quiet: bool,
    use_cache: bool,
    max_cache_age_hours: u64,
) -> (HashMap<PathBuf, u64>, usize, Duration) {
    if use_cache {
        if let Ok(cache) = Cache::new() {
            // Try to retrieve from cache first
            if let Ok(Some(cached_entry)) = cache.retrieve(base, max_cache_age_hours * 3600) {
                if !quiet {
                    eprintln!(
                        "🚀 {} {}",
                        "Using cached results for".bright_green().bold(),
                        base.display().to_string().bright_white()
                    );
                }
                return (
                    cached_entry.sizes,
                    cached_entry.total_files,
                    Duration::from_secs(0),
                );
            }

            // Check if we can use a parent directory's cache for this subdirectory
            if let Some(parent) = base.parent() {
                if let Ok(Some(parent_cache)) = cache.retrieve(parent, max_cache_age_hours * 3600) {
                    if let Some((filtered_sizes, file_count)) =
                        cache.can_use_for_subdir(&parent_cache, base)
                    {
                        if !quiet {
                            eprintln!(
                                "🚀 {} {}",
                                "Using parent cache for".bright_green().bold(),
                                base.display().to_string().bright_white()
                            );
                        }
                        return (filtered_sizes, file_count, Duration::from_secs(0));
                    }
                }
            }

            // No cache hit, compute normally and store in cache
            let (sizes, total_files, duration) =
                compute_dir_sizes_with_progress_internal(base, quiet);

            // Store in cache
            if let Err(e) = cache.store(base, &sizes, total_files) {
                if !quiet {
                    eprintln!("⚠️  Warning: Failed to store cache: {e}");
                }
            } else if !quiet {
                eprintln!(
                    "💾 {} {}",
                    "Cached results for".bright_blue(),
                    base.display().to_string().bright_white()
                );
            }

            (sizes, total_files, duration)
        } else {
            // Cache creation failed, fall back to normal computation
            compute_dir_sizes_with_progress_internal(base, quiet)
        }
    } else {
        compute_dir_sizes_with_progress_internal(base, quiet)
    }
}

pub fn compute_dir_sizes_with_progress(
    base: &Path,
    quiet: bool,
) -> (HashMap<PathBuf, u64>, usize, Duration) {
    compute_dir_sizes_with_progress_internal(base, quiet)
}

fn compute_dir_sizes_with_progress_internal(
    base: &Path,
    _quiet: bool,
) -> (HashMap<PathBuf, u64>, usize, Duration) {
    let start_time = Instant::now();

    // Use DashMap for thread-safe concurrent access with pre-allocated capacity
    let estimated_dirs = 1000; // Reasonable estimate for most directories
    let sizes = Arc::new(DashMap::with_capacity(estimated_dirs));
    #[cfg(all(unix, not(test)))]
    let seen_inodes = Arc::new(DashMap::<(u64, u64), bool>::with_capacity(
        estimated_dirs / 10,
    )); // Fewer hardlinks expected
    let file_count = Arc::new(AtomicUsize::new(0));

    // Create a channel for streaming file processing
    // Use a larger buffer for better throughput on fast storage
    let (tx, rx) = bounded(num_cpus::get() * 500); // Buffer based on CPU count
    let base_path = base.to_path_buf();

    // Spawn a thread to walk the directory and send files to the channel
    let walker_thread = {
        let tx = tx.clone();
        let base_path = base_path.clone();

        thread::spawn(move || {
            let mut count = 0;
            for entry in WalkDir::new(&base_path)
                .follow_links(false)
                .into_iter()
                .filter_map(Result::ok)
                .filter(is_file)
            {
                count += 1;

                if tx.send(entry).is_err() {
                    break; // Receiver dropped
                }
            }

            count
        })
    };

    // Process files in parallel using a thread pool

    // Spawn worker threads to process files from the channel
    let num_workers = num_cpus::get().min(8); // Limit to 8 threads max
    let mut worker_handles = Vec::with_capacity(num_workers);

    for _ in 0..num_workers {
        let rx = rx.clone();
        let sizes = Arc::clone(&sizes);
        #[cfg(all(unix, not(test)))]
        let seen_inodes = Arc::clone(&seen_inodes);
        let file_count = Arc::clone(&file_count);

        let base_path = base_path.clone();

        let handle = thread::spawn(move || {
            while let Ok(entry) = rx.recv() {
                if let Ok(metadata) = entry.metadata() {
                    #[cfg(all(unix, not(test)))]
                    let mut file_size = metadata.len();
                    #[cfg(any(not(unix), test))]
                    let file_size = metadata.len();
                    file_count.fetch_add(1, Ordering::Relaxed);

                    // Check for hardlinks to avoid double-counting (Unix only)
                    #[cfg(all(unix, not(test)))]
                    {
                        use std::os::unix::fs::MetadataExt;
                        let inode = metadata.ino();
                        let device = metadata.dev();
                        let key = (device, inode);

                        // If this inode has multiple links, only count it once
                        if metadata.nlink() > 1 && seen_inodes.insert(key, true).is_some() {
                            // Skip this file, we've already counted it
                            file_size = 0;
                        }
                    }

                    // Only process if we have a size to add
                    if file_size > 0 {
                        let mut current = entry.path();

                        // Bubble up file size to each ancestor directory
                        while let Some(parent) = current.parent() {
                            if !parent.starts_with(&base_path) {
                                break;
                            }
                            // Use DashMap's entry API for atomic updates
                            // Clone PathBuf only when necessary (when inserting new entry)
                            match sizes.get_mut(parent) {
                                Some(mut existing_size) => {
                                    *existing_size += file_size;
                                }
                                None => {
                                    sizes.insert(parent.to_path_buf(), file_size);
                                }
                            }
                            current = parent;
                        }
                    }
                }
            }
        });

        worker_handles.push(handle);
    }

    // Drop the sender to signal completion
    drop(tx);

    // Wait for the walker thread to complete
    let _total_files = walker_thread.join().unwrap_or(0);

    // Wait for all worker threads to complete
    for handle in worker_handles {
        let _ = handle.join();
    }

    // Convert DashMap to HashMap for return
    let final_sizes: HashMap<PathBuf, u64> = Arc::try_unwrap(sizes)
        .unwrap_or_else(|_| panic!("Failed to unwrap Arc"))
        .into_iter()
        .collect();
    let final_file_count = file_count.load(Ordering::Relaxed);

    // Ensure the base directory is present even if empty
    let mut result_sizes = final_sizes;
    result_sizes.entry(base.to_path_buf()).or_insert(0);

    let duration = start_time.elapsed();
    (result_sizes, final_file_count, duration)
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
        std::fs::write(&file_path_1, "abcd").unwrap(); // 4 bytes

        let file_path_2 = b.join("bar.txt");
        std::fs::write(&file_path_2, "xyz").unwrap(); // 3 bytes

        let sizes = compute_dir_sizes(dir.path());

        // root: 7 bytes, a: 7 bytes, a/b: 3 bytes
        assert_eq!(
            sizes.get(dir.path()),
            Some(&7),
            "Root directory should have 7 bytes total"
        );
        assert_eq!(
            sizes.get(&a),
            Some(&7),
            "Directory 'a' should have 7 bytes total"
        );
        assert_eq!(
            sizes.get(&b),
            Some(&3),
            "Directory 'b' should have 3 bytes total"
        );
    }

    #[test]
    fn test_cache_functionality() {
        let dir = tempdir().unwrap();
        let file_path = dir.path().join("test.txt");
        std::fs::write(file_path, "hello world").unwrap(); // 11 bytes

        // First scan without cache
        let (sizes1, files1, _) = compute_dir_sizes_with_cache(dir.path(), true, false, 24);
        assert_eq!(sizes1.get(dir.path()), Some(&11));
        assert_eq!(files1, 1);

        // Second scan with cache enabled - should produce same results
        let (sizes2, files2, _) = compute_dir_sizes_with_cache(dir.path(), true, true, 24);
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
