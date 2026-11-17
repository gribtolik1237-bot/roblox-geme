"""Текстура луча-навигатора обучения TRAP LAB (вариант 2): ЖИРНАЯ стрелка-треугольник «▶» с толстым чёрным контуром,
жёлтая с бликом, прозрачный промежуток до следующей. Тайл 256x256 = квадрат: Beam.TextureLength = ширине луча.
Только стандартная библиотека. Запуск:  python -I make_guide_arrows.py  -> ui/guide_arrows.png"""
import zlib, struct, os

W = H = 256
SS = 4
TIP_X, BACK_X = 200, 40          # треугольник: основание x=40 (по всей высоте с полями), вершина x=200 по центру
MARGIN = 26                      # поля сверху/снизу
OUT = 14                         # контур
YELLOW = (255, 206, 44)
HI = (255, 242, 160)
SHADE = (232, 160, 18)
INK = (18, 14, 26)


def inside(x, y, grow):
    # треугольник (BACK_X, MARGIN) - (BACK_X, H-MARGIN) - (TIP_X, H/2), раздутый на grow
    if x < BACK_X - grow or x > TIP_X + grow * 1.6:
        return False
    half = (H / 2 - MARGIN) * (TIP_X - x) / (TIP_X - BACK_X) + grow * 1.25
    return abs(y - H / 2) <= half


def sample(x, y):
    if inside(x, y, 0):
        top = y < H / 2
        t = (x - BACK_X) / (TIP_X - BACK_X)
        if top and abs(y - H / 2) > (H / 2 - MARGIN) * (1 - t) * 0.45:
            return HI if t < 0.7 else YELLOW
        if not top and abs(y - H / 2) > (H / 2 - MARGIN) * (1 - t) * 0.55:
            return SHADE
        return YELLOW
    if inside(x, y, OUT):
        return INK
    return None


px = bytearray(W * H * 4)
for y in range(H):
    for x in range(W):
        r = g = b = a = 0
        for sy in range(SS):
            for sx in range(SS):
                c = sample(x + (sx + 0.5) / SS, y + (sy + 0.5) / SS)
                if c:
                    r += c[0]; g += c[1]; b += c[2]; a += 1
        i = (y * W + x) * 4
        if a:
            px[i], px[i + 1], px[i + 2] = r // a, g // a, b // a
            px[i + 3] = 255 * a // (SS * SS)


def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


raw = bytearray()
for y in range(H):
    raw.append(0)
    raw += px[y * W * 4:(y + 1) * W * 4]
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0)) \
      + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ui", "guide_arrows.png")
with open(out, "wb") as f:
    f.write(png)
print("written", out, len(png), "bytes")
