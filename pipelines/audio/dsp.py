"""Small DSP toolkit for the placeholder synth (numpy + scipy, mono float64 at 44.1 kHz).

Everything is deterministic for a given numpy Generator. Loops and music stems are rendered into a
fixed-length buffer with wrap-around (`place`), so reverb and note tails land in the loop head and
the file loops seamlessly at its exact bar length (Audio Bible A3).
"""
from __future__ import annotations

import numpy as np
from scipy import signal

SR = 44100


def n_of(seconds: float) -> int:
    return max(1, int(round(seconds * SR)))


def midi_hz(m: float) -> float:
    return 440.0 * 2.0 ** ((m - 69.0) / 12.0)


def db(x: float) -> float:
    return 10.0 ** (x / 20.0)


# ----------------------------------------------------------------------------- oscillators

def _freq(f: float | np.ndarray | list, n: int) -> np.ndarray:
    if isinstance(f, (list, tuple)):  # [f0, f1] exponential sweep
        f0, f1 = float(f[0]), float(f[1])
        return f0 * (f1 / f0) ** np.linspace(0.0, 1.0, n)
    return np.broadcast_to(np.asarray(f, dtype=float), (n,)).astype(float)


def phase(f: float | np.ndarray | list, n: int) -> np.ndarray:
    return np.cumsum(_freq(f, n)) / SR


def osc(wave: str, f: float | np.ndarray | list, n: int) -> np.ndarray:
    p = phase(f, n)
    if wave == "sine":
        return np.sin(2 * np.pi * p)
    frac = p % 1.0
    if wave == "saw":
        return 2.0 * frac - 1.0
    if wave == "square":
        return np.where(frac < 0.5, 1.0, -1.0)
    if wave == "tri":
        return 4.0 * np.abs(frac - 0.5) - 1.0
    raise ValueError(wave)


def noise(n: int, rng: np.random.Generator, color: str = "white") -> np.ndarray:
    w = rng.standard_normal(n)
    if color == "white":
        return w / 3.0
    if color == "pink":
        b, a = [0.049922035, -0.095993537, 0.050612699, -0.004408786], [1, -2.494956002, 2.017265875, -0.522189400]
        return signal.lfilter(b, a, w) * 2.5 / 3.0
    if color == "brown":
        x = np.cumsum(w)
        x = signal.lfilter([1, -1], [1, -0.995], x)
        return x / (np.max(np.abs(x)) + 1e-9)
    raise ValueError(color)


# ----------------------------------------------------------------------------- envelopes

def perc(n: int, attack: float = 0.004, decay: float = 0.15) -> np.ndarray:
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0.0, 1.0)
    return a * np.exp(-np.maximum(t - attack, 0.0) / max(decay, 1e-4))


def adsr(n: int, a: float, d: float, s: float, r: float) -> np.ndarray:
    t = np.arange(n) / SR
    dur = n / SR
    e = np.where(t < a, t / max(a, 1e-4), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-4)))
    rel = np.clip((dur - t) / max(r, 1e-4), 0.0, 1.0)
    return e * rel


def fade(x: np.ndarray, fin: float = 0.002, fout: float = 0.01) -> np.ndarray:
    y = x.copy()
    a, b = min(len(y), n_of(fin)), min(len(y), n_of(fout))
    y[:a] *= np.linspace(0.0, 1.0, a)
    y[len(y) - b:] *= np.linspace(1.0, 0.0, b)
    return y


# ----------------------------------------------------------------------------- filters

def _sos(kind: str, fc: float | list, order: int = 2) -> np.ndarray:
    nyq = SR / 2.0
    if isinstance(fc, (list, tuple)):
        wn = [max(10.0, fc[0]) / nyq, min(fc[1], nyq * 0.95) / nyq]
    else:
        wn = min(max(10.0, fc), nyq * 0.95) / nyq
    return signal.butter(order, wn, btype=kind, output="sos")


def lp(x: np.ndarray, fc: float, order: int = 2) -> np.ndarray:
    return signal.sosfilt(_sos("lowpass", fc, order), x)


def hp(x: np.ndarray, fc: float, order: int = 2) -> np.ndarray:
    return signal.sosfilt(_sos("highpass", fc, order), x)


def bp(x: np.ndarray, lo: float, hi: float, order: int = 2) -> np.ndarray:
    return signal.sosfilt(_sos("bandpass", [lo, hi], order), x)


def sweep_bp(x: np.ndarray, start: list, end: list, blocks: int = 32) -> np.ndarray:
    """Band-pass whose band moves from `start` to `end` (block-wise, crossfaded)."""
    out = np.zeros_like(x)
    edges = np.linspace(0, len(x), blocks + 1).astype(int)
    for i in range(blocks):
        k = i / max(1, blocks - 1)
        lo = start[0] * (end[0] / start[0]) ** k
        hi = start[1] * (end[1] / start[1]) ** k
        seg = slice(max(0, edges[i] - 256), edges[i + 1])
        y = bp(x[seg], lo, hi)
        out[edges[i]:edges[i + 1]] = y[edges[i] - seg.start:]
    return out


def formant(x: np.ndarray, centers: list, q: float = 6.0) -> np.ndarray:
    out = np.zeros_like(x)
    for c in centers:
        out += bp(x, c * (1 - 0.5 / q), c * (1 + 0.5 / q))
    return out


# ----------------------------------------------------------------------------- effects

def saturate(x: np.ndarray, drive: float = 2.0) -> np.ndarray:
    return np.tanh(x * drive) / np.tanh(drive)


def reverb(x: np.ndarray, rng: np.random.Generator, rt: float = 0.5, wet: float = 0.2, lp_fc: float = 6000.0,
           keep_length: bool = False) -> np.ndarray:
    ir_n = n_of(rt * 1.2)
    ir = noise(ir_n, rng) * np.exp(-np.arange(ir_n) / SR * 6.9 / rt)
    ir = lp(ir, lp_fc)
    ir[0] = 0.0
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    w = signal.fftconvolve(x, ir)
    dry = np.concatenate([x, np.zeros(len(w) - len(x))])
    y = dry * (1.0 - wet) + w * wet
    return y[:len(x)] if keep_length else y


def resample(x: np.ndarray, ratio: float) -> np.ndarray:
    """Plays `x` at `ratio` speed (ratio > 1 → higher and shorter)."""
    n = max(1, int(len(x) / ratio))
    return np.interp(np.arange(n) * ratio, np.arange(len(x)), x)


def detune(x: np.ndarray, cents: float) -> np.ndarray:
    return resample(x, 2.0 ** (cents / 1200.0))


def granular(x: np.ndarray, rng: np.random.Generator, grain: float = 0.035, jitter: float = 0.02) -> np.ndarray:
    """Smears `x` into overlapping grains read from slightly random positions (blight wrongness)."""
    g = n_of(grain)
    hop = g // 2
    win = np.hanning(g)
    out = np.zeros(len(x) + g)
    j = n_of(jitter)
    for start in range(0, len(x), hop):
        src = int(np.clip(start + rng.integers(-j, j + 1), 0, max(0, len(x) - g)))
        seg = x[src:src + g]
        out[start:start + len(seg)] += seg * win[:len(seg)]
    return out[:len(x)]


def blight(x: np.ndarray, rng: np.random.Generator, cents: float = -45.0) -> np.ndarray:
    a = detune(x, cents)
    b = detune(x, cents + 60.0)
    n = min(len(a), len(b))
    y = 0.6 * a[:n] + 0.4 * b[:n]
    return granular(y, rng) * 0.7 + y * 0.3


def wrap(x: np.ndarray, length: int) -> np.ndarray:
    """Folds anything past `length` back into the head (seamless loop)."""
    out = np.zeros(length) if x.ndim == 1 else np.zeros((length, x.shape[1]))
    for s in range(0, len(x), length):
        seg = x[s:s + length]
        out[:len(seg)] += seg
    return out


def place(buf: np.ndarray, x: np.ndarray, at: int, gain: float = 1.0) -> None:
    """Adds `x` into the loop buffer at sample `at`, wrapping around the end."""
    length = len(buf)
    at %= length
    first = min(len(x), length - at)
    buf[at:at + first] += x[:first] * gain
    rest = x[first:]
    while len(rest) > 0:
        k = min(len(rest), length)
        buf[:k] += rest[:k] * gain
        rest = rest[k:]


def mix_to(n: int, *parts: np.ndarray) -> np.ndarray:
    out = np.zeros(n)
    for p in parts:
        k = min(n, len(p))
        out[:k] += p[:k]
    return out


# ----------------------------------------------------------------------------- loudness (ITU-R BS.1770)

def _k_weight(x: np.ndarray) -> np.ndarray:
    # Pre-filter (high shelf) + RLB high-pass, coefficients for 44.1 kHz from the BS.1770 design equations.
    f0, g, q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    k = np.tan(np.pi * f0 / SR)
    vh = 10 ** (g / 20.0)
    vb = vh ** 0.4996667741545416
    a0 = 1.0 + k / q + k * k
    b1 = [(vh + vb * k / q + k * k) / a0, 2.0 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0]
    a1 = [1.0, 2.0 * (k * k - 1.0) / a0, (1.0 - k / q + k * k) / a0]
    f0, q = 38.13547087602444, 0.5003270373238773
    k = np.tan(np.pi * f0 / SR)
    a0 = 1.0 + k / q + k * k
    b2 = [1.0, -2.0, 1.0]
    a2 = [1.0, 2.0 * (k * k - 1.0) / a0, (1.0 - k / q + k * k) / a0]
    return signal.lfilter(b2, a2, signal.lfilter(b1, a1, x, axis=0), axis=0)


def _block_power(x: np.ndarray, block: float, step: float) -> np.ndarray:
    y = _k_weight(x)
    if y.ndim == 1:
        y = y[:, None]
    p = np.sum(y ** 2, axis=1)
    b, s = n_of(block), n_of(step)
    if len(p) < b:
        p = np.concatenate([p, np.zeros(b - len(p))])
    c = np.concatenate([[0.0], np.cumsum(p)])
    starts = np.arange(0, len(p) - b + 1, s)
    return (c[starts + b] - c[starts]) / b


def lufs_momentary_max(x: np.ndarray) -> float:
    pw = _block_power(x, 0.4, 0.05)
    return -0.691 + 10.0 * np.log10(np.max(pw) + 1e-12)


def lufs_integrated(x: np.ndarray) -> float:
    pw = _block_power(x, 0.4, 0.1)
    lk = -0.691 + 10.0 * np.log10(pw + 1e-12)
    pw = pw[lk > -70.0]
    if len(pw) == 0:
        return -70.0
    rel = -0.691 + 10.0 * np.log10(np.mean(pw)) - 10.0
    gated = pw[(-0.691 + 10.0 * np.log10(pw + 1e-12)) > rel]
    return -0.691 + 10.0 * np.log10(np.mean(gated) + 1e-12)


def true_peak_db(x: np.ndarray) -> float:
    up = signal.resample_poly(x, 4, 1, axis=0)
    return 20.0 * np.log10(np.max(np.abs(up)) + 1e-12)


def limit_true_peak(x: np.ndarray, ceiling_db: float = -1.0) -> np.ndarray:
    tp = true_peak_db(x)
    return x * db(ceiling_db - tp) if tp > ceiling_db else x
