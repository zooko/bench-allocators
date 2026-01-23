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

**CPU:**  Intel(R) Xeon(R) Gold 6152 CPU @ 2.10GHz **OS:** linux-gnu  

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

**git commit:** e0a8dfa798a73be005820a3f7c677d9196d9bf3c  
**git clean status:** Clean  
**generated:** 2026-01-23 06:42:30 UTC  
