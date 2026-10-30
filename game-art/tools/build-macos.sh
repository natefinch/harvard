#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
godot="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
archive="$root/build/Nowhere-Near-Cambridge-macOS.zip"

if [[ ! -x "$godot" ]]; then
    printf 'Godot not found at %s. Set GODOT_BIN to your Godot executable.\n' "$godot" >&2
    exit 1
fi

mkdir -p "$root/build"
"$godot" --headless --path "$root/game" --import
"$godot" --headless --path "$root/game" --export-release macOS "$archive"
(
    cd "$root/build"
    shasum -a 256 "$(basename "$archive")" > SHA256SUMS
)
printf '\nBuilt %s\n' "$archive"
