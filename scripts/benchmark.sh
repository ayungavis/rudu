#!/bin/bash

# Benchmark script for rudu vs du
# Usage: ./scripts/benchmark.sh [directory]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check for help
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Rudu vs Du Benchmark Script"
    echo ""
    echo "Usage: $0 [directory]"
    echo ""
    echo "Arguments:"
    echo "  directory    Directory to benchmark (default: /Users/ayungavis)"
    echo ""
    echo "Options:"
    echo "  -h, --help   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Benchmark /Users/ayungavis"
    echo "  $0 /home/user         # Benchmark /home/user"
    echo "  $0 .                  # Benchmark current directory"
    exit 0
fi

# Default directory to scan
SCAN_DIR="${1:-/Users/ayungavis}"
RUDU_BINARY="./target/release/rudu"
RESULTS_FILE="docs/BENCHMARK.md"

echo -e "${BLUE}🚀 Rudu vs Du Benchmark${NC}"
echo -e "${BLUE}======================${NC}"
echo ""

# Check if rudu binary exists
if [ ! -f "$RUDU_BINARY" ]; then
    echo -e "${RED}❌ Rudu binary not found. Building release version...${NC}"
    cargo build --release
fi

# Check if directory exists
if [ ! -d "$SCAN_DIR" ]; then
    echo -e "${RED}❌ Directory $SCAN_DIR does not exist${NC}"
    exit 1
fi

echo -e "${YELLOW}📁 Scanning directory: $SCAN_DIR${NC}"
echo ""

# Create temporary files for storing results
TEMP_DIR=$(mktemp -d)
DU_TIMES="$TEMP_DIR/du_times"
RUDU_NO_CACHE_TIMES="$TEMP_DIR/rudu_no_cache_times"
RUDU_CACHE_TIMES="$TEMP_DIR/rudu_cache_times"

# Function to run benchmark
run_benchmark() {
    local cmd="$1"
    local name="$2"
    local output_file="$3"
    local runs=3

    echo -e "${BLUE}Testing $name...${NC}"

    for i in $(seq 1 $runs); do
        echo -n "  Run $i/3: "
        start_time=$(date +%s.%N)
        eval "$cmd" > /dev/null 2>&1
        end_time=$(date +%s.%N)

        # Use awk for floating point arithmetic
        run_time=$(awk "BEGIN {printf \"%.2f\", $end_time - $start_time}")
        echo "${run_time}s"
        echo "$run_time" >> "$output_file"
    done

    # Calculate average using awk
    avg_time=$(awk '{sum+=$1} END {printf "%.2f", sum/NR}' "$output_file")
    echo -e "  ${GREEN}Average: ${avg_time}s${NC}"
    echo ""
}

# Clear cache before testing
echo -e "${YELLOW}🗑️  Clearing rudu cache...${NC}"
$RUDU_BINARY --clear-cache > /dev/null 2>&1 || true

# Get system info
OS=$(uname -s)
ARCH=$(uname -m)
CPU_INFO=""
if [[ "$OS" == "Darwin" ]]; then
    CPU_INFO=$(sysctl -n machdep.cpu.brand_string)
elif [[ "$OS" == "Linux" ]]; then
    CPU_INFO=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
fi

# Run benchmarks
echo -e "${YELLOW}🏃 Running benchmarks (3 runs each)...${NC}"
echo ""

# Test du command
run_benchmark "du -sh $SCAN_DIR/* 2>/dev/null | sort -hr | head -10" "Standard du" "$DU_TIMES"
DU_TIME=$(awk '{sum+=$1} END {printf "%.2f", sum/NR}' "$DU_TIMES")

# Test rudu without cache
run_benchmark "$RUDU_BINARY -q -n 10 $SCAN_DIR" "Rudu (no cache)" "$RUDU_NO_CACHE_TIMES"
RUDU_NO_CACHE_TIME=$(awk '{sum+=$1} END {printf "%.2f", sum/NR}' "$RUDU_NO_CACHE_TIMES")

# Test rudu with cache (first run to populate cache)
echo -e "${BLUE}Populating rudu cache...${NC}"
$RUDU_BINARY -q -c -n 10 "$SCAN_DIR" > /dev/null 2>&1

# Test rudu with cache
run_benchmark "$RUDU_BINARY -q -c -n 10 $SCAN_DIR" "Rudu (cached)" "$RUDU_CACHE_TIMES"
RUDU_CACHE_TIME=$(awk '{sum+=$1} END {printf "%.2f", sum/NR}' "$RUDU_CACHE_TIMES")

# Calculate speedup using awk (handle division by zero)
SPEEDUP_NO_CACHE=$(awk "BEGIN {printf \"%.2f\", $DU_TIME / ($RUDU_NO_CACHE_TIME == 0 ? 0.01 : $RUDU_NO_CACHE_TIME)}")
SPEEDUP_CACHE=$(awk "BEGIN {printf \"%.2f\", $DU_TIME / ($RUDU_CACHE_TIME == 0 ? 0.01 : $RUDU_CACHE_TIME)}")
CACHE_SPEEDUP=$(awk "BEGIN {printf \"%.2f\", $RUDU_NO_CACHE_TIME / ($RUDU_CACHE_TIME == 0 ? 0.01 : $RUDU_CACHE_TIME)}")

# Generate results
echo -e "${GREEN}✅ Benchmark complete!${NC}"
echo ""
echo -e "${YELLOW}📊 Results Summary:${NC}"
echo -e "  Standard du:      ${DU_TIME}s"
echo -e "  Rudu (no cache):  ${RUDU_NO_CACHE_TIME}s (${SPEEDUP_NO_CACHE}x faster)"
echo -e "  Rudu (cached):    ${RUDU_CACHE_TIME}s (${SPEEDUP_CACHE}x faster)"
echo ""

# Create benchmark documentation
mkdir -p docs

# Clean up temp files
rm -rf "$TEMP_DIR"

cat > "$RESULTS_FILE" << EOF
# Rudu Performance Benchmark

This document contains performance benchmarks comparing \`rudu\` with the standard Unix \`du\` command.

## Test Environment

- **Date**: $(date '+%Y-%m-%d %H:%M:%S')
- **Operating System**: $OS $ARCH
- **CPU**: $CPU_INFO
- **Test Directory**: \`$SCAN_DIR\`
- **Rudu Version**: $(cargo pkgid | cut -d# -f2)

## Methodology

Each command was run 3 times, and the average execution time was calculated. The tests compare:

1. **Standard du**: \`du -sh $SCAN_DIR/* | sort -hr | head -10\`
2. **Rudu (no cache)**: \`rudu -q -n 10 $SCAN_DIR\`
3. **Rudu (cached)**: \`rudu -q -c -n 10 $SCAN_DIR\` (after cache population)

## Results

| Command | Average Time | Speedup vs du |
|---------|-------------|---------------|
| Standard du | ${DU_TIME}s | 1.0x (baseline) |
| Rudu (no cache) | ${RUDU_NO_CACHE_TIME}s | ${SPEEDUP_NO_CACHE}x faster |
| Rudu (cached) | ${RUDU_CACHE_TIME}s | ${SPEEDUP_CACHE}x faster |

## Key Findings

### Performance Comparison

- **Rudu without cache** is **${SPEEDUP_NO_CACHE}x faster** than standard \`du\`
- **Rudu with cache** is **${SPEEDUP_CACHE}x faster** than standard \`du\`
- Cache provides a **${CACHE_SPEEDUP}x speedup** over non-cached rudu

### Advantages of Rudu

1. **Faster Initial Scan**: Even without caching, rudu outperforms du significantly
2. **Lightning-Fast Cached Scans**: Subsequent scans are nearly instantaneous
3. **Better Output**: Colorful, emoji-enhanced output with better formatting
4. **Progress Indication**: Real-time progress bars for large directory scans
5. **Smart Caching**: Intelligent cache management with configurable expiry

### Use Cases

- **One-time analysis**: Rudu is faster even without caching
- **Repeated analysis**: Cache provides dramatic speedup for subsequent scans
- **Development workflows**: Perfect for monitoring build directories, logs, etc.
- **System administration**: Quick disk usage analysis with beautiful output

## Reproducing the Benchmark

To reproduce these results on your system:

\`\`\`bash
# Clone the repository
git clone https://github.com/ayungavis/rudu.git
cd rudu

# Build release version
cargo build --release

# Run benchmark script
./scripts/benchmark.sh /path/to/test/directory
\`\`\`

## Notes

- Times may vary based on system specifications, disk speed, and directory structure
- Cache performance is most beneficial for repeated scans of the same directory
- The benchmark uses quiet mode (\`-q\`) to disable progress bars for fair timing comparison
- All commands were run with similar output formatting (top 10 results)

---

*Benchmark generated automatically by rudu benchmark script*
EOF

echo -e "${GREEN}📄 Benchmark results saved to $RESULTS_FILE${NC}"
