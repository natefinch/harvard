#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
godot="${GODOT_BIN:-godot}"
destination="${1:-$root/build/web}"
mkdir -p "$destination"
destination="$(cd "$destination" && pwd)"
temporary="$(mktemp -d "${TMPDIR:-/tmp}/nowhere-web.XXXXXXXX")"
trap 'rm -rf -- "$temporary"' EXIT

"$godot" --headless --path "$root/game" --import
"$godot" --headless --path "$root/game" --export-release Web "$destination/index.html"

rsync -a --exclude '/.godot/' "$root/game/" "$temporary/game/"
python3 "$root/game-art/tools/prepare-web-mobile.py" "$temporary/game"
"$godot" --headless --path "$temporary/game" --import
"$godot" --headless --path "$temporary/game" --export-pack Web "$destination/index-mobile.pck"

python3 - "$destination/index.html" "$destination/index-mobile.pck" <<'PY'
import sys
from pathlib import Path

html = Path(sys.argv[1])
pack = Path(sys.argv[2])
text = html.read_text(encoding="utf-8")
placeholder = "__NNC_MOBILE_PACK_BYTES__"
if text.count(placeholder) != 1 or not pack.is_file() or pack.stat().st_size == 0:
    raise SystemExit("Could not configure the mobile pack in the exported web shell.")
html.write_text(text.replace(placeholder, str(pack.stat().st_size)), encoding="utf-8")
PY

touch "$destination/.nojekyll"
printf 'Desktop pack: %s bytes\n' "$(wc -c < "$destination/index.pck" | tr -d ' ')"
printf 'Mobile pack:  %s bytes\n' "$(wc -c < "$destination/index-mobile.pck" | tr -d ' ')"
