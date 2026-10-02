"""Placeholder music and ambience beds (Audio Bible A3): bar-exact stems, original melodies.

Grove: D minor pentatonic, 96 BPM, 16 bars (5 stems). Boss: D Phrygian, 120 BPM, 16 bars (4 stems).
Camp: D major pentatonic, 72 BPM, 32 bars (2 playlist tracks). Victory / defeat stingers.
Every note is placed with wrap-around, so tails land in the loop head and stems loop seamlessly.
The spirit leitmotif is D–E–G–A–D′ (MIDI 62 64 67 69 74).
"""
from __future__ import annotations

import numpy as np

from dsp import (SR, adsr, bp, db, detune, hp, lp, midi_hz, n_of, noise, osc, perc, place, reverb, saturate,
                 wrap)

MOTIF = [62, 64, 67, 69, 74]


# ----------------------------------------------------------------------------- instruments (mono)

def flute(m: float, dur: float, rng: np.random.Generator, breath: float = 0.3) -> np.ndarray:
    k = n_of(dur + 0.25)
    f = midi_hz(m)
    t = np.arange(k) / SR
    vib = 1.0 + 0.007 * np.sin(2 * np.pi * 5.0 * t + rng.random() * 6.28) * np.clip((t - 0.12) / 0.2, 0, 1)
    x = osc("sine", f * vib, k) + 0.22 * osc("sine", 2 * f * vib, k) + 0.06 * osc("sine", 3 * f * vib, k)
    air = bp(noise(k, rng), f * 0.9, f * 3.0) * breath
    chiff = bp(noise(k, rng), 2000, 6000) * perc(k, 0.003, 0.03) * 0.3
    env = adsr(k, 0.06, 0.15, 0.8, 0.22)
    return (x + air) * env + chiff


def bell_note(m: float, dur: float, rng: np.random.Generator, detune_c: float = 0.0) -> np.ndarray:
    k = n_of(dur)
    f = midi_hz(m) * 2.0 ** (detune_c / 1200.0)
    x = np.zeros(k)
    for i, r in enumerate([1.0, 2.0, 2.76, 4.07]):
        x += osc("sine", f * r, k) * perc(k, 0.002, dur * 0.5 / (1 + i)) / (1 + i)
    return x


def dhol(low: bool, rng: np.random.Generator, accent: float = 1.0) -> np.ndarray:
    if low:  # "dha": big low skin
        k = n_of(0.5)
        t = np.arange(k) / SR
        fr = 58 + 70 * np.exp(-t / 0.03)
        body = np.sin(2 * np.pi * np.cumsum(fr) / SR) * perc(k, 0.002, 0.22)
        slap = bp(noise(k, rng), 300, 2500) * perc(k, 0.001, 0.02) * 0.5
        return (body + slap) * accent
    k = n_of(0.25)  # "tin": high stick
    t = np.arange(k) / SR
    fr = 330 + 120 * np.exp(-t / 0.01)
    body = np.sin(2 * np.pi * np.cumsum(fr) / SR) * perc(k, 0.001, 0.06)
    slap = bp(noise(k, rng), 1500, 7000) * perc(k, 0.001, 0.015) * 0.7
    return (body * 0.6 + slap) * accent


def dholki_ghost(rng: np.random.Generator) -> np.ndarray:
    k = n_of(0.12)
    return bp(noise(k, rng), 600, 3000) * perc(k, 0.001, 0.02) * 0.35


def ghungroo(rng: np.random.Generator, length: float = 0.18) -> np.ndarray:
    k = n_of(length)
    x = np.zeros(k)
    for _ in range(5):  # a cluster of tiny bells, slightly spread
        s = rng.integers(0, max(1, k // 6))
        f = rng.uniform(5200, 8200)
        b = osc("sine", f, k - s) * perc(k - s, 0.0005, 0.04)
        x[s:] += b * 0.25
    return x + hp(noise(k, rng), 6000) * perc(k, 0.001, 0.03) * 0.3


def drone(m: float, length: int, rng: np.random.Generator, bright: float = 900.0) -> np.ndarray:
    """Tarpa-like reedy drone: two slowly beating saws through a soft low-pass."""
    f = midi_hz(m)
    t = np.arange(length) / SR
    lfo = 1.0 + 0.002 * np.sin(2 * np.pi * 0.11 * t)
    x = osc("saw", f * lfo, length) + osc("saw", f * 1.003, length) + 0.5 * osc("saw", f * 2.0 * 0.999, length)
    x = lp(x, bright, 2)
    amp = 0.8 + 0.2 * np.sin(2 * np.pi * 0.07 * t + rng.random() * 6.28)
    return x * amp / 3.0


def hum(m: float, length: int) -> np.ndarray:
    f = midi_hz(m)
    t = np.arange(length) / SR
    x = osc("sine", f, length) + 0.5 * osc("sine", f * 1.5 * 1.002, length) + 0.3 * osc("sine", f * 2.0, length)
    return x * (0.7 + 0.3 * np.sin(2 * np.pi * 0.05 * t)) / 2.0


def bass_pluck(m: float, dur: float, rng: np.random.Generator) -> np.ndarray:
    k = n_of(dur)
    f = midi_hz(m)
    x = osc("tri", f, k) + 0.3 * osc("sine", 2 * f, k)
    return lp(x, 700) * perc(k, 0.004, dur * 0.4)


def sub_pulse(rng: np.random.Generator, f: float = 50.0) -> np.ndarray:
    k = n_of(0.25)
    body = osc("sine", f, k) * perc(k, 0.004, 0.08)
    ghost = bp(noise(k, rng), 900, 2200) * perc(k, 0.001, 0.008) * 0.4  # mid "ghost" for phone speakers
    return body + ghost


def dhak(rng: np.random.Generator) -> np.ndarray:
    k = n_of(0.9)
    t = np.arange(k) / SR
    fr = 48 + 60 * np.exp(-t / 0.05)
    body = np.sin(2 * np.pi * np.cumsum(fr) / SR) * perc(k, 0.003, 0.4)
    return body + bp(noise(k, rng), 200, 1500) * perc(k, 0.002, 0.05) * 0.6


def glass_swell(m: float, dur: float, rng: np.random.Generator, detune_c: float = 35.0) -> np.ndarray:
    k = n_of(dur)
    f = midi_hz(m)
    x = osc("sine", f, k) + osc("sine", f * 2.0 ** (detune_c / 1200), k) + 0.4 * osc("sine", f * 2.76, k)
    return x * adsr(k, dur * 0.6, 0.2, 1.0, dur * 0.35) * 0.4


def cricket(rng: np.random.Generator) -> np.ndarray:
    k = n_of(0.35)
    f = rng.uniform(4200, 5200)
    x = osc("sine", f, k)
    gate = (np.sin(2 * np.pi * 32 * np.arange(k) / SR) > 0.2).astype(float)
    return lp(x * gate, 9000) * adsr(k, 0.02, 0.1, 0.8, 0.08) * 0.25


# ----------------------------------------------------------------------------- arranging helpers

class Grid:
    def __init__(self, bpm: float, bars: int, beats_per_bar: int = 4) -> None:
        self.bpm, self.bars, self.bpb = bpm, bars, beats_per_bar
        self.beat = 60.0 / bpm
        self.length = n_of(self.beat * beats_per_bar * bars)

    def at(self, bar: int, beat: float) -> int:
        return int(round(((bar * self.bpb) + beat) * self.beat * SR))

    def buf(self) -> np.ndarray:
        return np.zeros(self.length)


def melody(grid: Grid, phrases: list, rng: np.random.Generator, inst=flute, octave: int = 0,
           detune_c: float = 0.0, speed: float = 1.0) -> np.ndarray:
    """phrases: list of (bar, [(beat, midi, beats_long), ...])."""
    buf = grid.buf()
    for bar, notes in phrases:
        for beat, m, length in notes:
            x = inst(m + octave * 12, length * grid.beat * speed, rng)
            if detune_c:
                x = detune(x, detune_c)
            place(buf, x, grid.at(bar, beat * speed))
    return buf


def _room(x: np.ndarray, rng: np.random.Generator, rt: float, wet: float, length: int) -> np.ndarray:
    return wrap(reverb(x, rng, rt, wet), length)


# ----------------------------------------------------------------------------- cues

def grove(rng: np.random.Generator) -> dict:
    g = Grid(96, 16)
    n = g.length
    # S1 bed: D drone + A fifth + hum (stereo pair rendered with different phases).
    def bed_side(seed: int) -> np.ndarray:
        r = np.random.default_rng(seed)
        x = drone(38, n, r, 800) + 0.6 * drone(45, n, r, 700) + 0.5 * hum(50, n)
        return _room(x, r, 1.6, 0.3, n)
    s1 = np.stack([bed_side(11), bed_side(12)], axis=1)
    # S2 percussion: dhol dha/tin with swing, dholki ghosts, ghungroo on offbeats; fills on bars 8 and 16.
    s2 = g.buf()
    swing = 0.08
    for bar in range(16):
        place(s2, dhol(True, rng), g.at(bar, 0.0))
        place(s2, dhol(True, rng, 0.7), g.at(bar, 1.5 + swing))
        place(s2, dhol(False, rng), g.at(bar, 1.0))
        place(s2, dhol(False, rng), g.at(bar, 3.0))
        for e in range(8):
            if rng.random() < 0.45:
                place(s2, dholki_ghost(rng), g.at(bar, e * 0.5 + (swing if e % 2 else 0.0)))
        for b in range(4):
            place(s2, ghungroo(rng), g.at(bar, b + 0.5 + swing), 0.6)
        if bar in (7, 15):
            for e in range(4):
                place(s2, dhol(False, rng, 0.8), g.at(bar, 3.0 + e * 0.25))
    s2 = _room(s2, rng, 0.5, 0.15, n)
    # S3 melody: the spirit motif in D minor pentatonic phrases (original).
    A = [(0, 62, 1), (1, 65, 1), (2, 67, 1), (3, 69, 1.5)]
    A2 = [(0.5, 69, 0.5), (1, 67, 1), (2, 65, 1), (3, 62, 1)]
    B = [(0, 72, 1), (1, 69, 1), (2, 67, 1), (3, 65, 1)]
    B2 = [(0, 67, 3)]
    END = [(0, 74, 1), (1, 72, 1), (2, 69, 1), (3, 67, 1)]
    END2 = [(0, 62, 3.5)]
    phrases = [(0, A), (1, A2), (2, B), (3, B2), (4, A), (5, A2), (6, END), (7, END2),
               (8, B), (9, B2), (10, A), (11, A2), (12, B), (13, A2), (14, END), (15, END2)]
    s3 = melody(g, phrases, rng)
    s3 = _room(s3, rng, 1.2, 0.3, n)
    # S4 tension: dhak on 1 and 3 every other bar, sub pulse eighths, detuned glass swells (tritone G#).
    s4 = g.buf()
    for bar in range(16):
        if bar % 2 == 0:
            place(s4, dhak(rng), g.at(bar, 0.0))
            place(s4, dhak(rng), g.at(bar, 2.0), 0.7)
        for e in range(8):
            place(s4, sub_pulse(rng), g.at(bar, e * 0.5), 0.5 if e % 2 else 0.8)
        if bar % 4 == 0:
            place(s4, glass_swell(68, g.beat * 8, rng), g.at(bar, 0.0), 0.6)
    s4 = _room(s4, rng, 0.9, 0.2, n)
    # S5 frenzy: fast ghungroo sixteenths + dhol rolls at the end of each bar.
    s5 = g.buf()
    for bar in range(16):
        for s in range(16):
            place(s5, ghungroo(rng, 0.1), g.at(bar, s * 0.25), 0.8 if s % 4 == 0 else 0.45)
        for e in range(4):
            place(s5, dhol(False, rng, 0.6 + 0.1 * e), g.at(bar, 3.0 + e * 0.25))
    return {"bpm": 96, "bars": 16, "stems": [("bed", s1), ("perc", s2), ("melody", s3), ("tension", s4), ("frenzy", s5)]}


def boss(rng: np.random.Generator) -> dict:
    g = Grid(120, 16)
    n = g.length
    def bed_side(seed: int) -> np.ndarray:
        r = np.random.default_rng(seed)
        x = drone(38, n, r, 650) + 0.45 * drone(39, n, r, 600)  # D with an E♭ rub (blight)
        return _room(x, r, 1.4, 0.3, n)
    b1 = np.stack([bed_side(21), bed_side(22)], axis=1)
    b2 = g.buf()
    for bar in range(16):
        for e in range(8):
            place(b2, dhol(e % 4 == 0 or e == 3, rng, 1.0 if e % 2 == 0 else 0.7), g.at(bar, e * 0.5))
        for s in range(16):
            if rng.random() < 0.35:
                place(b2, dholki_ghost(rng), g.at(bar, s * 0.25))
    b2 = _room(b2, rng, 0.4, 0.12, n)
    # B3: the motif detuned and slowed (Rotheart's heart) over Phrygian answers.
    slow = [(0, 62, 2), (2, 63, 2)]
    slow2 = [(0, 67, 2), (2, 69, 2)]
    ans = [(0, 70, 1), (1, 69, 1), (2, 67, 1), (3, 63, 1)]
    ans2 = [(0, 62, 4)]
    phrases = []
    for base in (0, 4, 8, 12):
        phrases += [(base, slow), (base + 1, slow2), (base + 2, ans), (base + 3, ans2)]
    b3 = melody(g, phrases, rng, detune_c=-35.0)
    b3 = _room(b3, rng, 1.0, 0.3, n)
    b4 = g.buf()
    for bar in range(16):
        place(b4, dhak(rng), g.at(bar, 0.0))
        for e in range(8):
            place(b4, sub_pulse(rng, 46.0), g.at(bar, e * 0.5), 0.7)
        if bar % 2 == 0:
            place(b4, glass_swell(63, g.beat * 4, rng, 50.0), g.at(bar, 0.0), 0.5)
    b4 = _room(b4, rng, 0.8, 0.2, n)
    return {"bpm": 120, "bars": 16, "stems": [("bed", b1), ("perc", b2), ("melody", b3), ("tension", b4)]}


def camp(rng: np.random.Generator, variant: int) -> dict:
    g = Grid(72, 32)
    n = g.length
    L = np.zeros(n)
    R = np.zeros(n)
    r_l, r_r = np.random.default_rng(31 + variant), np.random.default_rng(41 + variant)
    bed_l = drone(50, n, r_l, 600) * 0.5 + hum(62, n) * 0.4
    bed_r = drone(50, n, r_r, 600) * 0.5 + hum(57, n) * 0.4
    L += bed_l
    R += bed_r
    perc_ = g.buf()
    for bar in range(32):
        place(perc_, dhol(True, rng, 0.5), g.at(bar, 0.0))
        place(perc_, dhol(False, rng, 0.4), g.at(bar, 2.0))
        for e in range(8):
            if rng.random() < 0.3:
                place(perc_, dholki_ghost(rng), g.at(bar, e * 0.5))
    # D major pentatonic (D E F# A B) with the motif as its home phrase; variant b answers differently.
    motif = [(0, 62, 1), (1, 64, 1), (2, 67, 1), (3, 69, 1)]
    home = [(0, 74, 3)]
    a = [(0, 66, 1), (1, 69, 1), (2, 71, 2)]
    b = [(0, 69, 1), (1, 66, 1), (2, 64, 2)]
    if variant:
        a, b = [(0, 71, 1), (1, 69, 1), (2, 66, 2)], [(0, 64, 1), (1, 66, 1), (2, 62, 2)]
    phrases = []
    for base in range(0, 32, 8):
        phrases += [(base, motif), (base + 1, home), (base + 2, a), (base + 3, b),
                    (base + 4, motif), (base + 5, a), (base + 6, b), (base + 7, [(0, 62, 3)])]
    mel = melody(g, phrases, rng)
    crick = g.buf()
    for _ in range(80):
        place(crick, cricket(rng), int(rng.integers(0, n)), rng.uniform(0.3, 0.8))
    mel = _room(mel, rng, 1.5, 0.35, n)
    perc_ = _room(perc_, rng, 0.6, 0.2, n)
    L += mel * 0.9 + perc_ * 0.7 + crick * 0.8
    R += mel * 0.8 + perc_ * 0.6 + np.roll(crick, n // 3) * 0.8
    return {"bpm": 72, "bars": 32, "mix": np.stack([L, R], axis=1)}


def stinger(rng: np.random.Generator, win: bool) -> np.ndarray:
    n = n_of(3.6 if win else 3.0)
    out = np.zeros(n)
    if win:
        for i, m in enumerate(MOTIF + [78, 81]):
            b = bell_note(m + 12, 1.6, rng)
            s = n_of(0.12 * i)
            out[s:s + len(b)] += b[:n - s] * 0.6
        d = dhol(True, rng)
        out[:len(d)] += d
        f = flute(74, 1.8, rng)
        s = n_of(0.9)
        out[s:s + len(f)] += f[:n - s] * 0.7
        out += drone(50, n, rng, 800) * adsr(n, 1.0, 0.2, 1.0, 1.4) * 0.5
    else:
        for i, m in enumerate([74, 69, 67, 64, 62]):
            f = detune(flute(m, 0.5, rng, 0.5), -40.0 - 10 * i)
            s = n_of(0.45 * i)
            out[s:s + len(f)] += f[:n - s] * 0.8
        out += drone(38, n, rng, 500) * adsr(n, 0.3, 0.2, 1.0, 1.5) * 0.5
    stereo = np.stack([out, out], axis=1)
    return reverb(stereo[:, 0], rng, 1.5, 0.3)[:n, None].repeat(2, axis=1)


def amb_grove(rng: np.random.Generator) -> np.ndarray:
    n = n_of(60.0)
    sides = []
    for seed in (51, 52):
        r = np.random.default_rng(seed)
        wind = lp(noise(n, r, "brown"), 500) * (0.5 + 0.5 * np.sin(2 * np.pi * np.arange(n) / SR * 0.05 + r.random() * 6))
        stream = bp(noise(n, r), 800, 4000) * (0.6 + 0.4 * np.abs(lp(noise(n, r), 8.0)) * 20.0) * 0.15
        bed = wind * 0.5 + stream
        for _ in range(140):
            place(bed, cricket(r), int(r.integers(0, n)), r.uniform(0.2, 0.6))
        sides.append(bed)
    return np.stack(sides, axis=1)


def amb_blight(rng: np.random.Generator, grove_bed: np.ndarray) -> np.ndarray:
    n = n_of(30.0)
    out = []
    for c in range(2):
        x = grove_bed[:, c][::-1][: n_of(40.0)]
        x = detune(x, -500.0)[:n]
        x = np.concatenate([x, np.zeros(max(0, n - len(x)))])
        x = wrap(lp(x, 2000), n) + drone(26, n, rng, 200) * 0.6
        out.append(x)
    return np.stack(out, axis=1)
