"""Nothing is recorded or downloaded, so there is nothing to license.

Run from the project root: python3 tools/make_sfx.py [name ...]   (needs numpy and ffmpeg with libvorbis)
With names, only those sounds are written: python3 tools/make_sfx.py plop knock

The noise generators are seeded, so re-running makes the same sounds. The Ogg container gets a new random
stream serial each run, so the bytes differ. Commit only the sounds you changed.
"""

import os
import subprocess
import sys
import wave

import numpy as np

RATE = 44100
OUT = "assets/audio/sfx"
RNG = np.random.default_rng(7)
# The feel sounds draw from their own generator, so adding them changed none of the sounds before them.
FEEL_RNG = np.random.default_rng(46)
# And the bouncy block's from its own, for the same reason.
BOING_RNG = np.random.default_rng(22)
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


def resonate(x, freq, q):
    """A two-pole resonator: the signal rings at `freq`, for about q cycles."""
    r = np.exp(-np.pi * freq / (q * RATE))
    a1 = 2 * r * np.cos(2 * np.pi * freq / RATE)
    a2 = -r * r
    y = np.zeros_like(x)
    y1 = y2 = 0.0
    gain = 1 - r
    for i, v in enumerate(x):
        y0 = gain * v + a1 * y1 + a2 * y2
        y[i] = y0
        y2, y1 = y1, y0
    return y


def partials(seconds, parts):
    """A struck thing as (frequency, amplitude, decay seconds) partials, with a 1 ms attack so it never clicks."""
    t = t_axis(seconds)
    out = np.zeros(t.size)
    for f, a, d in parts:
        out += a * np.sin(2 * np.pi * f * t) * decay(t.size, d)
    return out * np.clip(np.arange(t.size) / (RATE * 0.001), 0, 1)


def plop():
    """A marble landing in its hole: a glassy tick on the rim, then a short round drop whose pitch rises as a
    bubble's does."""
    seconds = 0.16
    n = int(RATE * seconds)
    out = 0.3 * partials(seconds, [(2350, 1.0, 0.006), (3710, 0.6, 0.004)])
    drop_n = int(RATE * 0.09)
    k = np.arange(drop_n) / drop_n
    freq = 480 + 420 * k ** 0.6
    drop = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * decay(drop_n, 0.028)
    drop *= np.clip(np.arange(drop_n) / (RATE * 0.003), 0, 1)
    at = int(RATE * 0.012)
    out[at:at + drop_n] += drop
    out += 0.25 * partials(seconds, [(150, 1.0, 0.02)])
    return normalise(out[:n], 0.5)


def knock():
    """A marble against a wooden wall: a low knock with two quicker overtones and a soft click."""
    seconds = 0.12
    body = partials(seconds, [(310, 1.0, 0.03), (760, 0.55, 0.014), (1620, 0.25, 0.006)])
    click = lowpass(FEEL_RNG.standard_normal(body.size), 2400) * decay(body.size, 0.0025)
    return normalise(body + 0.5 * click, 0.5)


def clink():
    """Glass against glass: high, short partials that are not in tune with each other."""
    seconds = 0.1
    ring = partials(seconds, [(2780, 1.0, 0.02), (4530, 0.6, 0.011), (6900, 0.3, 0.005)])
    click = FEEL_RNG.standard_normal(ring.size) * decay(ring.size, 0.0012)
    return normalise(ring + 0.25 * click, 0.4)


def rolling():
    """A marble rolling on wood, as a seamless loop: band-limited noise rings in two of the tray's wooden
    resonances, small knocks of grain come at random, and the whole flutters a little. The tail is folded back
    onto the start, as the music's is."""
    seconds = 2.0
    tail = 0.25
    n = int(RATE * (seconds + tail))
    noise = FEEL_RNG.standard_normal(n)
    body = lowpass(noise, 700) - lowpass(noise, 90)
    wood = resonate(body, 230, 16) + 0.6 * resonate(body, 470, 12)
    body /= np.max(np.abs(body))
    wood /= np.max(np.abs(wood))
    grain = np.zeros(n)
    tick = partials(0.02, [(1100, 1.0, 0.003), (1900, 0.4, 0.002)])
    for at in np.cumsum(FEEL_RNG.exponential(1 / 40.0, int(seconds * 60))):
        i = int(at * RATE)
        if i + tick.size < n:
            grain[i:i + tick.size] += tick * FEEL_RNG.uniform(0.05, 0.18)
    t = np.arange(n) / RATE
    flutter = 1 + 0.15 * np.sin(2 * np.pi * 9 * t + 0.8 * np.sin(2 * np.pi * 1.3 * t))
    out = (0.55 * body + 0.45 * wood + grain) * flutter
    loop = int(RATE * seconds)
    wrapped = out[:loop].copy()
    fade = np.linspace(0, 1, n - loop)
    wrapped[:n - loop] = wrapped[:n - loop] * fade + out[loop:] * (1 - fade)
    return normalise(wrapped, 0.45)


def chord_bell(freq, seconds, bright):
    """A bell that rings on, for a chord to sit in: a slower fundamental than bell()'s."""
    t = t_axis(seconds)
    n = t.size
    tone = np.sin(2 * np.pi * freq * t) * decay(n, 0.9)
    tone += 0.3 * bright * np.sin(2 * np.pi * freq * 2.76 * t) * decay(n, 0.18)
    tone += 0.12 * bright * np.sin(2 * np.pi * freq * 5.40 * t) * decay(n, 0.06)
    return tone * np.clip(np.arange(n) / (RATE * 0.004), 0, 1)


def chord():
    """The last marble home resolves the bells into C major (MATH.md section 19): C4 and G4 open at the bottom,
    then E5, A5 and D6, the sixth and the ninth on top, rolled upward like a strum. Every sink bell (C5, E5, G5,
    A5) is a note of this chord, so it follows any of them."""
    notes = [(261.63, 0.55, 0.3), (392.00, 0.45, 0.4), (659.25, 0.42, 0.5), (880.00, 0.34, 0.5), (1174.66, 0.26, 0.6)]
    strum = 0.045
    seconds = 2.8
    out = np.zeros(int(RATE * (strum * len(notes) + seconds)))
    for k, (f, gain, bright) in enumerate(notes):
        b = chord_bell(f, seconds, bright) * gain
        at = int(RATE * k * strum)
        out[at:at + b.size] += b
    shimmer = bell(2093.0, 1.4, 0.3) * 0.07
    at = int(RATE * 0.3)
    out[at:at + shimmer.size] += shimmer
    return normalise(out, 0.6)


def glide_resonate(x, freqs, q):
    """resonate() with a frequency that moves sample by sample, for a formant that glides between sounds."""
    y = np.zeros_like(x)
    y1 = y2 = 0.0
    for i, v in enumerate(x):
        f = freqs[i]
        r = np.exp(-np.pi * f / (q * RATE))
        y0 = (1 - r) * v + 2 * r * np.cos(2 * np.pi * f / RATE) * y1 - r * r * y2
        y[i] = y0
        y2, y1 = y1, y0
    return y


def voice_source(f0):
    """A buzz at the pitch `f0` (an array, one value a sample): the first harmonics, each softer than the last."""
    phase = 2 * np.pi * np.cumsum(f0) / RATE
    source = np.zeros(f0.size)
    for h in range(1, 13):
        source += np.sin(h * phase) / h
    return source


def ramp(n, points):
    """A value through the (seconds, value) points, straight between them."""
    t = np.arange(n) / RATE
    return np.interp(t, [p[0] for p in points], [p[1] for p in points])


def nooo():
    """A tiny cartoon "nooo": the hum of an n with the mouth shut, then the formants glide from where an n leaves
    the tongue (the second formant near 1.7 kHz) into the vowel of "no", while the pitch slides down."""
    seconds = 0.62
    n = int(RATE * seconds)
    t = np.arange(n) / RATE
    f0 = 560 * (330 / 560) ** (t / seconds) * (1 + 0.03 * np.sin(2 * np.pi * 6.5 * t))
    source = voice_source(f0)
    f1 = ramp(n, [(0, 260), (0.09, 260), (0.15, 470), (seconds, 430)])
    f2 = ramp(n, [(0, 1700), (0.09, 1700), (0.17, 880), (seconds, 780)])
    vowel = glide_resonate(source, f1, 6) + 0.6 * glide_resonate(source, f2, 9) + 0.12 * resonate(source, 2600, 10)
    nasal = resonate(source, 260, 4)
    open_ = np.clip((t - 0.08) / 0.05, 0, 1)
    out = nasal / np.max(np.abs(nasal)) * (1 - open_) * 0.45 + vowel / np.max(np.abs(vowel)) * open_
    env = np.clip(t / 0.02, 0, 1) * np.clip((seconds - t) / 0.18, 0, 1)
    return normalise(out * env, 0.35)


def mrrp():
    """A sleepy cat's trill: an m with the mouth shut, then a chirp that rises and falls through a low r (its third
    formant pulled down), rolled about 26 times a second."""
    seconds = 0.3
    n = int(RATE * seconds)
    t = np.arange(n) / RATE
    f0 = 430 + 250 * np.sin(np.pi * t / seconds) ** 0.8 - 70 * t / seconds
    source = voice_source(f0)
    f1 = ramp(n, [(0, 280), (0.05, 280), (0.1, 620), (seconds, 560)])
    voice = glide_resonate(source, f1, 5) + 0.6 * resonate(source, 1250, 7) + 0.2 * resonate(source, 1700, 9)
    hum = resonate(source, 280, 4)
    open_ = np.clip((t - 0.045) / 0.04, 0, 1)
    roll = 1 - open_ * (0.4 - 0.4 * np.sin(2 * np.pi * 26 * t))
    out = hum / np.max(np.abs(hum)) * (1 - open_) * 0.5 + voice / np.max(np.abs(voice)) * open_ * roll
    env = np.clip(t / 0.015, 0, 1) * np.clip((seconds - t) / 0.08, 0, 1)
    return normalise(out * env, 0.35)


def huff():
    """A sleepy dog's huff: a breath out through the nose that swells and fades, with a little of the throat under
    it and no hard start."""
    seconds = 0.3
    n = int(RATE * seconds)
    t = np.arange(n) / RATE
    noise = FEEL_RNG.standard_normal(n)
    breath = lowpass(noise, 3200) - lowpass(noise, 350)
    swell = np.sin(np.pi * np.clip(t / 0.26, 0, 1)) ** 1.6
    throat = 0.18 * np.sin(2 * np.pi * 150 * t) * swell
    return normalise(breath / np.max(np.abs(breath)) * swell + throat, 0.35)


def boing():
    """A marble off a bouncy block: a soft rubbery note that springs down in pitch and wobbles as it settles, over a
    muffled thump, like a jelly struck with a finger."""
    seconds = 0.42
    t = t_axis(seconds)
    n = t.size
    wobble = 1 + 0.07 * np.sin(2 * np.pi * 13 * t) * np.exp(-t / 0.15)
    freq = (190 + 330 * np.exp(-t / 0.035)) * wobble
    tone = np.sin(2 * np.pi * np.cumsum(freq) / RATE)
    tone += 0.3 * np.sin(2 * np.pi * np.cumsum(freq * 2.0) / RATE) * np.exp(-t / 0.05)
    env = np.clip(t / 0.006, 0, 1) * np.exp(-t / 0.12)
    thump = lowpass(BOING_RNG.standard_normal(n), 500) * decay(n, 0.01)
    body = lowpass(tone * env, 2600)
    return normalise(body / np.max(np.abs(body)) + 0.5 * thump / np.max(np.abs(thump)), 0.45)


SOUNDS = {
    "tap": tap,
    "roll": roll,
    "clack": clack,
    **{"sink_%d" % k: (lambda f=f: sink(f)) for k, f in enumerate(SINK_NOTES)},
    "pit": pit,
    "win": win,
    "star": star,
    "undo": undo,
    "hint": hint,
    "music": music,
    "plop": plop,
    "knock": knock,
    "clink": clink,
    "rolling": rolling,
    "chord": chord,
    "nooo": nooo,
    "mrrp": mrrp,
    "huff": huff,
    "boing": boing,
}


# The party's sounds (scenes/celebrate), from a generator of their own.
PARTY_RNG = np.random.default_rng(91)


def pop():
    """A soft cork pop: a quick falling note over a puff of bright noise."""
    seconds = 0.12
    n = int(RATE * seconds)
    t = np.arange(n) / RATE
    note = np.sin(2 * np.pi * np.cumsum(900 * (300 / 900) ** (t / 0.05)) / RATE) * decay(n, 0.02)
    noise = PARTY_RNG.standard_normal(n)
    puff = (lowpass(noise, 3000) - lowpass(noise, 700)) * decay(n, 0.012)
    return normalise(note + 0.5 * puff / np.max(np.abs(puff)), 0.5)


def cannon():
    """A confetti cannon, kept soft: a low thump that drops in pitch, and the rustle of paper after it."""
    seconds = 0.6
    n = int(RATE * seconds)
    t = np.arange(n) / RATE
    thump = np.sin(2 * np.pi * np.cumsum(110 * (45 / 110) ** (t / 0.2)) / RATE) * decay(n, 0.07)
    noise = PARTY_RNG.standard_normal(n)
    rustle = (noise - lowpass(noise, 2500)) * (PARTY_RNG.random(n) < 0.08) * decay(n, 0.25) * 0.5
    air = lowpass(noise, 600) * decay(n, 0.05)
    return normalise(thump + 0.3 * air / np.max(np.abs(air)) + rustle, 0.55)


def fanfare():
    """A little ta-da in bells: G5, C6, E6, then G6 held."""
    notes = [783.99, 1046.5, 1318.51, 1567.98]
    gap = int(RATE * 0.07)
    out = np.zeros(gap * len(notes) + int(RATE * 1.1))
    for k, f in enumerate(notes):
        b = bell(f, 1.1, 0.7) * (0.7 if k < 3 else 1.0)
        out[k * gap:k * gap + b.size] += b
    return normalise(out, 0.6)


SOUNDS.update({
    "pop": pop,
    "cannon": cannon,
    "fanfare": fanfare,
})


if __name__ == "__main__":
    wanted = sys.argv[1:]
    unknown = [name for name in wanted if name not in SOUNDS]
    if unknown:
        sys.exit("no such sound: " + ", ".join(unknown))
    # Every sound is made in order, so each draws the same noise whichever are written.
    for name, make in SOUNDS.items():
        samples = make()
        if not wanted or name in wanted:
            write(name, samples)
