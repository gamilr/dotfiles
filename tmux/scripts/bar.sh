#!/usr/bin/env sh
# Render a block-progress bar for a value 0-100.
# Usage:  bar.sh <value> [width]
#   width defaults to 8 cells.
# Outputs the bar characters only (no color codes); caller applies color.

val="${1:-0}"
width="${2:-8}"

# Clamp 0..100
[ "$val" -lt 0 ] && val=0
[ "$val" -gt 100 ] && val=100

# Filled cells: rounded
filled=$(( (val * width + 50) / 100 ))
empty=$(( width - filled ))

bar=""
i=0; while [ "$i" -lt "$filled" ]; do bar="${bar}▓"; i=$((i + 1)); done
i=0; while [ "$i" -lt "$empty"  ]; do bar="${bar}░"; i=$((i + 1)); done

printf '%s' "$bar"
