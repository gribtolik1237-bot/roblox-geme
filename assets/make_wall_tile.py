# TRAP LAB - seamless "studded brick" overlay for the world cliff wall (128x128 RGBA, transparent background):
#   blender.exe -b --factory-startup -P make_wall_tile.py
# A raised square stud in the middle of the tile (light top-left, dark bottom-right bevel) + a faint mortar edge, drawn OVER the part colour
# so the two-brown checker keeps showing through. Used as a Texture on the cliff segments (StudsPerTile ~ 8).
import bpy, os
import numpy as np
N = 128
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "wall_tile.png")
yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
c = N / 2.0
half = 28.0                      # half size of the stud square
dx, dy = xx - c, yy - c
inside = (np.abs(dx) < half) & (np.abs(dy) < half)
edge = np.minimum(half - np.abs(dx), half - np.abs(dy))          # distance to the stud border (inside)
bev = np.clip(1 - edge / 7.0, 0, 1) * inside                     # bevel ring
tl = ((dx < dy) & (dx + dy < 0)).astype(np.float32)              # top/left half of the ring
rgb = np.zeros((N, N, 3), np.float32)
a = np.zeros((N, N), np.float32)
a += inside * 0.10                                               # stud face slightly lighter
rgb += inside[..., None] * 1.0
lightA = bev * tl * 0.55
darkA = bev * (1 - tl) * 0.55
# composite: light bevel (white), dark bevel (black)
alpha = np.clip(a + lightA + darkA, 0, 1)
col = (np.ones(3, np.float32)[None, None, :] * (lightA + a)[..., None]) / np.maximum(alpha[..., None], 1e-4)
col = np.where((darkA > lightA)[..., None], 0.0, col)
# mortar: a thin dark frame at the tile border (seamless: both sides of the seam are dark)
m = ((xx < 3) | (xx > N - 4) | (yy < 3) | (yy > N - 4)).astype(np.float32)
alpha = np.clip(alpha + m * 0.35, 0, 1)
col = np.where((m > 0)[..., None] & (alpha[..., None] > 0) & ((lightA + a) < 0.01)[..., None], 0.0, col)
rgba = np.concatenate([np.clip(col, 0, 1), alpha[..., None]], axis=2).astype(np.float32)
img = bpy.data.images.new("wall_tile", N, N, alpha=True)
img.colorspace_settings.name = "Non-Color"
img.alpha_mode = "STRAIGHT"
img.pixels.foreach_set(rgba.reshape(-1))
img.filepath_raw = out
img.file_format = "PNG"
img.save()
# preview over brown, 3x3
brown = np.array([0.55, 0.38, 0.27], np.float32)
rep = np.tile(rgba, (3, 3, 1))
prev = rep[..., :3] * rep[..., 3:4] + brown * (1 - rep[..., 3:4])
prev = np.concatenate([prev, np.ones((N * 3, N * 3, 1), np.float32)], axis=2).astype(np.float32)
pv = bpy.data.images.new("wall_prev", N * 3, N * 3, alpha=True)
pv.colorspace_settings.name = "Non-Color"
pv.pixels.foreach_set(prev.reshape(-1))
pv.filepath_raw = os.path.join(os.path.dirname(out), "_wall_preview.png")
pv.file_format = "PNG"
pv.save()
print("DONE")
