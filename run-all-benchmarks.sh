#!/bin/bash
set -e

source "$(dirname "$0")/tools.sh"

# Directories
WORK_DIR="${WORK_DIR:-./benchmark-workspace}"
SIMD_JSON_REPO="https://github.com/zooko/simd-json"
REBAR_REPO="https://github.com/zooko/rebar"
SMALLOC_REPO="https://github.com/zooko/smalloc"

OUTPUT_BASE_DIR=./benchmark-results

OUTPUT_DIR="${OUTPUT_BASE_DIR}/${CPUSTR_DOT_OSSTR}"

# THE FOLLOWING LINES BLOW AWAY ALL CONTENTS OF THE OUTPUT BASE DIR (${OUTPUT_BASE_DIR}). (This is
# necessary to make multiple successive runs of this script show "git clean" instead of "git
# uncommitted changes".)

git clean -fd "$OUTPUT_BASE_DIR"
git restore "$OUTPUT_BASE_DIR"
mkdir -p "$OUTPUT_DIR"

# Create directories
mkdir -p "$WORK_DIR"

ARGS=$*

echo "========================================"
echo "Allocator Benchmark Suite"
echo "========================================"
echo "timestamp: ${TIMESTAMP}"
gather_and_print_git_metadata
print_machine_metadata
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

    pushd "$WORK_DIR"

    ../count-locs.sh ${SMALLOC_ONLY}

    python3 "../locs-graph.py" \
        "loc-output.txt" \
        --graph "../$OUTPUT_DIR/locs.graph.svg" \
        "${METADATA_ARGS_TO_PASS_TO_PYTHON_SCRIPT[@]}" \
        --smalloc-dep-version $(get_smalloc_dep_version "smalloc")

    cp "loc-output.txt" "../$OUTPUT_DIR/locs.result.txt"

    popd
}

# Function to run benchmark in simd-json, rebar, or smalloc repos
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
    ./bench-allocators.sh "${SMALLOC_ONLY}"

    popd

    # Copy results (one txt, any number of svgs)
    cp "$dir/${OUTPUT_DIR}/${name}.result.txt" "$OUTPUT_DIR/${name}.result.txt"
    cp $dir/${OUTPUT_DIR}/${name}.graph*.svg "$OUTPUT_DIR/"
}

# Run benchmarks
run_loc_benchmark
run_benchmark "simd-json" "$SIMD_JSON_REPO"
run_benchmark "rebar" "$REBAR_REPO"
run_benchmark "smalloc" "$SMALLOC_REPO"

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

**CPU:** $CPU_TYPE_STR
**OS:** $OS_TYPE_STR

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

![](smalloc.graph-st.svg)

### Multi-Threaded Performance

![](smalloc.graph-mt.svg)

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

**git source:** $GIT_SOURCE
**git commit:** $GIT_COMMIT
**git tag:** $GIT_TAG
**git clean status:** $GIT_CLEAN_STATUS
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
