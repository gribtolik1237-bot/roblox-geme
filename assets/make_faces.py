"""TRAP LAB - original NPC face decals (256x256 RGBA, transparent): big glossy toy eyes + thick ink mouths, 5 characters.
Pure stdlib, 3x3 supersampling. Run: python -I make_faces.py -> assets/faces/*.png"""
import math, os, struct, zlib

N, SS = 256, 3
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "faces")
os.makedirs(OUT, exist_ok=True)
INK = (22, 16, 20)
WHITE = (255, 255, 255)


def ellipse(cx, cy, rx, ry, ang=0.0):
    ca, sa = math.cos(ang), math.sin(ang)
    def f(x, y):
        dx, dy = x - cx, y - cy
        u, v = dx * ca + dy * sa, -dx * sa + dy * ca
        return (u / rx) ** 2 + (v / ry) ** 2 <= 1
    return f


def stroke(points, w):
    segs = list(zip(points, points[1:]))
    def f(x, y):
        for (ax, ay), (bx, by) in segs:
            vx, vy = bx - ax, by - ay
            l2 = vx * vx + vy * vy
            t = 0 if l2 == 0 else max(0, min(1, ((x - ax) * vx + (y - ay) * vy) / l2))
            px, py = ax + vx * t, ay + vy * t
            if (x - px) ** 2 + (y - py) ** 2 <= (w / 2) ** 2:
                return True
        return False
    return f


def arc(cx, cy, rx, ry, a0, a1, w, n=24):
    pts = [(cx + rx * math.cos(a0 + (a1 - a0) * i / n), cy + ry * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]
    return stroke(pts, w)


def rrect(x0, y0, x1, y1, r):
    def f(x, y):
        qx = max(x0 + r - x, 0, x - (x1 - r)); qy = max(y0 + r - y, 0, y - (y1 - r))
        return x0 <= x <= x1 and y0 <= y <= y1 and qx * qx + qy * qy <= r * r
    return f


def half_ellipse_down(cx, cy, rx, ry):   # open mouth: lower half of an ellipse
    e = ellipse(cx, cy, rx, ry)
    return lambda x, y: y >= cy and e(x, y)


def render(name, layers):
    buf = bytearray()
    for py in range(N):
        buf.append(0)
        for px in range(N):
            acc = [0.0, 0.0, 0.0, 0.0]
            for sy in range(SS):
                for sx in range(SS):
                    x, y = px + (sx + 0.5) / SS, py + (sy + 0.5) / SS
                    col = None
                    for shape, c in layers:   # last layer that covers the point wins
                        if shape(x, y):
                            col = c
                    if col:
                        acc[0] += col[0]; acc[1] += col[1]; acc[2] += col[2]; acc[3] += 1
            n = SS * SS
            if acc[3] > 0:
                buf += bytes((int(acc[0] / acc[3]), int(acc[1] / acc[3]), int(acc[2] / acc[3]), int(255 * acc[3] / n)))
            else:
                buf += b"\x00\x00\x00\x00"
    def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", N, N, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(bytes(buf), 9)) + chunk(b"IEND", b"")
    with open(os.path.join(OUT, name + ".png"), "wb") as f:
        f.write(png)
    print(name)


def eyes(y=112, rx=19, ry=27, gap=46, glint=True, look=0):
    L = []
    for s in (-1, 1):
        cx = 128 + s * gap
        L.append((ellipse(cx, y, rx, ry), INK))
        if glint:
            L.append((ellipse(cx - 6 + look, y - 10, 7, 9), WHITE))
            L.append((ellipse(cx + 6 + look, y + 9, 3.2, 3.2), WHITE))
    return L


# 1 happy: big glossy eyes + wide smile
render("happy", eyes() + [(arc(128, 150, 40, 26, math.radians(20), math.radians(160), 11), INK)])
# 2 grin: squinty happy eyes (arcs) + open grin with tongue
render("grin", [(arc(82, 118, 20, 14, math.radians(200), math.radians(340), 11), INK), (arc(174, 118, 20, 14, math.radians(200), math.radians(340), 11), INK),
                (half_ellipse_down(128, 148, 44, 40), INK), (lambda x, y: ellipse(128, 148, 36, 32)(x, y) and 152 <= y < 163, WHITE),
                (lambda x, y: ellipse(128, 180, 22, 12)(x, y) and ellipse(128, 148, 36, 32)(x, y), (240, 90, 110))])
# 3 determined: eyes + angled brows + firm smirk
render("determined", eyes(y=118, ry=23) + [(stroke([(56, 76), (100, 90)], 11), INK), (stroke([(156, 90), (200, 76)], 11), INK),
                                            (stroke([(100, 162), (130, 166), (160, 156)], 11), INK)])
# 4 cool: black shades with a shine + side smirk
render("cool", [(rrect(52, 92, 120, 132, 14), INK), (rrect(136, 92, 204, 132, 14), INK), (stroke([(118, 104), (138, 104)], 9), INK),
                (stroke([(64, 102), (84, 102)], 6), (120, 200, 255)), (stroke([(148, 102), (168, 102)], 6), (120, 200, 255)),
                (arc(140, 150, 28, 16, math.radians(15), math.radians(150), 10), INK)])
# 5 wonder: huge sparkly eyes + small happy "o"
render("wonder", eyes(y=110, rx=22, ry=30, gap=48) + [(ellipse(128, 165, 11, 13), INK), (ellipse(128, 168, 6, 7), (240, 90, 110))])
