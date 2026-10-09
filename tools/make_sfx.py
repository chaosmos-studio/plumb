"""Nothing is recorded or downloaded, so there is nothing to license.

Run from the project root: python3 tools/make_sfx.py   (needs numpy and ffmpeg with libvorbis)

The noise generator is seeded, so re-running makes the same sounds. The Ogg container gets a new random
stream serial each run, so the bytes differ. Commit only the sounds you changed.
"""

import os
import subprocess
import wave

import numpy as np

RATE = 44100
OUT = "assets/audio/sfx"
RNG = np.random.default_rng(7)
# C major pentatonic from C5: every pair is consonant, so a board cleared in any order sounds like a chord.
SINK_NOTES = [523.25, 659.25, 783.99, 880.00]


def t_axis(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def decay(n, seconds):
    return np.exp(-np.arange(n) / (RATE * seconds))


def bell(freq, seconds=0.9, bright=1.0):
    """The partials at 2.76 and 5.40 times the pitch are inharmonic, as a struck bell's are."""
    t = t_axis(seconds)
    n = t.size
    tone = np.sin(2 * np.pi * freq * t) * decay(n, 0.35)
    tone += 0.35 * bright * np.sin(2 * np.pi * freq * 2.76 * t) * decay(n, 0.12)
    tone += 0.18 * bright * np.sin(2 * np.pi * freq * 5.40 * t) * decay(n, 0.05)
    attack = np.clip(np.arange(n) / (RATE * 0.004), 0, 1)
    return tone * attack


def lowpass(x, cutoff):
    a = 1.0 - np.exp(-2.0 * np.pi * cutoff / RATE)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def sweep(f0, f1, seconds, curve=1.0):
    t = t_axis(seconds)
    k = (t / seconds) ** curve
    freq = f0 + (f1 - f0) * k
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    return np.sin(phase)


def normalise(x, peak=0.85):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    wav = os.path.join(OUT, name + ".wav")
    data = (np.clip(samples, -1.0, 1.0) * 32767).astype(np.int16)
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    ogg = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", ogg], check=True)
    os.remove(wav)
    print("wrote", ogg)


def tap():
    t = t_axis(0.06)
    return normalise(np.sin(2 * np.pi * 1320 * t) * decay(t.size, 0.012), 0.5)


def roll():
    n = int(RATE * 0.22)
    noise = lowpass(RNG.standard_normal(n), 420)
    env = np.sin(np.linspace(0, np.pi, n)) ** 1.5
    return normalise(noise * env, 0.45)


def clack():
    t = t_axis(0.09)
    body = np.sin(2 * np.pi * 740 * t) * decay(t.size, 0.018)
    body += 0.5 * np.sin(2 * np.pi * 1180 * t) * decay(t.size, 0.009)
    click = lowpass(RNG.standard_normal(t.size), 3000) * decay(t.size, 0.004)
    return normalise(body + 0.6 * click, 0.6)


def sink(freq):
    plop = sweep(620, 170, 0.09, 0.6) * decay(int(RATE * 0.09), 0.05)
    tone = bell(freq, 0.9)
    out = np.zeros(int(RATE * 0.05) + tone.size)
    out[:plop.size] += 0.8 * plop
    out[int(RATE * 0.05):] += tone
    return normalise(out, 0.8)


def pit():
    fall = sweep(900, 120, 0.5, 0.7) * np.linspace(1.0, 0.2, int(RATE * 0.5))
    thud = sweep(110, 50, 0.18) * decay(int(RATE * 0.18), 0.06)
    out = np.concatenate([0.5 * fall, thud])
    return normalise(out, 0.7)


def win():
    """The notes are C E G C."""
    notes = [523.25, 659.25, 783.99, 1046.5]
    gap = int(RATE * 0.11)
    out = np.zeros(gap * len(notes) + int(RATE * 1.2))
    for k, f in enumerate(notes):
        b = bell(f, 1.2, 0.8)
        out[k * gap:k * gap + b.size] += b
    return normalise(out, 0.8)


def star():
    b = bell(1567.98, 0.6, 1.2)
    sparkle = lowpass(RNG.standard_normal(b.size), 8000) * decay(b.size, 0.03) * 0.15
    return normalise(b + sparkle, 0.6)


def pad_voice(freq, seconds):
    """Detuned by a few cents so the three sines beat slowly."""
    t = t_axis(seconds)
    out = np.zeros(t.size)
    for cents in (-6, 0, 5):
        f = freq * 2 ** (cents / 1200.0)
        out += np.sin(2 * np.pi * f * t + RNG.uniform(0, 2 * np.pi))
    return out / 3.0


def music():
    """The tail is folded back onto the start, so the loop has no seam."""
    chord_seconds = 8.0
    loop = 4 * chord_seconds
    tail = 3.0
    total = int(RATE * (loop + tail))
    out = np.zeros(total)
    chords = [
        [130.81, 196.00, 246.94, 329.63, 293.66],   # C  G  B  E  D  (Cmaj9)
        [110.00, 164.81, 196.00, 261.63, 246.94],   # A  E  G  C  B  (Am9)
        [87.31, 130.81, 164.81, 220.00, 196.00],    # F  C  E  A  G  (Fmaj9)
        [98.00, 146.83, 164.81, 246.94, 220.00],    # G  D  E  B  A  (G6/9)
    ]
    length = chord_seconds + tail
    n = int(RATE * length)
    env = np.minimum(1.0, np.arange(n) / (RATE * 2.2))
    env *= np.minimum(1.0, (n - np.arange(n)) / (RATE * 3.0))
    for k, chord in enumerate(chords):
        start = int(RATE * k * chord_seconds)
        voice = np.zeros(n)
        for f in chord:
            voice += pad_voice(f, length)
        out[start:start + n] += lowpass(voice, 1400) * env * 0.22
    bells = [523.25, 587.33, 659.25, 783.99, 880.00, 1046.5]
    for _ in range(14):
        at = int(RATE * RNG.uniform(0.5, loop - 1.5))
        b = bell(float(RNG.choice(bells)), 2.2, 0.4) * 0.05
        out[at:at + b.size] += b[:max(0, total - at)]
    wrapped = out[:int(RATE * loop)].copy()
    wrapped[:total - wrapped.size] += out[wrapped.size:]
    return normalise(wrapped, 0.35)


def undo():
    return normalise(sweep(900, 400, 0.12) * decay(int(RATE * 0.12), 0.05), 0.4)


def hint():
    a = bell(783.99, 0.5, 0.5)
    b = bell(1046.5, 0.6, 0.5)
    out = np.zeros(int(RATE * 0.12) + b.size)
    out[:a.size] += a
    out[int(RATE * 0.12):] += b
    return normalise(out, 0.5)


if __name__ == "__main__":
    write("tap", tap())
    write("roll", roll())
    write("clack", clack())
    for k, f in enumerate(SINK_NOTES):
        write("sink_%d" % k, sink(f))
    write("pit", pit())
    write("win", win())
    write("star", star())
    write("undo", undo())
    write("hint", hint())
    write("music", music())
