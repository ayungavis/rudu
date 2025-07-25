# rudu

[![Rust](https://img.shields.io/badge/rust-1.75+-orange.svg)](https://www.rust-lang.org/)
[![CI](https://github.com/ayungavis/rudu/workflows/CI/badge.svg)](https://github.com/ayungavis/rudu/actions)
[![Security Audit](https://github.com/ayungavis/rudu/workflows/Security%20Audit/badge.svg)](https://github.com/ayungavis/rudu/actions)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Crates.io](https://img.shields.io/crates/v/rudu.svg)](https://crates.io/crates/rudu)
[![Documentation](https://docs.rs/rudu/badge.svg)](https://docs.rs/rudu)

A fast, parallel Rust CLI tool for analyzing directory sizes and finding the largest directories under a given path. Think of it as a modern, performant alternative to `du` with a focus on identifying space-consuming directories quickly.

## Features

- 🚀 **Fast parallel processing** with multi-threaded file processing and streaming architecture
- 📊 **Human-readable output** with formatted file sizes (KB, MB, GB, etc.)
- 🎯 **Top-N results** - show only the largest directories that matter
- 🛡️ **Safe symlink handling** - doesn't follow symbolic links to prevent infinite loops
- 📁 **Flexible path input** - analyze any directory, defaults to root (`/`)
- 🔧 **Simple CLI interface** with sensible defaults
- ⚡ **Fast scanning** - efficient directory traversal with timing information
- 🎨 **Clean output** - shows relative paths without base directory prefix
- 🔗 **Hardlink detection** - avoids double-counting hardlinked files
- 🌈 **Colorful output** - beautiful colors and emojis for enhanced visual experience
- ⚡ **Smart caching** - cache scan results for lightning-fast subsequent runs
- 🗂️ **Cache management** - built-in cache statistics and cleanup tools

## Installation

### Quick Install (Recommended)

**One-liner installation** for Linux and macOS:

```bash
curl -sSL https://raw.githubusercontent.com/ayungavis/rudu/main/install.sh | bash
```

Or download and run the installer:

```bash
wget https://raw.githubusercontent.com/ayungavis/rudu/main/install.sh
chmod +x install.sh
./install.sh
```

**Custom installation directory:**

```bash
INSTALL_DIR=~/.local/bin curl -sSL https://raw.githubusercontent.com/ayungavis/rudu/main/install.sh | bash
```

### Package Managers

#### Homebrew (macOS)

```bash
# Add the tap (once the formula is published)
brew tap ayungavis/tap
brew install rudu
```

#### Cargo (All platforms)

```bash
cargo install rudu
```

#### Linux Distribution Packages

**Debian/Ubuntu (.deb)**:

```bash
# Download the .deb package from releases
wget https://github.com/ayungavis/rudu/releases/download/v0.2.7/rudu_0.1.0_amd64.deb
sudo dpkg -i rudu_0.1.0_amd64.deb
```

**Red Hat/Fedora/CentOS (.rpm)**:

```bash
# Use the provided RPM spec file to build
rpmbuild -ba dist/rpm/rudu.spec
```

**Arch Linux (AUR)**:

```bash
# Use the provided PKGBUILD
makepkg -si
```

**AppImage (Universal Linux)**:

```bash
# Download and run
wget https://github.com/ayungavis/rudu/releases/download/v0.2.7/rudu-0.1.0-x86_64.AppImage
chmod +x rudu-0.1.0-x86_64.AppImage
./rudu-0.1.0-x86_64.AppImage
```

### Pre-built Binaries

Download the latest release for your platform from the [releases page](https://github.com/ayungavis/rudu/releases):

- **Linux x86_64**: `rudu-linux-x86_64.tar.gz`
- **Linux x86_64 (musl)**: `rudu-linux-x86_64-musl.tar.gz`
- **macOS x86_64**: `rudu-macos-x86_64.tar.gz`
- **macOS ARM64**: `rudu-macos-aarch64.tar.gz`

Extract and install:

```bash
# Example for Linux
tar -xzf rudu-linux-x86_64.tar.gz
sudo mv rudu /usr/local/bin/
```

### From Source

#### Using Make

```bash
git clone https://github.com/ayungavis/rudu.git
cd rudu
make install          # Install to /usr/local/bin (requires sudo)
# or
make install-user     # Install to ~/.local/bin
```

#### Using Cargo

```bash
git clone https://github.com/ayungavis/rudu.git
cd rudu
cargo build --release
```

The binary will be available at `target/release/rudu`.

### Verification

After installation, verify it works:

```bash
rudu --version
rudu --help
```

## Usage

### Basic Usage

```bash
# Analyze current directory, show top 10 largest subdirectories
rudu .

# Analyze root directory (default)
rudu

# Analyze specific directory
rudu /home/user/Documents

# Show top 20 largest directories
rudu -n 20 /var/log

# Show top 5 largest directories with long flag
rudu --number 5 /usr/local

# Suppress informational messages for scripting
rudu --quiet /home/user

# Short form of quiet mode
rudu -q /var/log

# Enable caching for faster subsequent scans
rudu --cache /home/user

# Use cache with custom max age (in hours)
rudu --cache --cache-age 12 /var/log

# Show cache statistics
rudu --cache-stats

# Clear all cached data
rudu --clear-cache
```

### Example Output

```
🔍 Scanning directory: /home/user/Documents
💾 Cached results for /home/user/Documents
🔥  1.    1.2 GB  Videos
📦  2.  456.7 MB  Photos
📁  3.  123.4 MB  Projects/rust-project
📁  4.   89.2 MB  Downloads
📄  5.   45.6 MB  Books

📊 Summary of /home/user/Documents
💾 Total file size: 2.4 GB
📋 Total files: 2847
⏱️  Time taken: 125.43ms
```

_Note: The actual output includes beautiful colors and emojis that enhance the visual experience!_

### Command Line Options

- `path` - Root directory to analyze (default: `/`)
- `-n, --number <NUMBER>` - Number of top results to show (default: 10)
- `-q, --quiet` - Suppress informational messages for scripting
- `-c, --cache` - Enable caching for faster subsequent scans
- `--cache-age <HOURS>` - Maximum cache age in hours (default: 24)
- `--cache-stats` - Show cache statistics
- `--clear-cache` - Clear all cached data
- `-h, --help` - Show help information
- `-V, --version` - Show version information

## How It Works

1. **Recursive Traversal**: Uses `walkdir` to recursively walk through all files in the directory tree
2. **Performance Tracking**: Measures and displays scan time for performance monitoring
3. **Hardlink Detection**: Identifies and avoids double-counting hardlinked files using inode tracking
4. **Size Aggregation**: For each file, adds its size to all ancestor directories up to the root
5. **Parallel Sorting**: Uses Rayon to sort results in parallel for better performance
6. **Clean Output**: Displays relative paths without the base directory prefix
7. **Human-Readable Output**: Formats byte sizes using decimal units (KB, MB, GB, etc.)

## File Size Accuracy

The tool now includes hardlink detection to provide more accurate file size calculations:

- **Hardlink Detection**: On Unix systems, files with multiple hardlinks are only counted once
- **Inode Tracking**: Uses device and inode numbers to identify duplicate files
- **Accurate Totals**: Prevents inflated directory sizes caused by hardlinked files

This is particularly important on macOS and Linux systems where system files often use hardlinks.

## Caching System

Rudu includes a smart caching system that dramatically speeds up subsequent scans:

### How Caching Works

- **Automatic Storage**: When using `--cache`, scan results are automatically stored in your system's cache directory
- **Smart Retrieval**: Subsequent scans of the same directory use cached data if it's still valid
- **Parent Cache Utilization**: Scanning subdirectories can use parent directory cache data for instant results
- **Configurable Expiry**: Cache entries expire after a configurable time (default: 24 hours)

### Cache Benefits

- **Lightning Fast**: Cached scans complete in milliseconds instead of seconds/minutes
- **Subdirectory Optimization**: Scanning `/home/user/Documents` after caching `/home/user` is nearly instant
- **Intelligent**: Only uses cache when data is fresh and relevant

### Cache Management

```bash
# Enable caching for a scan
rudu --cache /large/directory

# Set custom cache expiry (12 hours)
rudu --cache --cache-age 12 /path/to/scan

# View cache statistics
rudu --cache-stats

# Clear all cached data
rudu --clear-cache
```

### Cache Location

- **Linux**: `~/.cache/rudu/`
- **macOS**: `~/Library/Caches/rudu/`
- **Windows**: `%LOCALAPPDATA%\rudu\cache\`

## Performance

Rudu provides different performance characteristics compared to the standard `du` command:

- **First scan**: Slower than `du` due to additional features (hardlink detection, progress tracking, cache preparation)
- **Cached scans**: **200x+ faster** than `du` for subsequent runs
- **Best use case**: Repeated analysis of the same directories

For detailed benchmark results comparing rudu with `du`, see [docs/BENCHMARK.md](docs/BENCHMARK.md).

For technical details about performance optimizations, see [docs/OPTIMIZATIONS.md](docs/OPTIMIZATIONS.md).

## Development

### Prerequisites

- Rust 1.75 or later
- Cargo (comes with Rust)

### Building

```bash
# Clone the repository
git clone https://github.com/ayungavis/rudu.git
cd rudu

# Build in debug mode
cargo build

# Build in release mode (optimized)
cargo build --release

# Run directly with cargo
cargo run -- /path/to/analyze
```

### Testing

```bash
# Run all tests
cargo test

# Run tests with output
cargo test -- --nocapture

# Run specific test
cargo test test_nested_dirs
```

### Code Structure

- `src/main.rs` - CLI interface and main application logic
- `src/lib.rs` - Core directory size computation algorithm
- `src/cache.rs` - Caching system implementation
- `Cargo.toml` - Project configuration and dependencies

### Dependencies

- **clap** - Command-line argument parsing with derive macros
- **walkdir** - Recursive directory traversal
- **humansize** - Human-readable file size formatting
- **rayon** - Data parallelism for sorting
- **tempfile** - Temporary file handling for tests

- **colored** - Terminal color and styling support
- **serde** - Serialization framework for cache data
- **serde_json** - JSON serialization for cache storage
- **dirs** - Cross-platform system directory detection

## Contributing

We welcome contributions! Here's how you can help:

### Setting Up Development Environment

1. Fork the repository
2. Clone your fork: `git clone https://github.com/ayungavis/rudu.git`
3. Create a feature branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Run tests: `cargo test`
6. Run clippy for linting: `cargo clippy`
7. Format code: `cargo fmt`
8. Commit your changes: `git commit -m "Add your feature"`
9. Push to your fork: `git push origin feature/your-feature-name`
10. Create a Pull Request

### Code Style

- Follow Rust standard formatting (`cargo fmt`)
- Ensure all clippy warnings are addressed (`cargo clippy`)
- Write tests for new functionality
- Add documentation comments for public functions
- Keep functions focused and well-named

### Areas for Contribution

- **Performance improvements** - Optimize directory traversal or sorting
- **Additional output formats** - JSON, CSV, or other structured formats
- **Filtering options** - Exclude certain file types or directories
- **Cross-platform testing** - Ensure compatibility across different operating systems
- **Documentation** - Improve examples, add more detailed explanations
- **Error handling** - Better error messages and recovery
- **Configuration** - Support for config files or environment variables

### Running Benchmarks

```bash
# Add criterion to dev-dependencies if implementing benchmarks
cargo bench
```

### Debugging

```bash
# Run with debug logging
RUST_LOG=debug cargo run -- /path/to/analyze

# Run with backtraces on panic
RUST_BACKTRACE=1 cargo run -- /path/to/analyze
```

### CI/CD Pipeline

This project uses GitHub Actions for continuous integration and deployment:

- **CI Pipeline** (`.github/workflows/ci.yml`):

  - Tests on multiple Rust versions (stable, beta, nightly)
  - Cross-platform testing (Linux, Windows, macOS)
  - Code formatting checks (`cargo fmt`)
  - Linting with Clippy (`cargo clippy`)
  - Code coverage reporting with Codecov
  - Documentation building
  - MSRV (Minimum Supported Rust Version) verification

- **Security Audit** (`.github/workflows/security-audit.yml`):

  - Daily security vulnerability scans with `cargo audit`
  - License and dependency checking with `cargo deny`
  - Runs on every push and pull request

- **Release Pipeline** (`.github/workflows/release.yml`):
  - Automated releases when tags are pushed
  - Cross-platform binary builds
  - Automatic publishing to crates.io
  - GitHub release creation with binaries

#### Setting up CI/CD

To enable all CI/CD features, you'll need to:

1. **For code coverage**: Sign up at [Codecov](https://codecov.io) and link your repository
2. **For releases**: Add a `CRATES_TOKEN` secret to your GitHub repository settings
   - Get your token from [crates.io/me](https://crates.io/me)
   - Add it as a repository secret named `CRATES_TOKEN`

#### Running CI checks locally

```bash
# Run the same checks as CI
cargo test --all-features --workspace  # Tests
cargo fmt --all -- --check            # Formatting
cargo clippy --all-targets --all-features -- -D warnings  # Linting
cargo audit                            # Security audit
cargo deny check                       # License/dependency check
```

## Performance Considerations

- Uses parallel processing where beneficial (sorting large result sets)
- Avoids following symbolic links to prevent infinite loops
- Efficiently aggregates sizes by bubbling up through directory hierarchy
- Memory usage scales with the number of directories, not files

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with the excellent Rust ecosystem
- Inspired by traditional Unix `du` command
- Uses Rayon for efficient parallel processing

## Roadmap

### Completed ✅

- [x] Add timing information to track scan performance
- [x] Colorful output with emojis
- [x] Smart caching system
- [x] Cache management tools

### Planned 🚧

- [ ] Add JSON/CSV output formats
- [ ] Implement directory exclusion patterns
- [ ] Support for following symbolic links (optional)
- [ ] Configuration file support
- [ ] Windows-specific optimizations
- [ ] Interactive mode with real-time filtering
- [ ] Integration with cloud storage providers
- [ ] Plugin system for custom analyzers

---

**Found a bug or have a feature request?** Please [open an issue](https://github.com/ayungavis/rudu/issues/new) on GitHub.
