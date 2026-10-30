# Nowhere Near Cambridge

An exploration-and-mystery RPG set in a semi-fictional Harvard, Massachusetts,
in October 1995. Explore painted town landmarks, follow a missing person's
trail, and investigate the Hum beneath Bare Hill Pond.

## Download and play on macOS

[Download v0.1.0](https://github.com/natefinch/harvard/releases/tag/v0.1.0).
One ZIP contains a standalone app for both Apple Silicon and Intel Macs.
No Godot or Python installation is needed. Requires macOS 13 or later on
Apple Silicon, or macOS 11 or later on Intel.

To download with macOS's command-line `curl`, verify the checksum, and launch:

```sh
mkdir -p Nowhere-Near-Cambridge && cd Nowhere-Near-Cambridge &&
curl --fail --location --remote-name \
  https://github.com/natefinch/harvard/releases/download/v0.1.0/Nowhere-Near-Cambridge-macOS.zip &&
curl --fail --location --remote-name \
  https://github.com/natefinch/harvard/releases/download/v0.1.0/SHA256SUMS &&
shasum -a 256 -c SHA256SUMS &&
ditto -x -k Nowhere-Near-Cambridge-macOS.zip . &&
open "Nowhere Near Cambridge.app"
```

Command-line `curl` normally does not attach the quarantine metadata that
browsers add to downloaded files. However, **this build is ad-hoc signed, not
Developer ID signed or Apple-notarized**. Downloading with `curl` does not
change its signing status, and macOS security policies may still block it.
Only run software you trust.

## Controls

Move with **WASD or arrow keys**. **Z / Enter / Space / E** talks, examines,
or confirms; **X / Esc / Backspace** cancels. **Tab / M** opens the menu,
including the journal and items. Save at the farmhouse door or the payphone
on the Common.

## Source

- [`game/`](game/README.md): Godot project, development instructions, and macOS build instructions.
- [`game-art/`](game-art/): asset-generation tools and reference material.
- [`research/`](research/README.md): geography, folklore, and setting research.
- [`game/STORY.md`](game/STORY.md): story bible (spoilers).

Map geography is derived from [OpenStreetMap contributors](https://www.openstreetmap.org/copyright)
under the ODbL; see [research sources](research/sources.md).
