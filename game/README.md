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

Choose **Settings** on the title screen or in the in-game menu (Esc/Tab/M) to
adjust music and sound-effect volume separately. Each has a mute toggle that
preserves its slider value. Use the mouse, or Up/Down (W/S) to select a control,
Left/Right (A/D) to adjust volume, Z/Enter to toggle mute or go back, and Esc to
return. Changes apply immediately and are saved between launches independently
of your game save.

## Tests

```sh
# Reachability of every exit/hotspot/NPC from spawns
Godot --path game --headless -- --test reach
# Full Chapter 1 playthrough (auto-mashes accept)
Godot --path game --headless -- --test
# Audio settings, menu navigation, mouse controls, and persistence
# Use a temporary HOME so this test cannot overwrite your own audio settings.
HOME="$(mktemp -d)" Godot --path game --headless -- --test audio
# Windowed screenshots of every location to /tmp/shots (add `dbg` for overlays, `title` for title screen)
Godot --path game -- --shots
```

## Layout

- `scripts/Data.gd` – party, knacks, items, shop, enemies, landmarks
- `scripts/Locs.gd` – per-location geometry, exits, hotspots, NPCs, foes
- `scripts/Story.gd` – all dialogue and events (`ev_<name>`, `enter_<loc>`)
- `scripts/Location.gd`, `Overland.gd`, `Battle.gd`, `UI.gd`, `Game.gd` – engine
- `default_bus_layout.tres` – Music and SFX route independently to Master.
  Keep this saved layout rather than adding buses at runtime, which can
  scramble bus order in Godot's web sample playback.
- `assets/` – generated art, music (`game-art/audio/compose.py`), sfx (`game-art/audio/sfx.py`), map (`game-art/map/render_map.py`)

See `STORY.md` for the story bible.

## Standalone release builds

Requires Godot 4.7.2, its matching macOS and Windows export templates (install
from **Editor > Manage Export Templates**), and macOS's `codesign` and `zip`
commands. From the repository root:

```sh
bash game-art/tools/build-release.sh
```

Set `GODOT_BIN` if Godot is installed somewhere other than
`/Applications/Godot.app/Contents/MacOS/Godot`.

Outputs in `build/`, with SHA-256 checksums in `build/SHA256SUMS`:

- `Nowhere-Near-Cambridge-macOS.zip`: a self-contained, ad-hoc signed `.app`
  universal binary for Apple Silicon (macOS 13+) and Intel (macOS 11+).
- `Nowhere-Near-Cambridge-Windows-x86_64.zip`: a single unsigned
  `Nowhere Near Cambridge.exe` for 64-bit Windows, with the game data embedded.

Players do not need Godot or Python installed. See the
[repository README](../README.md) for release downloads, install commands, and
signing limitations.

## Browser build

The **Web** export preset produces a static site suitable for GitHub Pages.
It uses the Compatibility renderer and disables threads and extensions, so it
does not require special cross-origin isolation headers. The desktop builds
are unchanged.

Install Godot 4.7.2's matching Web export templates using **Editor > Manage
Export Templates**. From the repository root:

```sh
mkdir -p build/web
Godot --headless --path game --import
Godot --headless --path game --export-release Web ../build/web/index.html
python3 -m http.server 8000 --bind 127.0.0.1 --directory build/web
```

Open <http://127.0.0.1:8000/>. Serve the whole `build/web/` directory, keeping
the filenames together; opening `index.html` directly from disk will not work.
Hosting should use HTTPS and serve `.wasm` files as `application/wasm`.

The browser version requires WebAssembly and WebGL 2.0. Press a key or click
inside the game to enable audio. Saves and settings stay in that browser's
site storage, not in an account or the desktop game's save folder. Clearing
site data removes them; private browsing or blocked storage may prevent
persistence. This preset does not currently enable installation or offline
play.

### GitHub Pages

[`.github/workflows/pages.yml`](../.github/workflows/pages.yml) builds the Web
preset with Godot 4.7.2 on every push to `main` that changes `game/`, and
deploys only `build/web/` to <https://natefinch.github.io/harvard/>. Run it
manually from the **Actions** tab with **Run workflow**.
