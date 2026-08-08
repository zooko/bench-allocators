#!/usr/bin/env bash
set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT="$SCRIPT_DIR"

cd "$REPO_ROOT"
source "$SCRIPT_DIR/tools/tools.sh"

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

LOC_ALLOCATOR_METADATA_FILE="$PWD/$WORK_DIR/loc-allocator-metadata.txt"
FULL_METADATA_FILE="$PWD/$WORK_DIR/full-run-metadata.txt"

WORKLOAD_METADATA_DIR="$PWD/$WORK_DIR/workload-metadata"
WORKLOAD_LOCK_METADATA_FILE="$PWD/$WORK_DIR/workload-lock-metadata.txt"

mkdir -p "$WORKLOAD_METADATA_DIR"

prepare_repo() {
    local name="$1"
    local repo="$2"
    local dir="$WORK_DIR/$name"

    if [[ -d "$dir/.git" ]]; then
        echo "Updating $dir..."
        git -C "$dir" pull --ff-only
    else
        echo "Cloning $repo to $dir..."
        git clone "$repo" "$dir"
    fi
}

restore_workload_lockfiles() {
    local workload

    for workload in smalloc simd-json rebar; do
        if git -C "$WORK_DIR/$workload" \
            ls-files --error-unmatch Cargo.lock \
            >/dev/null 2>&1
        then
            git -C "$WORK_DIR/$workload" restore -- Cargo.lock
        fi
    done
}

save_workload_git_statuses() {
    local workload
    local directory
    local status

    for workload in smalloc simd-json rebar; do
        directory="$WORK_DIR/$workload"

        if [[ -z "$(git -C "$directory" status --porcelain)" ]]; then
            status=clean
        else
            status="dirty-$(
                git -C "$directory" diff --binary HEAD |
                b3sum --no-names
            )"
        fi

        printf '%s\n' "$status" \
            >"$WORKLOAD_METADATA_DIR/$workload.git-clean-status"
    done
}

write_workload_lock_metadata() {
    local workload
    local lockfile

    {
        echo "Prepared workload lockfile metadata"
        echo "==================================="

        for workload in smalloc simd-json rebar; do
            lockfile="$WORK_DIR/$workload/Cargo.lock"

            echo
            echo "workload: $workload"
            echo "Cargo.lock: $PWD/$lockfile"
            echo "Cargo.lock BLAKE3: $(b3sum --no-names "$lockfile")"
        done
    } >"$WORKLOAD_LOCK_METADATA_FILE"
}

restore_workload_lockfiles() {
    local workload

    for workload in smalloc simd-json rebar; do
        if git -C "$WORK_DIR/$workload" \
            ls-files --error-unmatch Cargo.lock \
            >/dev/null 2>&1
        then
            git -C "$WORK_DIR/$workload" restore -- Cargo.lock
        fi
    done
}

lock_contains_package() {
    local lockfile="$1"
    local wanted="$2"

    awk -v wanted="$wanted" '
        $0 == "[[" "package" "]]" {
            in_package = 1
            next
        }
        in_package && /^name = / {
            name = $0
            sub(/^name = "/, "", name)
            sub(/"$/, "", name)

            if (name == wanted) {
                found = 1
                exit
            }
        }

        END {
            exit !found
        }
    ' "$lockfile"
}

prepare_workload_allocator_versions() {
    local directory="$1"

    (
        cd "$directory"

        while IFS=$'\t' read -r package version manifest; do
            if lock_contains_package Cargo.lock "$package"; then
                cargo update \
                    -p "$package" \
                    --precise "$version"
            fi
        done < "$ALLOCATOR_PINS_FILE"

        # Complete dependency resolution with every allocator feature
        # enabled. This is allowed to update Cargo.lock. The subsequent
        # verification and benchmark builds use --locked.
        cargo metadata \
            --format-version=1 \
            --all-features \
            >/dev/null
    )
}

verify_workload_allocator_versions() {
    local directory="$1"
    local metadata_json

    metadata_json=$(
        cd "$directory"
        cargo metadata \
            --locked \
            --format-version=1 \
            --all-features
    )

    while IFS=$'\t' read -r package version expected_manifest; do
        actual=$(
            printf '%s' "$metadata_json" |
            jq -r --arg package "$package" '
                [
                    .packages[]
                    | select(.name == $package)
                    | .manifest_path
                ][0] // ""
            '
        )

        # A workload need not use every allocator package.
        if [[ -n "$actual" && "$actual" != "$expected_manifest" ]]; then
            echo "Error: $directory resolves $package from the wrong source." >&2
            echo "Expected: $expected_manifest" >&2
            echo "Actual:   $actual" >&2
            exit 1
        fi
    done < "$ALLOCATOR_PINS_FILE"
}

append_allocator_metadata() {
    local result_file="$1"

    {
        echo
        echo
        cat "$ALLOCATOR_METADATA_FILE"
    } >> "$result_file"
}

write_loc_allocator_metadata() {
    local output_file="$1"

    {
        echo "LOC allocator Git-source metadata"
        echo "================================="

        for allocator in jemalloc mimalloc rpmalloc snmalloc smalloc; do
            local directory="$allocator"

            if [[ ! -d "$directory/.git" ]]; then
                echo "Error: count-locs did not create a Git checkout at $PWD/$directory" >&2
                return 1
            fi

            local source
            local commit
            local tree
            local tag
            local clean_status
            local diff_hash
            local source_hash

            source=$(git -C "$directory" remote get-url origin)
            commit=$(git -C "$directory" rev-parse HEAD)
            tree=$(git -C "$directory" rev-parse 'HEAD^{tree}')
            tag=$(git -C "$directory" describe --tags --exact-match 2>/dev/null || true)

            if [[ -z "$(git -C "$directory" status --porcelain)" ]]; then
                clean_status=clean
            else
                clean_status=dirty
            fi

            diff_hash=$(
                git -C "$directory" diff --binary HEAD |
                b3sum --no-names
            )

            source_hash=$(
                git -C "$directory" archive --format=tar HEAD |
                b3sum --no-names
            )

            echo
            echo "allocator: $allocator"
            echo "git source: $source"
            echo "git commit: $commit"
            echo "git tree: $tree"
            echo "git tag: $tag"
            echo "git clean status: $clean_status"
            echo "git diff BLAKE3: $diff_hash"
            echo "committed source-tree BLAKE3: $source_hash"
        done

        echo
        echo "count-locs.sh BLAKE3: $(b3sum --no-names ../count-locs.sh)"
    } >"$output_file"
}

append_loc_allocator_metadata() {
    local result_file="$1"

    {
        echo
        echo
        cat "$LOC_ALLOCATOR_METADATA_FILE"
    } >>"$result_file"
}

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

    # count-locs.sh uses Git checkouts rather than Cargo dependencies.
    # Capture the exact Git sources that it actually counted.
    write_loc_allocator_metadata "$LOC_ALLOCATOR_METADATA_FILE"

    python3 "../tools/locs-graph.py" \
        "loc-output.txt" \
        --graph "../$OUTPUT_DIR/locs.graph.svg" \
        "${METADATA_ARGS_TO_PASS_TO_PYTHON_SCRIPT[@]}" \
        --smalloc-dep-version "$(get_smalloc_dep_version "smalloc")"

    cp "loc-output.txt" "../$OUTPUT_DIR/locs.result.txt"
    append_loc_allocator_metadata "../$OUTPUT_DIR/locs.result.txt"

    popd
}

embed_metadata_in_svg() {
    local svg_file="$1"
    local metadata_file="$2"
    local temporary="${svg_file}.tmp"

    awk -v metadata_file="$metadata_file" '
        /<\/svg>/ && !inserted {
            print "  <!--"

            while ((getline line < metadata_file) > 0) {
                # XML comments may not contain "--".
                gsub(/--/, "- -", line)
                print "  " line
            }

            close(metadata_file)
            print "  -->"
            inserted = 1
        }

        {
            print
        }

        END {
            if (!inserted) {
                print "Error: no </svg> element found" > "/dev/stderr"
                exit 1
            }
        }
    ' "$svg_file" >"$temporary"

    mv "$temporary" "$svg_file"
}

# Function to run benchmark in simd-json, rebar, or smalloc repos
run_benchmark() {
    local name=$1
    local repo=$2
    shift 2
    local dir="$WORK_DIR/$name"
    local original_git_status

    original_git_status=$(
        cat "$WORKLOAD_METADATA_DIR/$name.git-clean-status"
    )

    echo
    echo "========================================"
    echo "Running $name benchmarks..."
    echo "========================================"

    pushd "$dir"

    # Run benchmark
    if [[ -n "$SMALLOC_ONLY" ]]; then
        BENCHMARK_GIT_CLEAN_STATUS_OVERRIDE="$original_git_status" ./tools/bench-allocators.sh "$SMALLOC_ONLY" "$@"
    else
        BENCHMARK_GIT_CLEAN_STATUS_OVERRIDE="$original_git_status" ./tools/bench-allocators.sh "$@"
    fi
    if [[ -n "$SMALLOC_ONLY" ]]; then
        ./tools/bench-allocators.sh "$SMALLOC_ONLY" "$@"
    else
        ./tools/bench-allocators.sh "$@"
    fi
    popd

    # Copy results (one txt, any number of svgs)
    cp "$dir/${OUTPUT_DIR}/${name}.result.txt" "$OUTPUT_DIR/${name}.result.txt"
    {
        echo
        echo "Prepared workload Cargo.lock"
        echo "============================"
        echo "Cargo.lock BLAKE3: $(
            b3sum --no-names "$dir/Cargo.lock"
        )"
    } >>"$OUTPUT_DIR/${name}.result.txt"
    append_allocator_metadata "$OUTPUT_DIR/${name}.result.txt"
    cp $dir/${OUTPUT_DIR}/${name}.graph*.svg "$OUTPUT_DIR/"
}

# Prepare benchmark repositories first.
prepare_repo "smalloc" "$SMALLOC_REPO"
prepare_repo "simd-json" "$SIMD_JSON_REPO"
prepare_repo "rebar" "$REBAR_REPO"

# Discard lockfile changes left by an earlier completed or failed run.
restore_workload_lockfiles

# Record source-tree cleanliness before intentionally preparing Cargo.lock.
save_workload_git_statuses

# Restore committed lockfiles again whenever this script exits.
trap restore_workload_lockfiles EXIT INT TERM

# Start from each repository's committed lockfile. Restore them again
# when this script exits, including after an error or interruption.
restore_workload_lockfiles
trap restore_workload_lockfiles EXIT INT TERM

# The smalloc benchmark workspace's Cargo.lock is the canonical allocator
# dependency resolution for this complete benchmark run.
./tools/prepare-allocator-pins.py \
    "$WORK_DIR/smalloc" \
    "$WORK_DIR"

export ALLOCATOR_PINS_FILE="$PWD/$WORK_DIR/allocator-pins.tsv"
export ALLOCATOR_METADATA_FILE="$PWD/$WORK_DIR/allocator-metadata.txt"

# Cargo automatically discovers benchmark-workspace/.cargo/config.toml
# from every repository nested below benchmark-workspace.
for workload in smalloc simd-json rebar; do
    prepare_workload_allocator_versions "$WORK_DIR/$workload"
    verify_workload_allocator_versions "$WORK_DIR/$workload"
done

write_workload_lock_metadata

# Run benchmarks
run_loc_benchmark
run_benchmark "simd-json" "$SIMD_JSON_REPO" "${BENCHMARK_ARGS[@]}"
run_benchmark "rebar" "$REBAR_REPO" "${BENCHMARK_ARGS[@]}"
run_benchmark "smalloc" "$SMALLOC_REPO" "${BENCHMARK_ARGS[@]}"

# Generate combined report
REPORT_FILE="$OUTPUT_DIR/COMBINED-REPORT.md"

# Both metadata files now exist:
#
# - ALLOCATOR_METADATA_FILE describes the Cargo packages used by the
#   runtime benchmarks.
# - LOC_ALLOCATOR_METADATA_FILE describes the Git source trees counted
#   by count-locs.sh.
{
    echo "Benchmark run metadata"
    echo "======================"
    echo "timestamp: $TIMESTAMP"
    echo "git source: $GIT_SOURCE"
    echo "git commit: $GIT_COMMIT"
    echo "git tag: $GIT_TAG"
    echo "git clean status: $GIT_CLEAN_STATUS"
    echo "CPU type: $CPU_TYPE_STR"
    echo "CPU count: $CPU_COUNT"
    echo "OS type: $OS_TYPE_STR"

    echo
    cat "$ALLOCATOR_METADATA_FILE"

    echo
    cat "$WORKLOAD_LOCK_METADATA_FILE"

    echo
    cat "$LOC_ALLOCATOR_METADATA_FILE"
} >"$FULL_METADATA_FILE"

for svg_file in "$OUTPUT_DIR"/*.svg; do
    [[ -f "$svg_file" ]] || continue

    embed_metadata_in_svg \
        "$svg_file" \
        "$FULL_METADATA_FILE"
done

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

- **simd-json**: High-performance JSON parser ([fork for benchmarking](https://github.com/zooko/simd-json))
- **rebar**: Regex engine benchmark harness ([fork for benchmarking](https://github.com/zooko/rebar))
- **smalloc bench**: Micro-benchmarks for malloc/free/realloc operations
- **Lines of Code**: Implementation size comparison (excluding debug assertions)

**CPU:** $CPU_TYPE_STR
**OS:** $OS_TYPE_STR

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

## Lines of Code Comparison

![](locs.graph.svg)

[View detailed LOC results](locs.result.txt)

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
