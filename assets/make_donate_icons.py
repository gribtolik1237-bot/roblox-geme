# TRAP LAB - donate shop icons (512x512): 3 tips + Supporter pass. Rendered in Blender 5.x headless:
#   "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b --factory-startup -P make_donate_icons.py
# Same chunky brick-toy language as make_hud_icons.py (bevelled boxes, studs, warm saturated palette, ONE big readable object per icon),
# composited on a coloured sunburst card so the icon also works as a Roblox product thumbnail. Original shapes only (docs/ART_DIRECTION.md).
import bpy, math, os, bmesh
import numpy as np
from mathutils import Vector

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "donate")
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
SIZE = 512


def lin(c):
    return tuple(x ** 2.2 for x in c)


def mat(name, rgb, rough=0.45, emit=0.0, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*lin(rgb), 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*lin(rgb), 1)
        b.inputs["Emission Strength"].default_value = emit
    return m


C = {
    "teal": mat("teal", (0.16, 0.77, 0.84)), "purple": mat("purple", (0.63, 0.47, 1.0)), "purpleD": mat("purpleD", (0.42, 0.28, 0.78)),
    "green": mat("green", (0.33, 0.80, 0.38)), "orange": mat("orange", (1.0, 0.58, 0.24)), "yellow": mat("yellow", (1.0, 0.76, 0.18)),
    "red": mat("red", (0.94, 0.30, 0.30)), "pink": mat("pink", (1.0, 0.44, 0.63)), "wood": mat("wood", (0.58, 0.32, 0.23), 0.6),
    "woodL": mat("woodL", (0.82, 0.60, 0.38), 0.6), "cream": mat("cream", (0.98, 0.94, 0.82), 0.6), "ink": mat("ink", (0.14, 0.10, 0.11), 0.6),
    "gold": mat("gold", (1.0, 0.74, 0.12), 0.28), "goldD": mat("goldD", (0.88, 0.50, 0.06), 0.35), "goldL": mat("goldL", (1.0, 0.90, 0.45), 0.3),
    "sack": mat("sack", (0.74, 0.52, 0.30), 0.75), "sackD": mat("sackD", (0.55, 0.36, 0.20), 0.75), "white": mat("white", (1, 1, 1), 0.5),
    "gem": mat("gem", (0.20, 0.85, 0.95), 0.12, 0.25), "gemR": mat("gemR", (1.0, 0.25, 0.40), 0.12, 0.25), "gray": mat("gray", (0.62, 0.62, 0.68), 0.35),
}
g = mat("glass", (0.55, 0.85, 1.0), 0.25)
g.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.09
try:
    g.surface_render_method = "BLENDED"
except Exception:
    g.blend_method = "BLEND"
C["glass"] = g
made = []


def smooth(o):
    for p in o.data.polygons:
        p.use_smooth = True


def box(size, loc, m, bevel=0.07, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.scale = size
    o.rotation_euler = rot
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        bv = o.modifiers.new("Bevel", "BEVEL")
        bv.width = bevel
        bv.segments = 3
        bv.limit_method = "ANGLE"
    o.data.materials.append(m)
    smooth(o)
    made.append(o)
    return o


def cyl(r, h, loc, m, rot=(0, 0, 0), bevel=0.03, verts=32):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, location=loc, vertices=verts)
    o = bpy.context.active_object
    o.rotation_euler = rot
    if bevel:
        bv = o.modifiers.new("Bevel", "BEVEL")
        bv.width = bevel
        bv.segments = 2
        bv.limit_method = "ANGLE"
    o.data.materials.append(m)
    smooth(o)
    made.append(o)
    return o


def ball(r, loc, m, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=28, ring_count=14)
    o = bpy.context.active_object
    o.scale = scale
    o.data.materials.append(m)
    smooth(o)
    made.append(o)
    return o


def studs(nx, ny, w, d, top, m, cx=0.0, cy=0.0, r=0.17, h=0.12):
    for i in range(nx):
        for j in range(ny):
            cyl(r, h, (cx - w / 2 + w / nx * (i + 0.5), cy - d / 2 + d / ny * (j + 0.5), top + h / 2), m, bevel=0.02, verts=20)


def star(r1, r2, thick, loc, m, bevel=0.07):
    bm = bmesh.new()
    pts = []
    for i in range(10):
        a = math.pi / 2 + i * math.pi / 5
        r = r1 if i % 2 == 0 else r2
        pts.append((math.cos(a) * r, 0, math.sin(a) * r))
    top = [bm.verts.new((x, -thick / 2, z)) for x, _, z in pts]
    bot = [bm.verts.new((x, thick / 2, z)) for x, _, z in pts]
    bm.faces.new(top[::-1])
    bm.faces.new(bot)
    for i in range(10):
        j = (i + 1) % 10
        bm.faces.new((top[i], top[j], bot[j], bot[i]))
    me = bpy.data.meshes.new("star")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("star", me)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    bv = o.modifiers.new("Bevel", "BEVEL")
    bv.width = bevel
    bv.segments = 3
    me.materials.append(m)
    smooth(o)
    made.append(o)
    return o


def heart(cx, cz, s, m, y=0.0, thick=0.34, bevel=0.06):
    """A real heart outline (parametric), standing in the XZ plane, facing the camera (-Y). s = overall width in world units."""
    pts = []
    n = 56
    for i in range(n):
        t = i / n * math.tau
        x = 16 * math.sin(t) ** 3
        z = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x * s / 32.0, (z + 2.5) * s / 32.0))
    bm = bmesh.new()
    top = [bm.verts.new((x, -thick / 2, z)) for x, z in pts]
    bot = [bm.verts.new((x, thick / 2, z)) for x, z in pts]
    bm.faces.new(top)
    bm.faces.new(bot[::-1])
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((top[j], top[i], bot[i], bot[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new("heart")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("heart", me)
    bpy.context.scene.collection.objects.link(o)
    o.location = (cx, y, cz)
    bv = o.modifiers.new("Bevel", "BEVEL")
    bv.width = bevel
    bv.segments = 3
    me.materials.append(m)
    smooth(o)
    made.append(o)
    return o


def coin(r, loc, rot=(0, 0, 0), h=0.22):
    """Gold coin: bevelled disc with a darker groove ring (no dome in the middle)."""
    cyl(r, h, loc, C["gold"], rot=rot, bevel=0.035)
    cyl(r * 0.78, h + 0.02, loc, C["goldD"], rot=rot, bevel=0)
    cyl(r * 0.70, h + 0.04, loc, C["gold"], rot=rot, bevel=0)


def rotate_xy(x, y, ang):
    return x * math.cos(ang) - y * math.sin(ang), x * math.sin(ang) + y * math.cos(ang)


# ---- the four icons (one big hero object each, no base plate) -----------------------------------------------------
AX = (math.radians(90), 0, 0)


def i_tip_small():  # one big upright gold coin with a heart, and a few coins lying in front
    coin(1.4, (0, 0.0, 1.45), rot=AX, h=0.36)
    cyl(1.0, 0.1, (0, -0.2, 1.45), C["goldL"], rot=AX, bevel=0.0)                 # lighter face disc inside the groove
    heart(0, 1.45, 1.25, C["red"], y=-0.3, thick=0.3)
    for k, (x, y) in enumerate(((-0.95, -1.15), (-0.95 + 0.06, -1.15 + 0.05), (-0.95 - 0.04, -1.15 + 0.03))):
        coin(0.62, (x, y, 0.1 + k * 0.2), h=0.2)
    coin(0.5, (1.2, -1.0, 0.08), h=0.18)


def i_tip_medium():  # a tip jar full of gold coins with a heart label and a coin dropping into the slot
    cyl(1.05, 2.2, (0, 0, 1.1), C["glass"], bevel=0.05, verts=40)
    for k in range(13):                                                            # neat column of coins inside the jar
        coin(0.78, (0.04 * math.sin(k * 1.7), 0.04 * math.cos(k * 1.3), 0.2 + k * 0.15), rot=(0.05 * math.sin(k), 0.05 * math.cos(k), k), h=0.15)
    cyl(1.16, 0.36, (0, 0, 2.38), C["red"], bevel=0.05, verts=40)                  # lid
    box((0.9, 0.16, 0.06), (0, 0.0, 2.58), C["ink"], bevel=0.0)                     # coin slot
    coin(0.62, (0.0, 0.0, 3.0), rot=AX, h=0.18)                                    # coin dropping in
    box((1.15, 0.08, 1.15), (0, -1.07, 1.1), C["cream"], bevel=0.05)               # label
    heart(0, 1.1, 0.78, C["red"], y=-1.16, thick=0.12, bevel=0.03)


def i_tip_big():  # an open treasure chest overflowing with gold and gems, with a spark
    box((2.6, 1.8, 1.05), (0, 0, 0.35), C["wood"], bevel=0.09)
    for sx in (-0.9, 0.9):
        box((0.26, 1.86, 1.1), (sx, 0, 0.35), C["yellow"], bevel=0.04)
    box((2.64, 0.3, 1.3), (0, 1.02, 1.6), C["woodL"], bevel=0.1, rot=(math.radians(-18), 0, 0))   # lid, hinged at the back
    for sx in (-0.9, 0.9):
        box((0.28, 0.36, 1.34), (sx, 1.0, 1.6), C["yellow"], bevel=0.04, rot=(math.radians(-18), 0, 0))
    ball(1.22, (0, 0.0, 0.9), C["goldD"], scale=(1.0, 0.72, 0.42))                  # amber heap core, so the bright coins pop against it
    for k, x in enumerate((-1.0, -0.5, 0.0, 0.5, 1.0)):                            # fan of upright coins standing on the heap, facing the viewer
        coin(0.6, (x, 0.3 - 0.06 * abs(x), 1.95 + 0.16 * math.cos(x * 1.4)), rot=(math.radians(82), math.radians(-14 * x), 0), h=0.16)
    coin(0.5, (-0.6, -0.5, 1.52), rot=(math.radians(14), 0, 0.3), h=0.15)         # two flat coins on the front of the heap
    coin(0.46, (0.5, -0.45, 1.5), rot=(math.radians(-10), 0, -0.2), h=0.15)
    box((0.46, 0.46, 0.46), (1.05, -0.5, 1.45), C["gem"], bevel=0.07, rot=(0.5, 0.6, 0.4))
    box((0.4, 0.4, 0.4), (-1.1, -0.4, 1.4), C["gemR"], bevel=0.07, rot=(0.3, 0.4, 0.9))
    box((0.62, 0.2, 0.72), (0, -0.96, 0.45), C["yellow"], bevel=0.06)               # lock + keyhole
    cyl(0.1, 0.12, (0, -1.08, 0.5), C["ink"], rot=AX, bevel=0, verts=16)
    box((0.08, 0.12, 0.24), (0, -1.08, 0.3), C["ink"], bevel=0)
    coin(0.5, (1.0, -1.45, -0.1))
    star(0.45, 0.2, 0.14, (-1.55, -0.3, 2.4), C["goldL"], bevel=0.05)


def i_pass():  # a hanging star medal on a striped ribbon V: the "Supporter" badge
    for sx in (-1, 1):                                                             # ribbon, behind the medal
        ang = math.radians(sx * 26)
        cx, cz = sx * 0.4 + math.sin(ang) * 0.85, 1.25 + math.cos(ang) * 0.85
        box((0.78, 0.16, 1.7), (cx, 0.14, cz), C["red"], bevel=0.05, rot=(0, ang, 0))
        box((0.22, 0.18, 1.7), (cx, 0.13, cz), C["yellow"], bevel=0.03, rot=(0, ang, 0))
    cyl(1.5, 0.38, (0, 0.0, 0.0), C["gold"], rot=AX, bevel=0.06, verts=48)          # outer gold rim
    cyl(1.26, 0.44, (0, 0.0, 0.0), C["purpleD"], rot=AX, bevel=0.02, verts=48)
    cyl(1.12, 0.48, (0, 0.0, 0.0), C["purple"], rot=AX, bevel=0.0, verts=48)
    for k in range(12):                                                            # rim studs
        a = k * math.pi / 6
        cyl(0.115, 0.08, (math.cos(a) * 1.38, -0.21, math.sin(a) * 1.38), C["goldL"], rot=AX, bevel=0, verts=14)
    star(1.0, 0.44, 0.26, (0, -0.32, 0.0), C["yellow"], bevel=0.08)
    cyl(0.28, 0.22, (0, 0.0, 1.58), C["gold"], rot=AX, bevel=0.04, verts=24)        # ring where the ribbon meets the medal


ICONS = {  # file -> (builder, background accent)
    "tip_small": (i_tip_small, (0.16, 0.77, 0.84)),
    "tip_medium": (i_tip_medium, (0.33, 0.80, 0.38)),
    "tip_big": (i_tip_big, (1.0, 0.58, 0.24)),
    "pass_supporter": (i_pass, (0.63, 0.47, 1.0)),
}

# ---- render rig -------------------------------------------------------------------------------------------------
sc.world = bpy.data.worlds.new("W")
sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (*lin((0.88, 0.92, 1.0)), 1)
sc.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
sun = bpy.data.lights.new("Sun", "SUN")
sun.energy = 4.2
so = bpy.data.objects.new("Sun", sun)
sc.collection.objects.link(so)
so.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
fill = bpy.data.lights.new("Fill", "AREA")
fill.energy = 280
fill.size = 8
fo = bpy.data.objects.new("Fill", fill)
sc.collection.objects.link(fo)
fo.location = (-5, -7, 4)
fo.rotation_euler = (math.radians(65), 0, math.radians(-35))
cam = bpy.data.cameras.new("Cam")
cam.type = "ORTHO"
cam.ortho_scale = 4.7
co = bpy.data.objects.new("Cam", cam)
sc.collection.objects.link(co)
sc.camera = co
co.location = (3.4, -5.0, 3.2)
co.rotation_euler = (math.radians(62), 0, math.radians(34))
sc.render.engine = "BLENDER_EEVEE"
sc.view_settings.view_transform = "Standard"
sc.render.film_transparent = True
sc.render.resolution_x = sc.render.resolution_y = SIZE
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"
try:
    sc.eevee.taa_render_samples = 64
except Exception:
    pass

# thick dark toy outline (the references have a heavy ink contour around every icon): outer contour + inner material edges
sc.render.use_freestyle = True
sc.render.line_thickness_mode = "ABSOLUTE"
vl = sc.view_layers[0]
vl.use_freestyle = True
fsm = vl.freestyle_settings
fsm.crease_angle = math.radians(140)
for nm, th, ext in (("contour", 8.0, True), ("detail", 3.0, False)):
    ls = fsm.linesets.new(nm)
    ls.select_by_visibility = True
    ls.select_silhouette = not ext
    ls.select_border = not ext
    ls.select_crease = False
    ls.select_material_boundary = not ext
    ls.select_external_contour = ext
    ls.linestyle.color = (0.012, 0.006, 0.014)
    ls.linestyle.thickness = th


def backdrop(accent):
    """Radial light-to-deep accent gradient + soft sunburst rays, in sRGB 0..1 (matches how the PNG is stored)."""
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    nx, ny = (xx + 0.5) / SIZE - 0.5, (yy + 0.5) / SIZE - 0.5
    rr = np.sqrt(nx * nx + ny * ny) / 0.7071
    acc = np.array(accent, np.float32)
    inner = acc * 0.45 + 0.55
    outer = acc * 0.78
    t = np.clip(rr * 1.05, 0, 1)[..., None]
    bg = inner * (1 - t) + outer * t
    ray = (np.sin(np.arctan2(ny, nx) * 12.0) * 0.5 + 0.5)
    ray = (ray > 0.5).astype(np.float32) * 0.10 * (1 - np.clip(rr * 1.1, 0, 1))
    bg = np.clip(bg + ray[..., None], 0, 1)
    return bg


finals = []
for name, (fn, accent) in ICONS.items():
    made.clear()
    fn()
    mn = [1e9] * 3
    mx = [-1e9] * 3
    for o in made:
        for v in o.bound_box:
            w = o.matrix_world @ Vector(v)
            for k in range(3):
                mn[k] = min(mn[k], w[k])
                mx[k] = max(mx[k], w[k])
    ctr = [(mn[k] + mx[k]) / 2 for k in range(3)]
    for o in made:
        o.location = (o.location[0] - ctr[0], o.location[1] - ctr[1], o.location[2] - ctr[2])
    raw = os.path.join(OUT, f"_{name}_fg.png")
    sc.render.filepath = raw
    bpy.ops.render.render(write_still=True)
    for o in made:
        bpy.data.objects.remove(o, do_unlink=True)
    # composite on the backdrop (raw sRGB values, straight alpha)
    img = bpy.data.images.load(raw)
    img.colorspace_settings.name = "Non-Color"
    img.alpha_mode = "STRAIGHT"
    px = np.empty(SIZE * SIZE * 4, np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(SIZE, SIZE, 4)
    a = px[..., 3:4]
    rgb = px[..., :3]
    bgimg = backdrop(accent)
    ys, xs = np.where(a[..., 0] > 0.3)
    if len(ys):
        cx, rx, cy = (xs.min() + xs.max()) / 2.0, max(20.0, (xs.max() - xs.min()) * 0.40), ys.min() + 6
        gy, gx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
        d = np.sqrt(((gx - cx) / rx) ** 2 + ((gy - cy) / 20.0) ** 2)
        sh = (np.clip(1 - d, 0, 1) ** 1.5 * 0.45)[..., None]
        bgimg = bgimg * (1 - sh) + np.array(accent, np.float32) * 0.25 * sh
    out = np.concatenate([rgb * a + bgimg * (1 - a), np.ones((SIZE, SIZE, 1), np.float32)], axis=2)
    out = out.astype(np.float32)
    finals.append(out[..., :3])
    res = bpy.data.images.new(f"out_{name}", SIZE, SIZE, alpha=True)
    res.colorspace_settings.name = "Non-Color"
    res.alpha_mode = "STRAIGHT"
    res.pixels.foreach_set(out.reshape(-1))
    res.filepath_raw = os.path.join(OUT, f"{name}.png")
    res.file_format = "PNG"
    res.save()
    bpy.data.images.remove(img)
    bpy.data.images.remove(res)
    os.remove(raw)
# contact sheet at the real in-game card size (128 px) to judge readability
q = SIZE // 128
small = [f.reshape(128, q, 128, q, 3).mean(axis=(1, 3)) for f in finals]
sheet = np.concatenate(small, axis=1)
sheet = np.concatenate([sheet, np.ones((128, sheet.shape[1], 1), np.float32)], axis=2).astype(np.float32)
sh_img = bpy.data.images.new("sheet", sheet.shape[1], 128, alpha=True)
sh_img.colorspace_settings.name = "Non-Color"
sh_img.pixels.foreach_set(sheet.reshape(-1))
sh_img.filepath_raw = os.path.join(OUT, "_sheet.png")
sh_img.file_format = "PNG"
sh_img.save()
print("DONE")
