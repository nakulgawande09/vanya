"""SFX recipes for the placeholder synth. A BOM entry is a list of layers, each {"r": recipe, ...}.

Common layer keys: "g" gain dB, "at" start offset (s), "pf" pitch factor (set per variant).
Recipes return a mono float array; synth.py mixes the layers, applies "post" effects, levels the
result to its loudness class and limits it to −1 dBTP.
"""
from __future__ import annotations

import numpy as np

from dsp import (SR, adsr, bp, db, detune, fade, formant, granular, hp, lp, midi_hz, n_of, noise, osc, perc,
                 resample, reverb, saturate, sweep_bp)

Layer = dict


def _f(layer: Layer, key: str, default: float | list) -> float | list:
    v = layer.get(key, default)
    pf = layer.get("pf", 1.0)
    if isinstance(v, (list, tuple)):
        return [x * pf for x in v]
    return v * pf


def tone(L: Layer, rng: np.random.Generator) -> np.ndarray:
    """Pitched oscillator with an optional sweep, percussive or sustained envelope."""
    n = n_of(L.get("dur", 0.2))
    x = osc(L.get("wave", "sine"), _f(L, "f", 440.0), n)
    if L.get("vib"):
        x = x * (1.0 + 0.15 * np.sin(2 * np.pi * L["vib"] * np.arange(n) / SR))
    if L.get("flat"):
        env = np.ones(n)
    elif "decay" in L:
        env = perc(n, L.get("a", 0.004), L["decay"])
    else:
        env = adsr(n, L.get("a", 0.01), 0.1, 0.8, L.get("rel", 0.05))
    x = x * env
    if "lp" in L:
        x = lp(x, L["lp"])
    if "hp" in L:
        x = hp(x, L["hp"])
    return x


def hiss(L: Layer, rng: np.random.Generator) -> np.ndarray:
    """Shaped noise: band-pass (optionally sweeping), percussive or swelling envelope."""
    n = n_of(L.get("dur", 0.2))
    x = noise(n, rng, L.get("color", "white"))
    if "sweep" in L:
        x = sweep_bp(x, L["sweep"][0], L["sweep"][1])
    elif "bp" in L:
        x = bp(x, *L["bp"])
    if "lp" in L:
        x = lp(x, L["lp"])
    if "hp" in L:
        x = hp(x, L["hp"])
    if L.get("flat"):
        env = np.ones(n)
    elif L.get("swell"):
        env = adsr(n, L.get("a", n / SR * 0.7), 0.1, 1.0, L.get("rel", n / SR * 0.3))
    else:
        env = perc(n, L.get("a", 0.002), L.get("decay", 0.06))
    return x * env


def drum(L: Layer, rng: np.random.Generator) -> np.ndarray:
    """Membrane: sine with a fast pitch drop, plus a noise slap (dhol, thumps, sub hits)."""
    n = n_of(L.get("dur", 0.4))
    f = _f(L, "f", [160.0, 60.0])
    t = np.arange(n) / SR
    drop = L.get("drop", 0.04)
    freq = f[1] + (f[0] - f[1]) * np.exp(-t / drop)
    body = np.sin(2 * np.pi * np.cumsum(freq) / SR) * perc(n, 0.002, L.get("decay", 0.18))
    slap = bp(noise(n, rng), *L.get("slap_bp", [800.0, 5000.0])) * perc(n, 0.001, 0.015)
    ghost = hp(noise(n, rng), 1500.0) * perc(n, 0.001, 0.01) * L.get("ghost", 0.0)
    return body + slap * L.get("slap", 0.6) + ghost


def pluck(L: Layer, rng: np.random.Generator) -> np.ndarray:
    """Karplus–Strong string (bow twang, rope, bass)."""
    f = float(_f(L, "f", 220.0))
    n = n_of(L.get("dur", 0.3))
    period = max(2, int(SR / f))
    decay = L.get("damp", 0.996)
    buf = noise(period, rng) * 2.0
    out = np.zeros(n)
    out[:min(n, period)] = buf[:n]
    s = period
    while s < n:
        e = min(n, s + period)
        a = out[s - period:e - period]
        b = out[s - period - 1:e - period - 1] if s > period else np.concatenate([[0.0], out[0:e - period - 1]])
        out[s:e] = 0.5 * (a + b) * decay
        s = e
    return out * perc(n, 0.001, L.get("decay", 0.25))


def bell(L: Layer, rng: np.random.Generator) -> np.ndarray:
    """Glassy additive bell (spirit). Inharmonic partials decay faster as they rise."""
    n = n_of(L.get("dur", 0.8))
    f = float(_f(L, "f", 880.0))
    ratios = L.get("partials", [1.0, 2.0, 2.76, 4.07, 5.4])
    x = np.zeros(n)
    for i, r in enumerate(ratios):
        x += osc("sine", f * r, n) * perc(n, L.get("a", 0.002), L.get("decay", 0.6) / (1.0 + i * 0.7)) / (1.0 + i * 0.8)
    if L.get("detune_cents"):
        d = detune(x, L["detune_cents"])
        k = min(n, len(d))
        x[:k] = 0.5 * x[:k] + 0.5 * d[:k]
    return x


def chime(L: Layer, rng: np.random.Generator) -> np.ndarray:
    """A run of bells on MIDI notes, `step` seconds apart (motif jingles, rewards)."""
    notes = L.get("notes", [62, 64, 67, 69, 74])
    step = L.get("step", 0.09)
    each = L.get("each", 0.7)
    n = n_of(step * len(notes) + each)
    out = np.zeros(n)
    for i, m in enumerate(notes):
        b = bell({"f": midi_hz(m) * L.get("pf", 1.0), "dur": each, "decay": L.get("decay", 0.5)}, rng)
        s = n_of(step * i)
        out[s:s + len(b)] += b[:n - s]
    return out


def squeal(L: Layer, rng: np.random.Generator) -> np.ndarray:
    """FM squeal through a nasal formant (Rotling pig-voice)."""
    n = n_of(L.get("dur", 0.3))
    f = np.asarray(_f(L, "f", [700.0, 500.0]), dtype=float)
    car = 2 * np.pi * np.cumsum(f[0] * (f[1] / f[0]) ** np.linspace(0, 1, n)) / SR
    mod = L.get("index", 2.5) * np.sin(car * L.get("ratio", 0.5))
    x = np.sin(car + mod) + 0.3 * noise(n, rng)
    x = formant(x, L.get("formants", [900.0, 2300.0]), 4.0)
    jitter = 1.0 + 0.3 * np.sin(2 * np.pi * L.get("trem", 28.0) * np.arange(n) / SR)
    return x * jitter * adsr(n, 0.01, 0.08, 0.7, L.get("dur", 0.3) * 0.4)


def grunt(L: Layer, rng: np.random.Generator) -> np.ndarray:
    """Low growl: jittery saw through vowel formants (boar snort, beast groans)."""
    n = n_of(L.get("dur", 0.4))
    f0 = float(_f(L, "f", 90.0))
    jit = 1.0 + 0.08 * lp(noise(n, rng), 30.0) * 10.0
    x = osc("saw", f0 * jit, n) + 0.5 * noise(n, rng, "pink")
    x = formant(x, L.get("formants", [400.0, 900.0, 2400.0]), 3.0)
    return saturate(x * 1.5, 2.0) * adsr(n, L.get("a", 0.03), 0.1, 0.8, L.get("rel", 0.15))


def creak(L: Layer, rng: np.random.Generator) -> np.ndarray:
    """Stick-slip wood/vine creak: a slow impulse train with jittered rate through wood resonances."""
    n = n_of(L.get("dur", 0.5))
    rate = float(_f(L, "f", 60.0))
    rates = rate * (1.0 + 0.5 * lp(noise(n, rng), 6.0) * 20.0)
    ph = np.cumsum(np.clip(rates, 5.0, None)) / SR
    pulses = np.diff(np.floor(ph), prepend=0.0)
    x = formant(pulses * 3.0 + noise(n, rng) * 0.05, L.get("formants", [350.0, 900.0, 2100.0]), 8.0)
    return x * adsr(n, 0.05, 0.1, 0.9, 0.1)


def crack(L: Layer, rng: np.random.Generator) -> np.ndarray:
    """Sharp broadband transient with a short ringing body (stone, wood break, thunder crack)."""
    n = n_of(L.get("dur", 0.25))
    x = noise(n, rng) * perc(n, 0.0005, L.get("decay", 0.03))
    body = bp(noise(n, rng), *L.get("body", [300.0, 1800.0])) * perc(n, 0.001, L.get("ring", 0.12))
    return hp(x, L.get("hp", 1200.0)) + body * L.get("body_g", 0.8)


def rumble(L: Layer, rng: np.random.Generator) -> np.ndarray:
    n = n_of(L.get("dur", 0.6))
    x = lp(noise(n, rng, "brown"), L.get("lp", 180.0)) * 3.0
    crunch = bp(noise(n, rng), 1200.0, 3500.0) * (np.abs(lp(noise(n, rng), 20.0)) * 30.0)
    env = np.ones(n) if L.get("flat") else adsr(n, L.get("a", 0.05), 0.2, 0.9, L.get("rel", 0.2))
    return (x + crunch * L.get("crunch", 0.25)) * env


def zap(L: Layer, rng: np.random.Generator) -> np.ndarray:
    """Electric FM sweep (lightning, orb spit)."""
    n = n_of(L.get("dur", 0.3))
    f = _f(L, "f", [2400.0, 300.0])
    car = 2 * np.pi * np.cumsum(f[0] * (f[1] / f[0]) ** np.linspace(0, 1, n)) / SR
    x = np.sin(car + L.get("index", 6.0) * np.sin(car * 1.41)) + 0.4 * hp(noise(n, rng), 3000.0)
    return saturate(x, 2.5) * perc(n, 0.001, L.get("decay", 0.08))


def fizz(L: Layer, rng: np.random.Generator) -> np.ndarray:
    """Violet blight fizz: sparse crackles thickening or thinning over time."""
    n = n_of(L.get("dur", 0.4))
    dens = L.get("density", 0.02)
    clicks = (rng.random(n) < dens).astype(float) * rng.standard_normal(n)
    x = bp(clicks, *L.get("bp", [1500.0, 7000.0])) * 3.0 + 0.15 * hp(noise(n, rng), 4000.0)
    if L.get("flat"):
        shape = np.ones(n)
    else:
        shape = np.linspace(1.0, 0.0, n) ** 1.5 if not L.get("rise") else np.linspace(0.0, 1.0, n) ** 1.5
    return x * shape


def breath(L: Layer, rng: np.random.Generator) -> np.ndarray:
    """Breathy flute note(s): sine + octave + band-limited breath, gentle vibrato."""
    notes = L.get("notes", [74])
    each = L.get("each", 0.25)
    n = n_of(each * len(notes) + 0.2)
    out = np.zeros(n)
    for i, m in enumerate(notes):
        k = n_of(each + 0.15)
        f = midi_hz(m) * L.get("pf", 1.0)
        t = np.arange(k) / SR
        vib = 1.0 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.15, 0, 1)
        tone_ = osc("sine", f * vib, k) + 0.25 * osc("sine", 2 * f * vib, k)
        air = bp(noise(k, rng), f * 0.8, f * 2.5) * 0.35
        x = (tone_ + air) * adsr(k, 0.05, 0.1, 0.85, 0.12)
        s = n_of(each * i)
        out[s:s + k] += x[:n - s]
    return out


RECIPES = {
    "tone": tone, "hiss": hiss, "drum": drum, "pluck": pluck, "bell": bell, "chime": chime, "squeal": squeal,
    "grunt": grunt, "creak": creak, "crack": crack, "rumble": rumble, "zap": zap, "fizz": fizz, "breath": breath,
}


def render_layers(layers: list, rng: np.random.Generator, pf: float) -> np.ndarray:
    parts = []
    for L in layers:
        L = dict(L)
        L["pf"] = L.get("pf", 1.0) * (pf if not L.get("fixed_pitch") else 1.0)
        x = RECIPES[L["r"]](L, rng) * db(L.get("g", 0.0))
        ats = L.get("at", 0.0)
        for at in (ats if isinstance(ats, list) else [ats]):
            parts.append((n_of(at) if at else 0, x))
    n = max(s + len(x) for s, x in parts)
    out = np.zeros(n)
    for s, x in parts:
        out[s:s + len(x)] += x
    return out


def apply_post(x: np.ndarray, post: list, rng: np.random.Generator) -> np.ndarray:
    from dsp import blight
    for p in post:
        name, _, arg = p.partition(":")
        if name == "blight":
            x = blight(x, rng, float(arg) if arg else -45.0)
        elif name == "reverse":
            x = x[::-1].copy()
        elif name == "room":
            x = reverb(x, rng, float(arg) if arg else 0.35, 0.22)
        elif name == "hall":
            x = reverb(x, rng, float(arg) if arg else 1.4, 0.35)
        elif name == "sat":
            x = saturate(x / (np.max(np.abs(x)) + 1e-9), float(arg) if arg else 2.0)
        elif name == "lp":
            x = lp(x, float(arg))
        elif name == "hp":
            x = hp(x, float(arg))
        elif name == "detune":
            x = detune(x, float(arg))
        elif name == "grain":
            x = granular(x, rng)
        else:
            raise ValueError(f"unknown post '{p}'")
    return fade(x, 0.0005, 0.02)
