#!/usr/bin/env python3
"""Configure phone/tablet texture imports in an isolated project copy."""

import re
import sys
from pathlib import Path


def replace_setting(text: str, key: str, value: str, path: Path) -> str:
    text, count = re.subn(rf"^{re.escape(key)}=.*$", f"{key}={value}", text, flags=re.MULTILINE)
    if count != 1:
        raise ValueError(f"{path}: expected exactly one {key} setting, found {count}")
    return text


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: prepare-web-mobile.py <isolated-project-directory>")
    project = Path(sys.argv[1])
    backgrounds = sorted((project / "assets/bg").glob("*.png.import"))
    map_import = project / "assets/map/overland.png.import"
    title_import = project / "assets/ui/title.png.import"
    if not backgrounds or not map_import.is_file() or not title_import.is_file():
        raise SystemExit("Missing background, map, or title import settings.")

    for path in [*backgrounds, map_import, title_import]:
        text = path.read_text(encoding="utf-8")
        text = replace_setting(text, "compress/mode", "1", path)
        text = replace_setting(text, "compress/lossy_quality", "0.85", path)
        if path == map_import:
            text = replace_setting(text, "process/size_limit", "2048", path)
        path.write_text(text, encoding="utf-8")
    print(f"Prepared {len(backgrounds) + 2} mobile texture imports.")


if __name__ == "__main__":
    main()
