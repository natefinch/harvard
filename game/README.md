# Nowhere Near Cambridge

A Godot 4 exploration/mystery RPG set in a semi-fictional Harvard, Massachusetts, October 1995.

## Run

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path game          # play
/Applications/Godot.app/Contents/MacOS/Godot --path game -e       # open editor
```

## Controls

| Key | Action |
|---|---|
| Arrows / WASD | Move |
| Z / Enter / Space / E | Talk, examine, confirm |
| X / Esc / Backspace | Cancel |
| Tab / M | Field menu (Goods, Status, Journal) |
| F3 | Debug overlay (walk areas, exits, hotspots) |
| F12 | Screenshot to `user://` |

Save at the payphone on the Common or the farmhouse door.

## Tests

```sh
# Reachability of every exit/hotspot/NPC from spawns
Godot --path game --headless -- --test reach
# Full Chapter 1 playthrough (auto-mashes accept)
Godot --path game --headless -- --test
# Windowed screenshots of every location to /tmp/shots (add `dbg` for overlays, `title` for title screen)
Godot --path game -- --shots
```

## Layout

- `scripts/Data.gd` – party, knacks, items, shop, enemies, landmarks
- `scripts/Locs.gd` – per-location geometry, exits, hotspots, NPCs, foes
- `scripts/Story.gd` – all dialogue and events (`ev_<name>`, `enter_<loc>`)
- `scripts/Location.gd`, `Overland.gd`, `Battle.gd`, `UI.gd`, `Game.gd` – engine
- `assets/` – generated art, music (`game-art/audio/compose.py`), sfx (`game-art/audio/sfx.py`), map (`game-art/map/render_map.py`)

See `STORY.md` for the story bible.

## Standalone macOS build

Requires Godot 4.7.2, its matching export templates, and macOS's `codesign`
command (provided by the Xcode Command Line Tools). In Godot, install templates
from **Editor > Manage Export Templates**. Then, from the repository root:

```sh
bash game-art/tools/build-macos.sh
```

Set `GODOT_BIN` if Godot is installed somewhere other than
`/Applications/Godot.app/Contents/MacOS/Godot`.

The output is `build/Nowhere-Near-Cambridge-macOS.zip` with a SHA-256 checksum
in `build/SHA256SUMS`. The archive contains a self-contained `.app`, including
the game engine and assets, for both Apple Silicon and Intel Macs. Players do
not need Godot or Python installed. The export template requires macOS 13 or
later on Apple Silicon, or macOS 11 or later on Intel.

See the [repository README](../README.md#download-and-play-on-macos) for the
public release download, `curl` commands, and signing limitations.
