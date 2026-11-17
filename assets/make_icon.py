# TRAP LAB - game icon (512x512) and cover (1920x1080) rendered in Blender 5.x (headless):
#   blender.exe -b --factory-startup -P make_icon.py
# Style (docs/ART_DIRECTION.md, "Etalony"): bright brick-toy test range - studded sand platforms, a red swinging hammer on a wooden gantry,
# a blocky tester, a teal test pool, soft daylight. Original assets only (no Roblox/third-party art).
import bpy, math, os

OUT = os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene


def lin(c):  # sRGB 0..1 -> linear
    return tuple(x ** 2.2 for x in c)


def mat(name, rgb, rough=0.5, metal=0.0, emit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*lin(rgb), 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit > 0:
        b.inputs["Emission Color"].default_value = (*lin(rgb), 1)
        b.inputs["Emission Strength"].default_value = emit
    return m


M = {
    "sand": mat("Sand", (0.93, 0.80, 0.55), 0.55),
    "sand2": mat("SandDark", (0.84, 0.70, 0.45), 0.55),
    "wood": mat("Wood", (0.58, 0.32, 0.23), 0.6),
    "woodL": mat("WoodLight", (0.82, 0.60, 0.38), 0.6),
    "red": mat("Red", (0.94, 0.30, 0.26), 0.35),
    "yellow": mat("Yellow", (1.0, 0.76, 0.18), 0.4),
    "ink": mat("Ink", (0.14, 0.10, 0.11), 0.6),
    "water": mat("Water", (0.23, 0.68, 0.78), 0.12),
    "teal": mat("Teal", (0.16, 0.77, 0.84), 0.4),
    "green": mat("Green", (0.38, 0.80, 0.30), 0.5),
    "skin": mat("Skin", (1.0, 0.80, 0.22), 0.5),
    "shirt": mat("Shirt", (0.17, 0.55, 0.95), 0.5),
    "pants": mat("Pants", (0.24, 0.26, 0.36), 0.55),
    "cloud": mat("Cloud", (1.0, 1.0, 1.0), 0.9),
}


def shade_smooth(o):
    for p in o.data.polygons:
        p.use_smooth = True


def box(name, size, loc, m, bevel=0.05, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    o.rotation_euler = rot
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        bv = o.modifiers.new("Bevel", "BEVEL")
        bv.width = bevel
        bv.segments = 3
        bv.limit_method = "ANGLE"
    o.data.materials.append(m)
    shade_smooth(o)
    return o


def cyl(name, r, h, loc, m, rot=(0, 0, 0), bevel=0.02, verts=32):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, location=loc, vertices=verts)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = rot
    if bevel:
        bv = o.modifiers.new("Bevel", "BEVEL")
        bv.width = bevel
        bv.segments = 2
        bv.limit_method = "ANGLE"
    o.data.materials.append(m)
    shade_smooth(o)
    return o


def sphere(name, r, loc, m, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=24, ring_count=12)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    o.data.materials.append(m)
    shade_smooth(o)
    return o


def studded_platform(name, cx, cy, top, w, d, m, mdark, nx, ny):
    box(name, (w, d, 1.0), (cx, cy, top - 0.5), m, bevel=0.07)
    box(name + "Skirt", (w + 0.16, d + 0.16, 0.35), (cx, cy, top - 0.78), mdark, bevel=0.05)
    px, py = w / nx, d / ny
    for i in range(nx):
        for j in range(ny):
            x = cx - w / 2 + px * (i + 0.5)
            y = cy - d / 2 + py * (j + 0.5)
            cyl(name + "Stud", 0.27, 0.16, (x, y, top + 0.07), m, bevel=0.03, verts=20)


# ---- world ----------------------------------------------------------------------------------------------------
sc.world = bpy.data.worlds.new("Sky")
sc.world.use_nodes = True
wn = sc.world.node_tree.nodes
wl = sc.world.node_tree.links
bg = wn["Background"]
tc = wn.new("ShaderNodeTexCoord")
grad = wn.new("ShaderNodeTexGradient")
ramp = wn.new("ShaderNodeValToRGB")
mp = wn.new("ShaderNodeMapping")
mp.inputs["Rotation"].default_value = (0, math.radians(-90), 0)
ramp.color_ramp.elements[0].color = (*lin((0.78, 0.90, 1.0)), 1)
ramp.color_ramp.elements[1].color = (*lin((0.30, 0.58, 0.98)), 1)
wl.new(tc.outputs["Generated"], mp.inputs["Vector"])
wl.new(mp.outputs["Vector"], grad.inputs["Vector"])
wl.new(grad.outputs["Fac"], ramp.inputs["Fac"])
wl.new(ramp.outputs["Color"], bg.inputs["Color"])
bg.inputs["Strength"].default_value = 1.1

# ---- set -------------------------------------------------------------------------------------------------------
box("Water", (60, 60, 0.4), (0, 0, -1.55), M["water"], bevel=0)
# (no back edge: a lone beam behind the gantry read as a stray plank)

studded_platform("PlatA", 0, 0, 0.0, 7.0, 7.0, M["sand"], M["wood"], 6, 6)
studded_platform("PlatB", 6.4, -1.6, -0.35, 3.4, 3.4, M["sand"], M["wood"], 3, 3)
studded_platform("PlatC", -6.3, 2.2, -0.35, 3.4, 3.4, M["sand"], M["wood"], 3, 3)
box("StartStripe", (7.0, 0.55, 0.12), (0, -3.2, 0.06), M["yellow"], bevel=0.03)
for i in range(7):  # hazard blocks on the stripe
    if i % 2 == 0:
        box("Haz", (0.5, 0.56, 0.14), (-3.0 + i * 1.0, -3.2, 0.07), M["ink"], bevel=0.02, rot=(0, 0, math.radians(30)))
cyl("GoalDisc", 1.05, 0.14, (0.4, 1.6, 0.08), M["green"], bevel=0.03, verts=40)

# gantry + swinging hammer
for sx in (-1, 1):
    box("Post", (0.55, 0.55, 8.2), (sx * 3.5, 3.4, 3.7), M["wood"], bevel=0.08)
    box("PostFoot", (1.2, 1.2, 0.4), (sx * 3.5, 3.4, -0.1), M["woodL"], bevel=0.06)
box("Beam", (7.9, 0.7, 0.7), (0, 3.4, 7.7), M["woodL"], bevel=0.09)
pivot = (0, 3.4, 7.3)
ang = math.radians(32)  # swing angle toward the camera side
L = 5.6
hx, hz = pivot[0] - math.sin(ang) * L * 0.0, pivot[2]
arm_c = (pivot[0] - math.sin(ang) * L / 2 * 0.0 + 0.0, pivot[1] - math.sin(ang) * L / 2, pivot[2] - math.cos(ang) * L / 2)
cyl("Arm", 0.16, L, arm_c, M["woodL"], rot=(-ang, 0, 0), bevel=0.03)
head_c = (pivot[0], pivot[1] - math.sin(ang) * (L + 0.8), pivot[2] - math.cos(ang) * (L + 0.8))
box("HammerHead", (2.4, 1.5, 1.5), head_c, M["red"], bevel=0.14, rot=(-ang, 0, 0))
box("HammerBand", (2.5, 0.5, 1.6), head_c, M["yellow"], bevel=0.05, rot=(-ang, 0, 0))
cyl("Pin", 0.26, 0.9, pivot, M["ink"], rot=(0, math.radians(90), 0), bevel=0.03)

# the blocky tester
cx, cy = -1.7, -1.1
box("Legs", (0.95, 0.5, 0.95), (cx, cy, 0.5), M["pants"], bevel=0.05)
box("Torso", (1.15, 0.6, 1.1), (cx, cy, 1.5), M["shirt"], bevel=0.06)
for sx in (-1, 1):
    box("Arm", (0.4, 0.45, 1.0), (cx + sx * 0.82, cy, 1.5), M["skin"], bevel=0.05)
box("Head", (0.95, 0.9, 0.9), (cx, cy, 2.55), M["skin"], bevel=0.12)
for sx in (-1, 1):
    box("Eye", (0.14, 0.05, 0.22), (cx + sx * 0.23, cy - 0.47, 2.62), M["ink"], bevel=0.0)
box("Smile", (0.46, 0.05, 0.09), (cx, cy - 0.47, 2.38), M["ink"], bevel=0.0)

# clouds
for (x, y, z, s) in ((-9, 16, 8, 1.3), (8, 18, 10, 1.6), (-16, 20, 12, 1.2), (16, 14, 6, 1.0)):
    for k, (dx, dz, r) in enumerate(((0, 0, 2.0), (2.0, -0.3, 1.5), (-1.9, -0.4, 1.6), (0.8, 0.9, 1.5))):
        sphere("Cloud", r * s, (x + dx * s, y, z + dz * s), M["cloud"], scale=(1, 0.9, 0.8))

# title text (cover only)
bpy.ops.object.text_add(location=(0, 3.0, 12.4), rotation=(math.radians(90), 0, 0))
t = bpy.context.active_object
t.name = "Title"
t.data.body = "TRAP LAB"
t.data.align_x = "CENTER"
t.data.size = 2.6
t.data.extrude = 0.28
t.data.bevel_depth = 0.07
t.data.bevel_resolution = 3
t.data.materials.append(M["yellow"])
t.hide_render = True
# dark outline copy behind the title
bpy.ops.object.text_add(location=(0, 4.2, 12.36), rotation=(math.radians(90), 0, 0))
t2 = bpy.context.active_object
t2.name = "TitleOutline"
t2.data.body = "TRAP LAB"
t2.data.align_x = "CENTER"
t2.data.size = 2.6
t2.data.extrude = 0.5
t2.data.offset = 0.0
t2.data.bevel_depth = 0.22
t2.data.bevel_resolution = 3
t2.data.materials.append(M["ink"])
t2.hide_render = True

# ---- light / camera / render ----------------------------------------------------------------------------------
sun = bpy.data.lights.new("Sun", "SUN")
sun.energy = 4.2
sun.color = (1.0, 0.95, 0.86)
sun.angle = math.radians(6)
so = bpy.data.objects.new("Sun", sun)
sc.collection.objects.link(so)
so.rotation_euler = (math.radians(48), math.radians(8), math.radians(-40))
fill = bpy.data.lights.new("Fill", "AREA")
fill.energy = 450
fill.size = 14
fill.color = (0.85, 0.92, 1.0)
fo = bpy.data.objects.new("Fill", fill)
sc.collection.objects.link(fo)
fo.location = (-6, -12, 8)
fo.rotation_euler = (math.radians(65), 0, math.radians(-25))

cam = bpy.data.cameras.new("Cam")
co = bpy.data.objects.new("Cam", cam)
sc.collection.objects.link(co)
sc.camera = co
tgt = bpy.data.objects.new("Target", None)
sc.collection.objects.link(tgt)
cam.lens = 38
tr = co.constraints.new("TRACK_TO")
tr.target = tgt
tr.track_axis = "TRACK_NEGATIVE_Z"
tr.up_axis = "UP_Y"

sc.render.engine = "BLENDER_EEVEE"
sc.view_settings.view_transform = "Standard"
sc.view_settings.look = "None"
sc.render.film_transparent = False
try:
    sc.eevee.taa_render_samples = 96
    sc.eevee.use_raytracing = False
except Exception:
    pass
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGB"


def shot(name, w, h, cam_loc, target, lens, title):
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.resolution_percentage = 100
    co.location = cam_loc
    tgt.location = target
    cam.lens = lens
    t.hide_render = not title
    t2.hide_render = not title
    sc.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)


shot("icon_512.png", 512, 512, (9.0, -12.5, 6.4), (0.6, 1.2, 3.1), 42, False)
shot("cover_1920x1080.png", 1920, 1080, (5.8, -25.0, 8.2), (0.2, 2.0, 5.4), 30, True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "trap_lab_icon.blend"))
print("DONE")


