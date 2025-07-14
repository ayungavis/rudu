#!/bin/bash

# Performance test script for rudu optimizations
# Usage: ./scripts/performance_test.sh [directory]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default directory to scan
SCAN_DIR="${1:-/Users/ayungavis}"
RUDU_BINARY="./target/release/rudu"

echo -e "${BLUE}🚀 Rudu Performance Test${NC}"
echo -e "${BLUE}========================${NC}"
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

echo -e "${YELLOW}📁 Testing directory: $SCAN_DIR${NC}"
echo ""

# Clear cache before testing
echo -e "${YELLOW}🗑️  Clearing rudu cache...${NC}"
$RUDU_BINARY --clear-cache > /dev/null 2>&1 || true

# Function to run benchmark
run_test() {
    local name="$1"
    local output_file="$2"
    local runs=3
    local total_time=0

    echo -e "${BLUE}Testing $name...${NC}"

    for i in $(seq 1 $runs); do
        echo -n "  Run $i/3: "
        start_time=$(date +%s.%N)
        $RUDU_BINARY -q -n 10 "$SCAN_DIR" > /dev/null 2>&1
        end_time=$(date +%s.%N)

        # Use awk for floating point arithmetic
        run_time=$(awk "BEGIN {printf \"%.2f\", $end_time - $start_time}")
        echo "${run_time}s"
        total_time=$(awk "BEGIN {print $total_time + $run_time}")
    done

    # Calculate average using awk
    avg_time=$(awk "BEGIN {printf \"%.2f\", $total_time / $runs}")
    echo -e "  ${GREEN}Average: ${avg_time}s${NC}"
    echo ""

    # Save the average time to file
    echo "$avg_time" > "$output_file"
}

# Test optimized version (no cache)
echo -e "${YELLOW}🏃 Running performance test (3 runs each)...${NC}"
echo ""

# Create temp files for storing results
TEMP_DIR=$(mktemp -d)
OPTIMIZED_FILE="$TEMP_DIR/optimized_time"
CACHED_FILE="$TEMP_DIR/cached_time"

# Test optimized version (no cache)
run_test "Optimized Rudu (no cache)" "$OPTIMIZED_FILE"

# Test with cache
echo -e "${BLUE}Populating cache...${NC}"
$RUDU_BINARY -q -c -n 10 "$SCAN_DIR" > /dev/null 2>&1

run_test "Optimized Rudu (cached)" "$CACHED_FILE"

# Read results
OPTIMIZED_TIME=$(cat "$OPTIMIZED_FILE")
CACHED_TIME=$(cat "$CACHED_FILE")

# Generate results
echo -e "${GREEN}✅ Performance test complete!${NC}"
echo ""
echo -e "${YELLOW}📊 Results Summary:${NC}"
echo -e "  Optimized (no cache): ${OPTIMIZED_TIME}s"
echo -e "  Optimized (cached):   ${CACHED_TIME}s"

# Calculate cache speedup
if [ "$CACHED_TIME" != "0.00" ] && [ "$CACHED_TIME" != "0" ]; then
    CACHE_SPEEDUP=$(awk "BEGIN {printf \"%.2f\", $OPTIMIZED_TIME / $CACHED_TIME}")
    echo -e "  Cache speedup:        ${CACHE_SPEEDUP}x faster"
else
    echo -e "  Cache speedup:        Very fast (cached time too small to measure)"
fi

# Clean up
rm -rf "$TEMP_DIR"
echo ""

echo -e "${GREEN}🎯 Optimizations implemented:${NC}"
echo -e "  • Parallel file processing with worker threads"
echo -e "  • Streaming processing (no file collection phase)"
echo -e "  • Optimized memory usage with pre-allocated capacity"
echo -e "  • Faster hashing with AHash"
echo -e "  • Reduced progress bar update frequency"
echo -e "  • Efficient path operations with minimal allocations"
echo ""
