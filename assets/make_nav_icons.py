# TRAP LAB - navigation icons (256x256, transparent): hammer (hotbar slot 1), home (top bar), finish flag (PLAY sign).
# Reuses the exact render rig of make_ui_icons.py (same light, ortho camera, ink Freestyle outline) so the set stays one family.
# Run:  "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b --factory-startup -P make_nav_icons.py
# NO WOOD (owner rule D-030): the hammer handle is red toy plastic with yellow grip bands.
import os

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.join(HERE, "make_ui_icons.py")
src = open(BASE, encoding="utf-8").read()

NEW = r'''
from mathutils import Matrix
C["steel"] = mat("steel", (0.58, 0.63, 0.72), 0.3, metal=0.2)
C["steelD"] = mat("steelD", (0.38, 0.42, 0.50), 0.35)
C["blue"] = mat("blue", (0.20, 0.45, 0.95))
C["roof"] = mat("roof", (0.92, 0.26, 0.24))


def tilt(objs, deg, axis="Y"):
    R = Matrix.Rotation(math.radians(deg), 4, axis)
    for o in objs:
        o.matrix_world = R @ o.matrix_world


def i_hammer():  # toy hammer: red plastic handle with yellow grips, chunky steel head, tilted
    box((0.34, 0.34, 2.5), (0, 0, -0.45), C["red"], bevel=0.1)
    for z in (-1.35, -1.05):
        box((0.42, 0.42, 0.14), (0, 0, z), C["yellow"], bevel=0.04)
    box((1.75, 0.66, 0.66), (0, 0, 0.98), C["steel"], bevel=0.13)
    cyl(0.42, 0.34, (0.98, 0, 0.98), C["steelD"], rot=(0, math.radians(90), 0), bevel=0.05)
    box((0.6, 0.5, 0.34), (-1.05, 0, 1.12), C["steelD"], bevel=0.08, rot=(0, math.radians(-22), 0))
    tilt(list(made), -38)


def i_home():  # small house: cream walls, red gable roof, blue door, window, studded grass base
    box((2.6, 2.1, 0.26), (0, 0, -1.22), C["green"], bevel=0.06)
    studs(3, 2, 2.2, 1.6, -1.09, C["green"], r=0.16, h=0.1)
    box((2.0, 1.6, 1.5), (0, 0, -0.35), C["cream"], bevel=0.08)
    box((1.40, 1.50, 1.40), (0, 0, 0.40), C["cream"], bevel=0.04, rot=(0, math.radians(45), 0))
    for sgn in (1, -1):
        box((1.62, 1.86, 0.26), (sgn * 0.55, 0, 0.98), C["roof"], bevel=0.07, rot=(0, math.radians(45 * sgn), 0))
    box((0.30, 0.30, 0.70), (0.62, 0.42, 1.25), C["gray"], bevel=0.05)
    box((0.52, 0.14, 0.86), (-0.42, -0.82, -0.67), C["blue"], bevel=0.05)
    cyl(0.06, 0.06, (-0.26, -0.9, -0.67), C["yellow"], rot=(math.radians(90), 0, 0), bevel=0, verts=12)
    box((0.50, 0.14, 0.46), (0.52, -0.82, -0.18), C["gem"], bevel=0.04)


def i_flag():  # checkered finish flag on a pole, gently waving
    box((0.95, 0.95, 0.26), (-1.05, 0, -1.55), C["green"], bevel=0.06)
    cyl(0.16, 3.1, (-1.05, 0, 0.0), C["yellow"], bevel=0.03)
    ball(0.19, (-1.05, 0, 1.62), C["gold"])
    cols, rows, cell = 4, 3, 0.5
    for i in range(cols):
        for j in range(rows):
            y = 0.05 * math.sin(i * 1.3)
            m = C["white"] if (i + j) % 2 == 0 else C["ink"]
            box((cell, 0.12, cell), (-0.70 + cell * i, y, 1.30 - cell * j), m, bevel=0.015)


ICONS = {"hammer": (i_hammer, None), "home": (i_home, None), "playflag": (i_flag, None)}
'''

marker = 'ICONS = {"coin": (i_coin, None), "lock": (i_lock, None)}'
assert marker in src, "rig marker not found in make_ui_icons.py"
src = src.replace(marker, NEW)
exec(compile(src, BASE, "exec"), {"__file__": BASE, "__name__": "__main__"})
