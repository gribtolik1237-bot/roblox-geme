"""Бесшовная текстура газона для TRAP LAB: шахматка 2x2 из ярких зелёных «кирпичных» плит
(у каждой плиты 4x4 ячейки с фаской и круглым шипом — язык эталонов владельца).
Только стандартная библиотека. Запуск:  python -I make_lawn_tile.py   -> lawn_tile.png (512x512)."""
import zlib, struct, os, math

N = 512
BIG = 256          # одна крупная плита шахматки
CELL = 64          # ячейка 4x4 внутри плиты
LIGHT = (128, 216, 72)
DARK = (102, 190, 60)

def clamp(v):
    return max(0, min(255, int(v)))

px = bytearray(N * N * 3)
for y in range(N):
    for x in range(N):
        big_x, big_y = x // BIG, y // BIG
        base = LIGHT if (big_x + big_y) % 2 == 0 else DARK
        cx, cy = x % CELL, y % CELL
        r, g, b = base
        # фаска ячейки: свет сверху-слева, тень снизу-справа, тёмный шов
        if cx < 3 or cy < 3:
            r, g, b = r + 16, g + 14, b + 12
        if cx >= CELL - 4 or cy >= CELL - 4:
            r, g, b = r - 22, g - 24, b - 18
        if cx == CELL - 1 or cy == CELL - 1:
            r, g, b = r - 14, g - 16, b - 12
        # круглый шип в центре ячейки (подсветка сверху-слева, тень снизу-справа)
        dx, dy = cx - CELL / 2, cy - CELL / 2
        d = math.hypot(dx, dy)
        if d < 15:
            shade = (-dx - dy) / 30.0           # +1 слева-сверху
            k = 14 * shade
            r, g, b = r + k, g + k, b + k * 0.8
            if d > 13:
                r, g, b = r - 20, g - 22, b - 16
        i = (y * N + x) * 3
        px[i], px[i + 1], px[i + 2] = clamp(r), clamp(g), clamp(b)

def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

raw = bytearray()
for y in range(N):
    raw.append(0)
    raw += px[y * N * 3:(y + 1) * N * 3]
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", N, N, 8, 2, 0, 0, 0)) \
      + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lawn_tile.png")
with open(out, "wb") as f:
    f.write(png)
print("written", out, len(png), "bytes")
