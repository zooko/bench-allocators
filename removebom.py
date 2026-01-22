#!/usr/bin/env pypy3
"""
Remove any existing UTF-8 BOM from stdin and write to stdout.
Reads all of stdin as UTF-8, removes any BOM (EF BB BF), writes to stdout.
"""

import sys

def main():
    # Read all of stdin as bytes
    input_bytes = sys.stdin.buffer.read()

    if input_bytes[:3] == b'\xef\xbb\xbf':
        input_bytes = input_bytes[3:]

    try:
        # This will raise UnicodeDecodeError if input is not valid UTF-8
        input_text = input_bytes.decode('utf-8')
    except UnicodeDecodeError as e:
        print(f"ERROR: Input contains invalid UTF-8 data!", file=sys.stderr)
        print(f"  Position: byte {e.start} to {e.end}", file=sys.stderr)
        print(f"  Reason: {e.reason}", file=sys.stderr)
        print(f"  Invalid bytes: {e.object[e.start:e.end]}", file=sys.stderr)
        sys.exit(1)

    # Write the input text encoded as UTF-8 to stdout in binary mode
    sys.stdout.buffer.write(input_text.encode('utf-8'))

    # Flush to ensure everything is written
    sys.stdout.buffer.flush()

if __name__ == '__main__':
    main()
