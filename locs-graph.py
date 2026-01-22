#!/usr/bin/env python3
# Thanks to Claude (Opus 4.5 & Sonnet 4.5) for writing this to my specifications.

import sys
import re
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('input_file', help='Output from count-locs.sh')
parser.add_argument('--commit', help='Git commit hash')
parser.add_argument('--git-status', help='Git status (Clean or Uncommitted changes)')
parser.add_argument('--graph', help='Output SVG graph to this file')
parser.add_argument('--cpu', help='CPU type')
parser.add_argument('--os', help='OS type')
args = parser.parse_args()

# Desired output order
ALLOCATOR_ORDER = ['glibc', 'jemalloc', 'snmalloc', 'mimalloc', 'rpmalloc', 'smalloc', 'smalloc + ffi']

# Colors for each allocator
ALLOCATOR_COLORS = {
    'glibc': '#5c6bc0',      # indigo
    'jemalloc': '#42a5f5',   # blue
    'snmalloc': '#26a69a',   # teal
    'mimalloc': '#ffca28',   # amber
    'rpmalloc': '#ff7043',   # deep orange
    'smalloc': '#66bb6a',    # green
    'smalloc + ffi': '#a5d6a7',  # light green
}

def parse_tokei_output(content):
    """Parse tokei output sections and extract total code lines."""
    results = {}
    lines = content.strip().split('\n')

    current_allocator = None
    smalloc_ffi_loc = 0

    i = 0
    while i < len(lines):
        line = lines[i].strip()

        # Detect allocator section headers
        if line in ['smalloc', 'smalloc-ffi', 'rpmalloc', 'glibc', 'mimalloc', 'snmalloc', 'jemalloc']:
            current_allocator = line
            i += 1
            continue

        # Look for the "Total" line from tokei output
        if line.startswith('Total') and current_allocator:
            parts = line.split()
            # tokei format: Total    FILES  LINES  CODE  COMMENTS  BLANKS
            # We want CODE which is typically the 4th numeric column
            for j, part in enumerate(parts):
                if part.isdigit() and j >= 2:
                    # Third number should be CODE
                    numbers = [p for p in parts if p.isdigit()]
                    if len(numbers) >= 3:
                        code_lines = int(numbers[2])  # CODE is third number
                        if current_allocator == 'smalloc-ffi':
                            smalloc_ffi_loc = code_lines
                        elif current_allocator == 'smalloc':
                            results['smalloc'] = code_lines
                        else:
                            results[current_allocator] = code_lines
                    break
            current_allocator = None

        i += 1

    # Add combined smalloc + ffi entry
    if 'smalloc' in results:
        results['smalloc + ffi'] = results['smalloc'] + smalloc_ffi_loc

    return results

# Parse input
with open(args.input_file, 'r') as f:
    content = f.read()

allocator_locs = parse_tokei_output(content)

if not allocator_locs:
    print("ERROR: No allocator data found in input file", file=sys.stderr)
    print("Input content:", file=sys.stderr)
    print(content[:500], file=sys.stderr)
    sys.exit(1)

# Sort by desired order
sorted_allocators = [a for a in ALLOCATOR_ORDER if a in allocator_locs]

# Print summary
print(f"{'Allocator':<20} {'Lines of Code':>15}")
print("-" * 40)
for allocator in sorted_allocators:
    loc = allocator_locs[allocator]
    print(f"{allocator:<20} {loc:>15,}")

# Generate graph if requested
if args.graph:
    # Graph dimensions
    width = 750
    height = 500
    margin_top = 60
    margin_bottom = 120
    margin_left = 80
    margin_right = 40
    chart_width = width - margin_left - margin_right
    chart_height = height - margin_top - margin_bottom

    # Get values
    values = [allocator_locs[a] for a in sorted_allocators]
    max_val = max(values)

    # Round up to nice number for scale
    scale_max = ((max_val // 5000) + 1) * 5000

    # Calculate bar properties
    num_bars = len(sorted_allocators)
    bar_width = chart_width / num_bars
    padding = bar_width * 0.2
    actual_bar_width = bar_width - padding

    svg_parts = []
    # Removed Google Fonts import - use system fonts only
    svg_parts.append(f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}">
  <rect width="{width}" height="{height}" fill="#fafafa"/>
  <style>
    .bar {{ stroke: #fff; stroke-width: 1; }}
    .axis {{ stroke: #333; stroke-width: 1; }}
    .grid {{ stroke: #e0e0e0; stroke-width: 0.5; }}
    .label {{ font-family: Arial, Helvetica, sans-serif; font-size: 11px; fill: #333; }}
    .value {{ font-family: monospace; font-size: 11px; fill: #555; }}
    .title {{ font-family: Arial, Helvetica, sans-serif; font-size: 16px; font-weight: 600; fill: #333; }}
    .metadata {{ font-family: monospace; font-size: 9px; fill: #888; }}
  </style>
''')

    # Title
    svg_parts.append(f'  <text x="{width/2}" y="35" class="title" text-anchor="middle">Lines of code by allocator (excluding assertions)</text>\n')

    # Y-axis
    svg_parts.append(f'  <line x1="{margin_left}" y1="{margin_top}" x2="{margin_left}" y2="{margin_top + chart_height}" class="axis"/>\n')
    svg_parts.append(f'  <line x1="{margin_left}" y1="{margin_top + chart_height}" x2="{margin_left + chart_width}" y2="{margin_top + chart_height}" class="axis"/>\n')

    # Grid lines and Y-axis labels
    num_gridlines = 5
    for i in range(num_gridlines + 1):
        val = (scale_max / num_gridlines) * i
        y = margin_top + chart_height - (val / scale_max) * chart_height
        svg_parts.append(f'  <line x1="{margin_left}" y1="{y}" x2="{margin_left + chart_width}" y2="{y}" class="grid"/>\n')
        svg_parts.append(f'  <text x="{margin_left - 10}" y="{y + 4}" class="label" text-anchor="end">{int(val):,}</text>\n')

    # Bars
    for i, allocator in enumerate(sorted_allocators):
        val = allocator_locs[allocator]
        x = margin_left + i * bar_width + padding / 2
        bar_height = (val / scale_max) * chart_height
        y = margin_top + chart_height - bar_height

        color = ALLOCATOR_COLORS.get(allocator, '#4285f4')

        # Bar with rounded top corners
        svg_parts.append(f'  <rect x="{x}" y="{y}" width="{actual_bar_width}" height="{bar_height}" rx="3" ry="3" class="bar" fill="{color}"/>\n')

        # Value above bar
        svg_parts.append(f'  <text x="{x + actual_bar_width/2}" y="{y - 8}" class="value" text-anchor="middle">{val:,}</text>\n')

        # Allocator name below - handle two-line label for "smalloc + ffi"
        text_y = margin_top + chart_height + 20
        if allocator == 'smalloc + ffi':
            svg_parts.append(f'  <text x="{x + actual_bar_width/2}" y="{text_y}" class="label" text-anchor="middle">smalloc</text>\n')
            svg_parts.append(f'  <text x="{x + actual_bar_width/2}" y="{text_y + 14}" class="label" text-anchor="middle">+ ffi</text>\n')
        else:
            svg_parts.append(f'  <text x="{x + actual_bar_width/2}" y="{text_y}" class="label" text-anchor="middle">{allocator}</text>\n')

    # Metadata at bottom
    metadata_y = margin_top + chart_height + 55
    metadata_lines = []
    metadata_lines.append("Source: https://github.com/zooko/bench-allocators")
    if args.commit:
        metadata_lines.append(f"Commit: {args.commit[:12]}")
    if args.git_status:
        metadata_lines.append(f"Git status: {args.git_status}")
    if args.cpu:
        metadata_lines.append(f"CPU: {args.cpu}")
    if args.os:
        metadata_lines.append(f"OS: {args.os}")

    for i, line in enumerate(metadata_lines):
        y = metadata_y + i * 14
        svg_parts.append(f'  <text x="{width/2}" y="{y}" class="metadata" text-anchor="middle">{line}</text>\n')

    svg_parts.append('</svg>')

    with open(args.graph, 'w') as f:
        f.write(''.join(svg_parts))

    print(f"\n📊 Graph saved to: {args.graph}")
