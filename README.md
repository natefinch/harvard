<img width="1928" height="1083" alt="image" src="https://github.com/user-attachments/assets/dfb96bb8-7c85-4471-b7eb-0633eba701a4" />


An exploration-and-mystery RPG set in a semi-fictional Harvard, Massachusetts,
in October 1995. Explore painted town landmarks, follow a missing person's
trail, and investigate the Hum beneath Bare Hill Pond.

## Play in your browser

**[Play Nowhere Near Cambridge](https://natefinch.github.io/harvard/)** in
modern browsers with WebGL 2, including on Chromebooks, iPhones/iPads, and
Android devices. No install needed. On a phone, turn it sideways and tap
**Tap to play** to enable sound. Fullscreen starts where the browser supports
it; the game also works without fullscreen.

Touch controls appear automatically: drag the pad to move, use **A** to talk,
examine, or confirm, **B** to go back, and **MENU** for your journal and items.
You can also tap menu entries and dialogue, and drag the Settings sliders.

The first load is roughly **64 MB on phones/tablets** or **101 MB on desktop**,
before HTTP compression and browser caching. Smaller touch devices download
a separate optimized art pack; **desktop artwork stays at its original
resolution and quality**. Saves and settings are stored in that browser;
clearing site data removes them.

## Download and play on macOS

[Download v0.1.1](https://github.com/natefinch/harvard/releases/tag/v0.1.1).
One ZIP contains a standalone app for both Apple Silicon and Intel Macs.
Requires macOS 13 or later on
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

## Download and play on Windows

[Download Nowhere-Near-Cambridge-Windows-x86_64.zip](https://github.com/natefinch/harvard/releases/download/v0.1.1/Nowhere-Near-Cambridge-Windows-x86_64.zip)
(v0.1.1, 64-bit x86_64/amd64 Windows). Extract the ZIP and run
`Nowhere Near Cambridge.exe`. Checksums are in
[SHA256SUMS](https://github.com/natefinch/harvard/releases/download/v0.1.1/SHA256SUMS).


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
