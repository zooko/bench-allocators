To run all of the benchmarks against all of the allocators, execute

```code
./run-all-benchmarks.sh
```

It will generate a set of files in `./benchmark-results/$CPU.$OS/`. View
`./benchmark-results/$CPU.$OS/COMBINED-REPORT.md` or generate an HTML rendering of it with

```code
cd benchmark-results/$CPU.$OS/
pandoc COMBINED-REPORT.md --standalone -o COMBINED-REPORT.html
```

You can see some such reports committed into this git repo:

<a href="https://github.com/zooko/bench-allocators/blob/main/benchmark-results/AppleM4Max.darwin25/COMBINED-REPORT.md">
  <img src="https://raw.githubusercontent.com/zooko/bench-allocators/refs/heads/main/benchmark-results/AppleM4Max.darwin25/smalloc.graph-mt.svg" width="600">
</a>

(Click on the image.)

You can find benchmark results from other platforms in [benchmark-results](benchmark-results).

## Your Code Here

Make a script that runs benchmarks against your codebase, possibly following the examples of
https://github.com/zooko/rebar/blob/master/bench-allocators.sh and
https://github.com/zooko/simd-json/blob/master/bench-allocators.sh
(if your code is in Rust) or
https://github.com/zooko/mimalloc-bench/blob/master/bench-allocators.sh
(if your code is in C/C++/Zig/etc) and publish them and let me know by opening an issue or a
pull-request!

## License

You may use this work under the terms of any of these four Free and Open Source Software licences:

* MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
* Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
* Transitive Grace Period Public License 1.0 ([LICENSE-TGPPL](LICENSE-TGPPL) or https://spdx.org/licenses/TGPPL-1.0.html)
* Bootstrap Open Source License v1.0 ([LICENSE-BOSL.txt](LICENSE-BOSL.txt))
