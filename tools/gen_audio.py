#!/usr/bin/env python3
"""Procedural, original UI sound effects (stdlib only, deterministic). Output: assets/audio/sfx/*.wav
Usage: python3 tools/gen_audio.py        (re-run after changing recipes; outputs are committed)"""
import math, random, struct, wave, pathlib

SR = 22050
OUT = pathlib.Path(__file__).resolve().parent.parent / "assets/audio/sfx"

def tone(freq, dur, decay, sweep=0.0, vol=1.0):
    n = int(dur * SR)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = freq + sweep * t
        phase += 2 * math.pi * f / SR
        env = math.exp(-decay * t) * min(1.0, i / (0.003 * SR))
        out.append(math.sin(phase) * env * vol)
    return out

def noise(dur, decay, rng, vol=1.0):
    n = int(dur * SR)
    return [(rng.random() * 2 - 1) * math.exp(-decay * (i / SR)) * vol for i in range(n)]

def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]

def concat(*tracks):
    out = []
    for t in tracks:
        out.extend(t)
    return out

def save(name, samples, peak=0.8):
    m = max(abs(s) for s in samples) or 1.0
    k = peak / m
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * k)) * 32767)) for s in samples))
    print("wrote", name, f"{len(samples) / SR * 1000:.0f} ms")

rng = random.Random(1234)
save("ui_click", mix(tone(1400, 0.07, 60, -3000), noise(0.02, 250, rng, 0.35)))
save("ui_back", mix(tone(720, 0.10, 38, -1800), noise(0.015, 250, rng, 0.2)))
save("ui_confirm", concat(tone(660, 0.07, 30), tone(990, 0.12, 24)))
