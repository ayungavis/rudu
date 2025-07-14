# Rudu Performance Benchmark

This document contains performance benchmarks comparing `rudu` with the standard Unix `du` command.

## Test Environment

- **Date**: 2025-07-14 07:53:26
- **Operating System**: Darwin arm64
- **CPU**: Apple M4 Pro
- **Test Directory**: `/Users/ayungavis`
- **Rudu Version**: 0.2.5

## Methodology

Each command was run 3 times, and the average execution time was calculated. The tests compare:

1. **Standard du**: `du -sh /Users/ayungavis/* | sort -hr | head -10`
2. **Rudu (no cache)**: `rudu -q -n 10 /Users/ayungavis`
3. **Rudu (cached)**: `rudu -q -c -n 10 /Users/ayungavis` (after cache population)

## Results

| Command         | Average Time | Speedup vs du   |
| --------------- | ------------ | --------------- |
| Standard du     | 66.02s       | 1.0x (baseline) |
| Rudu (no cache) | 144.07s      | 0.46x faster    |
| Rudu (cached)   | 0.32s        | 206.31x faster  |

## Key Findings

### Performance Comparison

- **Rudu without cache** is **0.46x the speed** of standard `du` (slower on first run)
- **Rudu with cache** is **206.31x faster** than standard `du`
- Cache provides a **450.22x speedup** over non-cached rudu

### Key Insights

1. **Initial Scan Trade-off**: Rudu's first scan is slower than `du` because it performs additional processing (hardlink detection, progress tracking, and data preparation for caching)
2. **Dramatic Cache Benefits**: Once cached, rudu is over 200x faster than `du` for subsequent scans
3. **Best for Repeated Analysis**: Rudu excels when you need to analyze the same directory multiple times
4. **Rich Features**: Even when slower initially, rudu provides progress bars, colorful output, and better formatting

### Advantages of Rudu

1. **Lightning-Fast Cached Scans**: Subsequent scans are nearly instantaneous (0.32s vs 66s)
2. **Better Output**: Colorful, emoji-enhanced output with better formatting
3. **Progress Indication**: Real-time progress bars for large directory scans
4. **Smart Caching**: Intelligent cache management with configurable expiry
5. **Hardlink Detection**: More accurate file size calculations
6. **Modern UX**: Enhanced user experience with visual feedback

### When to Use Each Tool

**Use `du` when:**

- You need a quick one-time scan
- Working with scripts where speed is critical
- System resources are limited
- You only need basic size information

**Use `rudu` when:**

- You'll be scanning the same directory multiple times
- You want a better visual experience with colors and progress bars
- You need more accurate file size calculations (hardlink detection)
- You're doing interactive directory exploration
- You want to cache results for faster subsequent analysis

### Use Cases for Rudu

- **Repeated analysis**: Ideal when you need to scan the same directory multiple times
- **Development workflows**: Perfect for monitoring build directories, logs, etc. where you check sizes frequently
- **Interactive exploration**: Better UX with progress bars and colorful output for large directory analysis
- **System administration**: When you need both speed (after first scan) and rich visual feedback

## Reproducing the Benchmark

To reproduce these results on your system:

```bash
# Clone the repository
git clone https://github.com/ayungavis/rudu.git
cd rudu

# Build release version
cargo build --release

# Run benchmark script
./scripts/benchmark.sh /path/to/test/directory
```

## Notes

- **Test Environment**: Apple M4 Pro with fast SSD storage
- **Test Directory**: `/Users/ayungavis` containing ~765,000 files across multiple subdirectories
- Times may vary based on system specifications, disk speed, and directory structure
- Cache performance is most beneficial for repeated scans of the same directory
- The benchmark uses quiet mode (`-q`) to disable progress bars for fair timing comparison
- All commands were run with similar output formatting (top 10 results)
- Rudu's initial slower performance is due to additional features (hardlink detection, progress tracking, cache preparation)

---

_Benchmark generated automatically by rudu benchmark script_
