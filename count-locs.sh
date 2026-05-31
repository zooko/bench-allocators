#!/bin/bash

source "$(dirname "$0")/tools.sh"

if ! command -v tokei >/dev/null 2>&1; then
    echo "Need tokei installed to generate lines-of-code comparison. Install it with \"cargo install tokei\"."
    return 1
fi 

ALLOCATOR_LIST+=("glibc")
ALLOCATOR_LIST+=("smalloc")

OUTPUT_FILE="loc-output.txt"
rm $OUTPUT_FILE

for ALLOCATOR in "${ALLOCATOR_LIST[@]}"; do
    case "$ALLOCATOR" in
        glibc)
            url="https://sourceware.org/git/glibc.git"
            subdir=malloc
            ;;
        jemalloc)
            url="https://github.com/jemalloc/jemalloc"
            subdir=src
            ;;
        snmalloc)
            url="https://github.com/microsoft/snmalloc"
            subdir=src
            ;;
        mimalloc)
            url="https://github.com/microsoft/mimalloc"
            subdir=src
            ;;
        rpmalloc)
            url="https://github.com/mjansson/rpmalloc"
            subdir=rpmalloc
            ;;
        smalloc)
            url="https://github.com/zooko/smalloc"
            subdir=smalloc
            FILES_LIST=("src/lib.rs" "src/i/plat.rs")
            ;;
        *)
            echo "Error: $ALLOCATOR not found in table of git URLs"
            # If there's a already a directory named $ALLOCATOR we'll try using that, else exit.
            [ -d "$ALLOCATOR" ] || exit 1
            ;;
    esac

    echo "Cloning allocator sources for LOC comparison..."
    [ -d "$ALLOCATOR" ] || git clone --depth 1 --tags $url

    echo $ALLOCATOR | tee -a $OUTPUT_FILE
    pushd $ALLOCATOR
    gather_and_print_git_metadata | tee -a ../$OUTPUT_FILE
    cd $subdir

    find . -name '*-noa.*' -print0 | xargs -0 rm -f
    if [[ -n "${FILES_LIST[*]}" ]]; then
        FILES=${FILES_LIST[*]}
    else
        # tst-*.{c,h} is where glibc keeps test code. We don't count test code.
        FILES=$( find . \( -name '*.c' -o -name '*.h' -o -name '*.rs' \) ! -name 'tst-*' )
    fi

    noa_files=()
    for FILE in ${FILES[*]}; do
        FILENOA="${FILE%.*}-noa.${FILE##*.}"
        case "$FILE" in
            *.c|*.h)
                # We don't count asserts in C files.
                grep -v -i assert "${FILE}" > "${FILENOA}"
                noa_files+=("${FILENOA}")
                ;;
            *.rs)
                # We don't count debug_asserts in Rust files.
                grep -v debug_assert "${FILE}" > "${FILENOA}"
                noa_files+=("${FILENOA}")
                ;;
        esac
    done

    tokei ${noa_files[*]} | tee -a ../../$OUTPUT_FILE
    find . -name '*-noa.*' -print0 | xargs -0 rm -f
    popd
done
