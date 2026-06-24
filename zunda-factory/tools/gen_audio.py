#!/usr/bin/env python3
"""SFXを合成して assets/audio/ にWAVで出力する。"""
import math
import os
import struct
import wave

SR = 32000
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")

NOTE = {n: 440.0 * 2 ** ((i - 9) / 12) for i, n in enumerate(
    ["C4", "C#4", "D4", "D#4", "E4", "F4", "F#4", "G4", "G#4", "A4", "A#4", "B4"])}
def freq(name):
    base, octv = name[:-1], int(name[-1])
    return NOTE[base + "4"] * 2 ** (octv - 4)

def write_wav(path, samples):
    samples = [max(-1.0, min(1.0, s)) for s in samples]
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(s * 32000)) for s in samples))
    print(f"{path}: {len(samples)/SR:.2f}s")

def tone(f, dur, vol=0.5, decay=6.0, harmonics=((1, 1.0), (3, 0.25))):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-decay * t) * min(1.0, i / (SR * 0.004))
        s = sum(a * math.sin(2 * math.pi * f * h * t) for h, a in harmonics)
        out.append(vol * env * s)
    return out

def sweep(f0, f1, dur, vol=0.5, decay=10.0):
    n = int(SR * dur)
    out, phase = [], 0.0
    for i in range(n):
        t = i / SR
        f = f0 + (f1 - f0) * (t / dur)
        phase += 2 * math.pi * f / SR
        env = math.exp(-decay * t) * min(1.0, i / (SR * 0.003))
        out.append(vol * env * math.sin(phase))
    return out

def mix_at(base, add, at):
    i0 = int(SR * at)
    while len(base) < i0 + len(add):
        base.append(0.0)
    for i, s in enumerate(add):
        base[i0 + i] += s
    return base

def seq(notes, step, vol=0.4, dur=0.8, decay=5.0):
    out = []
    for i, n in enumerate(notes):
        if n:
            mix_at(out, tone(freq(n), dur, vol=vol, decay=decay), i * step)
    return out

os.makedirs(OUT, exist_ok=True)

# ずんだもん生産ポップ
write_wav(os.path.join(OUT, "spawn.wav"), sweep(500, 900, 0.08, vol=0.4, decay=20))
# 打撃
write_wav(os.path.join(OUT, "hit.wav"), sweep(300, 150, 0.06, vol=0.4, decay=30))
# 敵撃破
kill = sweep(700, 1100, 0.09, vol=0.4, decay=16)
mix_at(kill, sweep(400, 200, 0.1, vol=0.25, decay=18), 0.02)
write_wav(os.path.join(OUT, "kill.wav"), kill)
# 味方ロスト
write_wav(os.path.join(OUT, "lost.wav"), sweep(350, 140, 0.18, vol=0.35, decay=12))
# 建設・強化
write_wav(os.path.join(OUT, "build.wav"), seq(["E5", "A5"], 0.08, vol=0.4, dur=0.4, decay=8))
# ウェーブ接近ホーン
warn = tone(freq("D4"), 0.5, vol=0.35, decay=4, harmonics=((1, 1.0), (2, 0.5), (3, 0.3)))
mix_at(warn, tone(freq("D4"), 0.5, vol=0.35, decay=4, harmonics=((1, 1.0), (2, 0.5))), 0.55)
write_wav(os.path.join(OUT, "wave.wav"), warn)
# 前線突破ファンファーレ
write_wav(os.path.join(OUT, "advance.wav"), seq(["C5", "E5", "G5", "C6"], 0.08, vol=0.4, dur=0.7, decay=5))
# 敗北
write_wav(os.path.join(OUT, "lose.wav"), seq(["E5", "C5", "A4", "F4"], 0.22, vol=0.4, dur=1.0, decay=3))

# 床のきしみ
import random
random.seed(7)
def noise(dur, vol=0.5, decay=6.0):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-decay * t)
        out.append(vol * env * (random.random() * 2 - 1))
    return out

creak = sweep(140, 70, 0.7, vol=0.4, decay=3)
mix_at(creak, sweep(180, 90, 0.5, vol=0.25, decay=4), 0.25)
write_wav(os.path.join(OUT, "creak.wav"), creak)

# ステージ崩壊(轟音)
crash = noise(1.2, vol=0.55, decay=4)
mix_at(crash, sweep(120, 35, 1.0, vol=0.6, decay=3), 0.0)
mix_at(crash, noise(0.6, vol=0.4, decay=5), 0.45)
write_wav(os.path.join(OUT, "collapse.wav"), crash)
