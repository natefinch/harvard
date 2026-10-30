#!/usr/bin/env python3
"""Compose and render the music for "Nowhere Near Cambridge".

Usage:  .venv/bin/python game-art/audio/compose.py [track ...]

Each piece is composed as MIDI (midiutil), rendered with fluidsynth using the
GeneralUser GS soundfont, loudness-normalized to about -16 LUFS and encoded to
OGG Vorbis in game/assets/music/.

Looping tracks are rendered as two back-to-back copies of the loop, and the
second copy is cut out at exact sample boundaries. That way the reverb and
release tails from the end of the loop are already present at its start, so
the loop point is seamless.
"""
import os
import random
import subprocess
import sys

import numpy as np
import pyloudnorm
from midiutil import MIDIFile
from scipy.io import wavfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SF2 = os.path.join(HERE, "GeneralUser-GS.sf2")
BUILD = os.path.join(HERE, "build")
OUT = os.path.join(ROOT, "game", "assets", "music")
SR = 44100
TARGET_LUFS = -16.0

# ---------------------------------------------------------------- theory ---

NOTE_PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

QUALITIES = {
    "": [0, 4, 7],
    "m": [0, 3, 7],
    "7": [0, 4, 7, 10],
    "m7": [0, 3, 7, 10],
    "maj7": [0, 4, 7, 11],
    "m9": [0, 3, 7, 10, 14],
    "9": [0, 4, 7, 10, 14],
    "add9": [0, 4, 7, 14],
    "madd9": [0, 3, 7, 14],
    "sus2": [0, 2, 7],
    "sus4": [0, 5, 7],
    "7sus4": [0, 5, 7, 10],
    "dim": [0, 3, 6],
    "m7b5": [0, 3, 6, 10],
    "m6": [0, 3, 7, 9],
    "6": [0, 4, 7, 9],
    "7#9": [0, 4, 7, 10, 15],
    "7b9": [0, 4, 7, 10, 13],
    "maj7#11": [0, 4, 7, 11, 18],
    "5": [0, 7],
}


def pc_of(name):
    pc = NOTE_PC[name[0]]
    for ch in name[1:]:
        if ch == "#":
            pc += 1
        elif ch == "b":
            pc -= 1
    return pc % 12


def n(name):
    """Note name like 'C#4' or 'Bb2' -> MIDI number (C4 = 60)."""
    i = 1
    while i < len(name) and name[i] in "#b":
        i += 1
    return 12 * (int(name[i:]) + 1) + pc_of(name[:i])


class Chord:
    def __init__(self, sym):
        self.sym = sym
        bass = None
        if "/" in sym:
            sym, bass = sym.split("/")
        i = 1
        while i < len(sym) and sym[i] in "#b":
            i += 1
        self.root = pc_of(sym[:i])
        self.intervals = QUALITIES[sym[i:]]
        self.bass = pc_of(bass) if bass else self.root

    def pcs(self):
        return [(self.root + iv) % 12 for iv in self.intervals]

    def tones(self, low, high):
        """All chord tones between low and high (inclusive), sorted."""
        pcs = set(self.pcs())
        return [p for p in range(low, high + 1) if p % 12 in pcs]

    def voicing(self, center, count=4):
        """Close-ish voicing of `count` notes around `center`."""
        tones = self.tones(center - 9, center + 12)
        tones.sort(key=lambda p: abs(p - center))
        return sorted(tones[:count])

    def bass_note(self, octave=2):
        return 12 * (octave + 1) + self.bass

    def root_note(self, octave=2):
        return 12 * (octave + 1) + self.root


def parse_bars(spec):
    """'Am | F G | ...' -> list of bars, each a list of chord symbols."""
    return [[Chord(c) for c in bar.split()] for bar in spec.split("|") if bar.strip()]


def mel(spec):
    """'E5/1 r/0.5 G5/0.5' -> [(pitch or None, beats)]."""
    out = []
    for tok in spec.split():
        name, dur = tok.split("/")
        out.append((None if name.lower() == "r" else n(name), float(dur)))
    return out


# --------------------------------------------------------------- MIDI wrap -

class Song:
    def __init__(self, name, tempo, loop_beats=None, rng_seed=1):
        self.name = name
        self.tempo = tempo
        self.parts = []
        self.notes = []  # (part, pitch, start, dur, vel)
        self.ccs = []  # (part, time, cc, value)
        self.bends = []  # (part, time, value)
        self.timesigs = []  # (time, num, denom_power)
        self.loop_beats = loop_beats
        self.rng = random.Random(rng_seed)

    def part(self, program, channel, volume=100, pan=64, reverb=40, chorus=0):
        p = dict(program=program, channel=channel, volume=volume, pan=pan,
                 reverb=reverb, chorus=chorus, idx=len(self.parts))
        self.parts.append(p)
        return p

    def note(self, part, pitch, start, dur, vel=90, human=True):
        if pitch is None:
            return
        if human:
            vel += self.rng.randint(-5, 5)
        vel = max(1, min(127, int(vel)))
        self.notes.append((part, int(pitch), float(start), float(dur), vel))

    def chord(self, part, pitches, start, dur, vel=80, strum=0.0):
        for i, p in enumerate(pitches):
            self.note(part, p, start + i * strum, dur - i * strum, vel)

    def melody(self, part, notes, start, vel=90, legato=0.95, transpose=0):
        t = start
        for pitch, dur in notes:
            if pitch is not None:
                self.note(part, pitch + transpose, t, dur * legato, vel)
            t += dur
        return t

    def cc(self, part, time, cc, value):
        self.ccs.append((part, time, cc, value))

    def bend(self, part, time, value):
        self.bends.append((part, time, value))

    def timesig(self, time, num, denom_power):
        self.timesigs.append((time, num, denom_power))

    def write_midi(self, path, copies=1, tail_beats=8):
        span = self.loop_beats or 0
        mf = MIDIFile(len(self.parts), deinterleave=True, adjust_origin=False)
        for p in self.parts:
            t, ch = p["idx"], p["channel"]
            mf.addTempo(t, 0, self.tempo)
            if ch != 9:
                mf.addProgramChange(t, ch, 0, p["program"])
            mf.addControllerEvent(t, ch, 0, 7, p["volume"])
            mf.addControllerEvent(t, ch, 0, 10, p["pan"])
            mf.addControllerEvent(t, ch, 0, 91, p["reverb"])
            mf.addControllerEvent(t, ch, 0, 93, p["chorus"])
        for c in range(copies):
            off = c * span
            for (time, num, dp) in self.timesigs:
                mf.addTimeSignature(0, time + off, num, dp, 24)
            for (part, pitch, start, dur, vel) in self.notes:
                mf.addNote(part["idx"], part["channel"], pitch, start + off, max(dur, 0.05), vel)
            for (part, time, cc, value) in self.ccs:
                mf.addControllerEvent(part["idx"], part["channel"], time + off, cc, value)
            for (part, time, value) in self.bends:
                mf.addPitchWheelEvent(part["idx"], part["channel"], time + off, value)
        # A silent marker note keeps the file long enough to capture the tail.
        end = copies * span + tail_beats if span else max(s + d for _, _, s, d, _ in self.notes) + tail_beats
        mf.addControllerEvent(0, self.parts[0]["channel"], end, 7, self.parts[0]["volume"])
        with open(path, "wb") as f:
            mf.writeFile(f)

    def beats_to_samples(self, beats):
        return int(round(beats * 60.0 / self.tempo * SR))


# ------------------------------------------------------------ rendering ----

def has_libvorbis():
    out = subprocess.run(["ffmpeg", "-hide_banner", "-encoders"], capture_output=True, text=True).stdout
    return "libvorbis" in out


def encode_ogg(wav_path, ogg_path):
    """WAV -> OGG Vorbis (~q5) with ffmpeg. Prefers libvorbis; Homebrew's ffmpeg
    is built without it, so fall back to ffmpeg's native (experimental) encoder."""
    if has_libvorbis():
        codec = ["-c:a", "libvorbis", "-q:a", "5"]
    else:
        codec = ["-c:a", "vorbis", "-strict", "experimental", "-q:a", "5"]
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path] + codec + [ogg_path], check=True)


def render(song, loop=True, tail_beats=8, fade_out=0.0, max_seconds=None):
    os.makedirs(BUILD, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    mid = os.path.join(BUILD, song.name + ".mid")
    raw = os.path.join(BUILD, song.name + "_raw.wav")
    fin = os.path.join(BUILD, song.name + ".wav")
    ogg = os.path.join(OUT, song.name + ".ogg")
    song.write_midi(mid, copies=2 if loop else 1, tail_beats=tail_beats)
    subprocess.run(["fluidsynth", "-ni", "-q", "-g", "0.4", "-r", str(SR), "-F", raw, SF2, mid],
                   check=True, stdout=subprocess.DEVNULL)
    sr, data = wavfile.read(raw)
    audio = data.astype(np.float64) / 32768.0
    if audio.ndim == 1:
        audio = np.stack([audio, audio], axis=1)
    if loop:
        # fluidsynth fires MIDI events on 64-sample block boundaries, timed in
        # whole milliseconds. Copy 2 is only a sample-exact repeat of copy 1
        # when the loop is a whole number of ms *and* of 64-sample blocks,
        # i.e. a multiple of 640 ms at 44.1 kHz - so tempos are chosen for that.
        loop_ms = song.loop_beats * 60000.0 / song.tempo
        if abs(loop_ms / 640 - round(loop_ms / 640)) > 1e-6:
            print(f"warning: {song.name} loop is {loop_ms:.1f} ms, not a multiple of 640 ms")
        L = song.beats_to_samples(song.loop_beats)
        data2 = audio
        out = data2[L:2 * L].copy()
        # The sample after the loop end is out[0] == render[L], whose true
        # predecessor is render[L-1]; crossfade the last few ms into the end of
        # copy 1 so the wrap-around is continuous even with LFO/phase residue.
        k = int(0.012 * SR)
        w = np.linspace(0, 1, k)[:, None]
        out[-k:] = out[-k:] * (1 - w) + data2[L - k:L] * w
        audio = out
    else:
        # trim trailing silence
        mag = np.max(np.abs(audio), axis=1)
        idx = np.nonzero(mag > 1e-4)[0]
        audio = audio[: (idx[-1] + 1 if len(idx) else len(audio))]
        if max_seconds:
            audio = audio[: int(max_seconds * SR)]
        if fade_out > 0:
            k = min(len(audio), int(fade_out * SR))
            audio[-k:] *= np.linspace(1, 0, k)[:, None] ** 2
        k = int(0.003 * SR)
        audio[:k] *= np.linspace(0, 1, k)[:, None]
    meter = pyloudnorm.Meter(SR)
    loud = meter.integrated_loudness(audio)
    audio *= 10 ** ((TARGET_LUFS - loud) / 20.0)
    # gentle soft limiter above -1.5 dBFS
    th = 10 ** (-1.5 / 20)
    a = np.abs(audio)
    over = a > th
    audio[over] = np.sign(audio[over]) * (th + (1 - th) * np.tanh((a[over] - th) / (1 - th)))
    audio = np.clip(audio, -0.98, 0.98)
    wavfile.write(fin, SR, (audio * 32767).astype(np.int16))
    encode_ogg(fin, ogg)
    os.remove(raw)
    os.remove(fin)
    print(f"{song.name}.ogg  {len(audio) / SR:6.2f}s  loudness {meter.integrated_loudness(audio):.1f} LUFS"
          f"  loop={'yes' if loop else 'no'}")


# ------------------------------------------------------------- drum kit ----

KICK, RIM, SNARE, CLAP, ESNARE = 36, 37, 38, 39, 40
LTOM, CHH, MTOM, PHH, HTOM, OHH, CRASH, RIDE = 45, 42, 47, 44, 50, 46, 49, 51
TAMB, COWBELL, SHAKER, CABASA, CLAVES, WOODHI, WOODLO, TRI = 54, 56, 70, 69, 75, 76, 77, 81
RIDEBELL, SPLASH, CHINA = 53, 55, 52


def drum_pattern(song, part, start, beats_per_bar, pattern, vel_map=None):
    """pattern: {note: [(beat, vel), ...]} within a bar."""
    for note, hits in pattern.items():
        for beat, vel in hits:
            if beat < beats_per_bar:
                song.note(part, note, start + beat, 0.25, vel)


def arpeggiate(song, part, chord, start, beats, step, order, low, high, vel=70, dur=None, echo=None):
    tones = chord.tones(low, high)
    t, i = 0.0, 0
    while t < beats - 1e-6:
        p = tones[order[i % len(order)] % len(tones)]
        song.note(part, p, start + t, dur or step * 1.5, vel)
        if echo:
            delay, decay = echo
            if t + delay < beats:
                song.note(part, p, start + t + delay, step, vel * decay)
        t += step
        i += 1


# ================================================================ TITLE =====

def title():
    bars = parse_bars(
        "Am | Fmaj7 | Dm9 | E7sus4 E7 |"
        "Am | Fmaj7 | Dm9 | E7 |"
        "Fmaj7 | G | Em7 | Am |"
        "Dm | Bbmaj7 | Fmaj7 | E7 |"
        "Am | Fmaj7 | Dm9 | E7sus4 E7")
    s = Song("title", 75, loop_beats=4 * len(bars))
    pad = s.part(89, 0, volume=82, reverb=110, chorus=60)          # warm pad
    halo = s.part(94, 1, volume=55, reverb=127, chorus=80)         # halo pad
    piano = s.part(0, 2, volume=88, reverb=90, pan=54)
    lead = s.part(78, 3, volume=96, reverb=120, pan=72)            # whistle
    strings = s.part(49, 4, volume=78, reverb=100, pan=80)
    bass = s.part(38, 5, volume=72, reverb=40)                     # synth bass
    bells = s.part(8, 6, volume=60, reverb=120, pan=40)            # celesta

    for b, chords in enumerate(bars):
        t0 = b * 4
        seg = 4 / len(chords)
        for i, ch in enumerate(chords):
            t = t0 + i * seg
            s.chord(pad, ch.voicing(60, 4), t, seg, 62)
            s.note(bass, ch.bass_note(1), t, seg * 0.98, 70)
            arpeggiate(s, piano, ch, t, seg, 0.5, [0, 2, 4, 3, 5, 3, 4, 2], 57, 84,
                       vel=58 if b < 4 or b >= 16 else 50, dur=1.0, echo=(0.75, 0.45))
            if 4 <= b < 16:
                s.chord(strings, [ch.bass_note(2), ch.voicing(55, 3)[-1]], t, seg, 55)
        if b in (0, 8, 16):
            s.chord(halo, Chord(chords[0].sym).voicing(72, 3), t0, 16, 45)
    theme = mel(
        # bars 5-8
        "A4/1 E5/1 D5/0.5 E5/0.5 G5/1 E5/3 r/1 "
        "F5/1 E5/0.5 D5/0.5 C5/1 D5/1 B4/3 r/1 "
        # bars 9-12
        "C5/1 A5/1 G5/1 F5/1 D5/1.5 B4/0.5 G4/2 "
        "G5/1 F#5/0.5 E5/0.5 B4/2 A4/3 r/1 "
        # bars 13-16
        "F5/1.5 E5/0.5 D5/1 A4/1 Bb4/1 D5/1 F5/1 A5/1 "
        "G5/1.5 F5/0.5 E5/1 C5/1 G#4/2 B4/1 E5/1")
    s.melody(lead, theme, 16, vel=84, legato=0.98)
    # sparse celesta answer in the reprise
    s.melody(bells, mel("E6/1 r/1 C6/1 B5/1 A5/3 r/1 r/4 G#5/2 B5/2"), 64, vel=60)
    return s


# ================================================================= TOWN =====

def town():
    A = "G | C | Am7 | D7 | G | Eb | C | D7 |"
    B = "C | D | Bm7 | Em | Am7 | D7 | Gmaj7 | Cm D7 |"
    bars = parse_bars(A + A + B + A)
    s = Song("town", 100, loop_beats=4 * len(bars))
    gtr = s.part(24, 0, volume=90, pan=44, reverb=50)              # nylon guitar
    bass = s.part(32, 1, volume=96, reverb=20)                     # acoustic bass
    flute = s.part(73, 2, volume=96, pan=76, reverb=60)
    glock = s.part(9, 3, volume=70, pan=90, reverb=70)
    pizz = s.part(45, 4, volume=84, pan=30, reverb=50)
    clar = s.part(71, 5, volume=88, pan=70, reverb=60)
    drums = s.part(0, 9, volume=80, reverb=30)

    melA = mel(
        "G4/0.5 B4/0.5 D5/0.5 G5/0.5 F#5/0.5 G5/0.5 D5/1 "
        "E5/1 C5/0.5 E5/0.5 G5/1.5 r/0.5 "
        "A5/0.5 G5/0.5 E5/0.5 C5/0.5 D5/1 E5/1 "
        "F#5/1.5 E5/0.5 D5/1 C5/1 "
        "B4/0.5 D5/0.5 G5/1 A5/0.5 B5/0.5 G5/1 "
        "G5/1 Bb5/1 G5/0.5 F5/0.5 Eb5/1 "
        "E5/1.5 D5/0.5 C5/0.5 B4/0.5 A4/1 "
        "D5/1 F#4/1 A4/1 C5/1")
    melB = mel(
        "G5/1 E5/1 C5/1 E5/1 F#5/1.5 A5/0.5 F#5/1 D5/1 "
        "D5/1 F#5/1 A5/1 B5/1 G5/3 r/1 "
        "C6/1 B5/0.5 A5/0.5 G5/1 E5/1 F#5/1 A5/1 C6/1 A5/1 "
        "B5/2 F#5/1 D5/1 Eb5/1 G5/1 F#5/1 A5/1")
    # glockenspiel counter-line for the second A (off-beat "plinks")
    counter = mel(
        "r/2.5 B5/0.5 r/1 r/2.5 G6/0.5 r/1 r/2.5 E6/0.5 r/1 r/1 F#6/0.5 r/2.5 "
        "r/2.5 D6/0.5 r/1 r/2.5 Bb6/0.5 r/1 r/2.5 C6/0.5 r/1 A5/1 C6/1 D6/2")

    s.melody(flute, melA, 0, vel=88, legato=0.85)
    s.melody(clar, melA, 32, vel=84, legato=0.9)
    s.melody(glock, counter, 32, vel=80, legato=0.6)
    s.melody(glock, melB, 64, vel=78, legato=0.6)
    s.melody(flute, melB, 64, vel=62, legato=0.85, transpose=-12)
    s.melody(flute, melA, 96, vel=90, legato=0.85)
    s.melody(glock, melA, 96, vel=55, legato=0.5, transpose=12)

    for b, chords in enumerate(bars):
        t0 = b * 4
        seg = 4 / len(chords)
        section_b = 16 <= b < 24
        for i, ch in enumerate(chords):
            t = t0 + i * seg
            v = ch.voicing(57, 4)
            # strum on 1, 2&, 3 (+4& pickup) - a little lopsided
            for off, vel, d in [(0, 74, 1.4), (1.5, 58, 1.0), (2, 66, 0.9), (3.5, 52, 0.5)]:
                if off < seg:
                    s.chord(gtr, v, t + off, d, vel, strum=0.025)
            # walking-ish bass with chromatic approach on the last 8th
            root = ch.bass_note(2)
            fifth = root + 7 if root + 7 <= 52 else root - 5
            s.note(bass, root, t, 0.9, 92)
            if seg >= 4:
                s.note(bass, fifth, t + 2, 0.9, 80)
                nxt = bars[(b + 1) % len(bars)][0].bass_note(2)
                s.note(bass, nxt + (1 if (b % 2) else -1), t + 3.5, 0.45, 70)
            else:
                s.note(bass, fifth, t + 1, 0.9, 76)
            if section_b:
                for off in (0.5, 1.5, 2.5, 3.5):
                    if off < seg:
                        s.chord(pizz, ch.voicing(67, 2), t + off, 0.3, 64)
        # light percussion
        pat = {KICK: [(0, 70), (2, 60)], SHAKER: [(x / 2, 40 + 14 * (x % 2)) for x in range(8)],
               RIM: [(1, 45), (3, 50)]}
        if b % 4 == 3:
            pat[WOODHI] = [(2.5, 64), (3.5, 70)]
        if b % 8 == 5:
            pat[WOODLO] = [(1.75, 60)]
        drum_pattern(s, drums, t0, 4, pat)
    return s


# ============================================================= OVERLAND =====

def overland():
    intro = "D | Dsus2 | G | G | D | Dsus2 | G | A |"
    verse = "D | A/C# | Bm | G | D | A/C# | Bm | G |"
    chorus = "G | D | A | Bm | G | D | Em | A |"
    bridge = "Em | F#m | G | A | Em | F#m | G | Asus4 A |"
    bars = parse_bars(intro + verse + verse + chorus + chorus + bridge)
    s = Song("overland", 120, loop_beats=4 * len(bars))
    cgtr = s.part(27, 0, volume=82, pan=40, reverb=60, chorus=70)  # clean electric
    dgtr = s.part(29, 1, volume=68, pan=88, reverb=40)              # overdriven
    bass = s.part(34, 2, volume=96, reverb=10)                       # picked bass
    lead = s.part(80, 3, volume=70, pan=64, reverb=70, chorus=50)    # square lead
    pad = s.part(50, 4, volume=60, reverb=100, chorus=40)            # synth strings
    flute = s.part(73, 5, volume=70, pan=70, reverb=70)
    drums = s.part(0, 9, volume=92, reverb=25)

    verse_m = mel(
        "F#5/1 E5/0.5 D5/0.5 r/0.5 A4/0.5 D5/1 "
        "E5/1.5 C#5/0.5 A4/2 "
        "D5/0.5 F#5/0.5 F#5/0.5 E5/0.5 D5/1 B4/1 "
        "D5/3 r/1 "
        "F#5/1 A5/1 G5/0.5 F#5/0.5 E5/1 "
        "E5/2 C#5/1 E5/1 "
        "F#5/1.5 E5/0.5 D5/1 C#5/1 "
        "B4/2 A4/2")
    chorus_m = mel(
        "B5/1.5 A5/0.5 G5/1 D5/1 A5/2 F#5/2 "
        "E5/1 F#5/0.5 G5/0.5 A5/1 C#6/1 B5/3 r/1 "
        "B5/1.5 A5/0.5 G5/1 B5/1 A5/1.5 F#5/0.5 D5/2 "
        "G5/1 F#5/1 E5/1 B4/1 C#5/2 E5/1 A5/1")
    bridge_m = mel("B4/4 C#5/4 D5/4 E5/4 G5/4 A5/4 B5/4 A5/4")

    s.melody(flute, verse_m, 32, vel=82, legato=0.9)
    s.melody(lead, verse_m, 64, vel=84, legato=0.9)
    s.melody(flute, verse_m, 64, vel=60, legato=0.9, transpose=-12)
    s.melody(lead, chorus_m, 96, vel=92, legato=0.92)
    s.melody(lead, chorus_m, 128, vel=96, legato=0.92)
    s.melody(flute, chorus_m, 128, vel=70, legato=0.92, transpose=12)
    s.melody(flute, bridge_m, 160, vel=70, legato=0.98)

    for b, chords in enumerate(bars):
        t0 = b * 4
        seg = 4 / len(chords)
        sec = ("intro" if b < 8 else "verse" if b < 24 else "chorus" if b < 40 else "bridge")
        for i, ch in enumerate(chords):
            t = t0 + i * seg
            # chimey 8th-note arpeggio, U2-ish
            arpeggiate(s, cgtr, ch, t, seg, 0.5, [0, 3, 2, 4, 1, 3, 2, 4], 55, 79,
                       vel=70 if sec != "chorus" else 60, dur=0.9)
            # driving 8th bass
            root = ch.bass_note(2)
            if root > 45:
                root -= 12
            for k in range(int(seg * 2)):
                acc = 92 if k % 2 == 0 else 78
                s.note(bass, root + (12 if (sec == "chorus" and k == 3) else 0), t + k * 0.5, 0.45, acc)
            if sec == "chorus" or (sec == "bridge" and b >= 44):
                pw = [ch.root_note(2) + 12 if ch.root_note(2) < 45 else ch.root_note(2), None]
                pw[1] = pw[0] + 7
                for k in range(int(seg * 2)):
                    s.chord(dgtr, pw + [pw[0] + 12], t + k * 0.5, 0.45, 70 if k % 2 else 82)
            if sec in ("verse", "bridge") or (sec == "intro" and b >= 4):
                s.chord(pad, ch.voicing(64, 3), t, seg, 50)
        # drums
        if sec == "intro" and b < 4:
            pat = {KICK: [(0, 80), (2, 70)], CHH: [(x / 2, 50 + 10 * (x % 2 == 0)) for x in range(8)],
                   RIM: [(3.5, 40)]}
        elif sec == "bridge":
            pat = {KICK: [(0, 90), (1.5, 70), (2.5, 80)], SNARE: [(1, 80), (3, 86)],
                   RIDE: [(x / 2, 60) for x in range(8)]}
        else:
            pat = {KICK: [(0, 100), (1.5, 76), (2, 92), (2.5, 70)],
                   SNARE: [(1, 96), (3, 100)],
                   CHH: [(x / 2, 70 if x % 2 == 0 else 54) for x in range(8)]}
            if sec == "chorus":
                pat[TAMB] = [(x + 0.5, 56) for x in range(4)]
        if b % 8 == 7:  # fill
            pat.pop(CHH, None)
            pat[SNARE] = [(1, 90), (2, 70), (2.5, 80), (3, 84), (3.5, 92)]
            pat[HTOM] = [(2.25, 80)]
            pat[LTOM] = [(3.25, 90), (3.75, 96)]
        if b % 8 == 0 and b != 0:
            pat.setdefault(CRASH, []).append((0, 90))
        drum_pattern(s, drums, t0, 4, pat)
    return s


# ================================================================ NIGHT =====

def night():
    bars = parse_bars(
        "Dmadd9 | Dmadd9 | Bbmaj7#11 | Bbmaj7#11 | Gm6 | Gm6 | A7b9 | A7b9 |"
        "Dmadd9 | Dmadd9 | Ebmaj7 | Ebmaj7 | Gm6 | Gm6 | A7sus4 | A7b9 |"
        "Dmadd9 | Dmadd9 | Bbmaj7#11 | A7b9")
    s = Song("night", 60, loop_beats=4 * len(bars), rng_seed=7)
    pad = s.part(92, 0, volume=70, reverb=127, chorus=60)          # bowed pad
    lowstr = s.part(44, 1, volume=72, reverb=110)                  # tremolo strings
    hum1 = s.part(16, 2, volume=56, reverb=20)                     # drawbar organ
    hum2 = s.part(16, 3, volume=56, reverb=20)
    cel = s.part(8, 4, volume=70, reverb=127, pan=34)              # celesta
    bell = s.part(14, 5, volume=50, reverb=127, pan=96)            # tubular bells
    atmos = s.part(99, 6, volume=50, reverb=127, chorus=90)        # atmosphere
    goblin = s.part(101, 7, volume=40, reverb=127, pan=80)         # goblins

    L = s.loop_beats
    # The Hum: A1 (55 Hz) on two organ channels, one bent ~+12 cents -> slow beating
    s.bend(hum2, 0, 500)
    for t in range(0, L, 8):
        s.note(hum1, n("A1"), t, 8.0, 60, human=False)
        s.note(hum2, n("A1"), t, 8.0, 54, human=False)
    # slow swell of the hum volume
    for k in range(L * 2):
        t = k / 2
        s.cc(hum1, t, 11, int(80 + 30 * np.sin(2 * np.pi * t / 20)))
        s.cc(hum2, t, 11, int(80 + 30 * np.sin(2 * np.pi * t / 20 + 1.3)))

    scale = [n(x) for x in ["D5", "E5", "F5", "A5", "Bb5", "C6", "D6", "Eb6", "F6", "A6"]]
    for b, chords in enumerate(bars):
        t0 = b * 4
        ch = chords[0]
        if b % 2 == 0:
            s.chord(pad, ch.voicing(58, 4), t0, 8, 55)
            s.note(lowstr, ch.bass_note(2), t0, 8, 50)
            s.note(lowstr, ch.bass_note(2) + 12 if ch.bass < 7 else ch.bass_note(1) + 12, t0 + 2, 6, 38)
        # sparse celesta: 2-3 notes in a bar, at odd places
        r = s.rng
        k = r.choice([0, 1, 2, 2, 3])
        tones = ch.tones(74, 93) + [p for p in scale if r.random() < 0.15]
        for j in range(k):
            pos = r.choice([0.5, 1.25, 1.5, 2.0, 2.75, 3.0, 3.5])
            s.note(cel, r.choice(tones), t0 + pos, 2.0, r.randint(45, 72), human=False)
        if b % 4 == 2:
            s.note(bell, ch.root_note(4), t0 + 0.5, 4, 55)
        if b % 8 == 4:
            s.note(atmos, ch.voicing(70, 1)[0], t0, 7.5, 60)
        if b in (6, 14):
            s.note(goblin, n("Eb4"), t0 + 1, 5, 55)
            s.bend(goblin, t0 + 1, 0)
            for q in range(1, 20):
                s.bend(goblin, t0 + 1 + q * 0.25, -q * 120)
            s.bend(goblin, t0 + 7, 0)
    return s


# =============================================================== BATTLE =====

def battle():
    s = Song("battle", 150, rng_seed=3)
    bass = s.part(38, 0, volume=104, reverb=10)                    # synth bass 1
    brass = s.part(62, 1, volume=86, pan=80, reverb=40)            # synth brass
    lead = s.part(80, 2, volume=78, pan=50, reverb=50, chorus=40)  # square lead
    keys = s.part(4, 3, volume=70, pan=30, reverb=40)              # EP comp
    stab = s.part(61, 4, volume=82, pan=64, reverb=50)             # brass section
    drums = s.part(0, 9, volume=100, reverb=20)

    t = 0.0
    # ---- A: 8 bars of 7/8 (2+2+3), E minor
    A_chords = [Chord(c) for c in ["Em7", "Em7", "Cmaj7", "B7", "Em7", "Em7", "Cmaj7", "B7"]]
    A_mel = [
        "E5/0.5 G5/0.5 B5/0.5 A5/0.5 G5/0.5 F#5/0.5 E5/0.5",
        "D5/0.5 E5/1 B4/0.5 D5/0.5 E5/1",
        "G5/0.5 E5/0.5 C5/0.5 B4/0.5 C5/0.5 E5/0.5 G5/0.5",
        "F#5/1 D#5/0.5 F#5/0.5 A5/1.5",
        "B5/0.5 A5/0.5 G5/0.5 E5/0.5 r/0.5 E5/0.5 G5/0.5",
        "A5/0.5 Bb5/0.5 B5/1 r/0.5 E6/1",
        "E6/0.5 D6/0.5 B5/0.5 G5/0.5 E5/0.5 G5/0.5 C6/0.5",
        "B5/1 A5/0.5 F#5/0.5 D#5/1.5",
    ]

    def a_section(t, octave_brass):
        s.timesig(t, 7, 3)
        for i, ch in enumerate(A_chords):
            r = ch.root_note(1)
            if r < 31:
                r += 12
            # bass: 2+2+3 groove
            for off, p, d, v in [(0, r, 0.4, 110), (0.5, r + 12, 0.25, 84), (1.0, r, 0.4, 104),
                                 (1.5, r + 10, 0.25, 84), (2.0, r, 0.4, 108), (2.5, r + 7, 0.4, 92),
                                 (3.0, r + 12, 0.4, 96)]:
                s.note(bass, p, t + off, d, v)
            s.melody(lead, mel(A_mel[i]), t, vel=96, legato=0.8)
            v = ch.voicing(64, 4)
            for off in (0, 1.0, 2.0):
                s.chord(keys, v, t + off + 0.5, 0.3, 64)
            if i % 2 == 1:
                s.chord(stab, ch.voicing(67, 3), t + 2.0, 0.3, 96)
                s.chord(stab, ch.voicing(67, 3), t + 3.0, 0.4, 104)
                if octave_brass:
                    s.chord(brass, [p + 12 for p in ch.voicing(67, 3)], t + 3.0, 0.4, 90)
            drum_pattern(s, drums, t, 3.5, {
                KICK: [(0, 110), (1.0, 96), (2.0, 104)],
                SNARE: [(0.5, 60), (1.5, 100), (3.0, 110)],
                CHH: [(x / 2, 70 if x in (0, 2, 4) else 55) for x in range(7)],
                COWBELL: [(2.5, 70)] if i % 2 else [],
                CRASH: [(0, 96)] if i == 0 else [],
            })
            t += 3.5
        return t

    t = a_section(t, False)

    # ---- B: 16 bars of 4/4 funk, A dorian
    s.timesig(t, 4, 2)
    B_chords = [Chord(c) for c in ["Am7", "D9", "Am7", "D9", "Fmaj7", "E7#9", "Am7", "B7"] * 2]
    licks = [mel("A5/0.25 C6/0.25 D6/0.5 E6/0.25 D6/0.25 C6/0.5 A5/0.5 G5/0.5 A5/1"),
             mel("E6/0.5 D#6/0.25 E6/0.25 G6/0.5 E6/0.5 D6/0.5 B5/0.5 G#5/1"),
             mel("C6/0.25 B5/0.25 A5/0.5 G5/0.25 A5/0.75 E5/0.5 G5/0.5 A5/0.5 C6/0.5"),
             mel("F#6/0.5 E6/0.5 D#6/0.5 B5/0.5 A5/0.5 F#5/0.5 D#5/1")]
    for i, ch in enumerate(B_chords):
        r = ch.root_note(1)
        if r < 31:
            r += 12
        for k, iv, v in [(0, 0, 112), (3, 12, 80), (6, 0, 96), (8, 7, 90), (10, 10, 84),
                         (11, 12, 92), (14, 0, 100), (15, -2 if i % 2 else 3, 80)]:
            s.note(bass, r + iv, t + k * 0.25, 0.22, v)
        v = ch.voicing(64, 4)
        if i % 2 == 0:
            # brass stab call
            for off, vel in [(0.5, 104), (1.5, 96), (2.75, 110), (3.5, 100)]:
                s.chord(stab, ch.voicing(67, 4), t + off, 0.2, vel)
                s.chord(brass, ch.voicing(67, 3), t + off, 0.2, vel - 20)
        else:
            s.melody(lead, licks[(i // 2) % 4], t, vel=100, legato=0.85)
        for off in (0.75, 1.75, 2.25, 3.25):
            s.chord(keys, v, t + off, 0.18, 60)
        pat = {KICK: [(0, 112), (0.75, 80), (1.5, 96), (2.5, 104)],
               SNARE: [(1, 108), (3, 112), (1.75, 40), (2.75, 44), (3.75, 50)],
               CHH: [(x / 4, 80 if x % 4 == 0 else 60 if x % 2 == 0 else 44) for x in range(16)],
               CLAP: [(3, 70)]}
        if i % 4 == 3:
            pat[OHH] = [(3.5, 80)]
        if i == 7 or i == 15:
            pat[SNARE] = [(1, 100), (2, 90), (2.25, 80), (2.5, 94), (2.75, 86), (3, 104), (3.25, 96), (3.5, 108), (3.75, 112)]
            pat.pop(CHH)
        if i in (0, 8):
            pat[CRASH] = [(0, 100)]
        drum_pattern(s, drums, t, 4, pat)
        t += 4
    # ---- A': repeat 7/8 section with octave brass
    t = a_section(t, True)
    s.loop_beats = t
    return s


# ================================================================= BOSS =====

def boss():
    intro = "Cm | Cm | Ab | G |"
    A = "Cm | Ab | Fm | G | Cm | Ab | Fm | G7 |"
    B = "Ab | Bb | Gm | Cm | Ab | Fm | Dm7b5 | G7 |"
    brk = "Cm | Db | Cm | G7 |"
    bars = parse_bars(intro + A + B + A + brk)
    s = Song("boss", 160, loop_beats=4 * len(bars), rng_seed=5)
    organ = s.part(19, 0, volume=86, reverb=90)                    # church organ
    choir = s.part(52, 1, volume=100, reverb=110)                  # choir aahs
    strings = s.part(48, 2, volume=90, pan=40, reverb=70)
    bass = s.part(33, 3, volume=100, reverb=15)                    # finger bass
    timp = s.part(47, 4, volume=104, reverb=60)
    brass = s.part(61, 5, volume=86, pan=88, reverb=60)
    dgtr = s.part(30, 6, volume=60, pan=74, reverb=30)             # distortion gtr
    drums = s.part(0, 9, volume=104, reverb=40)

    choirA = mel("G4/2 Ab4/1 G4/1 C5/2 Eb5/2 F5/1.5 Eb5/0.5 D5/1 C5/1 B4/4 "
                 "G5/2 F5/1 Eb5/1 Eb5/2 C5/2 Ab5/2 G5/1 F5/1 D5/2 B4/2")
    organB = mel("C5/0.5 Eb5/0.5 Ab5/1 G5/0.5 F5/0.5 Eb5/1 D5/0.5 F5/0.5 Bb5/1 Ab5/0.5 G5/0.5 F5/1 "
                 "G5/1.5 Bb5/0.5 D6/1 Bb5/1 C6/3 G5/1 "
                 "Ab5/0.5 G5/0.5 F5/0.5 Eb5/0.5 C5/2 F5/0.5 Eb5/0.5 D5/0.5 C5/0.5 Ab4/2 "
                 "Ab4/1 C5/1 F5/1 Ab5/1 B5/2 D6/1 F6/1")

    s.melody(choir, choirA, 16, vel=96, legato=0.98)
    s.melody(organ, organB, 48, vel=100, legato=0.9)
    s.melody(brass, organB, 48, vel=78, legato=0.9, transpose=-12)
    s.melody(choir, choirA, 80, vel=104, legato=0.98)
    s.melody(brass, choirA, 80, vel=84, legato=0.9, transpose=12)

    for b, chords in enumerate(bars):
        t0 = b * 4
        ch = chords[0]
        sec = "intro" if b < 4 else "A" if b < 12 else "B" if b < 20 else "A2" if b < 28 else "brk"
        r = ch.root_note(1)
        if r < 31:
            r += 12
        # string ostinato
        rs = ch.root_note(3)
        if rs > 62:
            rs -= 12
        third = rs + ch.intervals[1]
        fifth = rs + 7
        ost = [rs, rs, third, rs, fifth, rs, rs + 8 if 3 in ch.intervals else rs + 9, fifth]
        if sec != "intro":
            for k, p in enumerate(ost):
                s.note(strings, p, t0 + k * 0.5, 0.45, 88 if k % 4 == 0 else 72)
        # organ chord pads (except when organ has the melody)
        if sec != "B":
            s.chord(organ, ch.voicing(60, 4), t0, 4, 70 if sec != "brk" else 86)
        else:
            s.chord(choir, ch.voicing(60, 3), t0, 4, 64)
        if sec == "brk":
            s.chord(choir, ch.voicing(67, 4), t0, 4, 90)
        # bass: pounding 8ths
        for k in range(8):
            s.note(bass, r + (12 if k in (3, 7) else 0), t0 + k * 0.5, 0.45, 100 if k % 2 == 0 else 84)
        if sec in ("A2", "B"):
            for k in range(8):
                s.chord(dgtr, [r + 12, r + 19], t0 + k * 0.5, 0.4, 76)
        # timpani on downbeats, roll at phrase ends
        s.note(timp, ch.root_note(2) if ch.root_note(2) <= 50 else ch.root_note(1), t0, 1.5, 110)
        if b % 4 == 3:
            for k in range(8):
                s.note(timp, ch.root_note(2) if ch.root_note(2) <= 50 else ch.root_note(1),
                       t0 + 2 + k * 0.25, 0.25, 70 + k * 6)
        # drums
        if sec == "intro":
            pat = {LTOM: [(0, 110), (1, 96), (2, 104), (3, 100)], KICK: [(0, 110), (2, 100)]}
            if b == 3:
                pat[SNARE] = [(2 + x * 0.25, 70 + x * 7) for x in range(8)]
        else:
            pat = {KICK: [(0, 120), (1, 100), (2, 116), (2.5, 96), (3, 104)],
                   SNARE: [(1, 112), (3, 118)],
                   RIDE: [(x / 2, 76) for x in range(8)] if sec != "B" else [],
                   CHH: [(x / 2, 70) for x in range(8)] if sec == "B" else []}
            if b % 4 == 0:
                pat[CRASH] = [(0, 110)]
            if b % 8 == 7:
                pat[HTOM] = [(2, 100), (2.25, 96)]
                pat[MTOM] = [(2.5, 104), (2.75, 100)]
                pat[LTOM] = [(3.25, 110), (3.5, 112), (3.75, 116)]
            if sec == "brk":
                pat = {KICK: [(0, 120), (0.75, 90), (1.5, 110), (2, 104), (3, 110), (3.5, 100)],
                       LTOM: [(1, 104), (2.5, 100), (3, 110)], CHINA: [(0, 96)] if b % 2 == 0 else []}
        drum_pattern(s, drums, t0, 4, pat)
    return s


# ============================================================= INTERIOR =====

def interior():
    bars = parse_bars(
        "Fmaj7 | Em7 A7 | Dm7 | Cm7 F7 | Bbmaj7 | Bbm6 | Am7 | D7 |"
        "Gm7 | C7 | Fmaj7 | D7 | Gm7 | C7 | Fmaj7 Dm7 | Gm7 C7")
    s = Song("interior", 75, loop_beats=4 * len(bars), rng_seed=11)
    ep = s.part(4, 0, volume=86, pan=50, reverb=70, chorus=50)    # Rhodes
    box = s.part(10, 1, volume=86, pan=76, reverb=90)              # music box
    bass = s.part(32, 2, volume=88, reverb=30)
    vib = s.part(11, 3, volume=58, pan=30, reverb=90)              # vibraphone
    drums = s.part(0, 9, volume=60, reverb=40)

    tune = mel(
        "A5/1 C6/1 E6/1.5 D6/0.5 C6/1 B5/1 C#6/1 E6/1 "
        "F6/2 E6/1 D6/1 Eb6/1 C6/1 A5/1 F5/1 "
        "D6/1.5 C6/0.5 Bb5/1 A5/1 Db6/2 Bb5/1 G5/1 "
        "C6/1 A5/1 E5/2 F#5/1 A5/1 C6/1 D6/1 "
        "Bb5/1.5 A5/0.5 G5/1 D6/1 E5/1 G5/1 Bb5/1 C6/1 "
        "A5/3 r/1 F#5/1 A5/1 D6/1 C6/1 "
        "Bb5/1 D6/1 F6/1 E6/0.5 D6/0.5 E6/2 Bb5/1 G5/1 "
        "F5/1 A5/1 D6/1 C6/1 Bb5/1 A5/1 G5/1 E5/1")
    s.melody(box, tune, 0, vel=80, legato=0.9)
    # vibraphone shadows the second half an octave down, softly
    s.melody(vib, tune[len(tune) // 2:], 32, vel=50, legato=0.9, transpose=-12)

    for b, chords in enumerate(bars):
        t0 = b * 4
        seg = 4 / len(chords)
        for i, ch in enumerate(chords):
            t = t0 + i * seg
            v = ch.voicing(62, 4)
            s.chord(ep, v, t, min(1.4, seg), 58, strum=0.015)
            if seg >= 4:
                s.chord(ep, v, t + 2.5, 1.4, 50, strum=0.015)
                s.note(bass, ch.bass_note(2), t, 1.9, 78)
                s.note(bass, ch.bass_note(2) + 7 if ch.bass_note(2) < 41 else ch.bass_note(2) - 5, t + 2, 1.9, 70)
            else:
                s.chord(ep, v, t + 1.5, 0.5, 46)
                s.note(bass, ch.bass_note(2), t, 1.9, 76)
        drum_pattern(s, drums, t0, 4, {SHAKER: [(x / 2, 30 + 10 * (x % 2)) for x in range(8)],
                                       RIM: [(3, 30)] if b % 2 else []})
    return s


# ============================================================== STINGERS ====

def victory():
    s = Song("victory", 144)
    brass = s.part(61, 0, volume=104, reverb=70)
    tpt = s.part(56, 1, volume=96, reverb=70, pan=74)              # trumpet
    glock = s.part(9, 2, volume=80, reverb=80, pan=40)
    timp = s.part(47, 3, volume=100, reverb=60)
    bass = s.part(32, 4, volume=96, reverb=30)
    drums = s.part(0, 9, volume=96, reverb=40)
    third = 1 / 3
    line = mel(f"G4/{third} C5/{third} E5/{third} G5/1 E5/0.5 G5/0.5 A5/0.5 B5/0.5 C6/3")
    s.melody(tpt, line, 0, vel=110, legato=0.9)
    s.melody(glock, line, 0, vel=90, legato=0.6, transpose=12)
    s.chord(brass, [n("C4"), n("E4"), n("G4")], 1, 0.5, 100)
    s.chord(brass, [n("D4"), n("F4"), n("A4")], 2, 0.5, 96)
    s.chord(brass, [n("F4"), n("G4"), n("B4")], 2.5, 0.5, 100)
    s.chord(brass, [n("C4"), n("E4"), n("G4"), n("C5")], 3, 3, 110)
    s.note(bass, n("C2"), 1, 0.5, 100)
    s.note(bass, n("G2"), 2.5, 0.5, 96)
    s.note(bass, n("C2"), 3, 3, 110)
    for k in range(6):
        s.note(timp, n("G2"), 2 + k * 1 / 6, 1 / 6, 70 + 6 * k)
    s.note(timp, n("C2"), 3, 2, 120)
    drum_pattern(s, drums, 0, 8, {CRASH: [(3, 110)], KICK: [(1, 100), (3, 116)], SNARE: [(2.5, 90)]})
    return s


def gameover():
    s = Song("gameover", 56)
    strings = s.part(49, 0, volume=96, reverb=110)
    piano = s.part(0, 1, volume=96, reverb=100)
    cel = s.part(8, 2, volume=70, reverb=120, pan=40)
    pad = s.part(89, 3, volume=70, reverb=120)
    for t, sym, d in [(0, "Am", 1), (1, "F", 1), (2, "Dm", 1), (3, "E7", 1), (4, "Am", 3)]:
        ch = Chord(sym)
        s.chord(strings, [ch.bass_note(2)] + ch.voicing(57, 3), t, d, 76 if t < 4 else 66)
        s.chord(pad, ch.voicing(64, 3), t, d, 50)
    s.melody(piano, mel("E5/1 C5/1 A4/0.5 F4/0.5 G#4/1 A4/3"), 0, vel=76, legato=1.0)
    s.note(piano, n("A2"), 4, 3, 60)
    s.note(cel, n("A6"), 4.5, 2, 50)
    s.note(cel, n("E6"), 5.25, 2, 40)
    return s


# ================================================================== main ====

LOOPS = {"title": title, "town": town, "overland": overland, "night": night,
         "battle": battle, "boss": boss, "interior": interior}
ONESHOTS = {"victory": (victory, 1.0, 5.5), "gameover": (gameover, 2.5, 7.5)}


def main(names):
    if not os.path.exists(SF2):
        sys.exit(f"missing soundfont {SF2} - download GeneralUser-GS.sf2 from "
                 "https://github.com/mrbumpy409/GeneralUser-GS")
    for name in names or list(LOOPS) + list(ONESHOTS):
        if name in LOOPS:
            render(LOOPS[name](), loop=True)
        else:
            fn, fade, max_s = ONESHOTS[name]
            render(fn(), loop=False, tail_beats=6, fade_out=fade, max_seconds=max_s)


if __name__ == "__main__":
    main(sys.argv[1:])
