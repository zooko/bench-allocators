#!/bin/bash
set -e

# Configuration
WORK_DIR="${WORK_DIR:-./benchmark-workspace}"
SIMD_JSON_REPO="https://github.com/zooko/simd-json"
REBAR_REPO="https://github.com/zooko/rebar"
SMALLOC_REPO="https://github.com/zooko/smalloc"

# Collect metadata
GITCOMMIT=$(git rev-parse HEAD)
GITCLEANSTATUS=$( [ -z "$( git status --porcelain )" ] && echo "Clean" || echo "Uncommitted changes" )
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

# Detect CPU type
# try Linux first
if command -v sysctl >/dev/null 2>&1; then
    CPUTYPE=$(lscpu 2>/dev/null | grep -i "model name" | cut -d':' -f2-)
elif command -v sysctl >/dev/null 2>&1; then
    # macOS
    CPUTYPE=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
fi
CPUTYPE=${CPUTYPE:-Unknown}
CPUTYPE=${CPUTYPE## }  # Trim leading space

CPUTYPESTR="${CPUTYPE//[^[:alnum:]]/}"
OSTYPESTR="${OSTYPE//[^[:alnum:]]/}"

CPUCOUNT=$(nproc 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || echo "${NUMBER_OF_PROCESSORS:-unknown}")

CPUSTR_DOT_OSSTR="${CPUTYPESTR}.${OSTYPESTR}"
OUTPUT_DIR="${OUTPUT_DIR:-./benchmark-results}/${CPUSTR_DOT_OSSTR}"

# Create directories
mkdir -p "$WORK_DIR"
mkdir -p "$OUTPUT_DIR"

echo "========================================"
echo "Allocator Benchmark Suite"
echo "========================================"
echo "git commit: $GITCOMMIT"
echo "git clean status: $GITCLEANSTATUS"
echo "CPU: $CPUTYPE"
echo "OS: $OSTYPE"
echo "CPU count: $CPUCOUNT"
echo "Timestamp: $TIMESTAMP"
echo "Work directory: $WORK_DIR"
echo "Output directory: $OUTPUT_DIR"
echo "========================================"
echo

if ! command -v cargo >/dev/null 2>&1; then
    echo "Need cargo installed."
    exit 1
fi

# Lines-of-code benchmark
run_loc_benchmark() {
    echo
    echo "========================================"
    echo "Running lines-of-code comparison..."
    echo "========================================"

    if ! command -v tokei >/dev/null 2>&1; then
        echo "Need tokei installed to generate lines-of-code comparison. Install it with \"cargo install tokei\"."
        return 1
    fi 
    pushd "$WORK_DIR"

    echo "Cloning allocator sources for LOC comparison..."
    [ -d "glibc" ] || git clone --depth 1 https://sourceware.org/git/glibc.git
    [ -d "jemalloc" ] || git clone --depth 1 https://github.com/jemalloc/jemalloc
    [ -d "snmalloc" ] || git clone --depth 1 https://github.com/microsoft/snmalloc
    [ -d "mimalloc" ] || git clone --depth 1 https://github.com/microsoft/mimalloc
    [ -d "rpmalloc" ] || git clone --depth 1 https://github.com/mjansson/rpmalloc
    [ -d "smalloc" ] || git clone --depth 1 https://github.com/zooko/smalloc

    echo "Counting lines of code..."
    "../count-locs.sh" > "loc-output.txt" 2>&1

    python3 "../locs-graph.py" \
        "loc-output.txt" \
        --commit "$GITCOMMIT" \
        --git-status "$GITCLEANSTATUS" \
        --cpu "$CPUTYPESTR" \
        --os "$OSTYPESTR" \
        --graph "../$OUTPUT_DIR/locs.graph.svg"

    cp "loc-output.txt" "../$OUTPUT_DIR/locs.result.txt"

    popd
}

# Function to run benchmark in simd-json or rebar repos (standard interface)
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

    # Copy results (1 txt, 1 svg)
    cp "$dir/${OUTPUT_DIR}/${name}.result.txt" "$OUTPUT_DIR/${name}.result.txt"
    cp "$dir/${OUTPUT_DIR}/${name}.graph.svg" "$OUTPUT_DIR/${name}.graph.svg"
}

# Function to run smalloc benchmark (different interface: runbench.sh, 1 txt, 2 svgs)
run_smalloc_benchmark() {
    local name="smalloc"
    local repo="$SMALLOC_REPO"
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

    # Run benchmark (different script name)
    ./runbench.sh

    popd

    # Copy results (1 txt, 2 svgs - st and mt)
    # smalloc outputs to bench/results/{CPU}.{OS}/
    local smalloc_results_dir="$dir/bench/results/${CPUSTR_DOT_OSSTR}"

    cp "$smalloc_results_dir/cargo-bench.result.txt" "$OUTPUT_DIR/smalloc.result.txt"
    cp "$smalloc_results_dir/cargo-bench.graph-st.svg" "$OUTPUT_DIR/smalloc-st.graph.svg"
    cp "$smalloc_results_dir/cargo-bench.graph-mt.svg" "$OUTPUT_DIR/smalloc-mt.graph.svg"
}

# Run benchmarks
run_loc_benchmark
run_benchmark "simd-json" "$SIMD_JSON_REPO"
run_benchmark "rebar" "$REBAR_REPO"
run_smalloc_benchmark

# Generate combined report
REPORT_FILE="$OUTPUT_DIR/COMBINED-REPORT.md"

echo
echo "========================================"
echo "Generating combined report"
echo "========================================"

cat > "$REPORT_FILE" << EOF
# Allocator Performance Benchmarks

This report compares memory allocator performance across different workloads.

## Allocators Tested

- **default**: the default Rust global allocator (falls through to system allocator)
- [jemalloc](https://github.com/jemalloc/jemalloc): using [tikv-jemallocator](https://github.com/tikv/jemallocator) Rust wrappers
- [snmalloc](https://github.com/microsoft/snmalloc): using [snmalloc-rs](https://github.com/SchrodingerZhu/snmalloc-rs) Rust wrappers
- [mimalloc](https://github.com/microsoft/mimalloc): using [mimalloc_rust](https://github.com/purpleprotocol/mimalloc_rust) Rust wrappers
- [rpmalloc](https://github.com/mjansson/rpmalloc): using [rpmalloc-rs](https://github.com/EmbarkStudios/rpmalloc-rs) Rust wrappers
- [smalloc](https://github.com/zooko/smalloc): a simple memory allocator (written in Rust)

## Workloads

- **Lines of Code**: Implementation size comparison (excluding debug assertions)
- **simd-json**: High-performance JSON parser ([fork for benchmarking](https://github.com/zooko/simd-json))
- **rebar**: Regex engine benchmark harness ([fork for benchmarking](https://github.com/zooko/rebar))
- **smalloc bench**: Micro-benchmarks for malloc/free/realloc operations

**CPU:** $CPUTYPE
**OS:** $OSTYPE

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

## smalloc Micro-Benchmarks

### Single-Threaded Performance

![](smalloc-st.graph.svg)

### Multi-Threaded Performance

![](smalloc-mt.graph.svg)

[View detailed smalloc benchmark results](smalloc.result.txt)

---

## Summary

- **Lines of Code** compares implementation size (excluding debug assertions)
- **simd-json** tests allocator performance during JSON parsing
- **rebar** tests allocator performance during regex compilation and matching
- **smalloc bench** tests raw malloc/free/realloc performance in single and multi-threaded scenarios

### Methodology

- Each allocator is tested using identical code with only the global allocator changed
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
