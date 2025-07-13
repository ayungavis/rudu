use std::collections::HashMap;
use std::path::{Path, PathBuf};
use walkdir::{DirEntry, WalkDir};

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
    let mut sizes: HashMap<PathBuf, u64> = HashMap::new();

    for entry in WalkDir::new(base)
        .follow_links(false)
        .into_iter()
        .filter_map(Result::ok)
        .filter(is_file)
    {
        if let Ok(metadata) = entry.metadata() {
            let file_size = metadata.len();
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

    // Ensure the base directory is present even if empty
    sizes.entry(base.to_path_buf()).or_insert(0);
    sizes
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::{tempdir};

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
}
