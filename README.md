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

You can see some such reports committed into this git repo: [benchmark-results](benchmark-results).

# smalloc's own bench tool

Someone should extend this script to git checkout and run `smalloc`'s `bench` executable. To do it
manually in the meantime, get [the `smalloc` repo](https://github.com/zooko/smalloc) and run its
`./runbench.sh` script.

# mimalloc-bench

Someone should extend this script to git checkout and run `mimalloc-bench`. To do it manually in the
meantime, get this fork of the mimalloc-bench repo: https://github.com/zooko/mimalloc-bench and run
its [bench-allocators.sh](https://github.com/zooko/mimalloc-bench/blob/master/bench-allocators.sh)
script. (It works only on Linux in my experience.)

## License

You may use this work under the terms of any of these four Free and Open Source Software licences:

* MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
* Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
* Transitive Grace Period Public License 1.0 ([LICENSE-TGPPL](LICENSE-TGPPL) or https://spdx.org/licenses/TGPPL-1.0.html)
* Bootstrap Open Source License v1.0 ([LICENSE-BOSL.txt](LICENSE-BOSL.txt))
