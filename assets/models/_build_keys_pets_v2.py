# THOCK v2: all keys = single keycap.obj size. Pets get real silhouette variety.
# Eggs left as-is (already exported).

import json
import math
import os
from mathutils import Vector, Euler
import bpy

ROOT = r"C:\Users\zatch\dev\roblox\assets\models"
KEYCAP_OBJ = os.path.join(ROOT, "keycap.obj")
OUT = os.path.join(ROOT, "roster")
PREVIEWS = os.path.join(ROOT, "previews")
MANIFEST = os.path.join(OUT, "manifest.json")

EGG_IDS = {"Linear", "Tactile", "Clicky", "Golden", "Rainbow"}
KEEP = {"Cam", "Area", "Area.001", "Area.002"} | EGG_IDS


def clear_keys_pets():
	for obj in list(bpy.data.objects):
		if obj.name in KEEP or obj.type != "MESH":
			continue
		bpy.data.objects.remove(obj, do_unlink=True)
	for coll in (bpy.data.meshes, bpy.data.materials):
		for block in list(coll):
			if block.users == 0:
				coll.remove(block)


def mat(name, color, roughness=0.28, metallic=0.0, coat=0.35):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	bsdf = m.node_tree.nodes.get("Principled BSDF")
	bsdf.inputs["Base Color"].default_value = (*color, 1.0)
	bsdf.inputs["Roughness"].default_value = roughness
	bsdf.inputs["Metallic"].default_value = metallic
	try:
		bsdf.inputs["Coat Weight"].default_value = coat
		bsdf.inputs["Coat Roughness"].default_value = 0.12
	except Exception:
		pass
	return m


def assign(obj, material):
	if obj.data.materials:
		obj.data.materials[0] = material
	else:
		obj.data.materials.append(material)


def shade(obj):
	bpy.context.view_layer.objects.active = obj
	obj.select_set(True)
	try:
		bpy.ops.object.shade_smooth()
	except Exception:
		pass
	obj.select_set(False)


def bevel(obj, width=0.04, segments=2):
	mod = obj.modifiers.new("Bevel", "BEVEL")
	mod.width = width
	mod.segments = segments
	mod.limit_method = "ANGLE"
	mod.angle_limit = math.radians(28)
	bpy.context.view_layer.objects.active = obj
	try:
		bpy.ops.object.modifier_apply(modifier=mod.name)
	except Exception:
		pass


def origin_bottom(obj):
	bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj
	bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
	min_z = min(v.co.z for v in obj.data.vertices)
	for v in obj.data.vertices:
		v.co.z -= min_z
	obj.data.update()
	obj.location = (0, 0, 0)


def join_parts(parts, name):
	bpy.ops.object.select_all(action="DESELECT")
	for p in parts:
		if p is not None:
			p.select_set(True)
	bpy.context.view_layer.objects.active = parts[0]
	bpy.ops.object.join()
	obj = bpy.context.active_object
	obj.name = name
	obj.data.name = name
	origin_bottom(obj)
	return obj


def sphere(name, r, loc, material, seg=16, rings=10):
	bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=seg, ring_count=rings)
	o = bpy.context.active_object
	o.name = name
	assign(o, material)
	shade(o)
	return o


def cube(name, size, loc, material):
	bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
	o = bpy.context.active_object
	o.name = name
	o.scale = (size, size, size) if isinstance(size, (int, float)) else size
	bpy.ops.object.transform_apply(scale=True)
	assign(o, material)
	bevel(o, 0.04, 2)
	shade(o)
	return o


def cyl(name, radius, depth, loc, material, verts=20):
	bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=loc, vertices=verts)
	o = bpy.context.active_object
	o.name = name
	assign(o, material)
	bevel(o, 0.03, 2)
	shade(o)
	return o


def cone(name, radius1, depth, loc, material, verts=16):
	bpy.ops.mesh.primitive_cone_add(radius1=radius1, radius2=0.02, depth=depth, location=loc, vertices=verts)
	o = bpy.context.active_object
	o.name = name
	assign(o, material)
	shade(o)
	return o


# ---------- KEYS: always single keycap.obj ----------
def import_keycap():
	before = set(bpy.data.objects)
	bpy.ops.wm.obj_import(filepath=KEYCAP_OBJ, forward_axis="NEGATIVE_Z", up_axis="Y")
	obj = [o for o in bpy.data.objects if o not in before][0]
	obj.scale = (2.2, 2.2, 2.2)
	bpy.ops.object.transform_apply(scale=True)
	shade(obj)
	return obj


def add_legend(body, color):
	top_z = max(v.co.z for v in body.data.vertices) + 0.03
	return cube("Legend", (0.7, 0.28, 0.1), (0, -0.05, top_z), mat("Leg", color, 0.4, 0.0, 0.2))


def top_z_of(body):
	return max(v.co.z for v in body.data.vertices)


def hook_clover(z, m):
	return [sphere(f"l{i}", 0.18, (dx, dy, z), m, 12, 8) for i, (dx, dy) in enumerate(((-0.22, 0.12), (0.22, 0.12), (0, 0.35), (0, -0.08)))]


def hook_bolt(z, m):
	return [
		cube("b1", (0.22, 0.1, 0.5), (0.05, 0, z + 0.1), m),
		cube("b2", (0.32, 0.1, 0.16), (-0.05, 0, z - 0.08), m),
		cube("b3", (0.2, 0.1, 0.35), (-0.1, 0, z - 0.32), m),
	]


def hook_sun(z, core, ray):
	parts = [sphere("sun", 0.26, (0, 0, z), core, 14, 10)]
	for i in range(8):
		a = i * math.tau / 8
		parts.append(cube("ray", (0.09, 0.07, 0.26), (math.cos(a) * 0.42, math.sin(a) * 0.42, z), ray))
	return parts


def hook_cat(z, fur, pink):
	return [
		cube("earL", (0.2, 0.12, 0.26), (-0.32, 0.05, z + 0.12), fur),
		cube("earR", (0.2, 0.12, 0.26), (0.32, 0.05, z + 0.12), fur),
		sphere("nose", 0.07, (0, 0.32, z - 0.05), pink, 10, 8),
	]


def hook_lava(z, hot, core):
	parts = [sphere("core", 0.2, (0, 0, z), core, 12, 8)]
	for i, (dx, dy, dz) in enumerate(((-0.28, 0.1, -0.08), (0.24, -0.1, 0.04), (0.08, 0.28, -0.12), (-0.08, -0.22, 0.08))):
		parts.append(sphere(f"d{i}", 0.11, (dx, dy, z + dz), hot, 10, 8))
	return parts


def hook_crown(z, m):
	parts = [cyl("band", 0.42, 0.1, (0, 0, z - 0.04), m, 16)]
	for i in range(5):
		parts.append(cube("pt", (0.1, 0.1, 0.26), (-0.72 + i * 0.36, 0, z + 0.14), m))
	return parts


def hook_gem(z, m):
	return [sphere("gem", 0.26, (0, 0, z), m, 14, 10)]


def hook_chest(z, wood, gold_m, gems):
	parts = [
		cube("box", (0.65, 0.4, 0.32), (0, 0, z), wood),
		cube("lid", (0.65, 0.4, 0.16), (0, 0, z + 0.2), wood),
		cube("lock", (0.12, 0.09, 0.1), (0, 0.26, z + 0.04), gold_m),
	]
	for i, (dx, c) in enumerate(((-0.2, gems[0]), (0.2, gems[1]), (0, gems[2]))):
		parts.append(sphere(f"g{i}", 0.09, (dx, 0.04, z + 0.34), mat(f"g{i}", c, 0.15, 0.3), 10, 8))
	return parts


def hook_dragon(z, scale_m, horn_m, eye_m):
	# Compact dragon head sitting ON the keycap (not a long spacebar)
	return [
		sphere("head", 0.3, (0, 0.12, z), scale_m, 14, 10),
		cube("hornL", (0.09, 0.09, 0.32), (-0.16, 0.04, z + 0.32), horn_m),
		cube("hornR", (0.09, 0.09, 0.32), (0.16, 0.04, z + 0.32), horn_m),
		sphere("eyeL", 0.06, (-0.1, 0.35, z + 0.04), eye_m, 8, 6),
		sphere("eyeR", 0.06, (0.1, 0.35, z + 0.04), eye_m, 8, 6),
		cube("jaw", (0.28, 0.22, 0.12), (0, 0.28, z - 0.12), scale_m),
	]


def hook_phoenix(z, flame, gold_m):
	parts = [sphere("core", 0.18, (0, 0, z), gold_m, 12, 8)]
	for i in range(5):
		parts.append(cube("plume", (0.1, 0.07, 0.38), (-0.5 + i * 0.25, 0.04, z + 0.18), flame))
	return parts


def hook_galaxy(z, star, planets):
	parts = [sphere("star", 0.2, (0, 0, z), star, 12, 8)]
	for i, (ang, r, col) in enumerate(planets):
		parts.append(sphere(f"p{i}", r, (math.cos(ang) * 0.4, math.sin(ang) * 0.4, z), mat(f"pl{i}", col, 0.25, 0.1), 10, 8))
	return parts


def hook_aurora(z, colors):
	return [
		cube(f"band{i}", (0.8 - i * 0.08, 0.1, 0.09), (0, 0.04 * i, z + i * 0.11), mat(f"au{i}", c, 0.2, 0.05, 0.6))
		for i, c in enumerate(colors)
	]


def hook_eclipse(z, dark, gold_m):
	return [
		sphere("moon", 0.3, (0, 0, z), dark, 14, 10),
		sphere("rim", 0.16, (0.16, 0.04, z + 0.04), gold_m, 12, 8),
	]


def hook_void(z, void_m, spark):
	return [
		sphere("hole", 0.28, (0, 0, z), void_m, 14, 10),
		sphere("spark", 0.07, (0.32, 0.18, z + 0.22), spark, 8, 6),
	]


def hook_prism(z, colors):
	parts = []
	for i, c in enumerate(colors):
		a = i * math.tau / len(colors)
		parts.append(cube(f"f{i}", (0.16, 0.16, 0.32), (math.cos(a) * 0.22, math.sin(a) * 0.22, z), mat(f"pr{i}", c, 0.12, 0.25, 0.7)))
	parts.append(sphere("core", 0.14, (0, 0, z), mat("prc", (1, 1, 1), 0.1, 0.2), 10, 8))
	return parts


def hook_glitch(z, tones):
	return [
		cube(f"g{i}", (0.32, 0.1, 0.16), (off[0], off[1], z + off[2]), mat(f"gl{i}", c, 0.3))
		for i, (off, c) in enumerate(zip(((-0.22, 0.08, 0.08), (0.18, -0.08, 0), (0, 0.18, -0.12), (0.12, 0.12, 0.18)), tones))
	]


def hook_bump(z, m, n=6):
	return [sphere(f"b{i}", 0.09, (math.cos(i * math.tau / n) * 0.38, math.sin(i * math.tau / n) * 0.38, z), m, 8, 6) for i in range(n)]


def hook_ring(z, m):
	return [cyl("ring", 0.4, 0.09, (0, 0, z), m, 18)]


def hook_coffee(z, cup, cream):
	return [cyl("cup", 0.26, 0.18, (0, 0, z), cup, 14), sphere("cream", 0.14, (0, 0, z + 0.1), cream, 10, 8)]


def hook_pencil(z, pink, band):
	return [cyl("eraser", 0.28, 0.2, (0, 0, z), pink, 14), cyl("band", 0.3, 0.07, (0, 0, z - 0.1), band, 14)]


def hook_spacebar_mark(z, m):
	# Visual "I'm the spacebar" mark on a NORMAL sized key
	return [cube("bar", (0.85, 0.18, 0.12), (0, 0, z), m), cube("notch", (0.2, 0.12, 0.08), (0, 0.2, z + 0.08), m)]


def hook_enter_mark(z, m):
	# Bent-arrow enter glyph on a single key
	return [
		cube("h", (0.45, 0.12, 0.12), (0.05, 0.1, z), m),
		cube("v", (0.12, 0.12, 0.4), (-0.12, 0.1, z - 0.1), m),
		cube("tip", (0.22, 0.12, 0.12), (-0.22, 0.1, z - 0.28), m),
	]


def hook_shift_mark(z, m):
	return [cone("arrow", 0.28, 0.35, (0, 0, z + 0.05), m, 12), cube("stem", (0.14, 0.14, 0.22), (0, 0, z - 0.18), m)]


def hook_esc_mark(z, m):
	return [cube("badge", (0.55, 0.35, 0.12), (0, 0, z), m)]


def hook_tab_mark(z, m):
	return [
		cube("a", (0.35, 0.12, 0.12), (-0.1, 0, z), m),
		cube("b", (0.12, 0.12, 0.28), (0.15, 0, z - 0.05), m),
		cube("c", (0.2, 0.12, 0.12), (0.2, 0, z - 0.18), m),
	]


def build_key(spec):
	kid = spec["id"]
	body = import_keycap()
	body.name = kid + "_Body"
	assign(body, mat(kid + "_B", spec["color"], spec.get("roughness", 0.28), spec.get("metallic", 0.0), spec.get("coat", 0.4)))
	accent = spec.get("accent", tuple(max(0, c - 0.25) for c in spec["color"]))
	parts = [body, add_legend(body, accent)]
	z = top_z_of(body) + 0.32
	if spec.get("hook"):
		parts.extend(spec["hook"](z))
	return join_parts(parts, kid)


def key_specs():
	g = lambda *rgb: tuple(c / 255 for c in rgb)
	s = []

	def add(kid, color, **kw):
		s.append({"id": kid, "color": color, **kw})

	# Common
	add("PlainClack", g(200, 200, 205), accent=g(120, 120, 130))
	add("BeigeBlock", g(220, 200, 160), accent=g(150, 130, 90))
	add("OfficeTap", g(170, 175, 185), accent=g(80, 85, 95))
	add("DustyKeycap", g(160, 150, 140), roughness=0.45, coat=0.15, accent=g(100, 90, 80))
	add("StickyShift", g(210, 200, 120), roughness=0.4, accent=g(160, 140, 60), hook=lambda z: hook_shift_mark(z, mat("ss", g(180, 160, 70), 0.4)) + hook_ring(z - 0.15, mat("sr", g(180, 160, 70), 0.5)))
	add("PencilPad", g(255, 170, 190), accent=g(200, 100, 130), hook=lambda z: hook_pencil(z, mat("er", g(255, 150, 180), 0.4), mat("bd", g(120, 120, 130), 0.35)))
	add("CoffeeCap", g(110, 70, 45), accent=g(70, 40, 25), hook=lambda z: hook_coffee(z, mat("cup", g(90, 55, 35), 0.3), mat("cr", g(245, 230, 200), 0.35)))

	# Uncommon
	add("CreamyThock", g(245, 230, 200), roughness=0.2, coat=0.55, accent=g(180, 150, 100))
	add("MintLinear", g(140, 230, 190), roughness=0.22, accent=g(60, 160, 130))
	add("CloverCap", g(90, 200, 110), accent=g(40, 140, 70), hook=lambda z: hook_clover(z, mat("cl", g(50, 170, 80), 0.3)))
	add("MintTactile", g(100, 210, 170), accent=g(50, 140, 110), hook=lambda z: hook_bump(z, mat("mb", g(60, 160, 130), 0.35)))
	add("PeachPastel", g(255, 180, 150), roughness=0.25, coat=0.5, accent=g(220, 120, 100))
	add("LemonLinear", g(255, 230, 90), roughness=0.22, accent=g(200, 170, 40))
	add("SkyClick", g(110, 190, 255), accent=g(50, 120, 200), hook=lambda z: hook_ring(z, mat("sk", g(70, 150, 230), 0.25, 0.1, 0.6)))

	# Rare
	add("GlassTink", g(160, 220, 240), roughness=0.08, metallic=0.15, coat=0.85, accent=g(230, 245, 255))
	add("TopazTap", g(255, 170, 60), roughness=0.18, metallic=0.35, coat=0.6, accent=g(255, 220, 120))
	add("TurboSwitch", g(255, 90, 70), accent=g(255, 220, 60), hook=lambda z: hook_bolt(z, mat("tb", g(255, 220, 70), 0.2, 0.2)))
	add("OceanLinear", g(50, 120, 210), roughness=0.2, coat=0.5, accent=g(140, 200, 255))
	add("CoralClick", g(255, 110, 130), accent=g(255, 180, 160), hook=lambda z: hook_bump(z, mat("co", g(255, 150, 140), 0.3), 5))
	add("MochiPink", g(255, 170, 200), roughness=0.35, coat=0.3, accent=g(230, 120, 160))
	add("ForestTactile", g(50, 130, 80), accent=g(30, 90, 50), hook=lambda z: hook_bump(z, mat("fo", g(70, 160, 90), 0.35), 7))

	# Epic
	add("CrystalChime", g(200, 180, 255), roughness=0.1, metallic=0.2, coat=0.8, accent=g(255, 255, 255), hook=lambda z: hook_gem(z, mat("xt", g(220, 200, 255), 0.08, 0.3, 0.9)))
	add("AmethystPop", g(150, 70, 220), roughness=0.15, metallic=0.25, coat=0.7, accent=g(220, 160, 255), hook=lambda z: hook_gem(z, mat("am", g(180, 100, 255), 0.1, 0.4, 0.8)))
	add("GoldPlate", g(255, 200, 60), roughness=0.15, metallic=0.85, coat=0.5, accent=g(255, 240, 150))
	add("NebulaClicky", g(60, 40, 120), roughness=0.25, coat=0.6, accent=g(200, 120, 255), hook=lambda z: hook_galaxy(z, mat("nb", g(255, 220, 120), 0.15, 0.2), [(0.5, 0.11, g(230, 80, 120)), (2.2, 0.09, g(80, 160, 255)), (4.0, 0.08, g(120, 255, 200))]))
	add("SakuraPop", g(255, 160, 190), coat=0.55, accent=g(255, 230, 240), hook=lambda z: hook_clover(z, mat("sk", g(255, 140, 180), 0.25)))
	add("ArcadeClacker", g(40, 40, 50), accent=g(255, 60, 100), hook=lambda z: hook_glitch(z, [g(255, 60, 100), g(60, 220, 120), g(60, 140, 255), g(255, 220, 60)]))
	add("FrostbiteClick", g(170, 225, 255), roughness=0.12, metallic=0.2, coat=0.75, accent=g(230, 250, 255), hook=lambda z: hook_gem(z, mat("ice", g(140, 210, 255), 0.08, 0.25, 0.85)))

	# Legendary — still ONE keycap, cool top ornament
	add("ThunderKey", g(70, 70, 110), coat=0.5, accent=g(255, 230, 70), hook=lambda z: hook_bolt(z, mat("th", g(255, 230, 70), 0.15, 0.3, 0.7)))
	add("SunburstKey", g(255, 170, 40), roughness=0.18, metallic=0.4, coat=0.65, accent=g(255, 230, 100), hook=lambda z: hook_sun(z, mat("su", g(255, 200, 50), 0.15, 0.4), mat("ry", g(255, 150, 40), 0.2)))
	add("FourLeafArtisan", g(60, 180, 90), roughness=0.22, coat=0.55, accent=g(255, 220, 80), hook=lambda z: hook_clover(z, mat("ar", g(40, 160, 70), 0.25, 0.1)))
	add("DragonSpacebar", g(50, 140, 80), accent=g(250, 230, 180), hook=lambda z: hook_dragon(z, mat("ds", g(60, 160, 90), 0.3), mat("dh", g(250, 235, 200), 0.25), mat("de", g(255, 220, 60), 0.2)) + hook_spacebar_mark(z - 0.35, mat("dbar", g(40, 110, 70), 0.3)))
	add("PhoenixPlume", g(230, 70, 40), accent=g(255, 200, 80), hook=lambda z: hook_phoenix(z, mat("fl", g(255, 120, 40), 0.25), mat("pg", g(255, 220, 100), 0.15, 0.4)))
	add("FrostCrown", g(180, 230, 255), roughness=0.12, metallic=0.3, coat=0.8, accent=g(100, 180, 255), hook=lambda z: hook_crown(z, mat("fc", g(200, 235, 255), 0.12, 0.35, 0.8)))
	add("TreasureTab", g(160, 100, 50), accent=g(255, 200, 60), hook=lambda z: hook_chest(z, mat("wd", g(150, 90, 45), 0.4), mat("gl", g(255, 205, 60), 0.2, 0.85), [g(235, 60, 80), g(70, 150, 255), g(70, 220, 130)]) + hook_tab_mark(z - 0.4, mat("tt", g(255, 200, 60), 0.25, 0.5)))

	# Mythic
	add("LavaKey", g(40, 30, 35), roughness=0.35, coat=0.4, accent=g(255, 100, 40), hook=lambda z: hook_lava(z, mat("lv", g(230, 50, 30), 0.3), mat("lc", g(255, 200, 80), 0.15)))
	add("GoldenSpacebar", g(255, 200, 50), roughness=0.12, metallic=0.9, coat=0.55, accent=g(255, 240, 150), hook=lambda z: hook_gem(z, mat("gs", g(255, 225, 100), 0.1, 0.9)) + hook_spacebar_mark(z - 0.35, mat("gbar", g(255, 220, 80), 0.15, 0.85)))
	add("GalaxyEnter", g(30, 20, 60), coat=0.65, accent=g(255, 210, 90), hook=lambda z: hook_galaxy(z, mat("ge", g(255, 214, 90), 0.12, 0.25), [(0.4, 0.12, g(230, 80, 70)), (2.4, 0.14, g(70, 140, 255)), (4.3, 0.09, g(60, 220, 200))]) + hook_enter_mark(z - 0.4, mat("en", g(255, 210, 90), 0.2, 0.2)))
	add("AuroraAlt", g(40, 60, 90), coat=0.7, accent=g(120, 255, 200), hook=lambda z: hook_aurora(z, [g(70, 240, 170), g(70, 200, 240), g(160, 110, 255), g(255, 120, 200)]))
	add("EclipseShift", g(30, 24, 48), coat=0.5, accent=g(255, 190, 60), hook=lambda z: hook_eclipse(z, mat("ec", g(30, 24, 48), 0.35), mat("eg", g(255, 190, 60), 0.15, 0.7)) + hook_shift_mark(z - 0.4, mat("es", g(255, 190, 60), 0.2, 0.5)))

	# Secret
	add("MeowKey", g(255, 200, 230), coat=0.5, accent=g(255, 110, 150), hook=lambda z: hook_cat(z, mat("fur", g(255, 200, 230), 0.4), mat("pk", g(255, 110, 150), 0.3)))
	add("VoidEsc", g(15, 10, 25), roughness=0.45, coat=0.2, accent=g(180, 120, 255), hook=lambda z: hook_void(z, mat("vd", g(10, 5, 20), 0.5), mat("sp", g(200, 150, 255), 0.15, 0.2)) + hook_esc_mark(z - 0.4, mat("esc", g(120, 80, 180), 0.3)))
	add("PrismReturn", g(240, 240, 250), roughness=0.1, metallic=0.35, coat=0.85, accent=g(255, 100, 200), hook=lambda z: hook_prism(z, [g(255, 80, 120), g(80, 220, 255), g(255, 230, 80), g(160, 100, 255)]) + hook_enter_mark(z - 0.45, mat("pr", g(255, 100, 200), 0.15, 0.2)))
	add("GlitchTab", g(40, 40, 48), accent=g(60, 255, 220), hook=lambda z: hook_glitch(z, [g(255, 60, 200), g(60, 230, 240), g(250, 250, 255), g(22, 14, 40)]) + hook_tab_mark(z - 0.4, mat("gt", g(60, 255, 220), 0.25)))

	return s


# ---------- PETS: real silhouette variety ----------
EYE = (0.1, 0.1, 0.12)


def face(parts, y, z, eye_m, nose_m=None, spacing=0.2, r=0.09):
	parts.append(sphere("eL", r, (-spacing, y, z), eye_m, 10, 8))
	parts.append(sphere("eR", r, (spacing, y, z), eye_m, 10, 8))
	if nose_m:
		parts.append(sphere("nose", r * 0.65, (0, y + 0.1, z - 0.12), nose_m, 8, 6))


def wing_pair(parts, z, y, m, span=1.4, thick=0.16, depth=0.55, lift=0.35, flare=0.55):
	"""Big readable spread wings — must read at gameplay distance."""
	# main wing panels angled out
	for side, sign in (("L", -1), ("R", 1)):
		w = cube(f"w{side}", (span * 0.65, thick, depth), (sign * span * 0.5, y, z + lift), m)
		w.rotation_euler = (0.25, sign * flare, sign * 0.15)
		bpy.context.view_layer.objects.active = w
		bpy.ops.object.transform_apply(rotation=True)
		parts.append(w)
		# outer tip feather
		tip = cube(f"tip{side}", (span * 0.35, thick * 0.7, depth * 0.55), (sign * span * 1.05, y - 0.08, z + lift + 0.12), m)
		tip.rotation_euler = (0.15, sign * (flare + 0.25), sign * 0.25)
		bpy.context.view_layer.objects.active = tip
		bpy.ops.object.transform_apply(rotation=True)
		parts.append(tip)
		# trailing feather
		parts.append(cube(f"trail{side}", (0.2, thick * 0.6, depth * 0.4), (sign * span * 0.7, y - 0.25, z + lift - 0.15), m))



def build_pet(spec):
	pid = spec["id"]
	kind = spec["kind"]
	color = spec["color"]
	accent = spec.get("accent", tuple(min(1, c + 0.15) for c in color))
	body_m = mat(pid + "_B", color, 0.38, spec.get("metallic", 0.0), 0.25)
	acc_m = mat(pid + "_A", accent, 0.32, spec.get("accent_metal", 0.0), 0.35)
	eye_m = mat(pid + "_E", EYE, 0.4)
	dark_m = mat(pid + "_D", (0.12, 0.1, 0.14), 0.4)
	parts = []
	s = spec.get("scale", 1.0)

	if kind == "blob":
		# Cute starter: big head, compact body
		parts.append(sphere("body", 0.55 * s, (0, 0, 0.55 * s), body_m, 18, 12))
		parts.append(sphere("head", 0.62 * s, (0, 0.12, 1.35 * s), body_m, 18, 12))
		for side in (-1, 1):
			parts.append(sphere(f"ear{side}", 0.16, (side * 0.38, 0.1, 1.85 * s), body_m, 10, 8))
		face(parts, 0.55, 1.4 * s, eye_m, dark_m)
		if spec.get("gimmick") == "keycap":
			parts.append(cube("cap", (0.32, 0.32, 0.18), (0, 0, 2.05 * s), acc_m))
		elif spec.get("gimmick") == "collar":
			parts.append(cyl("col", 0.38, 0.1, (0, 0.2, 1.05 * s), acc_m, 14))
		elif spec.get("gimmick") == "coin":
			parts.append(cyl("coin", 0.16, 0.05, (0.4, 0.35, 0.85 * s), acc_m, 12))

	elif kind == "chick":
		parts.append(sphere("body", 0.6 * s, (0, 0, 0.6 * s), body_m, 18, 12))
		parts.append(sphere("head", 0.48 * s, (0, 0.15, 1.4 * s), body_m, 16, 12))
		parts.append(cube("beak", (0.18, 0.26, 0.14), (0, 0.55, 1.35 * s), acc_m))
		face(parts, 0.5, 1.5 * s, eye_m)
		parts.append(cyl("crest", 0.14, 0.18, (0, 0, 1.9 * s), acc_m, 12))
		# tiny stub wings (not flying yet)
		parts.append(cube("wL", (0.12, 0.28, 0.2), (-0.55, 0, 0.75 * s), acc_m))
		parts.append(cube("wR", (0.12, 0.28, 0.2), (0.55, 0, 0.75 * s), acc_m))

	elif kind == "quad":
		# Four-legged: longer body, distinct from ducks
		parts.append(sphere("body", 0.55 * s, (0, 0, 0.7 * s), body_m, 18, 12))
		b = parts[-1]
		b.scale = (1.35, 0.85, 0.85)
		bpy.ops.object.transform_apply(scale=True)
		parts.append(sphere("head", 0.42 * s, (0, 0.7, 1.15 * s), body_m, 16, 12))
		parts.append(sphere("snout", 0.2 * s, (0, 1.05, 1.05 * s), acc_m, 12, 8))
		face(parts, 0.95, 1.25 * s, eye_m, dark_m, 0.16, 0.08)
		ear = spec.get("ears", "round")
		for side in (-1, 1):
			if ear == "long":
				parts.append(cube(f"ear{side}", (0.12, 0.1, 0.5), (side * 0.28, 0.65, 1.55 * s), body_m))
			elif ear == "point":
				parts.append(cube(f"ear{side}", (0.14, 0.1, 0.32), (side * 0.32, 0.6, 1.5 * s), body_m))
			else:
				parts.append(sphere(f"ear{side}", 0.14, (side * 0.38, 0.55, 1.45 * s), body_m, 10, 8))
		# legs
		for dx, dy in ((-0.35, 0.35), (0.35, 0.35), (-0.35, -0.35), (0.35, -0.35)):
			parts.append(cyl(f"leg{dx}{dy}", 0.1, 0.35, (dx, dy, 0.2), body_m, 10))
		# tail
		parts.append(sphere("tail", 0.18 if ear != "bigtail" else 0.32, (0, -0.85, 0.75 * s), body_m if ear != "bigtail" else acc_m, 12, 8))
		if spec.get("mask"):
			parts.append(sphere("mL", 0.14, (-0.2, 0.85, 1.25 * s), dark_m, 10, 8))
			parts.append(sphere("mR", 0.14, (0.2, 0.85, 1.25 * s), dark_m, 10, 8))
		if spec.get("spots"):
			for i, (dx, dy, dz) in enumerate(((-0.4, 0.1, 0.85), (0.35, -0.15, 0.95), (0.1, 0.25, 0.7))):
				parts.append(sphere(f"sp{i}", 0.1, (dx, dy, dz * s), acc_m, 8, 6))
		if spec.get("gimmick") == "bolt":
			parts.extend(hook_bolt(1.7 * s, acc_m))
		elif spec.get("gimmick") == "crown":
			parts.extend(hook_crown(1.65 * s, acc_m))
		elif spec.get("gimmick") == "sticky":
			parts.append(sphere("loot", 0.15, (0.5, 0.5, 0.7), acc_m, 10, 8))
		elif spec.get("gimmick") == "spacebar":
			parts.append(cube("bar", (0.65, 0.18, 0.1), (0, 0, 1.7 * s), acc_m))
		elif spec.get("gimmick") == "spring":
			parts.append(cyl("spr", 0.1, 0.4, (0, -0.9, 0.9), acc_m, 10))
		elif spec.get("gimmick") == "coin":
			parts.append(cyl("coin", 0.16, 0.05, (0.45, 0.4, 0.8), acc_m, 12))
		elif spec.get("gimmick") == "clover":
			parts.extend(hook_clover(1.7 * s, acc_m))
		elif spec.get("gimmick") == "switch":
			parts.append(cyl("sw", 0.14, 0.18, (0, 0, 1.7 * s), acc_m, 12))
		elif spec.get("gimmick") == "laser":
			parts.append(cyl("las", 0.07, 0.55, (0, 1.15, 1.2 * s), mat(pid + "_L", (1, 0.3, 0.35), 0.2, 0.1, 0.7), 10))
		elif spec.get("gimmick") == "collar":
			parts.append(cyl("col", 0.36, 0.1, (0, 0.35, 1.0 * s), acc_m, 14))

	elif kind == "frog":
		parts.append(sphere("body", 0.7 * s, (0, 0, 0.55 * s), body_m, 18, 12))
		parts.append(sphere("head", 0.5 * s, (0, 0.35, 1.1 * s), body_m, 16, 12))
		# huge eyes on top
		parts.append(sphere("eyeL", 0.22, (-0.22, 0.45, 1.45 * s), eye_m, 12, 8))
		parts.append(sphere("eyeR", 0.22, (0.22, 0.45, 1.45 * s), eye_m, 12, 8))
		parts.append(sphere("pL", 0.1, (-0.22, 0.55, 1.55 * s), dark_m, 8, 6))
		parts.append(sphere("pR", 0.1, (0.22, 0.55, 1.55 * s), dark_m, 8, 6))
		for side in (-1, 1):
			parts.append(sphere(f"leg{side}", 0.22, (side * 0.55, 0.35, 0.35), body_m, 12, 8))
		parts.extend(hook_clover(1.75 * s, acc_m))

	elif kind == "lizard":
		parts.append(sphere("body", 0.45 * s, (0, 0, 0.55 * s), body_m, 16, 12))
		b = parts[-1]
		b.scale = (0.85, 1.5, 0.7)
		bpy.ops.object.transform_apply(scale=True)
		parts.append(sphere("head", 0.32 * s, (0, 0.85, 0.75 * s), body_m, 14, 10))
		face(parts, 1.05, 0.85 * s, eye_m, None, 0.14, 0.07)
		# long tail
		parts.append(sphere("tail1", 0.2, (0, -0.9, 0.5), body_m, 12, 8))
		parts.append(sphere("tail2", 0.14, (0, -1.35, 0.55), body_m, 10, 8))
		for i, (dx, dy) in enumerate(((-0.3, 0.2), (0.3, -0.1), (0.1, 0.35))):
			parts.append(sphere(f"sp{i}", 0.09, (dx, dy, 0.7), acc_m, 8, 6))
		if spec.get("gimmick") == "clover":
			parts.extend(hook_clover(1.15 * s, acc_m))
		elif spec.get("gimmick") == "gold":
			parts.append(cyl("coin", 0.14, 0.05, (0.35, 0.5, 0.85), acc_m, 12))

	elif kind == "flyer":
		# Bird / owl / parrot — airborne silhouette with BIG wings
		parts.append(sphere("body", 0.45 * s, (0, 0, 1.3 * s), body_m, 18, 12))
		parts.append(sphere("head", 0.38 * s, (0, 0.25, 1.95 * s), body_m, 16, 12))
		parts.append(cube("beak", (0.16, 0.3, 0.14), (0, 0.6, 1.9 * s), acc_m))
		face(parts, 0.52, 2.05 * s, eye_m, None, 0.16, 0.1 if spec.get("big_eyes") else 0.08)
		wing_pair(parts, 1.35 * s, 0, acc_m, span=spec.get("wing_span", 1.45), depth=0.6, lift=0.35, flare=0.65)
		for i in range(3):
			parts.append(cube(f"tf{i}", (0.12, 0.14, 0.45), (-0.22 + i * 0.22, -0.65, 1.05 * s), acc_m))
		parts.append(cube("ftL", (0.1, 0.1, 0.25), (-0.18, 0.1, 0.7 * s), acc_m))
		parts.append(cube("ftR", (0.1, 0.1, 0.25), (0.18, 0.1, 0.7 * s), acc_m))
		if spec.get("gimmick") == "laser":
			parts.append(cyl("las", 0.06, 0.65, (0, 0.75, 1.9 * s), mat(pid + "_L", (1, 0.3, 0.35), 0.2, 0.1, 0.7), 10))
		elif spec.get("gimmick") == "switch":
			parts.append(cyl("sw", 0.12, 0.16, (0, 0, 2.4 * s), acc_m, 12))
		elif spec.get("tuft"):
			parts.append(cube("tuftL", (0.1, 0.1, 0.28), (-0.2, 0.15, 2.35 * s), body_m))
			parts.append(cube("tuftR", (0.1, 0.1, 0.28), (0.2, 0.15, 2.35 * s), body_m))

	elif kind == "shark":
		parts.append(sphere("body", 0.55 * s, (0, 0, 0.7 * s), body_m, 18, 12))
		b = parts[-1]
		b.scale = (1.0, 1.6, 0.85)
		bpy.ops.object.transform_apply(scale=True)
		parts.append(sphere("head", 0.4 * s, (0, 0.95, 0.75 * s), body_m, 14, 10))
		face(parts, 1.2, 0.85 * s, eye_m, None, 0.18, 0.08)
		parts.append(cube("dorsal", (0.12, 0.28, 0.55), (0, 0.1, 1.4 * s), acc_m))
		parts.append(cube("tail", (0.12, 0.4, 0.55), (0, -1.15, 0.9 * s), acc_m))
		parts.append(cube("finL", (0.45, 0.12, 0.22), (-0.7, 0.2, 0.6), acc_m))
		parts.append(cube("finR", (0.45, 0.12, 0.22), (0.7, 0.2, 0.6), acc_m))
		parts.append(cyl("las", 0.07, 0.75, (0, 1.4, 0.75 * s), mat(pid + "_L", (1, 0.25, 0.3), 0.2, 0.1, 0.8), 10))

	elif kind == "phoenix":
		# BIG mythic flex — flying phoenix, unmistakable wingspan + flame tail
		parts.append(sphere("body", 0.75 * s, (0, 0, 1.6 * s), body_m, 20, 14))
		parts.append(sphere("head", 0.48 * s, (0, 0.4, 2.55 * s), body_m, 16, 12))
		parts.append(cube("beak", (0.2, 0.36, 0.18), (0, 0.8, 2.5 * s), acc_m))
		face(parts, 0.72, 2.65 * s, eye_m, None, 0.18, 0.1)
		wing_pair(parts, 1.7 * s, 0, acc_m, span=2.2, thick=0.18, depth=0.85, lift=0.45, flare=0.75)
		flame = mat(pid + "_F", spec.get("flame", (1.0, 0.45, 0.15)), 0.25, 0.05, 0.5)
		for i in range(7):
			parts.append(cube(f"plume{i}", (0.16, 0.18, 0.85 + i * 0.1), (-0.55 + i * 0.18, -1.0 - i * 0.1, 1.15 * s), flame))
		for i in range(4):
			parts.append(cone(f"crest{i}", 0.14, 0.5, (-0.28 + i * 0.18, 0.25, 3.05 * s), flame, 10))
		parts.append(sphere("jewel", 0.26, (0, 0.4, 1.7 * s), mat(pid + "_J", (0.7, 0.9, 1.0), 0.1, 0.45, 0.9), 12, 8))
		parts.append(cube("talL", (0.14, 0.14, 0.35), (-0.28, 0.15, 0.75 * s), acc_m))
		parts.append(cube("talR", (0.14, 0.14, 0.35), (0.28, 0.15, 0.75 * s), acc_m))

	elif kind == "gorilla":
		parts.append(sphere("body", 0.75 * s, (0, 0, 0.85 * s), body_m, 18, 12))
		parts.append(sphere("head", 0.55 * s, (0, 0.15, 1.75 * s), body_m, 16, 12))
		parts.append(sphere("muzzle", 0.32 * s, (0, 0.45, 1.55 * s), dark_m, 12, 8))
		face(parts, 0.5, 1.9 * s, eye_m, None, 0.18, 0.08)
		parts.append(sphere("earL", 0.16, (-0.5, 0.1, 1.85 * s), body_m, 10, 8))
		parts.append(sphere("earR", 0.16, (0.5, 0.1, 1.85 * s), body_m, 10, 8))
		# big arms
		parts.append(sphere("armL", 0.28, (-0.85, 0.2, 0.9 * s), body_m, 12, 8))
		parts.append(sphere("armR", 0.28, (0.85, 0.2, 0.9 * s), body_m, 12, 8))

	else:
		# fallback blob
		parts.append(sphere("body", 0.6, (0, 0, 0.6), body_m, 16, 12))
		parts.append(sphere("head", 0.5, (0, 0.1, 1.3), body_m, 16, 12))
		face(parts, 0.5, 1.35, eye_m, dark_m)

	return join_parts(parts, pid)


def pet_specs():
	g = lambda *rgb: tuple(c / 255 for c in rgb)
	return [
		# Common — keep cute
		{"id": "KeycapKitty", "charm_id": "KeycapPin", "kind": "blob", "color": g(230, 190, 130), "accent": g(140, 190, 240), "gimmick": "keycap"},
		{"id": "ClickyChick", "charm_id": "CloverFob", "kind": "chick", "color": g(255, 220, 70), "accent": g(255, 150, 50)},
		{"id": "ThockPup", "charm_id": "TinySwitch", "kind": "quad", "color": g(180, 120, 70), "accent": g(245, 220, 190), "ears": "long", "gimmick": "collar"},
		# Uncommon
		{"id": "BrassBear", "charm_id": "BrassStab", "kind": "quad", "color": g(200, 150, 70), "accent": g(255, 210, 100), "metallic": 0.55, "ears": "round"},
		{"id": "LuckyFrog", "charm_id": "LuckyLube", "kind": "frog", "color": g(90, 200, 100), "accent": g(255, 230, 80)},
		{"id": "SpringSquirrel", "charm_id": "QuickSpring", "kind": "quad", "color": g(200, 120, 60), "accent": g(180, 200, 220), "ears": "point", "gimmick": "spring"},
		{"id": "GoldenHamster", "charm_id": "GoldenTick", "kind": "blob", "color": g(255, 200, 70), "accent": g(255, 230, 120), "metallic": 0.45, "gimmick": "coin"},
		# Rare
		{"id": "ThockPanda", "charm_id": "ThockPad", "kind": "quad", "color": g(245, 245, 250), "accent": g(40, 40, 45), "ears": "round", "mask": True},
		{"id": "LuckyLizard", "charm_id": "LuckyCable", "kind": "lizard", "color": g(90, 210, 120), "accent": g(255, 220, 70), "gimmick": "clover"},
		{"id": "TurboHare", "charm_id": "TurboSpring", "kind": "quad", "color": g(230, 210, 190), "accent": g(255, 90, 70), "ears": "long", "gimmick": "bolt"},
		{"id": "GoldGecko", "charm_id": "GoldTab", "kind": "lizard", "color": g(255, 195, 60), "accent": g(255, 230, 120), "metallic": 0.5, "gimmick": "gold"},
		{"id": "StickyRaccoon", "charm_id": "StickyFingers", "kind": "quad", "color": g(150, 140, 145), "accent": g(170, 120, 255), "ears": "round", "mask": True, "gimmick": "sticky"},
		{"id": "LaserOwl", "charm_id": "LaserLens", "kind": "flyer", "color": g(120, 100, 80), "accent": g(255, 90, 100), "big_eyes": True, "tuft": True, "gimmick": "laser", "wing_span": 1.55},
		# Epic — more flying / distinct
		{"id": "RainbowParrot", "charm_id": "RainbowCoil", "kind": "flyer", "color": g(255, 90, 120), "accent": g(80, 200, 255), "gimmick": "switch", "wing_span": 1.7},
		{"id": "FourLeafFawn", "charm_id": "FourLeafCap", "kind": "quad", "color": g(200, 150, 100), "accent": g(90, 200, 100), "ears": "point", "spots": True, "gimmick": "clover"},
		{"id": "SwitchFox", "charm_id": "HyperSwitch", "kind": "quad", "color": g(230, 120, 50), "accent": g(80, 180, 255), "ears": "point", "gimmick": "switch"},
		{"id": "GoldenGorilla", "charm_id": "GoldenGear", "kind": "gorilla", "color": g(255, 190, 60), "accent": g(255, 230, 120), "metallic": 0.55, "scale": 1.1},
		{"id": "GhostFerret", "charm_id": "GhostHand", "kind": "lizard", "color": g(220, 230, 240), "accent": g(170, 120, 255)},  # long weasel body via lizard
		{"id": "LaserLynx", "charm_id": "LaserCore", "kind": "quad", "color": g(220, 160, 90), "accent": g(255, 80, 90), "ears": "point", "gimmick": "laser"},
		# Legendary — flyers + flex
		{"id": "SpacebarBunny", "charm_id": "GoldSpacebar", "kind": "quad", "color": g(245, 235, 240), "accent": g(255, 200, 60), "ears": "long", "gimmick": "spacebar", "scale": 1.05},
		{"id": "CrownKoala", "charm_id": "CloverCrown", "kind": "quad", "color": g(180, 180, 185), "accent": g(255, 200, 60), "ears": "round", "gimmick": "crown"},
		{"id": "LightningLeopard", "charm_id": "LightningSwitch", "kind": "quad", "color": g(240, 180, 70), "accent": g(255, 230, 80), "ears": "round", "spots": True, "gimmick": "bolt", "scale": 1.1},
		{"id": "GoldenGoose", "charm_id": "MidasKey", "kind": "flyer", "color": g(255, 205, 70), "accent": g(255, 240, 150), "metallic": 0.55, "wing_span": 1.75, "scale": 1.15},
		{"id": "PhantomWolf", "charm_id": "PhantomPaw", "kind": "quad", "color": g(160, 170, 190), "accent": g(200, 220, 255), "ears": "point", "scale": 1.1},
		{"id": "MegaLaserShark", "charm_id": "MegaLaser", "kind": "shark", "color": g(90, 140, 180), "accent": g(255, 80, 100), "scale": 1.25},
		# Mythic — big phoenix flex
		{
			"id": "DiamondDragon",
			"charm_id": "DiamondSpacebar",
			"kind": "phoenix",
			"color": g(255, 140, 60),
			"accent": g(255, 220, 100),
			"flame": g(255, 70, 30),
			"metallic": 0.2,
			"scale": 1.5,
		},
	]


def export_obj(obj, folder):
	os.makedirs(folder, exist_ok=True)
	path = os.path.join(folder, obj.name + ".obj")
	bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj
	bpy.ops.wm.obj_export(filepath=path, export_selected_objects=True, forward_axis="NEGATIVE_Z", up_axis="Y", export_materials=False)
	return path


def setup_stage():
	world = bpy.context.scene.world
	world.use_nodes = True
	bg = world.node_tree.nodes.get("Background")
	bg.inputs[0].default_value = (0.86, 0.88, 0.92, 1.0)
	bg.inputs[1].default_value = 0.9
	if "Cam" not in bpy.data.objects:
		bpy.ops.object.camera_add()
		bpy.data.objects["Cam"].name = "Cam"
	bpy.context.scene.camera = bpy.data.objects["Cam"]
	for name, loc, energy, size in [("Area", (4, 10, 12), 450, 10), ("Area.001", (-8, 2, 8), 200, 7), ("Area.002", (6, -6, 6), 140, 6)]:
		if name not in bpy.data.objects:
			bpy.ops.object.light_add(type="AREA", location=loc)
			bpy.context.active_object.name = name
		light = bpy.data.objects[name]
		light.location = loc
		light.data.energy = energy
		light.data.size = size


def layout_grid(objects, cols, gap=3.4):
	for i, obj in enumerate(objects):
		row, col = divmod(i, cols)
		obj.location = ((col - (cols - 1) / 2) * gap, -row * (gap + 0.5), 0)
		obj.rotation_euler = (0, 0, 0)


def world_bounds(objects):
	mins = Vector((1e9, 1e9, 1e9))
	maxs = Vector((-1e9, -1e9, -1e9))
	for obj in objects:
		for corner in obj.bound_box:
			w = obj.matrix_world @ Vector(corner)
			mins = Vector((min(mins.x, w.x), min(mins.y, w.y), min(mins.z, w.z)))
			maxs = Vector((max(maxs.x, w.x), max(maxs.y, w.y), max(maxs.z, w.z)))
	return mins, maxs


def render_sheet(objects, path, cols, gap=3.4):
	show = set(objects)
	for o in bpy.data.objects:
		if o.type == "MESH":
			o.hide_render = o.hide_viewport = o not in show
	layout_grid(objects, cols, gap)
	bpy.context.view_layer.update()
	mins, maxs = world_bounds(objects)
	center = (mins + maxs) * 0.5
	size = max(maxs.x - mins.x, maxs.y - mins.y, maxs.z - mins.z, 2.0)
	cam = bpy.data.objects["Cam"]
	cam.location = (center.x, center.y + size * 1.55, center.z + size * 0.9)
	cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
	cam.data.lens = 32
	scene = bpy.context.scene
	try:
		scene.render.engine = "BLENDER_EEVEE_NEXT"
	except Exception:
		scene.render.engine = "BLENDER_EEVEE"
	scene.render.resolution_x = 1920
	scene.render.resolution_y = 1080
	scene.render.filepath = path
	scene.render.image_settings.file_format = "PNG"
	try:
		scene.eevee.taa_render_samples = 48
	except Exception:
		pass
	bpy.ops.render.render(write_still=True)
	for o in objects:
		o.hide_render = o.hide_viewport = False
	print("SHEET", path, len(objects))


def main():
	clear_keys_pets()
	setup_stage()
	keys_dir = os.path.join(OUT, "keys")
	pets_dir = os.path.join(OUT, "pets")

	key_objs = []
	for spec in key_specs():
		obj = build_key(spec)
		export_obj(obj, keys_dir)
		key_objs.append(obj)
		print("KEY", spec["id"])

	pet_objs = []
	pet_meta = []
	for spec in pet_specs():
		obj = build_pet(spec)
		export_obj(obj, pets_dir)
		pet_objs.append(obj)
		pet_meta.append({"id": spec["id"], "charm_id": spec["charm_id"], "file": f"pets/{spec['id']}.obj", "kind": spec["kind"]})
		print("PET", spec["id"], spec["kind"])

	# update manifest keys/pets, keep eggs
	manifest = {"keys": [], "eggs": [], "pets": pet_meta}
	if os.path.isfile(MANIFEST):
		old = json.load(open(MANIFEST, encoding="utf-8"))
		manifest["eggs"] = old.get("eggs", [])
	for o in key_objs:
		manifest["keys"].append({"id": o.name, "file": f"keys/{o.name}.obj", "shape": "Square"})
	json.dump(manifest, open(MANIFEST, "w", encoding="utf-8"), indent=2)

	render_sheet(key_objs[:14], os.path.join(PREVIEWS, "keys_common_uncommon.png"), 7)
	render_sheet(key_objs[14:28], os.path.join(PREVIEWS, "keys_rare_epic.png"), 7)
	render_sheet(key_objs[28:], os.path.join(PREVIEWS, "keys_legendary_mythic_secret.png"), 8, gap=3.6)
	render_sheet(pet_objs[:13], os.path.join(PREVIEWS, "pets_common_to_rare.png"), 7, gap=3.6)
	render_sheet(pet_objs[13:], os.path.join(PREVIEWS, "pets_epic_to_mythic.png"), 7, gap=3.8)
	# flyer spotlight + phoenix
	flyers = [o for o, s in zip(pet_objs, pet_specs()) if s["kind"] in {"flyer", "phoenix", "shark"}]
	render_sheet(flyers, os.path.join(PREVIEWS, "pets_flying_flex.png"), min(4, len(flyers)), gap=4.2)
	overview = key_objs[:3] + key_objs[28:31] + key_objs[-3:] + pet_objs[:3] + flyers
	render_sheet(overview, os.path.join(PREVIEWS, "roster_overview.png"), 5, gap=3.8)
	print("DONE", len(key_objs), "keys", len(pet_objs), "pets")


main()
