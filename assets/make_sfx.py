"""TRAP LAB - original game sound effects, synthesised from scratch (no samples, no third-party audio -> fully ours).
Bright toy-like cues for a bright brick-toy game: sine/triangle tones with soft attacks and exponential decays.
Run:  python -I make_sfx.py   -> assets/audio/*.wav (44.1 kHz, 16-bit mono)."""
import math, os, random, struct, wave

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "audio")
os.makedirs(OUT, exist_ok=True)
random.seed(7)


def env(t, attack, decay):
    a = min(1.0, t / attack) if attack > 0 else 1.0
    return a * math.exp(-t / decay)


def tone(freq_fn, dur, wave_kind="sine", attack=0.004, decay=0.15, harm=0.0, vib=0.0):
    out, ph = [], 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        f = freq_fn(t) * (1 + vib * math.sin(2 * math.pi * 6 * t))
        ph += 2 * math.pi * f / SR
        if wave_kind == "sine":
            s = math.sin(ph) + harm * math.sin(2 * ph)
        elif wave_kind == "tri":
            s = 2 / math.pi * math.asin(math.sin(ph))
        else:  # soft square: first odd harmonics only (no harsh buzz)
            s = math.sin(ph) + math.sin(3 * ph) / 3 + math.sin(5 * ph) / 5
        out.append(s * env(t, attack, decay))
    return out


def mix(*parts):
    n = max(len(p) + off for p, off in parts)
    buf = [0.0] * n
    for p, off in parts:
        for i, s in enumerate(p):
            buf[off + i] += s
    return buf


def at(sec):
    return int(SR * sec)


def noise(dur, decay):
    return [(random.random() * 2 - 1) * math.exp(-(i / SR) / decay) for i in range(int(SR * dur))]


def save(name, buf, peak=0.85):
    m = max(1e-9, max(abs(s) for s in buf))
    tail = at(0.01)
    buf = [s / m * peak for s in buf]
    for i in range(min(tail, len(buf))):  # 10 ms fade-out: no click at the end
        buf[-1 - i] *= i / tail
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in buf))
    print(f"{name}.wav  {len(buf) / SR:.2f}s")


# coin: two-note bell "ka-ching" up a fourth (B5 -> E6), with a light octave harmonic
save("coin", mix((tone(lambda t: 988, 0.07, harm=0.3, decay=0.05), 0), (tone(lambda t: 1319, 0.32, harm=0.3, decay=0.12), at(0.06))))
# spend: two quick falling clinks + a tiny tick
save("spend", mix((tone(lambda t: 1568, 0.08, harm=0.25, decay=0.03), 0), (tone(lambda t: 1175, 0.18, harm=0.25, decay=0.06), at(0.07)), ([s * 0.25 for s in noise(0.01, 0.003)], 0)))
# place: chunky "thock" (pitch-dropping low sine) + short click: a brick snapping in
save("place", mix((tone(lambda t: 200 * math.exp(-t * 9) + 70, 0.16, decay=0.06), 0), ([s * 0.35 for s in noise(0.012, 0.004)], 0)))
# open: soft rising "bloop" for windows
save("open", tone(lambda t: 420 + 900 * t, 0.12, attack=0.008, decay=0.06))
# checkpoint: quick rising arpeggio C6-E6-G6 (triangle)
save("checkpoint", mix(*[(tone(lambda t, f=f: f, 0.16, "tri", decay=0.07), at(0.065 * k)) for k, f in enumerate((1047, 1319, 1568))]))
# clear: small fanfare C5-E5-G5 -> long C6 with gentle vibrato (soft square)
notes = [(523, 0.0, 0.12), (659, 0.11, 0.12), (784, 0.22, 0.12), (1047, 0.33, 0.7)]
save("clear", mix(*[(tone(lambda t, f=f: f, d, "square", decay=(0.35 if d > 0.3 else 0.08), vib=(0.006 if d > 0.3 else 0.0)), at(s)) for f, s, d in notes]))
# fall: cartoon slide-whistle down with a wobble
save("fall", tone(lambda t: 720 * math.exp(-t * 2.4) + 110, 0.7, "tri", attack=0.01, decay=0.45, vib=0.02))
