#!/bin/bash

# Configuration
WORK_DIR="${WORK_DIR:-./benchmark-workspace}"
SIMD_JSON_REPO="https://github.com/zooko/simd-json"
REBAR_REPO="https://github.com/zooko/rebar"

# Collect metadata
GITCOMMIT=$(git log -1 | head -1 | cut -d' ' -f2)
GITCLEANSTATUS=$( [ -z "$( git status --porcelain )" ] && echo "Clean" || echo "Uncommitted changes" )
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

# CPU type on linuxy
CPUTYPE=$(grep "model name" /proc/cpuinfo 2>/dev/null | uniq | cut -d':' -f2-)
if [ -z "${CPUTYPE}" ] ; then
    # CPU type on macos
    CPUTYPE=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")
fi
CPUTYPESTR="${CPUTYPE//[^[:alnum:]]/}"
OSTYPESTR="${OSTYPE//[^[:alnum:]]/}"
CPUSTR_DOT_OSSTR="${CPUTYPESTR}.${OSTYPESTR}"
OUTPUT_DIR="${OUTPUT_DIR:-./benchmark-results}/${CPUSTR_DOT_OSSTR}"

echo "========================================"
echo "Allocator Benchmark Suite"
echo "========================================"
echo "CPU: $CPUTYPE"
echo "OS: $OSTYPE"
echo "git commit: $GITCOMMIT"
echo "git clean status: $GITCLEANSTATUS"
echo "Timestamp: $TIMESTAMP"
echo "Work directory: $WORK_DIR"
echo "Output directory: $OUTPUT_DIR"
echo "========================================"
echo

# Create directories
mkdir -p "$WORK_DIR"
mkdir -p "$OUTPUT_DIR"

# Add this function
run_loc_benchmark() {
    echo
    echo "========================================"
    echo "Running lines-of-code comparison..."
    echo "========================================"

    # Clone the allocator source repos that count-locs.sh needs
    pushd "$WORK_DIR"

    echo "Cloning allocator sources for LOC comparison..."

    [ -d "glibc" ] || git clone --depth 1 https://sourceware.org/git/glibc.git
    [ -d "jemalloc" ] || git clone --depth 1 https://github.com/jemalloc/jemalloc
    [ -d "snmalloc" ] || git clone --depth 1 https://github.com/microsoft/snmalloc
    [ -d "mimalloc" ] || git clone --depth 1 https://github.com/microsoft/mimalloc
    [ -d "rpmalloc" ] || git clone --depth 1 https://github.com/mjansson/rpmalloc
    [ -d "smalloc" ] || git clone --depth 1 https://github.com/zooko/smalloc

    # Run count-locs.sh and capture output
    echo "Counting lines of code..."
    "../count-locs.sh" > "loc-output.txt" 2>&1

    python3 "../locs-graph.py" \
        "loc-output.txt" \
        --commit "$GITCOMMIT" \
        --git-status "$GITCLEANSTATUS" \
        --cpu "$CPUTYPESTR" \
        --os "$OSTYPESTR" \
        --graph "../$OUTPUT_DIR/locs.graph.svg"

    # Copy results
    cp "loc-output.txt" "../$OUTPUT_DIR/locs.result.txt"

    popd
}

# Function to run benchmark in a repo
run_benchmark() {
    local name=$1
    local repo=$2
    local dir="$WORK_DIR/$name"

    echo
    echo "========================================"
    echo "Running $name benchmarks..."
    echo "========================================"

    # Clone or update
    if [ -d "$dir" ]; then
        echo "Updating $dir..."
        pushd "$dir"
        git pull
    else
        echo "Cloning $repo to $dir..."
        git clone "$repo" "$dir"
        pushd "$dir"
    fi
    
    # Run benchmark
    ./bench-allocators.sh
    
    popd
    
    # Copy results
    cp $dir/${OUTPUT_DIR}/${name}.result.txt "$OUTPUT_DIR/${name}.result.txt"
    cp $dir/${OUTPUT_DIR}/${name}.graph.svg "$OUTPUT_DIR/${name}.graph.svg"
}

# Run benchmarks
run_loc_benchmark
run_benchmark "simd-json" "$SIMD_JSON_REPO"
run_benchmark "rebar" "$REBAR_REPO"

# Generate combined report
REPORT_FILE="$OUTPUT_DIR/COMBINED-REPORT.md"

echo
echo "========================================"
echo "Generating combined report"
echo "========================================"

cat > "$REPORT_FILE" << EOF
# Allocator Performance Benchmarks

This report compares memory allocator performance in different codebases.

Allocators:

- default: the default Rust global allocator, which in current Rust falls through to the system
  allocator
- [jemalloc](https://github.com/jemalloc/jemalloc): using
  [tikv-jemallocator](https://github.com/tikv/jemallocator) Rust wrappers
- [snmalloc](https://github.com/microsoft/snmalloc): using
  [snmalloc-rs](https://github.com/SchrodingerZhu/snmalloc-rs) Rust wrappers
- [mimalloc](https://github.com/microsoft/mimalloc): using
  [mimalloc_rust](https://github.com/purpleprotocol/mimalloc_rust) Rust wrappers
- [rpmalloc](https://github.com/mjansson/rpmalloc): using
  [rpmalloc-rs](https://github.com/EmbarkStudios/rpmalloc-rs) Rust wrappers
- [smalloc](https://github.com/zooko/smalloc): (written in Rust)

Count Lines-of-Code:

- the number of lines of source code (excluding debug assertions) in the allocator implementation

Work-loads:

- [simd-json](https://github.com/simd-lite/simd-json): High-performance JSON parser ([fork for
  benchmarking](https://github.com/zooko/simd-json))
- [rebar](https://github.com/BurntSushi/rebar): Regex engine benchmark harness ([fork for
  benchmarking](https://github.com/zooko/simd-json))

**CPU:** $CPUTYPE **OS:** $OSTYPE  

---

## Lines of Code Comparison

![](locs.graph.svg)

[View detailed LOC results](locs.result.txt)

---

## simd-json Results

![](simd-json.graph.svg)

[View detailed simd-json results](simd-json.result.txt)

---

## rebar Results

![](rebar.graph.svg)

[View detailed rebar results](rebar.result.txt)

---

## Summary

- **Lines of Code** compares implementation size (excluding debug assertions)  
- **simd-json** tests memory allocation performance in simd-json (JSON parsing)  
- **rebar** tests memory allocation performance in rebar (regex compilation and matching)  

### Methodology

- Each allocator is tested using identical code with only the global allocator changed
- Summary is the mean of normalized performance ratios across all tests
- Results show percentage differences from baseline (system allocator)
- Lower percentages = better performance (less time)

### How to Read the Performance Graphs

- **Baseline (default)**: The system allocator, shown at 100%
- **Negative percentages**: Faster than baseline (e.g., -3% means 3% faster)
- **Positive percentages**: Slower than baseline (e.g., +5% means 5% slower)
- **Bar height**: Proportional to execution time

---

Source: https://github.com/zooko/bench-allocators

**git commit:** $GITCOMMIT  
**git clean status:** $GITCLEANSTATUS  
**generated:** $TIMESTAMP  
EOF

echo
echo "========================================"
echo "✅ All benchmarks complete!"
echo "========================================"
echo "Results directory: $OUTPUT_DIR"
echo "Combined report: $REPORT_FILE"
echo
echo "Files generated:"
ls -lh "$OUTPUT_DIR"
echo
echo "To view the report with graphs:"
echo "  - Open in GitHub (graphs will render)"
echo "  - Or use a markdown viewer that supports SVG"
echo "  - Or open in a browser: file://$PWD/$REPORT_FILE"
