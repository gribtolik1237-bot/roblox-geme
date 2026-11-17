# TRAP LAB - UI icons (256x256, transparent): coin + padlock. Rendered in Blender 5.x headless:
#   "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b --factory-startup -P make_donate_icons.py
# Same chunky brick-toy language as make_hud_icons.py (bevelled boxes, studs, warm saturated palette, ONE big readable object per icon),
# composited on a coloured sunburst card so the icon also works as a Roblox product thumbnail. Original shapes only (docs/ART_DIRECTION.md).
import bpy, math, os, bmesh
import numpy as np
from mathutils import Vector

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ui")
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
SIZE = 256


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


# ---- UI icons (one hero object each, thick ink outline via Freestyle) -------------------------------------------
AX = (math.radians(90), 0, 0)


def i_coin():  # chunky gold coin with a raised star, tilted toward the viewer
    cyl(1.45, 0.42, (0, 0.0, 0.0), C["gold"], rot=AX, bevel=0.07, verts=48)
    cyl(1.18, 0.46, (0, 0.0, 0.0), C["goldD"], rot=AX, bevel=0.0, verts=48)
    cyl(1.08, 0.5, (0, 0.0, 0.0), C["gold"], rot=AX, bevel=0.0, verts=48)
    star(0.78, 0.34, 0.26, (0, -0.3, 0.0), C["goldL"], bevel=0.07)


def i_lock():  # chunky padlock: gold body + shackle + keyhole
    bpy.ops.mesh.primitive_torus_add(major_radius=0.7, minor_radius=0.2, location=(0, 0, 0.95), rotation=(math.radians(90), 0, 0), major_segments=40, minor_segments=14)
    sh = bpy.context.active_object
    sh.data.materials.append(C["gray"])
    smooth(sh)
    made.append(sh)
    box((1.9, 0.9, 1.5), (0, 0, -0.1), C["gold"], bevel=0.14)
    box((1.9, 0.5, 0.35), (0, -0.02, 0.45), C["goldL"], bevel=0.08)
    cyl(0.17, 0.12, (0, -0.48, -0.05), C["ink"], rot=AX, bevel=0, verts=20)
    box((0.12, 0.12, 0.42), (0, -0.48, -0.36), C["ink"], bevel=0)


ICONS = {"coin": (i_coin, None), "lock": (i_lock, None)}

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
cam.ortho_scale = 3.9
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



for name, (fn, _acc) in ICONS.items():
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
    sc.render.filepath = os.path.join(OUT, f"{name}.png")
    bpy.ops.render.render(write_still=True)
    for o in made:
        bpy.data.objects.remove(o, do_unlink=True)
print("DONE")
