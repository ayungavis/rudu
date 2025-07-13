use clap::Parser;
use humansize::{format_size, DECIMAL};
use rayon::prelude::*;
use std::path::PathBuf;
use std::process;

use rudu::compute_dir_sizes;

/// Simple Rust CLI to report top-N largest directories under a path.
#[derive(Parser)]
#[command(name = "rudu", author, version, about)]
struct Cli {
    /// Root directory to analyze
    #[arg(default_value = "/")]
    path: PathBuf,

    /// How many results to show
    #[arg(short = 'n', long = "number", default_value_t = 10)]
    top: usize,
}

fn main() {
    let cli = Cli::parse();

    let base = match cli.path.canonicalize() {
        Ok(p) => p,
        Err(err) => {
            eprintln!(
                "Error: failed to resolve path '{}': {}",
                cli.path.display(),
                err
            );
            process::exit(1);
        }
    };

    eprintln!("Scanning directory: {}", base.display());

    let sizes = compute_dir_sizes(&base);

    let mut entries: Vec<(PathBuf, u64)> = sizes.into_iter().collect();
    entries.par_sort_unstable_by(|a, b| b.1.cmp(&a.1));

    for (i, (path, bytes)) in entries.into_iter().take(cli.top).enumerate() {
        let human = format_size(bytes, DECIMAL);
        println!("{:2}. {:>10}  {}", i + 1, human, path.display());
    }
}
