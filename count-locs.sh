#!/bin/bash

echo smalloc
pushd smalloc/smalloc
find . -name '*-noda.*' -print0 | xargs -0 rm -f
for F in src/lib.rs src/i/plat.rs; do F2="${F%.*}-noda.${F##*.}" ; grep -v debug_assert ${F} > ${F2} ; done
tokei `find . -name '*-noda.*'`
find . -name '*-noda.*' -print0 | xargs -0 rm -f
cd ..

echo smalloc-ffi
cd smalloc-ffi
find . -name '*-noa.*' -print0 | xargs -0 rm -f
for F in `find . -name '*.rs' -o -name '*.c' -o -name '*.h'`; do F2="${F%.*}-noa.${F##*.}" ; grep -v -i assert ${F} > ${F2} ; done
tokei `find . -name "*-noa.*"`
find . -name '*-noa.*' -print0 | xargs -0 rm -f
popd

echo rpmalloc
pushd rpmalloc/rpmalloc
find . -name '*-noa.*' -print0 | xargs -0 rm -f
for F in `find . -name '*.c' -o -name '*.h'`; do F2="${F%.*}-noa.${F##*.}" ; grep -v -i assert ${F} > ${F2} ; done
tokei `find . -name '*-noa.*'`
find . -name '*-noa.*' -print0 | xargs -0 rm -f
popd

echo glibc
pushd glibc/malloc
find . -name '*-noa.*' -print0 | xargs -0 rm -f
for F in `find . -name '*.c' -o -name '*.h'`; do F2="${F%.*}-noa.${F##*.}" ; grep -v -i assert ${F} > ${F2} ; done
tokei `find . -name "*-noa.*" ! -name "tst-*"`
find . -name '*-noa.*' -print0 | xargs -0 rm -f
popd

echo mimalloc
pushd mimalloc/src
find . -name '*-noa.*' -print0 | xargs -0 rm -f
for F in `find . -name '*.c' -o -name '*.h'`; do F2="${F%.*}-noa.${F##*.}" ; grep -v -i assert ${F} > ${F2} ; done
tokei `find . -name '*-noa.*'`
find . -name '*-noa.*' -print0 | xargs -0 rm -f
popd

echo snmalloc
pushd snmalloc/src
find . -name '*-noa.*' -print0 | xargs -0 rm -f
for F in `find . -name '*.c' -o -name '*.h'`; do F2="${F%.*}-noa.${F##*.}" ; grep -v -i assert ${F} > ${F2} ; done
tokei `find . -name "*-noa.*"`
find . -name '*-noa.*' -print0 | xargs -0 rm -f
popd

echo jemalloc
pushd jemalloc/src
find . -name '*-noa.*' -print0 | xargs -0 rm -f
for F in `find . -name '*.c' -o -name '*.h'`; do F2="${F%.*}-noa.${F##*.}" ; grep -v -i assert ${F} > ${F2} ; done
tokei `find . -name "*-noa.*"`
find . -name '*-noa.*' -print0 | xargs -0 rm -f
popd
