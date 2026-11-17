# TRAP LAB - HUD menu icons (256x256, transparent) rendered in Blender 5.x headless:
#   blender.exe -b --factory-startup -P make_hud_icons.py
# One chunky brick-toy object per menu button, same lighting/camera, original shapes only (docs/ART_DIRECTION.md).
import bpy, math, os, bmesh

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "hud")
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene


def lin(c):
    return tuple(x ** 2.2 for x in c)


def mat(name, rgb, rough=0.45, emit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*lin(rgb), 1)
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*lin(rgb), 1)
        b.inputs["Emission Strength"].default_value = emit
    return m


C = {
    "teal": mat("teal", (0.16, 0.77, 0.84)), "purple": mat("purple", (0.63, 0.47, 1.0)), "green": mat("green", (0.33, 0.80, 0.38)),
    "orange": mat("orange", (1.0, 0.58, 0.24)), "yellow": mat("yellow", (1.0, 0.76, 0.18)), "red": mat("red", (0.94, 0.30, 0.30)),
    "pink": mat("pink", (1.0, 0.44, 0.63)), "wood": mat("wood", (0.58, 0.32, 0.23), 0.6), "woodL": mat("woodL", (0.82, 0.60, 0.38), 0.6),
    "cream": mat("cream", (0.98, 0.94, 0.82), 0.6), "ink": mat("ink", (0.14, 0.10, 0.11), 0.6), "skin": mat("skin", (1.0, 0.80, 0.22)),
    "gray": mat("gray", (0.62, 0.62, 0.68), 0.35), "blue": mat("blue", (0.17, 0.55, 0.95)), "pants": mat("pants", (0.24, 0.26, 0.36), 0.55),
    "leaf": mat("leaf", (0.36, 0.78, 0.36), 0.6), "white": mat("white", (1, 1, 1), 0.5),
}
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


def cyl(r, h, loc, m, rot=(0, 0, 0), bevel=0.03):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, location=loc, vertices=28)
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


def studs(nx, ny, w, d, top, m, r=0.2, h=0.14):
    for i in range(nx):
        for j in range(ny):
            cyl(r, h, (-w / 2 + w / nx * (i + 0.5), -d / 2 + d / ny * (j + 0.5), top + h / 2), m, bevel=0.02)


def face(cx, cy, z, s=1.0):  # eyes + smile on the -Y side of a head
    for sx in (-1, 1):
        box((0.12 * s, 0.05, 0.22 * s), (cx + sx * 0.26 * s, cy, z + 0.12 * s), C["ink"], bevel=0)
    box((0.5 * s, 0.05, 0.09 * s), (cx, cy, z - 0.2 * s), C["ink"], bevel=0)


def spin(ang):  # rotate everything built so far about Z (to face the camera)
    ca, sa = math.cos(ang), math.sin(ang)
    for o in made:
        x, y, z = o.location
        o.location = (x * ca - y * sa, x * sa + y * ca, z)
        o.rotation_euler.rotate_axis("Z", ang)


def star(r1, r2, thick, loc, m):
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
    bv.width = 0.09
    bv.segments = 3
    me.materials.append(m)
    smooth(o)
    made.append(o)


# ---- icons -------------------------------------------------------------------------------------------------
def i_shop():
    box((2.3, 1.3, 1.0), (0, 0, -0.55), C["wood"])
    for sx in (-1, 1):
        box((0.2, 0.2, 1.7), (sx * 1.0, -0.5, 0.25), C["woodL"], bevel=0.04)
    for k in range(5):
        box((0.5, 1.6, 0.16), (-1.0 + k * 0.5, -0.1, 1.05 - 0.0), C["teal"] if k % 2 == 0 else C["cream"], bevel=0.03, rot=(math.radians(-14), 0, 0))
    box((0.7, 0.5, 0.35), (-0.5, -0.1, 0.1), C["orange"], bevel=0.05)
    box((0.5, 0.5, 0.5), (0.5, -0.1, 0.18), C["red"], bevel=0.05)


def i_npcshop():
    box((1.5, 1.4, 1.5), (0, 0, 0), C["skin"], bevel=0.14)
    face(0, -0.72, 0.05, 1.25)
    box((1.64, 1.5, 0.55), (0, 0, 0.9), C["purple"], bevel=0.1)
    box((1.7, 0.8, 0.14), (0, -0.85, 0.7), C["purple"], bevel=0.05)
    cyl(0.17, 0.22, (0, 0, 1.28), C["yellow"])


def i_build():
    box((2.4, 1.6, 0.95), (0, 0, -0.55), C["orange"], bevel=0.09)
    studs(2, 4, 2.3, 1.5, -0.075, C["orange"], r=0.25)
    box((1.2, 1.6, 0.95), (-0.6, 0, 0.45), C["yellow"], bevel=0.09)
    studs(1, 2, 1.1, 1.5, 0.925, C["yellow"], r=0.25)

def i_npcs():
    box((0.95, 0.5, 0.9), (0, 0, -1.0), C["pants"], bevel=0.05)
    box((1.15, 0.6, 1.05), (0, 0, 0.0), C["purple"], bevel=0.06)
    for sx in (-1, 1):
        box((0.4, 0.45, 0.95), (sx * 0.82, 0, 0.0), C["skin"], bevel=0.05)
    box((0.95, 0.9, 0.9), (0, 0, 1.0), C["skin"], bevel=0.12)
    face(0, -0.47, 1.0, 0.85)


def i_rebirth():
    for k, z in enumerate((0.55, -0.45)):
        m = C["green"] if k == 0 else C["yellow"]
        for sx in (-1, 1):
            box((1.5, 0.6, 0.5), (sx * 0.52, 0, z), m, bevel=0.1, rot=(0, math.radians(sx * 38), 0))
    spin(math.radians(34))


def i_daily():
    box((2.2, 0.5, 2.2), (0, 0, 0), C["cream"], bevel=0.1)
    box((2.2, 0.56, 0.7), (0, -0.02, 0.75), C["red"], bevel=0.08)
    for sx in (-0.6, 0.6):
        cyl(0.11, 0.7, (sx, 0, 1.25), C["gray"], rot=(math.radians(90), 0, 0))
    cols = ("green", "teal", "orange", "yellow", "purple", "green")
    for k in range(6):
        box((0.46, 0.08, 0.46), (-0.6 + (k % 3) * 0.6, -0.28, 0.15 - (k // 3) * 0.62), C[cols[k]], bevel=0.04)


def i_popular():
    star(1.25, 0.58, 0.5, (0, 0, 0), C["yellow"])
    ball(0.17, (0.0, -0.3, 0.1), C["white"], scale=(1, 0.4, 1))


def i_decor():
    cyl(0.22, 1.1, (0, 0, -0.65), C["wood"], bevel=0.03)
    ball(0.85, (0, 0, 0.3), C["leaf"])
    ball(0.6, (0.6, 0, -0.05), C["green"])
    ball(0.55, (-0.6, 0, 0.0), C["leaf"])
    ball(0.12, (0.2, -0.75, 0.2), C["red"])
    ball(0.12, (-0.35, -0.7, 0.5), C["yellow"])


def i_inventory():
    box((2.2, 1.5, 1.1), (0, 0, -0.5), C["wood"], bevel=0.09)
    box((2.3, 1.6, 0.6), (0, 0, 0.35), C["woodL"], bevel=0.12)
    for sx in (-0.75, 0.75):
        box((0.22, 1.66, 1.75), (sx, 0, -0.1), C["yellow"], bevel=0.04)
    box((0.5, 0.2, 0.55), (0, -0.82, 0.05), C["yellow"], bevel=0.05)
    cyl(0.08, 0.1, (0, -0.95, 0.05), C["ink"], rot=(math.radians(90), 0, 0), bevel=0)


def i_donate():
    for sx in (-1, 1):
        ball(0.7, (sx * 0.55, 0, 0.5), C["red"], scale=(1, 0.75, 1))
    box((1.55, 0.95, 1.55), (0, 0, -0.1), C["red"], bevel=0.14, rot=(0, math.radians(45), 0))
    ball(0.16, (-0.62, -0.5, 0.82), C["white"], scale=(1, 0.5, 1))


ICONS = {"shop": i_shop, "npcshop": i_npcshop, "build": i_build, "npcs": i_npcs, "rebirth": i_rebirth, "daily": i_daily,
         "popular": i_popular, "decor": i_decor, "inventory": i_inventory, "donate": i_donate}

# ---- render rig ---------------------------------------------------------------------------------------------
sc.world = bpy.data.worlds.new("W")
sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (*lin((0.85, 0.9, 1.0)), 1)
sc.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
sun = bpy.data.lights.new("Sun", "SUN")
sun.energy = 4.0
so = bpy.data.objects.new("Sun", sun)
sc.collection.objects.link(so)
so.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
fill = bpy.data.lights.new("Fill", "AREA")
fill.energy = 250
fill.size = 8
fo = bpy.data.objects.new("Fill", fill)
sc.collection.objects.link(fo)
fo.location = (-5, -7, 4)
fo.rotation_euler = (math.radians(65), 0, math.radians(-35))
cam = bpy.data.cameras.new("Cam")
cam.type = "ORTHO"
cam.ortho_scale = 4.1
co = bpy.data.objects.new("Cam", cam)
sc.collection.objects.link(co)
sc.camera = co
co.location = (3.4, -5.0, 3.2)
co.rotation_euler = (math.radians(62), 0, math.radians(34))
sc.render.engine = "BLENDER_EEVEE"
sc.view_settings.view_transform = "Standard"
sc.render.film_transparent = True
sc.render.resolution_x = sc.render.resolution_y = 256
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"
try:
    sc.eevee.taa_render_samples = 64
except Exception:
    pass


# thick dark toy outline (same as the donate/UI icons; the owner's references have a heavy ink contour on every icon)
sc.render.use_freestyle = True
sc.render.line_thickness_mode = "ABSOLUTE"
vl = sc.view_layers[0]
vl.use_freestyle = True
fsm = vl.freestyle_settings
fsm.crease_angle = math.radians(140)
for nm, th, ext in (("contour", 9.0, True), ("detail", 2.6, False)):
    ls = fsm.linesets.new(nm)
    ls.select_by_visibility = True
    ls.select_silhouette = not ext
    ls.select_border = not ext
    ls.select_crease = False
    ls.select_material_boundary = not ext
    ls.select_external_contour = ext
    ls.linestyle.color = (0.012, 0.006, 0.014)
    ls.linestyle.thickness = th

import numpy as np
sheet_tiles = []
for name, fn in ICONS.items():
    made.clear()
    fn()
    # centre the object group on the origin (visual bounding box)
    mn = [1e9] * 3
    mx = [-1e9] * 3
    for o in made:
        for v in o.bound_box:
            w = o.matrix_world @ __import__("mathutils").Vector(v)
            for k in range(3):
                mn[k] = min(mn[k], w[k])
                mx[k] = max(mx[k], w[k])
    ctr = [(mn[k] + mx[k]) / 2 for k in range(3)]
    for o in made:
        o.location = (o.location[0] - ctr[0], o.location[1] - ctr[1], o.location[2] - ctr[2])
    sc.render.filepath = os.path.join(OUT, f"{name}.png")
    bpy.ops.render.render(write_still=True)
    for o in made:
        bpy.data.objects.remove(o, do_unlink=True)
    im = bpy.data.images.load(sc.render.filepath)
    im.colorspace_settings.name = "Non-Color"
    im.alpha_mode = "STRAIGHT"
    arr = np.empty(256 * 256 * 4, np.float32)
    im.pixels.foreach_get(arr)
    sheet_tiles.append(arr.reshape(256, 256, 4))
    bpy.data.images.remove(im)
# contact sheet: the 10 icons at the real in-game size (128 px) over a dark tile, 5 per row
tiles = []
for t in sheet_tiles:
    a = t[..., 3:4]
    comp = t[..., :3] * a + np.array([0.16, 0.16, 0.22], np.float32) * (1 - a)
    tiles.append(comp.reshape(128, 2, 128, 2, 3).mean(axis=(1, 3)))
row1 = np.concatenate(tiles[:5], axis=1)
row2 = np.concatenate(tiles[5:], axis=1)
sheet = np.concatenate([row1, row2], axis=0)
sheet = np.concatenate([sheet, np.ones((sheet.shape[0], sheet.shape[1], 1), np.float32)], axis=2).astype(np.float32)
shi = bpy.data.images.new("sheet", sheet.shape[1], sheet.shape[0], alpha=True)
shi.colorspace_settings.name = "Non-Color"
shi.pixels.foreach_set(sheet.reshape(-1))
shi.filepath_raw = os.path.join(os.path.dirname(OUT), "hud_sheet.png")
shi.file_format = "PNG"
shi.save()
print("DONE")


