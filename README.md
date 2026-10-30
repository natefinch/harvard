# Nowhere Near Cambridge

An exploration-and-mystery RPG set in a semi-fictional Harvard, Massachusetts,
in October 1995. Explore painted town landmarks, follow a missing person's
trail, and investigate the Hum beneath Bare Hill Pond.

## Download and play on macOS

[Download v0.1.1](https://github.com/natefinch/harvard/releases/tag/v0.1.1).
One ZIP contains a standalone app for both Apple Silicon and Intel Macs.
No Godot or Python installation is needed. Requires macOS 13 or later on
Apple Silicon, or macOS 11 or later on Intel.

Paste this into Terminal from any directory. It downloads the ZIP to
`~/Downloads`, verifies its checksum, installs the app to `~/Applications`, and
launches it:

```sh
(
  set -e
  mkdir -p ~/Downloads ~/Applications
  cd ~/Downloads
  curl --fail --location -o Nowhere-Near-Cambridge-macOS.zip \
    https://github.com/natefinch/harvard/releases/download/v0.1.1/Nowhere-Near-Cambridge-macOS.zip
  curl --fail --location -o Nowhere-Near-Cambridge-SHA256SUMS \
    https://github.com/natefinch/harvard/releases/download/v0.1.1/SHA256SUMS
  shasum -a 256 -c --ignore-missing Nowhere-Near-Cambridge-SHA256SUMS
  ditto -x -k Nowhere-Near-Cambridge-macOS.zip ~/Applications
  open ~/Applications/"Nowhere Near Cambridge.app"
)
```

The surrounding parentheses keep your Terminal in its current directory.

Command-line `curl` normally does not attach the quarantine metadata that
browsers add to downloaded files. However, **this build is ad-hoc signed, not
Developer ID signed or Apple-notarized**. Downloading with `curl` does not
change its signing status, and macOS security policies may still block it.
Only run software you trust.

## Download and play on Windows

[Download Nowhere-Near-Cambridge-Windows-x86_64.zip](https://github.com/natefinch/harvard/releases/download/v0.1.1/Nowhere-Near-Cambridge-Windows-x86_64.zip)
(v0.1.1, 64-bit x86_64/amd64 Windows). Extract the ZIP and run
`Nowhere Near Cambridge.exe`; it is a single standalone EXE and needs no Godot
installation. Checksums are in
[SHA256SUMS](https://github.com/natefinch/harvard/releases/download/v0.1.1/SHA256SUMS).

**The Windows build is not code-signed.** Windows SmartScreen or antivirus
software may warn about or block it. Only run software you trust.

## Controls

Move with **WASD or arrow keys**. **Z / Enter / Space / E** talks, examines,
or confirms; **X / Esc / Backspace** cancels. **Tab / M** opens the menu,
including the journal and items. Save at the farmhouse door or the payphone
on the Common.

Choose **Settings** from the title screen or in-game menu to adjust music and
sound-effect volume independently, or mute either one. Settings are remembered
between launches.

## Source

- [`game/`](game/README.md): Godot project, development instructions, and release build instructions.
- [`game-art/`](game-art/): asset-generation tools and reference material.
- [`research/`](research/README.md): geography, folklore, and setting research.
- [`game/STORY.md`](game/STORY.md): story bible (spoilers).

Map geography is derived from [OpenStreetMap contributors](https://www.openstreetmap.org/copyright)
under the ODbL; see [research sources](research/sources.md).
