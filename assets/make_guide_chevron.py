"""Текстура луча-навигатора обучения TRAP LAB: жёлтый шеврон «>» с толстым чёрным контуром и бликом,
прозрачный фон (RGBA). Тайлится по длине луча (Beam.TextureMode = Static/Wrap).
Только стандартная библиотека. Запуск:  python -I make_guide_chevron.py  -> ui/guide_chevron.png (384x128, chevron + 50% gap)."""
import zlib, struct, os, sys

# args: [width] [file]  (beam: 384 guide_chevron.png = chevron + gap; marker/screen arrow: 256 guide_arrow.png = tight)
W = int(sys.argv[1]) if len(sys.argv) > 1 else 384
H = 128
OUT_NAME = sys.argv[2] if len(sys.argv) > 2 else "guide_chevron.png"
SS = 4                      # суперсэмплинг для гладких краёв
TIP = 200                   # x вершины шеврона
SLOPE = 1.25                # наклон плеч
THICK = 64                  # толщина плеча по x
OUTLINE = 12                # чёрный контур
YELLOW = (255, 206, 44)
HI = (255, 240, 150)
INK = (18, 14, 26)


def sample(x, y):
    """Возвращает (r,g,b,a) в точке субпикселя."""
    d = abs(y - H / 2)
    xc = TIP - SLOPE * d          # передний край плеча на этой высоте
    # расстояние внутрь фигуры по горизонтали
    inner = xc - x                # >0 — за передним краем
    # поля по вертикали (верх/низ плеч обрезаны)
    vy = H / 2 - 6 - d            # >0 — внутри по высоте
    if vy < -OUTLINE:
        return None
    if -OUTLINE <= inner <= THICK + OUTLINE and vy >= -OUTLINE:
        core = 0 <= inner <= THICK and vy >= 0
        if core:
            # блик: светлая полоса у переднего края, сверху ярче
            t = inner / THICK
            col = YELLOW
            if t < 0.28 and y < H / 2:
                col = HI
            elif t > 0.8:
                col = (230, 160, 20)
            return col + (255,)
        return INK + (255,)
    return None


px = bytearray(W * H * 4)
for y in range(H):
    for x in range(W):
        acc = [0, 0, 0, 0]
        for sy in range(SS):
            for sx in range(SS):
                s = sample(x + (sx + 0.5) / SS, y + (sy + 0.5) / SS)
                if s:
                    acc[0] += s[0]; acc[1] += s[1]; acc[2] += s[2]; acc[3] += 255
        n = SS * SS
        a = acc[3] / n
        i = (y * W + x) * 4
        if a > 0:
            cov = acc[3] / 255
            px[i] = int(acc[0] / cov); px[i + 1] = int(acc[1] / cov); px[i + 2] = int(acc[2] / cov)
        px[i + 3] = int(a)


def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


raw = bytearray()
for y in range(H):
    raw.append(0)
    raw += px[y * W * 4:(y + 1) * W * 4]
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0)) \
      + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ui")
os.makedirs(out_dir, exist_ok=True)
out = os.path.join(out_dir, OUT_NAME)
with open(out, "wb") as f:
    f.write(png)
print("written", out, len(png), "bytes")
