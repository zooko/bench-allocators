#!/usr/bin/env pypy3
"""
Add UTF-8 BOM to stdin and write to stdout.
Reads all of stdin as UTF-8, prepends BOM (EF BB BF), writes to stdout.
"""

import sys

def main():
    try:
        # Read all of stdin as UTF-8 text
        # This will raise UnicodeDecodeError if input is not valid UTF-8
        input_text = sys.stdin.read()

    except UnicodeDecodeError as e:
        print(f"ERROR: Input contains invalid UTF-8 data!", file=sys.stderr)
        print(f"  Position: byte {e.start} to {e.end}", file=sys.stderr)
        print(f"  Reason: {e.reason}", file=sys.stderr)
        print(f"  Invalid bytes: {e.object[e.start:e.end]}", file=sys.stderr)
        sys.exit(1)

    # Write UTF-8 BOM (EF BB BF) to stdout in binary mode
    sys.stdout.buffer.write(b'\xef\xbb\xbf')

    # Write the input text encoded as UTF-8 to stdout in binary mode
    sys.stdout.buffer.write(input_text.encode('utf-8'))

    # Flush to ensure everything is written
    sys.stdout.buffer.flush()

if __name__ == '__main__':
    main()
