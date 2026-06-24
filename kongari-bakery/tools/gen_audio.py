#!/usr/bin/env python3
"""SFXとBGMを合成して assets/audio/ にWAVで出力する。"""
import math
import os
import struct
import wave

SR = 32000
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")

NOTE = {n: 440.0 * 2 ** ((i - 9) / 12) for i, n in enumerate(
    ["C4", "C#4", "D4", "D#4", "E4", "F4", "F#4", "G4", "G#4", "A4", "A#4", "B4"])}
def freq(name):  # e.g. "C5"
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

def silence(dur):
    return [0.0] * int(SR * dur)

def tone(f, dur, vol=0.5, decay=6.0, harmonics=((1, 1.0), (3, 0.25))):
    """オルゴール風: 基音+高次倍音、指数減衰。"""
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
    """notes: [(name or None), ...] を step 秒間隔で並べる。"""
    out = []
    for i, n in enumerate(notes):
        if n:
            mix_at(out, tone(freq(n), dur, vol=vol, decay=decay), i * step)
    return out

os.makedirs(OUT, exist_ok=True)

# クリック: 軽いポップ
write_wav(os.path.join(OUT, "click.wav"), sweep(750, 480, 0.07, vol=0.5, decay=28))

# クリティカル: 跳ねる2連ポップ
crit = sweep(600, 900, 0.08, vol=0.5, decay=18)
mix_at(crit, sweep(900, 1400, 0.12, vol=0.5, decay=14), 0.07)
write_wav(os.path.join(OUT, "crit.wav"), crit)

# こげパン: 残念な下降音
write_wav(os.path.join(OUT, "burnt.wav"), sweep(280, 130, 0.25, vol=0.45, decay=8))

# 購入: 2音チャイム
buy = seq(["E5", "G5"], 0.09, vol=0.4, dur=0.5, decay=7)
write_wav(os.path.join(OUT, "buy.wav"), buy)

# ゴールデンパン出現: キラキラ上昇
ga = seq(["C6", "E6", "G6"], 0.07, vol=0.3, dur=0.5, decay=8)
write_wav(os.path.join(OUT, "golden_appear.wav"), ga)

# ゴールデンパン獲得: ファンファーレ
gg = seq(["C5", "E5", "G5", "C6", "E6"], 0.08, vol=0.4, dur=0.9, decay=4)
write_wav(os.path.join(OUT, "golden_get.wav"), gg)

# マイルストーン称号: ゆったりファンファーレ
ms = seq(["G5", "C6", "E6"], 0.16, vol=0.4, dur=1.2, decay=3)
write_wav(os.path.join(OUT, "milestone.wav"), ms)

# 注文出現: ドアベル「カランコロン」
bell = tone(freq("E6"), 0.5, vol=0.35, decay=5, harmonics=((1, 1.0), (2.76, 0.4)))
mix_at(bell, tone(freq("C6"), 0.6, vol=0.35, decay=4, harmonics=((1, 1.0), (2.76, 0.4))), 0.12)
write_wav(os.path.join(OUT, "order_bell.wav"), bell)

# 注文成功: 明るい3音
write_wav(os.path.join(OUT, "order_ok.wav"), seq(["C5", "G5", "C6"], 0.09, vol=0.4, dur=0.7, decay=5))

# 注文失敗: しょんぼり下降
of = seq(["E5", "C5"], 0.18, vol=0.35, dur=0.6, decay=5)
mix_at(of, sweep(220, 110, 0.35, vol=0.3, decay=6), 0.36)
write_wav(os.path.join(OUT, "order_fail.wav"), of)

# トロフィー獲得: キラッ
write_wav(os.path.join(OUT, "trophy.wav"), seq(["A5", "E6"], 0.10, vol=0.35, dur=0.8, decay=5))

# フィーバー突入: 上昇ライザー+キラキラ
fv = sweep(300, 1400, 0.5, vol=0.4, decay=2.5)
mix_at(fv, seq(["C6", "E6", "G6", "C7"], 0.06, vol=0.3, dur=0.5, decay=6), 0.3)
write_wav(os.path.join(OUT, "fever.wav"), fv)

# エンディング: 長いファンファーレ
end = seq(["C5", "E5", "G5", "C6", "G5", "E6", "C6"], 0.22, vol=0.4, dur=1.6, decay=2.2)
mix_at(end, tone(freq("C4") / 2, 2.5, vol=0.2, decay=1.2), 0.0)
mix_at(end, tone(freq("C4"), 2.0, vol=0.15, decay=1.5), 0.88)
write_wav(os.path.join(OUT, "ending.wav"), end)

# BGM: オルゴールワルツ (3/4, 100bpm, 8小節ループ)
beat = 60.0 / 100.0           # 0.6s
bar = beat * 3                # 1.8s
melody_bars = [
    ["C5", "E5", "G5"],
    ["A5", "G5", "E5"],
    ["D5", "E5", "G5"],
    ["E5", "D5", "C5"],
    ["C5", "E5", "G5"],
    ["A5", "C6", "A5"],
    ["G5", "E5", "D5"],
    ["C5", None, None],
]
bass_bars = ["C4", "G4", "F4", "C4", "C4", "F4", "G4", "C4"]
bgm = silence(bar * 8 + 0.001)
for b, (mb, bb) in enumerate(zip(melody_bars, bass_bars)):
    t0 = b * bar
    mix_at(bgm, tone(freq(bb) / 2, 1.6, vol=0.16, decay=2.0), t0)
    for k, n in enumerate(mb):
        if n:
            mix_at(bgm, tone(freq(n), 1.4, vol=0.20, decay=3.0), t0 + k * beat)
bgm = bgm[: int(SR * bar * 8)]  # ループ境界ぴったりで切る
write_wav(os.path.join(OUT, "bgm.wav"), bgm)
