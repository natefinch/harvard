#!/bin/bash
# Builds the macOS (universal) and Windows (x86_64) release archives into build/.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
godot="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
build="$root/build"
mac_zip="Nowhere-Near-Cambridge-macOS.zip"
win_zip="Nowhere-Near-Cambridge-Windows-x86_64.zip"

if [[ ! -x "$godot" ]]; then
    printf 'Godot not found at %s. Set GODOT_BIN to your Godot executable.\n' "$godot" >&2
    exit 1
fi

mkdir -p "$build"
rm -rf "$build/windows" "$build/$mac_zip" "$build/$win_zip"
mkdir -p "$build/windows"
"$godot" --headless --path "$root/game" --import
"$godot" --headless --path "$root/game" --export-release macOS "$build/$mac_zip"
"$godot" --headless --path "$root/game" --export-release Windows "$build/windows/Nowhere Near Cambridge.exe"
(
    cd "$build/windows"
    zip -q -9 "$build/$win_zip" "Nowhere Near Cambridge.exe"
)
(
    cd "$build"
    shasum -a 256 "$mac_zip" "$win_zip" > SHA256SUMS
)
printf '\nBuilt %s and %s\n' "$build/$mac_zip" "$build/$win_zip"
