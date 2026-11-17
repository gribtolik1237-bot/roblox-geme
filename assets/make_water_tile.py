# TRAP LAB - seamless pool tile (256x256, 2x2 tiles with grout), generated in Blender's Python (numpy, no render needed):
#   "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b --factory-startup -P make_water_tile.py
# Used as a Texture on the plot BuildZone (StudsPerTile 16 => each tile is 8 studs): alternating two cyan tones, light grout,
# a soft bevel (light top-left, shade bottom-right) and a faint caustic band so the pool reads as tiled water, not a flat slab.
import bpy, os, math
import numpy as np

N = 256
T = N // 2          # tile edge in pixels
G = 5               # grout width
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "water_tile.png")

yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
tx, ty = xx % T, yy % T                      # position inside the tile
ix, iy = (xx // T).astype(int), (yy // T).astype(int)
checker = ((ix + iy) % 2).astype(np.float32)[..., None]

A = np.array([0.20, 0.77, 0.89], np.float32)   # tile tone 1 (sRGB)
B = np.array([0.14, 0.66, 0.84], np.float32)   # tile tone 2
GROUT = np.array([0.74, 0.95, 0.98], np.float32)
col = A * (1 - checker) + B * checker

# bevel: light on the top-left inner edge, shade on the bottom-right inner edge
inner_x = np.clip(np.minimum(tx - G, T - 1 - tx), 0, None)
inner_y = np.clip(np.minimum(ty - G, T - 1 - ty), 0, None)
edge_tl = np.clip(1 - np.minimum(tx - G, ty - G) / 9.0, 0, 1)
edge_br = np.clip(1 - np.minimum(T - 1 - tx, T - 1 - ty) / 9.0, 0, 1)
col = col + (edge_tl[..., None] * 0.13) - (edge_br[..., None] * 0.10)

# faint caustic band across each tile (tiles stay seamless because the pattern repeats per tile)
b1 = np.sin((tx / T) * math.tau * 2.0 + (ty / T) * math.tau * 1.0)
b2 = np.sin((ty / T) * math.tau * 2.0 - (tx / T) * math.tau * 1.0 + 1.3)
band = (b1 * b2) * 0.5 + 0.5
col = col + (band[..., None] ** 5) * 0.12

# grout lines on the first G pixels of every tile (both axes) => seamless
grout = ((tx < G) | (ty < G)).astype(np.float32)[..., None]
col = col * (1 - grout) + GROUT * grout
col = np.clip(col, 0, 1)

rgba = np.concatenate([col, np.ones((N, N, 1), np.float32)], axis=2).astype(np.float32)
img = bpy.data.images.new("water_tile", N, N, alpha=True)
img.colorspace_settings.name = "Non-Color"
img.pixels.foreach_set(rgba.reshape(-1))
img.filepath_raw = out
img.file_format = "PNG"
img.save()

# 2x2 repeat preview to eyeball seams
rep = np.tile(rgba, (2, 2, 1))
pv = bpy.data.images.new("water_preview", N * 2, N * 2, alpha=True)
pv.colorspace_settings.name = "Non-Color"
pv.pixels.foreach_set(rep.reshape(-1))
pv.filepath_raw = os.path.join(os.path.dirname(out), "_water_preview.png")
pv.file_format = "PNG"
pv.save()
print("DONE")
