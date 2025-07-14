use clap::Parser;
use colored::*;
use humansize::{format_size, DECIMAL};
use rayon::prelude::*;
use std::path::PathBuf;
use std::process;

use rudu::{compute_dir_sizes_with_cache, Cache};

/// Fast, parallel Rust CLI tool for analyzing directory sizes with colorful output and smart caching.
#[derive(Parser)]
#[command(name = "rudu", author, version, about)]
struct Cli {
    /// Root directory to analyze
    #[arg(default_value = "/")]
    path: PathBuf,

    /// How many results to show
    #[arg(short = 'n', long = "number", default_value_t = 10)]
    top: usize,

    /// Suppress informational messages
    #[arg(short = 'q', long = "quiet")]
    quiet: bool,

    /// Enable caching for faster subsequent scans
    #[arg(short = 'c', long = "cache")]
    cache: bool,

    /// Maximum cache age in hours (default: 24)
    #[arg(long = "cache-age", default_value_t = 24)]
    cache_age: u64,

    /// Clear all cached data
    #[arg(long = "clear-cache")]
    clear_cache: bool,

    /// Show cache statistics
    #[arg(long = "cache-stats")]
    cache_stats: bool,
}

fn main() {
    let cli = Cli::parse();

    // Handle cache operations first
    if cli.clear_cache {
        match Cache::new() {
            Ok(cache) => match cache.clear() {
                Ok(()) => {
                    println!(
                        "🗑️  {} {}",
                        "Cache cleared successfully!".bright_green().bold(),
                        format!("({})", cache.cache_directory().display()).bright_blue()
                    );
                    return;
                }
                Err(e) => {
                    eprintln!("❌ {}: {}", "Failed to clear cache".bright_red().bold(), e);
                    process::exit(1);
                }
            },
            Err(e) => {
                eprintln!("❌ {}: {}", "Failed to access cache".bright_red().bold(), e);
                process::exit(1);
            }
        }
    }

    if cli.cache_stats {
        match Cache::new() {
            Ok(cache) => match cache.stats() {
                Ok((count, size)) => {
                    println!(
                        "📊 {} {}",
                        "Cache Statistics".bright_green().bold(),
                        format!("({})", cache.cache_directory().display()).bright_blue()
                    );
                    println!(
                        "📁 {}: {}",
                        "Cache entries".bright_cyan(),
                        count.to_string().bright_yellow().bold()
                    );
                    println!(
                        "💾 {}: {}",
                        "Cache size".bright_cyan(),
                        format_size(size, DECIMAL).bright_yellow().bold()
                    );
                    return;
                }
                Err(e) => {
                    eprintln!(
                        "❌ {}: {}",
                        "Failed to get cache stats".bright_red().bold(),
                        e
                    );
                    process::exit(1);
                }
            },
            Err(e) => {
                eprintln!("❌ {}: {}", "Failed to access cache".bright_red().bold(), e);
                process::exit(1);
            }
        }
    }

    let base = match cli.path.canonicalize() {
        Ok(p) => p,
        Err(err) => {
            eprintln!(
                "❌ {}: failed to resolve path '{}': {}",
                "Error".bright_red().bold(),
                cli.path.display().to_string().bright_white(),
                err.to_string().bright_red()
            );
            process::exit(1);
        }
    };

    eprintln!(
        "🔍 {} {}",
        "Scanning directory:".bright_cyan().bold(),
        base.display().to_string().bright_white()
    );

    let (sizes, total_files, duration) =
        compute_dir_sizes_with_cache(&base, cli.quiet, cli.cache, cli.cache_age);

    let mut entries: Vec<(PathBuf, u64)> = sizes.into_iter().collect();
    entries.par_sort_unstable_by(|a, b| b.1.cmp(&a.1));

    // Get the base directory size for summary
    let base_size = entries
        .iter()
        .find(|(path, _)| path == &base)
        .map(|(_, size)| *size)
        .unwrap_or(0);

    let mut display_count = 0;
    for (path, bytes) in entries.into_iter() {
        // Skip the base directory in the list
        if path == base {
            continue;
        }

        // Stop if we've shown enough entries
        if display_count >= cli.top {
            break;
        }

        let human = format_size(bytes, DECIMAL);

        // Remove the base directory prefix from the displayed path
        let display_path = if let Ok(relative) = path.strip_prefix(&base) {
            // Show relative path from base
            let rel_str = relative.display().to_string();
            if rel_str.is_empty() {
                continue; // Skip empty relative paths
            } else {
                rel_str
            }
        } else {
            // Fallback to full path if strip_prefix fails
            path.display().to_string()
        };

        display_count += 1;

        // Add emoji based on size
        let emoji = if bytes >= 1_000_000_000 {
            "🔥"
        }
        // >= 1GB
        else if bytes >= 100_000_000 {
            "📦"
        }
        // >= 100MB
        else if bytes >= 10_000_000 {
            "📁"
        }
        // >= 10MB
        else {
            "📄"
        }; // < 10MB

        // Color the rank number based on position
        let rank_color = match display_count {
            1 => format!("{display_count:2}.").bright_yellow().bold(),
            2 => format!("{display_count:2}.").bright_magenta().bold(),
            3 => format!("{display_count:2}.").bright_cyan().bold(),
            _ => format!("{display_count:2}.").bright_white(),
        };

        // Color the size based on magnitude
        let size_color = if bytes >= 1_000_000_000 {
            human.bright_red().bold()
        }
        // >= 1GB
        else if bytes >= 100_000_000 {
            human.bright_yellow().bold()
        }
        // >= 100MB
        else if bytes >= 10_000_000 {
            human.bright_green().bold()
        }
        // >= 10MB
        else {
            human.bright_blue()
        }; // < 10MB

        println!(
            "{} {} {:>10}  {}",
            emoji,
            rank_color,
            size_color,
            display_path.bright_white()
        );
    }

    // Print summary
    println!(
        "📊 {} {}",
        "Summary of".bright_green().bold(),
        base.display().to_string().bright_white().bold()
    );
    println!(
        "💾 {}: {}",
        "Total file size".bright_cyan(),
        format_size(base_size, DECIMAL).bright_yellow().bold()
    );
    println!(
        "📋 {}: {}",
        "Total files".bright_cyan(),
        total_files.to_string().bright_yellow().bold()
    );
    println!(
        "⏱️  {}: {}",
        "Time taken".bright_cyan(),
        format!("{:.2?}", duration).bright_yellow().bold()
    );
}
