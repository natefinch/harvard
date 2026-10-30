#!/usr/bin/env python3
"""Synthesize the sound effects for "Nowhere Near Cambridge".

Usage:  .venv/bin/python game-art/audio/sfx.py [name ...]

Everything is generated with numpy/scipy (deterministic seeds) and written as
16-bit 44.1 kHz mono WAV into game/assets/sfx/, peak-normalized to -3 dBFS.
"""
import os
import sys

import numpy as np
from scipy import signal
from scipy.io import wavfile

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, "..", "..", "game", "assets", "sfx"))
SR = 44100
PEAK_DB = -3.0


# ------------------------------------------------------------- helpers -----

def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def rng(seed):
    return np.random.default_rng(seed)


def env_adsr(n, a=0.005, d=0.05, s=0.6, r=0.05):
    a, d, r = int(a * SR), int(d * SR), int(r * SR)
    sus = max(0, n - a - d - r)
    e = np.concatenate([np.linspace(0, 1, a, endpoint=False), np.linspace(1, s, d, endpoint=False),
                        np.full(sus, s), np.linspace(s, 0, r)])
    return np.pad(e, (0, max(0, n - len(e))))[:n]


def env_exp(n, tau, attack=0.002):
    t = np.arange(n) / SR
    e = np.exp(-t / tau)
    a = int(attack * SR)
    if a:
        e[:a] *= np.linspace(0, 1, a)
    return e


def sweep_phase(f):
    """Instantaneous frequency array -> phase."""
    return 2 * np.pi * np.cumsum(f) / SR


def osc(f, shape="sine"):
    ph = sweep_phase(f) if np.ndim(f) else None
    if ph is None:
        raise ValueError("pass an array of frequencies")
    if shape == "sine":
        return np.sin(ph)
    if shape == "square":
        return np.sign(np.sin(ph)) * 0.6
    if shape == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    if shape == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    raise ValueError(shape)


def lp(x, fc, order=2):
    b, a = signal.butter(order, min(fc, SR / 2 - 100) / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def hp(x, fc, order=2):
    b, a = signal.butter(order, fc / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), min(hi, SR / 2 - 100) / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def swept_bp(x, centers, q=4.0, block=256):
    """Band-pass with a time-varying center frequency (block-wise state-variable filter)."""
    y = np.zeros_like(x)
    low = band = 0.0
    for i in range(0, len(x), block):
        fc = centers[min(i, len(centers) - 1)]
        f = 2 * np.sin(np.pi * min(fc, SR / 6) / SR)
        damp = 1.0 / q
        for j in range(i, min(i + block, len(x))):
            low += f * band
            high = x[j] - low - damp * band
            band += f * high
            y[j] = band
    return y


def reverb(x, seconds=1.2, mix=0.3, seed=0, damp=4000):
    n = int(seconds * SR)
    ir = rng(seed).standard_normal(n) * np.exp(-np.arange(n) / SR * 6.9 / seconds)
    ir = lp(ir, damp)
    ir /= np.sqrt(np.sum(ir ** 2))
    wet = np.pad(signal.fftconvolve(x, ir), (0, 1))[: len(x) + n]
    dry = np.pad(x, (0, n))
    return (1 - mix) * dry + mix * wet


def bell_partials(t, f0, ratios, amps, taus):
    out = np.zeros_like(t)
    for r, a, tau in zip(ratios, amps, taus):
        out += a * np.sin(2 * np.pi * f0 * r * t) * np.exp(-t / tau)
    return out


def fade(x, fin=0.002, fout=0.01):
    x = x.copy()
    a, b = int(fin * SR), int(fout * SR)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def trim(x, thresh=1e-3):
    idx = np.nonzero(np.abs(x) > thresh * np.abs(x).max())[0]
    return x[: idx[-1] + 1] if len(idx) else x


def save(name, x, peak_db=PEAK_DB):
    x = np.asarray(x, dtype=np.float64)
    x = x - np.mean(x) if len(x) > SR else x
    x = fade(x, 0.001, 0.008)
    x *= 10 ** (peak_db / 20) / np.max(np.abs(x))
    os.makedirs(OUT, exist_ok=True)
    wavfile.write(os.path.join(OUT, name + ".wav"), SR, np.round(x * 32767).astype(np.int16))
    print(f"{name}.wav  {len(x) / SR:5.2f}s  peak {20 * np.log10(np.max(np.abs(x))):.1f} dBFS")


# ------------------------------------------------------------- effects -----

def blip():
    t = t_axis(0.045)
    f = np.full_like(t, 660.0)
    x = 0.7 * osc(f, "tri") + 0.3 * osc(f * 2, "sine")
    x *= env_adsr(len(t), 0.002, 0.015, 0.5, 0.02)
    return lp(x, 3500)


def cursor():
    t = t_axis(0.05)
    x = osc(np.full_like(t, 1320.0), "square") * env_exp(len(t), 0.012, 0.001)
    return lp(x, 6000)


def select():
    parts = []
    for f, d in [(1046.5, 0.06), (1568.0, 0.12)]:
        t = t_axis(d)
        x = osc(np.full_like(t, f), "square") * 0.6 + osc(np.full_like(t, f * 2), "sine") * 0.2
        parts.append(x * env_adsr(len(t), 0.002, 0.03, 0.6, d * 0.5))
    return lp(np.concatenate(parts), 7000)


def cancel():
    parts = []
    for f, d in [(784.0, 0.06), (523.25, 0.13)]:
        t = t_axis(d)
        x = osc(np.full_like(t, f), "square") * 0.6
        parts.append(x * env_adsr(len(t), 0.002, 0.03, 0.6, d * 0.5))
    return lp(np.concatenate(parts), 4000)


def hit():
    t = t_axis(0.28)
    f = 55 + 140 * np.exp(-t / 0.03)
    body = osc(f, "sine") * env_exp(len(t), 0.07)
    noise = rng(1).standard_normal(len(t))
    smack = bp(noise, 600, 4000) * env_exp(len(t), 0.015)
    x = body + 0.7 * smack
    return np.tanh(2.0 * x)


def crit():
    t = t_axis(1.1)
    r = rng(2)
    f = 45 + 260 * np.exp(-t / 0.05)
    boom = osc(f, "sine") * env_exp(len(t), 0.18)
    noise = r.standard_normal(len(t))
    crash = hp(noise, 1500) * env_exp(len(t), 0.25) * 0.6
    smash = bp(noise, 300, 3000) * env_exp(len(t), 0.06)
    metal = bell_partials(t, 420, [1, 2.76, 5.4, 8.93], [0.5, 0.35, 0.25, 0.15], [0.3, 0.2, 0.12, 0.08])
    x = 1.3 * boom + smash + crash + 0.5 * metal
    x = np.tanh(3.0 * x)  # crunchy saturation = SMAAAASH
    return reverb(x, 0.8, 0.25, seed=2)


def miss():
    t = t_axis(0.4)
    noise = rng(3).standard_normal(len(t))
    centers = 500 + 2500 * np.sin(np.pi * t / t[-1]) ** 2
    x = swept_bp(noise, centers, q=3.0)
    e = np.sin(np.pi * np.clip(t / t[-1], 0, 1)) ** 1.5
    return x * e


def heal():
    notes = [523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0]
    dur = 1.1
    t = t_axis(dur)
    x = np.zeros_like(t)
    for i, f in enumerate(notes):
        st = int(i * 0.07 * SR)
        tt = t[: len(t) - st]
        tone = bell_partials(tt, f, [1, 2, 3.01], [1, 0.3, 0.1], [0.35, 0.2, 0.1])
        x[st:] += tone * (0.6 + 0.08 * i)
    sparkle = hp(rng(4).standard_normal(len(t)), 6000) * 0.15
    grains = np.zeros_like(t)
    for k in range(40):
        st = int(rng(100 + k).uniform(0.05, 0.8) * SR)
        g = t_axis(0.03)
        fr = rng(200 + k).uniform(2500, 6000)
        grains[st:st + len(g)] += np.sin(2 * np.pi * fr * g) * np.exp(-g / 0.008) * 0.25
    x += grains + sparkle * env_exp(len(t), 0.3)
    return reverb(x, 1.0, 0.3, seed=4)


def enemy_die():
    t = t_axis(0.8)
    r = rng(6)
    f = 900 * np.exp(-t / 0.25) + 60
    tone = osc(f * (1 + 0.05 * np.sin(2 * np.pi * 30 * t)), "square") * env_exp(len(t), 0.25)
    noise = r.standard_normal(len(t))
    centers = 4000 * np.exp(-t / 0.2) + 200
    puff = swept_bp(noise, centers, q=1.5) * env_exp(len(t), 0.3, 0.01)
    x = 0.4 * tone + puff
    # bit-crush wobble for a "dissolve" feel
    steps = 2 ** (6 - 4 * t / t[-1])
    x = np.round(x * steps) / steps
    hold = 4
    x = np.repeat(x[::hold], hold)[: len(t)]
    return lp(x, 8000)


def encounter():
    dur = 1.2
    t = t_axis(dur)
    r = rng(7)
    # rising swirl: FM tone sweeping up, then a dissonant stinger chord
    f = 120 * (2 ** (5 * (t / dur) ** 1.5))
    swirl = np.sin(sweep_phase(f) + 3 * np.sin(sweep_phase(f * 1.5)))
    swirl *= np.clip(t / 0.5, 0, 1) * np.exp(-np.clip(t - 0.55, 0, None) / 0.05)
    whoosh = swept_bp(r.standard_normal(len(t)), 300 + 5000 * (t / dur) ** 2, q=2.0)
    whoosh *= np.sin(np.pi * np.clip(t / 0.6, 0, 1))
    stinger = np.zeros_like(t)
    st = int(0.55 * SR)
    tt = t[: len(t) - st]
    for fr in [220.0, 233.08, 311.13, 466.16]:  # A, Bb, Eb, Bb - tritone cluster
        stinger[st:] += osc(np.full_like(tt, fr), "saw") * 0.3
    stinger[st:] *= env_exp(len(tt), 0.35, 0.005)
    stinger = lp(stinger, 3000)
    hitn = np.zeros_like(t)
    h = hit()
    hitn[st:st + len(h)] = h * 0.8
    x = 0.5 * swirl + 0.6 * whoosh + stinger + hitn
    return reverb(x, 0.9, 0.25, seed=7)


def door():
    r = rng(8)
    # creak: low rough tone with irregular "stick-slip" pulses
    t1 = t_axis(0.55)
    f = 180 + 60 * np.sin(2 * np.pi * 1.3 * t1) + 25 * r.standard_normal(len(t1)).cumsum() / 300
    pulses = np.sin(sweep_phase(f)) ** 15 * np.sign(np.sin(sweep_phase(f)))
    creak = bp(pulses, 300, 3000) * np.sin(np.pi * t1 / t1[-1]) * 0.6
    # thump + wooden knock resonance when it closes
    t2 = t_axis(0.5)
    thud = osc(70 + 80 * np.exp(-t2 / 0.02), "sine") * env_exp(len(t2), 0.08)
    wood = bell_partials(t2, 210, [1, 2.3, 3.9], [0.6, 0.4, 0.2], [0.05, 0.03, 0.02])
    knock = bp(r.standard_normal(len(t2)), 200, 2000) * env_exp(len(t2), 0.02)
    close = thud + wood + 0.5 * knock
    x = np.concatenate([creak, np.zeros(int(0.02 * SR))])
    out = np.zeros(len(x) + len(close))
    out[: len(x)] += x
    out[len(x) - int(0.05 * SR): len(x) - int(0.05 * SR) + len(close)] += close
    return reverb(out, 0.5, 0.2, seed=8, damp=2500)


def pickup():
    t = t_axis(0.7)
    x = np.zeros_like(t)
    for st, f in [(0.0, 1318.5), (0.08, 1975.5)]:
        s = int(st * SR)
        tt = t[: len(t) - s]
        x[s:] += bell_partials(tt, f, [1, 2.0, 3.0, 4.2], [1, 0.4, 0.2, 0.1], [0.3, 0.15, 0.08, 0.05])
    return reverb(x, 0.8, 0.25, seed=9)


def save_sfx():
    # coin-drop "ding" then a short burst of North American dial tone (350 + 440 Hz)
    t = t_axis(0.6)
    ding = bell_partials(t, 1400, [1, 2.4, 3.9], [1, 0.4, 0.2], [0.25, 0.1, 0.05])
    ding2 = np.zeros_like(t)
    s = int(0.09 * SR)
    ding2[s:] = 0.7 * bell_partials(t[: len(t) - s], 1050, [1, 2.4], [1, 0.3], [0.2, 0.08])
    td = t_axis(0.7)
    dial = (np.sin(2 * np.pi * 350 * td) + np.sin(2 * np.pi * 440 * td)) * 0.25
    dial = bp(dial, 300, 3400) * env_adsr(len(td), 0.01, 0.05, 1.0, 0.15)
    out = np.zeros(int(1.25 * SR))
    out[: len(t)] += ding + ding2
    st = int(0.45 * SR)
    out[st: st + len(td)] += dial
    return out


def hum():
    dur = 3.2
    t = t_axis(dur)
    r = rng(10)
    x = (np.sin(2 * np.pi * 55.0 * t) + 0.9 * np.sin(2 * np.pi * 56.2 * t + 0.4)  # ~1.2 Hz beating
         + 0.35 * np.sin(2 * np.pi * 110.3 * t) + 0.2 * np.sin(2 * np.pi * 164.8 * t)
         + 0.08 * np.sin(2 * np.pi * 220.7 * t))
    # slight mains-like buzz
    x += 0.04 * lp(np.sign(np.sin(2 * np.pi * 55 * t)), 600)
    # faint rising whine
    fw = 1800 + 500 * (t / dur) ** 2
    whine = np.sin(sweep_phase(fw)) * 0.03 * np.clip(t / 1.0, 0, 1)
    whine *= 1 + 0.3 * np.sin(2 * np.pi * 5.5 * t)
    air = lp(r.standard_normal(len(t)), 300) * 0.05
    e = np.clip(t / 0.8, 0, 1) * np.clip((dur - t) / 0.8, 0, 1)
    return (x + whine + air) * e


def phone_ring():
    dur = 2.0
    t = t_axis(dur)
    # two bells struck alternately by a 20 Hz clapper
    tone = np.zeros_like(t)
    for f, a in [(1000, 1), (1250, 0.8), (2650, 0.35), (3400, 0.2)]:
        tone += a * np.sin(2 * np.pi * f * t)
    strike = np.zeros_like(t)
    for k in np.arange(0, 1.7, 1 / 40):
        i = int(k * SR)
        n = len(t) - i
        strike[i:] += np.exp(-np.arange(n) / SR / 0.03)
    strike = np.minimum(strike, 1.6)
    ring_env = np.ones_like(t)
    tail = t > 1.7
    ring_env[tail] = np.exp(-(t[tail] - 1.7) / 0.08)
    x = tone * strike * ring_env
    x = bp(x, 400, 5000)
    return reverb(x, 0.4, 0.15, seed=11)


def bell():
    dur = 3.2
    t = t_axis(dur)
    f0 = 196.0
    # church-bell partials: hum, prime, tierce, quint, nominal, upper
    x = bell_partials(t, f0, [0.5, 1.0, 1.183, 1.506, 2.0, 2.514, 3.011],
                      [0.6, 1.0, 0.7, 0.4, 0.6, 0.3, 0.2],
                      [2.5, 1.8, 1.4, 1.0, 0.9, 0.6, 0.4])
    # underwater: slow pitch wobble (via varying delay), heavy low-pass, murk
    wob = 0.004 * np.sin(2 * np.pi * 0.7 * t) * SR
    idx = np.clip(np.arange(len(t)) - 200 - wob, 0, len(t) - 1)
    x = np.interp(idx, np.arange(len(t)), x)
    x = lp(x, 700, order=4)
    x += lp(rng(12).standard_normal(len(t)), 150) * 0.03 * np.clip(t / 0.3, 0, 1)
    x = reverb(x, 2.0, 0.45, seed=12, damp=1200)
    return x[: int(dur * SR)] * np.clip((dur - t) / 0.5, 0, 1)


def step():
    r = rng(13)
    t = t_axis(0.22)
    body = lp(r.standard_normal(len(t)), 900) * env_exp(len(t), 0.04, 0.005)
    crackle = np.zeros_like(t)
    for k in range(18):
        i = int(r.uniform(0.0, 0.15) * SR)
        g = t_axis(0.004)
        crackle[i:i + len(g)] += r.standard_normal(len(g)) * np.exp(-g / 0.001) * r.uniform(0.2, 0.7)
    crackle = bp(crackle, 1500, 7000)
    return 0.8 * body + crackle * env_exp(len(t), 0.08)


def bike():
    t = t_axis(1.0)
    x = np.zeros_like(t)
    for st in (0.0, 0.16):
        s = int(st * SR)
        tt = t[: len(t) - s]
        tone = bell_partials(tt, 2900, [1, 1.006, 2.35, 3.6, 5.1], [1, 0.8, 0.45, 0.25, 0.12],
                             [0.45, 0.45, 0.25, 0.12, 0.06])
        click = hp(rng(14).standard_normal(len(tt)), 3000) * np.exp(-tt / 0.002) * 0.4
        x[s:] += tone + click
    return x


EFFECTS = {
    "blip": blip, "select": select, "cursor": cursor, "cancel": cancel,
    "hit": hit, "crit": crit, "miss": miss, "heal": heal, "enemy_die": enemy_die,
    "encounter": encounter, "door": door, "pickup": pickup, "save": save_sfx,
    "hum": hum, "phone_ring": phone_ring, "bell": bell, "step": step, "bike": bike,
}


def main(names):
    for name in names or EFFECTS:
        x = EFFECTS[name]()
        if name not in ("hum", "bell"):
            x = trim(x)
        save(name, x)


if __name__ == "__main__":
    main(sys.argv[1:])
