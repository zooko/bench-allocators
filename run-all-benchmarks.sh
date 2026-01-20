#!/bin/bash
set -e

echo "========================================="
echo "Running All Allocator Benchmarks"
echo "========================================="
echo

# Create output directory
OUTPUT_DIR="benchmark-results"
mkdir -p "$OUTPUT_DIR"

REPORT_FILE="$OUTPUT_DIR/COMBINED-REPORT.md"

# Get current timestamp
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Clean up old report
rm -f "$REPORT_FILE"

echo "========================================="
echo "1. Running simd-json benchmarks"
echo "========================================="

# Clone or update simd-json
if [ ! -d "simd-json" ]; then
    git clone https://github.com/zooko/simd-json.git
else
    cd simd-json
    git pull
    cd ..
fi

cd simd-json
./bench-allocators.sh

# Copy results to output directory
cp tmp/*.txt "$OUTPUT_DIR/simd-json.result.txt" 2>/dev/null || true
cp tmp/*.svg "$OUTPUT_DIR/simd-json.graph.svg" 2>/dev/null || true

cd ..

echo
echo "========================================="
echo "2. Running rebar benchmarks"
echo "========================================="

# Clone or update rebar
if [ ! -d "rebar" ]; then
    git clone https://github.com/zooko/rebar.git
else
    cd rebar
    git pull
    cd ..
fi

cd rebar
./bench-allocators.sh

# Copy results to output directory
cp tmp/*.txt "$OUTPUT_DIR/rebar.result.txt" 2>/dev/null || true
cp tmp/*.svg "$OUTPUT_DIR/rebar.graph.svg" 2>/dev/null || true

cd ..

echo
echo "========================================="
echo "3. Generating combined report"
echo "========================================="

# Generate markdown report
cat > "$REPORT_FILE" << EOF
# Allocator Benchmark Results

**Generated:** $TIMESTAMP

This report compares memory allocator performance across two different Rust workloads:
- **simd-json**: JSON parsing benchmark suite
- **rebar**: Regex engine benchmark suite

---

## simd-json Results

### Performance Graph

![simd-json allocator performance](simd-json.graph.svg)

### Detailed Results

\`\`\`
EOF

# Append simd-json results
if [ -f "$OUTPUT_DIR/simd-json.result.txt" ]; then
    cat "$OUTPUT_DIR/simd-json.result.txt" >> "$REPORT_FILE"
else
    echo "(Results file not found)" >> "$REPORT_FILE"
fi

cat >> "$REPORT_FILE" << 'EOF'
