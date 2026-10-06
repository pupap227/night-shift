#!/usr/bin/env python3
"""Generates placeholder SFX and music stems (16-bit mono WAV, 22050 Hz).
Replace any file in audio/ with real recordings — ids are mapped in data/audio.json."""
import math, os, random, struct, wave

SR = 22050
ROOT = os.path.join(os.path.dirname(__file__), "..", "audio")
random.seed(3)


def write(path, samples):
    path = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    k = 0.85 / peak if peak > 0.85 else 1.0
    with wave.open(path, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * k)) * 32767)) for s in samples))


def env(i, n, a=0.01, r=0.1):
    t = i / SR; d = n / SR
    return min(1.0, t / a if a > 0 else 1.0) * min(1.0, (d - t) / r if r > 0 else 1.0)


def tone(freq, dur, vol=0.5, a=0.005, r=0.05, shape="sine"):
    n = int(SR * dur); out = []
    for i in range(n):
        ph = 2 * math.pi * freq * i / SR
        v = math.sin(ph) if shape == "sine" else (1 if math.sin(ph) > 0 else -1) * 0.5
        out.append(v * vol * env(i, n, a, r))
    return out


def silence(d): return [0.0] * int(SR * d)


def mix(a, b):
    n = max(len(a), len(b)); return [(a[i] if i < len(a) else 0) + (b[i] if i < len(b) else 0) for i in range(n)]


def lowpass(x, k=0.05):
    y = []; p = 0.0
    for v in x:
        p += k * (v - p); y.append(p)
    return y


# --- SFX
ring = []
for _ in range(2):
    burst = []
    for i in range(int(SR * 0.4)):
        t = i / SR
        burst.append((math.sin(2 * math.pi * 440 * t) + math.sin(2 * math.pi * 480 * t)) * 0.25 * (1 if int(t * 40) % 2 == 0 else 0.4))
    ring += burst + silence(0.2)
write("sfx/phone.wav", ring)

siren = []
n = int(SR * 2.2); ph = 0
for i in range(n):
    t = i / SR
    f = 650 + 250 * math.sin(2 * math.pi * 0.9 * t)
    ph += 2 * math.pi * f / SR
    siren.append(math.sin(ph) * 0.35 * env(i, n, 0.3, 0.8))
write("sfx/siren.wav", lowpass(siren, 0.3))

door = lowpass([random.uniform(-1, 1) * math.exp(-i / (SR * 0.05)) for i in range(int(SR * 0.4))], 0.08)
door = mix(door, [math.sin(2 * math.pi * 70 * i / SR) * 0.6 * math.exp(-i / (SR * 0.08)) for i in range(int(SR * 0.4))])
write("sfx/door.wav", door)

steps = []
for k in range(4):
    steps += lowpass([random.uniform(-1, 1) * math.exp(-i / (SR * 0.015)) for i in range(int(SR * 0.05))], 0.2) + silence(0.22)
write("sfx/steps.wav", steps)

write("sfx/beep.wav", tone(1000, 0.12, 0.4, 0.002, 0.03) + silence(0.05))
write("sfx/flatline.wav", tone(1000, 2.0, 0.35, 0.002, 0.4))
alarm = []
for _ in range(3):
    alarm += tone(330, 0.25, 0.4, 0.01, 0.05, "square") + tone(262, 0.25, 0.4, 0.01, 0.05, "square")
write("sfx/alarm.wav", lowpass(alarm, 0.15))
write("sfx/assign.wav", lowpass(tone(520, 0.06, 0.4) + tone(780, 0.11, 0.4, 0.002, 0.08), 0.5))
write("sfx/confirm.wav", tone(600, 0.08, 0.35) + tone(900, 0.16, 0.35, 0.002, 0.12))
write("sfx/error.wav", lowpass(tone(140, 0.22, 0.5, 0.005, 0.05, "square"), 0.2))
write("sfx/click.wav", lowpass([random.uniform(-1, 1) * math.exp(-i / (SR * 0.004)) for i in range(int(SR * 0.03))], 0.4))
write("sfx/pickup.wav", lowpass([random.uniform(-1, 1) * math.exp(-i / (SR * 0.02)) * 0.6 for i in range(int(SR * 0.08))], 0.12))
write("sfx/drop.wav", door[: int(SR * 0.2)])

# --- Music stems (loopable, same length so they stay in sync)
L = 16.0; n = int(SR * L)
amb = []
rain_noise = lowpass([random.uniform(-1, 1) for _ in range(n)], 0.25)
for i in range(n):
    t = i / SR
    drone = sum(math.sin(2 * math.pi * f * t + p) * a for f, p, a in [(55, 0, .25), (82.5, 1, .12), (110.25, 2, .06)])
    drone *= 0.6 + 0.4 * math.sin(2 * math.pi * t / L)
    amb.append(drone * 0.5 + rain_noise[i] * 0.12)
write("music/ambient.wav", amb)
ten = []
for i in range(n):
    t = i / SR
    beat = t % 0.75
    pulse = math.sin(2 * math.pi * 49 * t) * math.exp(-beat * 9) * 0.6
    pad = math.sin(2 * math.pi * 116.5 * t) * 0.08 * (0.5 + 0.5 * math.sin(2 * math.pi * t / 4))
    ten.append(pulse + pad)
write("music/tension.wav", ten)
cri = []
for i in range(n):
    t = i / SR
    b = t % 0.5
    hb = math.sin(2 * math.pi * 60 * t) * (math.exp(-b * 18) + 0.7 * math.exp(-max(0, b - 0.16) * 18) * (b > 0.16))
    dis = (math.sin(2 * math.pi * 233 * t) + math.sin(2 * math.pi * 247 * t)) * 0.05
    cri.append(hb * 0.55 + dis)
write("music/crisis.wav", cri)
print("audio generated")
