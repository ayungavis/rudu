use dirs::cache_dir;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

/// Cache entry containing directory scan results
#[derive(Serialize, Deserialize, Clone)]
pub struct CacheEntry {
    /// Directory sizes mapping
    pub sizes: HashMap<PathBuf, u64>,
    /// Total number of files
    pub total_files: usize,
    /// Timestamp when this entry was created
    pub timestamp: u64,
    /// Base directory that was scanned
    pub base_path: PathBuf,
}

/// Cache manager for directory scan results
pub struct Cache {
    cache_dir: PathBuf,
}

impl Cache {
    /// Create a new cache instance
    pub fn new() -> Result<Self, Box<dyn std::error::Error>> {
        let cache_dir = cache_dir()
            .ok_or("Could not determine cache directory")?
            .join("rudu");

        // Create cache directory if it doesn't exist
        fs::create_dir_all(&cache_dir)?;

        Ok(Cache { cache_dir })
    }

    /// Create a cache instance with a custom directory (for testing)
    #[cfg(test)]
    pub fn with_dir(cache_dir: PathBuf) -> Result<Self, Box<dyn std::error::Error>> {
        fs::create_dir_all(&cache_dir)?;
        Ok(Cache { cache_dir })
    }

    /// Generate a cache key for a given path
    fn cache_key(&self, path: &Path) -> String {
        use std::collections::hash_map::DefaultHasher;
        use std::hash::{Hash, Hasher};
        
        let mut hasher = DefaultHasher::new();
        path.hash(&mut hasher);
        format!("{:x}", hasher.finish())
    }

    /// Get cache file path for a given directory
    fn cache_file_path(&self, path: &Path) -> PathBuf {
        self.cache_dir.join(format!("{}.json", self.cache_key(path)))
    }

    /// Check if cache entry is valid (not too old)
    fn is_cache_valid(&self, entry: &CacheEntry, max_age_seconds: u64) -> bool {
        let current_time = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();
        
        current_time - entry.timestamp <= max_age_seconds
    }

    /// Store scan results in cache
    pub fn store(
        &self,
        path: &Path,
        sizes: &HashMap<PathBuf, u64>,
        total_files: usize,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        let entry = CacheEntry {
            sizes: sizes.clone(),
            total_files,
            timestamp,
            base_path: path.to_path_buf(),
        };

        let cache_file = self.cache_file_path(path);
        let json = serde_json::to_string_pretty(&entry)?;
        fs::write(cache_file, json)?;

        Ok(())
    }

    /// Retrieve scan results from cache if available and valid
    pub fn retrieve(
        &self,
        path: &Path,
        max_age_seconds: u64,
    ) -> Result<Option<CacheEntry>, Box<dyn std::error::Error>> {
        let cache_file = self.cache_file_path(path);
        
        if !cache_file.exists() {
            return Ok(None);
        }

        let json = fs::read_to_string(cache_file)?;
        let entry: CacheEntry = serde_json::from_str(&json)?;

        if self.is_cache_valid(&entry, max_age_seconds) {
            Ok(Some(entry))
        } else {
            // Cache is too old, remove it
            let _ = fs::remove_file(self.cache_file_path(path));
            Ok(None)
        }
    }

    /// Check if we can use cached data for a subdirectory scan
    pub fn can_use_for_subdir(
        &self,
        parent_cache: &CacheEntry,
        subdir: &Path,
    ) -> Option<(HashMap<PathBuf, u64>, usize)> {
        // Check if the subdirectory is within the cached parent directory
        if !subdir.starts_with(&parent_cache.base_path) {
            return None;
        }

        // Filter the cached results to only include entries under the subdirectory
        let mut filtered_sizes = HashMap::new();
        let mut file_count = 0;

        for (path, size) in &parent_cache.sizes {
            if path.starts_with(subdir) {
                filtered_sizes.insert(path.clone(), *size);
                
                // Count files in this directory (approximate)
                if path == subdir {
                    // This is a rough estimate - in a real implementation,
                    // we'd need to store file counts per directory
                    file_count = (*size / 1024).max(1) as usize; // Rough estimate
                }
            }
        }

        if !filtered_sizes.is_empty() {
            Some((filtered_sizes, file_count))
        } else {
            None
        }
    }

    /// Clear all cache entries
    pub fn clear(&self) -> Result<(), Box<dyn std::error::Error>> {
        if self.cache_dir.exists() {
            fs::remove_dir_all(&self.cache_dir)?;
            fs::create_dir_all(&self.cache_dir)?;
        }
        Ok(())
    }

    /// Get cache directory path
    pub fn cache_directory(&self) -> &Path {
        &self.cache_dir
    }

    /// Get cache statistics
    pub fn stats(&self) -> Result<(usize, u64), Box<dyn std::error::Error>> {
        let mut count = 0;
        let mut total_size = 0;

        if self.cache_dir.exists() {
            for entry in fs::read_dir(&self.cache_dir)? {
                let entry = entry?;
                if entry.path().extension().and_then(|s| s.to_str()) == Some("json") {
                    count += 1;
                    total_size += entry.metadata()?.len();
                }
            }
        }

        Ok((count, total_size))
    }
}

impl Default for Cache {
    fn default() -> Self {
        Self::new().expect("Failed to create cache")
    }
}
