# THOCK full roster builder — every key, egg, pet from game config.
# Style: chunky glossy cute premium Roblox-readable. Uses keycap.obj for square keys.

import json
import math
import os
import shutil
from mathutils import Vector, Euler

import bpy

ROOT = r"C:\Users\zatch\dev\roblox\assets\models"
KEYCAP_OBJ = os.path.join(ROOT, "keycap.obj")
OUT = os.path.join(ROOT, "roster")
PREVIEWS = os.path.join(ROOT, "previews")
MANIFEST = os.path.join(OUT, "manifest.json")


def clear_meshes():
	keep = {"Cam", "Area", "Area.001", "Area.002"}
	for obj in list(bpy.data.objects):
		if obj.name in keep:
			continue
		if obj.type in {"MESH", "EMPTY", "CURVE", "FONT"}:
			bpy.data.objects.remove(obj, do_unlink=True)
	for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.curves):
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
	if isinstance(size, (int, float)):
		o.scale = (size, size, size)
	else:
		o.scale = size
	bpy.ops.object.transform_apply(scale=True)
	assign(o, material)
	bevel(o, 0.045, 2)
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


def import_base_keycap():
	before = set(bpy.data.objects)
	bpy.ops.wm.obj_import(filepath=KEYCAP_OBJ, forward_axis="NEGATIVE_Z", up_axis="Y")
	imported = [o for o in bpy.data.objects if o not in before]
	obj = imported[0]
	obj.scale = (2.2, 2.2, 2.2)
	bpy.ops.object.transform_apply(scale=True)
	shade(obj)
	return obj


def make_key_body(shape="Square"):
	"""Square / Wide / Enter / Shift / Tab bodies from keycap.obj or scaled copies."""
	if shape == "Square":
		return import_base_keycap()
	if shape == "Wide":
		# spacebar: stretch X
		base = import_base_keycap()
		for v in base.data.vertices:
			v.co.x *= 3.1
			v.co.y *= 0.85
		base.data.update()
		return base
	if shape == "Shift":
		base = import_base_keycap()
		for v in base.data.vertices:
			v.co.x *= 1.7
		base.data.update()
		return base
	if shape == "Tab":
		base = import_base_keycap()
		for v in base.data.vertices:
			v.co.x *= 1.45
		base.data.update()
		return base
	if shape == "Enter":
		# L-shape: main + stem
		a = import_base_keycap()
		for v in a.data.vertices:
			v.co.x *= 1.35
			v.co.y *= 0.95
		a.data.update()
		b = import_base_keycap()
		for v in b.data.vertices:
			v.co.x *= 0.7
			v.co.y *= 1.55
			v.co.x += 0.55
			v.co.y += 0.55
		b.data.update()
		return join_parts([a, b], "EnterBody")
	return import_base_keycap()


def add_legend(body, accent_color, letter_scale=(0.7, 0.28, 0.1)):
	top_z = max(v.co.z for v in body.data.vertices) + 0.03
	cx = sum(v.co.x for v in body.data.vertices) / len(body.data.vertices)
	cy = sum(v.co.y for v in body.data.vertices) / len(body.data.vertices)
	leg = cube("Legend", letter_scale, (cx, cy - 0.05, top_z), mat("LegendMat", accent_color, 0.4, 0.0, 0.2))
	return leg


def accent_clover(z, m):
	parts = []
	for dx, dy in ((-0.25, 0.15), (0.25, 0.15), (0, 0.4), (0, -0.05)):
		parts.append(sphere("leaf", 0.2, (dx, dy, z), m, 12, 8))
	parts.append(cyl("stem", 0.05, 0.35, (0.35, -0.25, z - 0.05), m, 10))
	return parts


def accent_bolt(z, m):
	parts = []
	parts.append(cube("b1", (0.25, 0.12, 0.55), (0.05, 0, z + 0.15), m))
	parts.append(cube("b2", (0.35, 0.12, 0.18), (-0.05, 0, z - 0.05), m))
	parts.append(cube("b3", (0.22, 0.12, 0.4), (-0.1, 0, z - 0.35), m))
	return parts


def accent_sun(z, m_core, m_ray):
	parts = [sphere("sun", 0.28, (0, 0, z), m_core, 14, 10)]
	for i in range(8):
		a = i * math.tau / 8
		parts.append(cube("ray", (0.1, 0.08, 0.28), (math.cos(a) * 0.45, math.sin(a) * 0.45, z), m_ray))
	return parts


def accent_cat(z, fur, pink):
	parts = []
	parts.append(cube("earL", (0.22, 0.14, 0.28), (-0.35, 0.05, z + 0.15), fur))
	parts.append(cube("earR", (0.22, 0.14, 0.28), (0.35, 0.05, z + 0.15), fur))
	parts.append(sphere("nose", 0.08, (0, 0.35, z - 0.05), pink, 10, 8))
	return parts


def accent_lava(z, m_hot, m_core):
	parts = [sphere("core", 0.22, (0, 0, z), m_core, 12, 8)]
	for i, (dx, dy, dz) in enumerate(((-0.3, 0.1, -0.1), (0.25, -0.1, 0.05), (0.1, 0.3, -0.15), (-0.1, -0.25, 0.1))):
		parts.append(sphere(f"drip{i}", 0.12, (dx, dy, z + dz), m_hot, 10, 8))
	return parts


def accent_crown(z, m):
	parts = [cyl("band", 0.45, 0.12, (0, 0, z - 0.05), m, 16)]
	for i in range(5):
		a = -0.8 + i * 0.4
		parts.append(cube("pt", (0.12, 0.12, 0.28), (a, 0, z + 0.15), m))
	return parts


def accent_gem(z, m):
	return [sphere("gem", 0.28, (0, 0, z), m, 14, 10)]


def accent_chest(z, wood, gold_m, gems):
	parts = [
		cube("box", (0.7, 0.45, 0.35), (0, 0, z), wood),
		cube("lid", (0.7, 0.45, 0.18), (0, 0, z + 0.22), wood),
		cube("lock", (0.14, 0.1, 0.12), (0, 0.28, z + 0.05), gold_m),
	]
	for i, (dx, c) in enumerate(((-0.22, gems[0]), (0.22, gems[1]), (0, gems[2]))):
		parts.append(sphere(f"g{i}", 0.1, (dx, 0.05, z + 0.38), mat(f"gem{i}", c, 0.15, 0.3), 10, 8))
	return parts


def accent_dragon(z, scale_m, horn_m, eye_m):
	parts = [
		sphere("head", 0.32, (0, 0.15, z), scale_m, 14, 10),
		cube("hornL", (0.1, 0.1, 0.35), (-0.18, 0.05, z + 0.35), horn_m),
		cube("hornR", (0.1, 0.1, 0.35), (0.18, 0.05, z + 0.35), horn_m),
		sphere("eyeL", 0.07, (-0.12, 0.38, z + 0.05), eye_m, 8, 6),
		sphere("eyeR", 0.07, (0.12, 0.38, z + 0.05), eye_m, 8, 6),
	]
	return parts


def accent_phoenix(z, flame_m, gold_m):
	parts = [sphere("core", 0.2, (0, 0, z), gold_m, 12, 8)]
	for i in range(5):
		a = -0.6 + i * 0.3
		parts.append(cube("plume", (0.12, 0.08, 0.4), (a, 0.05, z + 0.2), flame_m))
	return parts


def accent_galaxy(z, star_m, planets):
	parts = [sphere("star", 0.22, (0, 0, z), star_m, 12, 8)]
	for i, (ang, r, col) in enumerate(planets):
		parts.append(sphere(f"p{i}", r, (math.cos(ang) * 0.45, math.sin(ang) * 0.45, z), mat(f"pl{i}", col, 0.25, 0.1), 10, 8))
	return parts


def accent_aurora(z, colors):
	parts = []
	for i, c in enumerate(colors):
		parts.append(cube(f"band{i}", (0.85 - i * 0.08, 0.12, 0.1), (0, 0.05 * i, z + i * 0.12), mat(f"au{i}", c, 0.2, 0.05, 0.6)))
	return parts


def accent_eclipse(z, dark_m, gold_m):
	parts = [
		sphere("moon", 0.32, (0, 0, z), dark_m, 14, 10),
		sphere("rim", 0.18, (0.18, 0.05, z + 0.05), gold_m, 12, 8),
	]
	return parts


def accent_void(z, void_m, spark_m):
	parts = [
		sphere("hole", 0.3, (0, 0, z), void_m, 14, 10),
		sphere("spark", 0.08, (0.35, 0.2, z + 0.25), spark_m, 8, 6),
	]
	return parts


def accent_prism(z, colors):
	parts = []
	for i, c in enumerate(colors):
		a = i * math.tau / len(colors)
		parts.append(cube(f"facet{i}", (0.18, 0.18, 0.35), (math.cos(a) * 0.25, math.sin(a) * 0.25, z), mat(f"pr{i}", c, 0.12, 0.25, 0.7)))
	parts.append(sphere("core", 0.15, (0, 0, z), mat("prc", (1, 1, 1), 0.1, 0.2), 10, 8))
	return parts


def accent_glitch(z, tones):
	parts = []
	for i, (off, c) in enumerate(zip(((-0.25, 0.1, 0.1), (0.2, -0.1, 0), (0, 0.2, -0.15), (0.15, 0.15, 0.2)), tones)):
		parts.append(cube(f"g{i}", (0.35, 0.12, 0.18), (off[0], off[1], z + off[2]), mat(f"gl{i}", c, 0.3, 0.0, 0.2)))
	return parts


def accent_bump(z, m, n=6):
	parts = []
	for i in range(n):
		a = i * math.tau / n
		parts.append(sphere(f"bump{i}", 0.1, (math.cos(a) * 0.4, math.sin(a) * 0.4, z), m, 8, 6))
	return parts


def accent_ring(z, m):
	return [cyl("ring", 0.42, 0.1, (0, 0, z), m, 18)]


def accent_coffee(z, cup_m, cream_m):
	return [
		cyl("cup", 0.28, 0.2, (0, 0, z), cup_m, 14),
		sphere("cream", 0.16, (0, 0, z + 0.12), cream_m, 10, 8),
	]


def accent_pencil(z, pink_m, band_m):
	return [
		cyl("eraser", 0.3, 0.22, (0, 0, z), pink_m, 14),
		cyl("band", 0.32, 0.08, (0, 0, z - 0.12), band_m, 14),
	]


def build_key(spec):
	"""spec: id, color, accent, shape, roughness, metallic, coat, accent_fn"""
	kid = spec["id"]
	body = make_key_body(spec.get("shape", "Square"))
	body.name = kid + "_Body"
	bm = mat(kid + "_Body", spec["color"], spec.get("roughness", 0.28), spec.get("metallic", 0.0), spec.get("coat", 0.4))
	assign(body, bm)
	accent_col = spec.get("accent", tuple(max(0, c - 0.25) for c in spec["color"]))
	leg = add_legend(body, accent_col)
	parts = [body, leg]
	top_z = max(v.co.z for v in body.data.vertices) + 0.35
	fn = spec.get("hook")
	if fn:
		parts.extend(fn(top_z))
	obj = join_parts(parts, kid)
	return obj


# ---- KEY SPECS (Ids match Keys.luau) ----
def key_specs():
	g = lambda *rgb: tuple(c / 255 for c in rgb)
	specs = []

	def add(kid, color, shape="Square", roughness=0.28, metallic=0.0, coat=0.4, accent=None, hook=None):
		specs.append(
			{
				"id": kid,
				"color": color,
				"shape": shape,
				"roughness": roughness,
				"metallic": metallic,
				"coat": coat,
				"accent": accent,
				"hook": hook,
			}
		)

	# Common
	add("PlainClack", g(200, 200, 205), accent=g(120, 120, 130))
	add("BeigeBlock", g(220, 200, 160), accent=g(150, 130, 90))
	add("OfficeTap", g(170, 175, 185), accent=g(80, 85, 95))
	add("DustyKeycap", g(160, 150, 140), roughness=0.45, coat=0.15, accent=g(100, 90, 80))
	add(
		"StickyShift",
		g(210, 200, 120),
		shape="Shift",
		roughness=0.4,
		accent=g(160, 140, 60),
		hook=lambda z: accent_ring(z, mat("sticky", g(180, 160, 70), 0.5)),
	)
	add(
		"PencilPad",
		g(255, 170, 190),
		accent=g(200, 100, 130),
		hook=lambda z: accent_pencil(z, mat("erasers", g(255, 150, 180), 0.4), mat("band", g(120, 120, 130), 0.35)),
	)
	add(
		"CoffeeCap",
		g(110, 70, 45),
		accent=g(70, 40, 25),
		hook=lambda z: accent_coffee(z, mat("cup", g(90, 55, 35), 0.3), mat("cream", g(245, 230, 200), 0.35)),
	)

	# Uncommon
	add("CreamyThock", g(245, 230, 200), roughness=0.2, coat=0.55, accent=g(180, 150, 100))
	add("MintLinear", g(140, 230, 190), roughness=0.22, accent=g(60, 160, 130))
	add(
		"CloverCap",
		g(90, 200, 110),
		accent=g(40, 140, 70),
		hook=lambda z: accent_clover(z, mat("clover", g(50, 170, 80), 0.3)),
	)
	add(
		"MintTactile",
		g(100, 210, 170),
		accent=g(50, 140, 110),
		hook=lambda z: accent_bump(z, mat("bumps", g(60, 160, 130), 0.35), 6),
	)
	add("PeachPastel", g(255, 180, 150), roughness=0.25, coat=0.5, accent=g(220, 120, 100))
	add("LemonLinear", g(255, 230, 90), roughness=0.22, accent=g(200, 170, 40))
	add(
		"SkyClick",
		g(110, 190, 255),
		accent=g(50, 120, 200),
		hook=lambda z: accent_ring(z, mat("sky", g(70, 150, 230), 0.25, 0.1, 0.6)),
	)

	# Rare
	add("GlassTink", g(160, 220, 240), roughness=0.08, metallic=0.15, coat=0.85, accent=g(230, 245, 255))
	add("TopazTap", g(255, 170, 60), roughness=0.18, metallic=0.35, coat=0.6, accent=g(255, 220, 120))
	add(
		"TurboSwitch",
		g(255, 90, 70),
		accent=g(255, 220, 60),
		hook=lambda z: accent_bolt(z, mat("turbo", g(255, 220, 70), 0.2, 0.2)),
	)
	add("OceanLinear", g(50, 120, 210), roughness=0.2, coat=0.5, accent=g(140, 200, 255))
	add(
		"CoralClick",
		g(255, 110, 130),
		accent=g(255, 180, 160),
		hook=lambda z: accent_bump(z, mat("coral", g(255, 150, 140), 0.3), 5),
	)
	add("MochiPink", g(255, 170, 200), roughness=0.35, coat=0.3, accent=g(230, 120, 160))
	add(
		"ForestTactile",
		g(50, 130, 80),
		accent=g(30, 90, 50),
		hook=lambda z: accent_bump(z, mat("forest", g(70, 160, 90), 0.35), 7),
	)

	# Epic
	add(
		"CrystalChime",
		g(200, 180, 255),
		roughness=0.1,
		metallic=0.2,
		coat=0.8,
		accent=g(255, 255, 255),
		hook=lambda z: accent_gem(z, mat("xtal", g(220, 200, 255), 0.08, 0.3, 0.9)),
	)
	add(
		"AmethystPop",
		g(150, 70, 220),
		roughness=0.15,
		metallic=0.25,
		coat=0.7,
		accent=g(220, 160, 255),
		hook=lambda z: accent_gem(z, mat("amy", g(180, 100, 255), 0.1, 0.4, 0.8)),
	)
	add("GoldPlate", g(255, 200, 60), roughness=0.15, metallic=0.85, coat=0.5, accent=g(255, 240, 150))
	add(
		"NebulaClicky",
		g(60, 40, 120),
		roughness=0.25,
		coat=0.6,
		accent=g(200, 120, 255),
		hook=lambda z: accent_galaxy(
			z,
			mat("neb", g(255, 220, 120), 0.15, 0.2),
			[(0.5, 0.12, g(230, 80, 120)), (2.2, 0.1, g(80, 160, 255)), (4.0, 0.08, g(120, 255, 200))],
		),
	)
	add(
		"SakuraPop",
		g(255, 160, 190),
		coat=0.55,
		accent=g(255, 230, 240),
		hook=lambda z: accent_clover(z, mat("sakura", g(255, 140, 180), 0.25)),
	)
	add(
		"ArcadeClacker",
		g(40, 40, 50),
		accent=g(255, 60, 100),
		hook=lambda z: accent_glitch(z, [g(255, 60, 100), g(60, 220, 120), g(60, 140, 255), g(255, 220, 60)]),
	)
	add(
		"FrostbiteClick",
		g(170, 225, 255),
		roughness=0.12,
		metallic=0.2,
		coat=0.75,
		accent=g(230, 250, 255),
		hook=lambda z: accent_gem(z, mat("ice", g(140, 210, 255), 0.08, 0.25, 0.85)),
	)

	# Legendary
	add(
		"ThunderKey",
		g(70, 70, 110),
		coat=0.5,
		accent=g(255, 230, 70),
		hook=lambda z: accent_bolt(z, mat("thun", g(255, 230, 70), 0.15, 0.3, 0.7)),
	)
	add(
		"SunburstKey",
		g(255, 170, 40),
		roughness=0.18,
		metallic=0.4,
		coat=0.65,
		accent=g(255, 230, 100),
		hook=lambda z: accent_sun(z, mat("sun", g(255, 200, 50), 0.15, 0.4), mat("ray", g(255, 150, 40), 0.2)),
	)
	add(
		"FourLeafArtisan",
		g(60, 180, 90),
		roughness=0.22,
		coat=0.55,
		accent=g(255, 220, 80),
		hook=lambda z: accent_clover(z, mat("art", g(40, 160, 70), 0.25, 0.1)),
	)
	add(
		"DragonSpacebar",
		g(50, 140, 80),
		shape="Wide",
		accent=g(250, 230, 180),
		hook=lambda z: accent_dragon(
			z,
			mat("dscale", g(60, 160, 90), 0.3),
			mat("dhorn", g(250, 235, 200), 0.25),
			mat("deye", g(255, 220, 60), 0.2),
		),
	)
	add(
		"PhoenixPlume",
		g(230, 70, 40),
		accent=g(255, 200, 80),
		hook=lambda z: accent_phoenix(z, mat("flame", g(255, 120, 40), 0.25), mat("pgold", g(255, 220, 100), 0.15, 0.4)),
	)
	add(
		"FrostCrown",
		g(180, 230, 255),
		roughness=0.12,
		metallic=0.3,
		coat=0.8,
		accent=g(100, 180, 255),
		hook=lambda z: accent_crown(z, mat("crown", g(200, 235, 255), 0.12, 0.35, 0.8)),
	)
	add(
		"TreasureTab",
		g(160, 100, 50),
		shape="Tab",
		accent=g(255, 200, 60),
		hook=lambda z: accent_chest(
			z,
			mat("wood", g(150, 90, 45), 0.4),
			mat("gld", g(255, 205, 60), 0.2, 0.85),
			[g(235, 60, 80), g(70, 150, 255), g(70, 220, 130)],
		),
	)

	# Mythic
	add(
		"LavaKey",
		g(40, 30, 35),
		roughness=0.35,
		coat=0.4,
		accent=g(255, 100, 40),
		hook=lambda z: accent_lava(z, mat("lav", g(230, 50, 30), 0.3), mat("core", g(255, 200, 80), 0.15)),
	)
	add(
		"GoldenSpacebar",
		g(255, 200, 50),
		shape="Wide",
		roughness=0.12,
		metallic=0.9,
		coat=0.55,
		accent=g(255, 240, 150),
		hook=lambda z: accent_gem(z, mat("gbar", g(255, 225, 100), 0.1, 0.9)),
	)
	add(
		"GalaxyEnter",
		g(30, 20, 60),
		shape="Enter",
		coat=0.65,
		accent=g(255, 210, 90),
		hook=lambda z: accent_galaxy(
			z,
			mat("gal", g(255, 214, 90), 0.12, 0.25),
			[(0.4, 0.14, g(230, 80, 70)), (2.4, 0.16, g(70, 140, 255)), (4.3, 0.1, g(60, 220, 200))],
		),
	)
	add(
		"AuroraAlt",
		g(40, 60, 90),
		coat=0.7,
		accent=g(120, 255, 200),
		hook=lambda z: accent_aurora(z, [g(70, 240, 170), g(70, 200, 240), g(160, 110, 255), g(255, 120, 200)]),
	)
	add(
		"EclipseShift",
		g(30, 24, 48),
		shape="Shift",
		coat=0.5,
		accent=g(255, 190, 60),
		hook=lambda z: accent_eclipse(z, mat("ecl", g(30, 24, 48), 0.35), mat("egold", g(255, 190, 60), 0.15, 0.7)),
	)

	# Secret
	add(
		"MeowKey",
		g(255, 200, 230),
		coat=0.5,
		accent=g(255, 110, 150),
		hook=lambda z: accent_cat(z, mat("fur", g(255, 200, 230), 0.4), mat("pnk", g(255, 110, 150), 0.3)),
	)
	add(
		"VoidEsc",
		g(15, 10, 25),
		roughness=0.45,
		coat=0.2,
		accent=g(180, 120, 255),
		hook=lambda z: accent_void(z, mat("void", g(10, 5, 20), 0.5), mat("spark", g(200, 150, 255), 0.15, 0.2)),
	)
	add(
		"PrismReturn",
		g(240, 240, 250),
		shape="Enter",
		roughness=0.1,
		metallic=0.35,
		coat=0.85,
		accent=g(255, 100, 200),
		hook=lambda z: accent_prism(z, [g(255, 80, 120), g(80, 220, 255), g(255, 230, 80), g(160, 100, 255)]),
	)
	add(
		"GlitchTab",
		g(40, 40, 48),
		shape="Tab",
		accent=g(60, 255, 220),
		hook=lambda z: accent_glitch(z, [g(255, 60, 200), g(60, 230, 240), g(250, 250, 255), g(22, 14, 40)]),
	)

	return specs


# ---- EGGS (Ids match Eggs.luau) ----
def build_egg(spec):
	eid = spec["id"]
	color = spec["color"]
	spot = spec["spot"]
	personality = spec["style"]
	body_m = mat(eid + "_Body", color, 0.25 if personality != "Golden" else 0.15, 0.85 if personality == "Golden" else 0.0, 0.45)
	spot_m = mat(eid + "_Spot", spot, 0.3, 0.0, 0.25)

	bpy.ops.mesh.primitive_uv_sphere_add(radius=1.05, location=(0, 0, 1.2), segments=28, ring_count=18)
	egg = bpy.context.active_object
	egg.name = eid + "_Raw"
	for v in egg.data.vertices:
		v.co.z *= 1.22
		if personality == "Tactile":
			v.co.x *= 1.05
			v.co.y *= 1.05
		elif personality == "Clicky":
			v.co.z *= 1.05
	egg.data.update()
	assign(egg, body_m)
	shade(egg)
	parts = [egg]

	if personality == "Linear":
		parts.append(cyl("band1", 0.82, 0.12, (0, 0, 0.85), spot_m, 20))
		parts.append(cyl("band2", 0.7, 0.1, (0, 0, 1.55), spot_m, 20))
		for i in range(5):
			a = i * math.tau / 5 + 0.3
			parts.append(sphere(f"dot{i}", 0.14, (math.cos(a) * 0.85, math.sin(a) * 0.85, 1.2), spot_m, 10, 8))
	elif personality == "Tactile":
		for i in range(10):
			a = i * math.tau / 10
			parts.append(sphere(f"nub{i}", 0.16, (math.cos(a) * 0.95, math.sin(a) * 0.95, 1.15), spot_m, 10, 8))
		parts.append(cyl("belt", 0.9, 0.14, (0, 0, 1.05), spot_m, 20))
	elif personality == "Clicky":
		parts.append(cyl("switch", 0.28, 0.35, (0, 0, 2.35), mat("sw", (0.3, 0.55, 1.0), 0.25), 14))
		parts.append(cube("stem", (0.14, 0.14, 0.2), (0, 0, 2.1), mat("stem", (0.85, 0.9, 1.0), 0.3)))
		for i in range(6):
			a = i * math.tau / 6
			parts.append(cube(f"fin{i}", (0.12, 0.08, 0.22), (math.cos(a) * 0.9, math.sin(a) * 0.9, 1.3), spot_m))
	elif personality == "Golden":
		parts.append(cyl("belt", 0.88, 0.14, (0, 0, 1.1), mat("gbelt", (1.0, 0.85, 0.3), 0.15, 0.9), 20))
		parts.append(sphere("jewel", 0.28, (0, 0, 2.4), mat("jewel", spot, 0.12, 0.4, 0.8), 14, 10))
		parts.extend(accent_crown(2.15, mat("gcrown", (1.0, 0.82, 0.25), 0.15, 0.85)))
	elif personality == "Rainbow":
		rainbow = [
			(1.0, 0.35, 0.4),
			(1.0, 0.65, 0.25),
			(1.0, 0.9, 0.35),
			(0.4, 0.85, 0.45),
			(0.35, 0.55, 1.0),
			(0.7, 0.4, 1.0),
		]
		for i, c in enumerate(rainbow):
			parts.append(cyl(f"rb{i}", 0.9 - i * 0.02, 0.1, (0, 0, 0.7 + i * 0.28), mat(f"rb{i}", c, 0.22, 0.05, 0.6), 20))
		parts.append(sphere("cap", 0.25, (0, 0, 2.45), mat("rcap", spot, 0.2, 0.1), 12, 8))

	return join_parts(parts, eid)


def egg_specs():
	g = lambda *rgb: tuple(c / 255 for c in rgb)
	return [
		{"id": "Linear", "color": g(235, 90, 80), "spot": g(255, 220, 210), "style": "Linear"},
		{"id": "Tactile", "color": g(170, 120, 255), "spot": g(235, 220, 255), "style": "Tactile"},
		{"id": "Clicky", "color": g(70, 170, 255), "spot": g(215, 240, 255), "style": "Clicky"},
		{"id": "Golden", "color": g(255, 200, 50), "spot": g(255, 245, 190), "style": "Golden"},
		{"id": "Rainbow", "color": g(255, 110, 190), "spot": g(120, 235, 255), "style": "Rainbow"},
	]


# ---- PETS ----
EYE = (0.1, 0.1, 0.12)
INK = (0.15, 0.12, 0.16)


def pet_face(parts, y, z, eye_m, nose_m=None, spacing=0.22, eye_r=0.1):
	parts.append(sphere("eyeL", eye_r, (-spacing, y, z), eye_m, 10, 8))
	parts.append(sphere("eyeR", eye_r, (spacing, y, z), eye_m, 10, 8))
	if nose_m:
		parts.append(sphere("nose", eye_r * 0.7, (0, y + 0.12, z - 0.15), nose_m, 8, 6))


def build_pet(spec):
	pid = spec["id"]
	color = spec["color"]
	accent = spec.get("accent", tuple(min(1, c + 0.15) for c in color))
	style = spec["style"]
	body_m = mat(pid + "_B", color, 0.4, spec.get("metallic", 0.0), 0.25)
	acc_m = mat(pid + "_A", accent, 0.35, 0.0, 0.3)
	eye_m = mat(pid + "_E", EYE, 0.4)
	dark_m = mat(pid + "_D", INK, 0.4)
	parts = []

	# body + head
	scale = spec.get("scale", 1.0)
	body = sphere("body", 0.65 * scale, (0, 0, 0.65 * scale), body_m, 20, 12)
	if style in {"Shark", "Dragon"}:
		body.scale = (1.4, 0.85, 0.9)
	elif style in {"Gorilla"}:
		body.scale = (1.25, 1.0, 1.1)
	elif style in {"Ferret"}:
		body.scale = (0.85, 1.3, 0.75)
	else:
		body.scale = (1.05, 0.9, 0.9)
	bpy.ops.object.transform_apply(scale=True)
	parts.append(body)

	head_r = 0.55 * scale if style not in {"Gorilla", "Dragon", "Shark"} else 0.5 * scale
	head_y = 0.15 if style != "Shark" else 0.55
	head_z = 1.4 * scale
	head = sphere("head", head_r, (0, head_y, head_z), body_m, 20, 12)
	parts.append(head)

	# ears / features
	ez = head_z + head_r * 0.55
	if style in {"Kitty", "Fox", "Wolf", "Fawn", "Squirrel", "Lynx"}:
		parts.append(cube("earL", (0.22, 0.14, 0.32) if style != "Lynx" else (0.18, 0.12, 0.38), (-0.35, head_y, ez), body_m))
		parts.append(cube("earR", (0.22, 0.14, 0.32) if style != "Lynx" else (0.18, 0.12, 0.38), (0.35, head_y, ez), body_m))
	elif style in {"Pup", "Bunny", "Hare"}:
		tall = 0.55 if style in {"Bunny", "Hare"} else 0.35
		parts.append(cube("earL", (0.16, 0.12, tall), (-0.28, head_y + 0.05, ez + 0.1), body_m))
		parts.append(cube("earR", (0.16, 0.12, tall), (0.28, head_y + 0.05, ez + 0.1), body_m))
	elif style in {"Bear", "Panda", "Hamster", "Koala", "Raccoon", "Gorilla"}:
		parts.append(sphere("earL", 0.18, (-0.42, head_y, ez - 0.05), body_m, 12, 8))
		parts.append(sphere("earR", 0.18, (0.42, head_y, ez - 0.05), body_m, 12, 8))
	elif style in {"Chick", "Owl", "Parrot", "Goose", "Frog", "Lizard", "Gecko", "Shark", "Dragon"}:
		parts.append(cube("finL", (0.14, 0.1, 0.22), (-0.35, head_y, ez), acc_m))
		parts.append(cube("finR", (0.14, 0.1, 0.22), (0.35, head_y, ez), acc_m))

	# snout / beak
	if style in {"Chick", "Owl", "Parrot", "Goose"}:
		parts.append(cube("beak", (0.22, 0.28, 0.16), (0, head_y + head_r * 0.85, head_z - 0.05), acc_m))
	elif style != "Shark":
		parts.append(sphere("snout", 0.22, (0, head_y + head_r * 0.7, head_z - 0.1), acc_m if style in {"Pup", "Fox", "Wolf"} else body_m, 12, 8))

	pet_face(parts, head_y + head_r * 0.75, head_z + 0.05, eye_m, dark_m if style not in {"Chick", "Owl", "Parrot", "Goose"} else None)

	# mask patches
	if style in {"Panda", "Raccoon", "Gorilla", "Ferret"}:
		parts.append(sphere("maskL", 0.16, (-0.22, head_y + 0.35, head_z + 0.05), dark_m, 10, 8))
		parts.append(sphere("maskR", 0.16, (0.22, head_y + 0.35, head_z + 0.05), dark_m, 10, 8))

	# wings
	if style in {"Chick", "Owl", "Parrot", "Goose", "Dragon"}:
		parts.append(cube("wingL", (0.15, 0.45, 0.35), (-0.7, 0, 0.8 * scale), acc_m))
		parts.append(cube("wingR", (0.15, 0.45, 0.35), (0.7, 0, 0.8 * scale), acc_m))

	# horns
	if style in {"Fawn", "Dragon"}:
		parts.append(cube("hornL", (0.1, 0.1, 0.35), (-0.2, head_y, ez + 0.2), acc_m))
		parts.append(cube("hornR", (0.1, 0.1, 0.35), (0.2, head_y, ez + 0.2), acc_m))

	# tails
	if style in {"Kitty", "Fox", "Wolf", "Squirrel", "Lizard", "Gecko", "Raccoon", "Lynx", "Leopard", "Ferret", "Dragon"}:
		tx = 0.9 if style != "Squirrel" else 0.7
		parts.append(sphere("tail", 0.22 if style != "Squirrel" else 0.38, (0, -tx, 0.55 * scale), body_m, 12, 8))
	elif style == "Shark":
		parts.append(cube("tailfin", (0.12, 0.35, 0.45), (0, -1.0, 0.7), acc_m))
		parts.append(cube("dorsalfin", (0.1, 0.2, 0.4), (0, 0.1, 1.2), acc_m))

	# spots
	if style in {"Frog", "Lizard", "Gecko", "Fawn", "Leopard", "Dragon"}:
		for i, (dx, dy, dz) in enumerate(((-0.35, 0.2, 0.7), (0.3, -0.1, 0.85), (0.1, 0.3, 0.55), (-0.2, -0.25, 0.95))):
			parts.append(sphere(f"spot{i}", 0.1, (dx, dy, dz * scale), acc_m, 8, 6))

	# gimmick accents
	gimmick = spec.get("gimmick")
	if gimmick == "keycap":
		parts.append(cube("cap", (0.35, 0.35, 0.2), (0, 0, head_z + head_r + 0.15), acc_m))
	elif gimmick == "spring":
		parts.append(cyl("spring", 0.12, 0.35, (0, -0.7, 0.7), acc_m, 12))
	elif gimmick == "crown":
		parts.extend(accent_crown(head_z + head_r + 0.05, acc_m))
	elif gimmick == "laser":
		parts.append(cyl("laser", 0.08, 0.5, (0, head_y + 0.55, head_z), mat(pid + "_L", (1.0, 0.3, 0.35), 0.2, 0.1, 0.7), 10))
	elif gimmick == "clover":
		parts.extend(accent_clover(head_z + head_r + 0.1, acc_m))
	elif gimmick == "switch":
		parts.append(cyl("sw", 0.16, 0.2, (0, 0, head_z + head_r + 0.1), acc_m, 12))
	elif gimmick == "spacebar":
		parts.append(cube("bar", (0.7, 0.2, 0.12), (0, 0, head_z + head_r + 0.1), acc_m))
	elif gimmick == "bolt":
		parts.extend(accent_bolt(head_z + head_r + 0.1, acc_m))
	elif gimmick == "diamond":
		parts.append(sphere("dia", 0.22, (0, 0, head_z + head_r + 0.2), mat(pid + "_Dia", (0.7, 0.9, 1.0), 0.1, 0.4, 0.9), 12, 8))
	elif gimmick == "sticky":
		parts.append(sphere("loot", 0.16, (0.45, 0.4, 0.7), acc_m, 10, 8))
	elif gimmick == "goldcoin":
		parts.append(cyl("coin", 0.18, 0.06, (0.4, 0.35, 0.75), acc_m, 14))

	return join_parts(parts, pid)


def pet_specs():
	g = lambda *rgb: tuple(c / 255 for c in rgb)
	# id = PascalCase display name; charm_id matches Charms.luau
	return [
		{"id": "KeycapKitty", "charm_id": "KeycapPin", "style": "Kitty", "color": g(230, 190, 130), "accent": g(140, 190, 240), "gimmick": "keycap"},
		{"id": "ClickyChick", "charm_id": "CloverFob", "style": "Chick", "color": g(255, 220, 70), "accent": g(255, 150, 50), "gimmick": "switch"},
		{"id": "ThockPup", "charm_id": "TinySwitch", "style": "Pup", "color": g(180, 120, 70), "accent": g(245, 220, 190)},
		{"id": "BrassBear", "charm_id": "BrassStab", "style": "Bear", "color": g(200, 150, 70), "accent": g(255, 210, 100), "metallic": 0.55},
		{"id": "LuckyFrog", "charm_id": "LuckyLube", "style": "Frog", "color": g(90, 200, 100), "accent": g(255, 230, 80), "gimmick": "clover"},
		{"id": "SpringSquirrel", "charm_id": "QuickSpring", "style": "Squirrel", "color": g(200, 120, 60), "accent": g(180, 200, 220), "gimmick": "spring"},
		{"id": "GoldenHamster", "charm_id": "GoldenTick", "style": "Hamster", "color": g(255, 200, 70), "accent": g(255, 230, 120), "metallic": 0.45, "gimmick": "goldcoin"},
		{"id": "ThockPanda", "charm_id": "ThockPad", "style": "Panda", "color": g(245, 245, 250), "accent": g(40, 40, 45)},
		{"id": "LuckyLizard", "charm_id": "LuckyCable", "style": "Lizard", "color": g(90, 210, 120), "accent": g(255, 220, 70), "gimmick": "clover"},
		{"id": "TurboHare", "charm_id": "TurboSpring", "style": "Hare", "color": g(230, 210, 190), "accent": g(255, 90, 70), "gimmick": "bolt"},
		{"id": "GoldGecko", "charm_id": "GoldTab", "style": "Gecko", "color": g(255, 195, 60), "accent": g(255, 230, 120), "metallic": 0.5},
		{"id": "StickyRaccoon", "charm_id": "StickyFingers", "style": "Raccoon", "color": g(150, 140, 145), "accent": g(170, 120, 255), "gimmick": "sticky"},
		{"id": "LaserOwl", "charm_id": "LaserLens", "style": "Owl", "color": g(120, 100, 80), "accent": g(255, 90, 100), "gimmick": "laser"},
		{"id": "RainbowParrot", "charm_id": "RainbowCoil", "style": "Parrot", "color": g(255, 90, 120), "accent": g(80, 200, 255), "gimmick": "switch"},
		{"id": "FourLeafFawn", "charm_id": "FourLeafCap", "style": "Fawn", "color": g(200, 150, 100), "accent": g(90, 200, 100), "gimmick": "clover"},
		{"id": "SwitchFox", "charm_id": "HyperSwitch", "style": "Fox", "color": g(230, 120, 50), "accent": g(80, 180, 255), "gimmick": "switch"},
		{"id": "GoldenGorilla", "charm_id": "GoldenGear", "style": "Gorilla", "color": g(255, 190, 60), "accent": g(255, 230, 120), "metallic": 0.55, "scale": 1.15},
		{"id": "GhostFerret", "charm_id": "GhostHand", "style": "Ferret", "color": g(220, 230, 240), "accent": g(170, 120, 255)},
		{"id": "LaserLynx", "charm_id": "LaserCore", "style": "Lynx", "color": g(220, 160, 90), "accent": g(255, 80, 90), "gimmick": "laser"},
		{"id": "SpacebarBunny", "charm_id": "GoldSpacebar", "style": "Bunny", "color": g(245, 235, 240), "accent": g(255, 200, 60), "gimmick": "spacebar"},
		{"id": "CrownKoala", "charm_id": "CloverCrown", "style": "Koala", "color": g(180, 180, 185), "accent": g(255, 200, 60), "gimmick": "crown"},
		{"id": "LightningLeopard", "charm_id": "LightningSwitch", "style": "Leopard", "color": g(240, 180, 70), "accent": g(255, 230, 80), "gimmick": "bolt"},
		{"id": "GoldenGoose", "charm_id": "MidasKey", "style": "Goose", "color": g(255, 205, 70), "accent": g(255, 240, 150), "metallic": 0.6},
		{"id": "PhantomWolf", "charm_id": "PhantomPaw", "style": "Wolf", "color": g(160, 170, 190), "accent": g(200, 220, 255)},
		{"id": "MegaLaserShark", "charm_id": "MegaLaser", "style": "Shark", "color": g(90, 140, 180), "accent": g(255, 80, 100), "gimmick": "laser", "scale": 1.2},
		{"id": "DiamondDragon", "charm_id": "DiamondSpacebar", "style": "Dragon", "color": g(180, 220, 255), "accent": g(255, 220, 100), "metallic": 0.35, "gimmick": "diamond", "scale": 1.25},
	]


def export_obj(obj, folder):
	os.makedirs(folder, exist_ok=True)
	path = os.path.join(folder, obj.name + ".obj")
	bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj
	bpy.ops.wm.obj_export(
		filepath=path,
		export_selected_objects=True,
		forward_axis="NEGATIVE_Z",
		up_axis="Y",
		export_materials=False,
	)
	return path


def setup_stage():
	world = bpy.context.scene.world
	world.use_nodes = True
	bg = world.node_tree.nodes.get("Background")
	bg.inputs[0].default_value = (0.86, 0.88, 0.92, 1.0)
	bg.inputs[1].default_value = 0.9

	if "Cam" not in bpy.data.objects:
		bpy.ops.object.camera_add()
		cam = bpy.context.active_object
		cam.name = "Cam"
	else:
		cam = bpy.data.objects["Cam"]
	bpy.context.scene.camera = cam

	for name, loc, energy, size in [
		("Area", (4, 10, 12), 450, 10),
		("Area.001", (-8, 2, 8), 200, 7),
		("Area.002", (6, -6, 6), 140, 6),
	]:
		if name not in bpy.data.objects:
			bpy.ops.object.light_add(type="AREA", location=loc)
			light = bpy.context.active_object
			light.name = name
		else:
			light = bpy.data.objects[name]
		light.location = loc
		light.data.energy = energy
		light.data.size = size


def layout_grid(objects, cols, gap=3.2):
	for i, obj in enumerate(objects):
		row = i // cols
		col = i % cols
		x = (col - (cols - 1) / 2) * gap
		y = -row * gap
		obj.location = (x, y, 0)
		obj.rotation_euler = (0, 0, 0)


def frame_camera(objects, elev=9.0, dist_factor=1.35):
	cam = bpy.data.objects["Cam"]
	xs = [o.location.x for o in objects]
	ys = [o.location.y for o in objects]
	cx = (min(xs) + max(xs)) / 2
	cy = (min(ys) + max(ys)) / 2
	span = max(max(xs) - min(xs), max(ys) - min(ys), 4.0)
	cam.location = (cx, cy + span * dist_factor, elev + span * 0.15)
	cam.rotation_euler = Euler((math.radians(52), 0, math.radians(180)), "XYZ")
	cam.data.lens = 35


def render_sheet(objects, path, cols):
	os.makedirs(os.path.dirname(path), exist_ok=True)
	# hide others
	show = set(objects)
	for o in bpy.data.objects:
		if o.type == "MESH":
			o.hide_render = o not in show
			o.hide_viewport = o not in show
	layout_grid(objects, cols)
	frame_camera(objects)
	scene = bpy.context.scene
	try:
		scene.render.engine = "BLENDER_EEVEE_NEXT"
	except Exception:
		try:
			scene.render.engine = "BLENDER_EEVEE"
		except Exception:
			pass
	scene.render.resolution_x = 1920
	scene.render.resolution_y = 1080
	scene.render.filepath = path
	scene.render.image_settings.file_format = "PNG"
	try:
		scene.eevee.taa_render_samples = 32
	except Exception:
		pass
	bpy.ops.render.render(write_still=True)
	for o in objects:
		o.hide_render = False
		o.hide_viewport = False
	print("SHEET", path)


def main():
	if os.path.isdir(OUT):
		shutil.rmtree(OUT)
	os.makedirs(OUT, exist_ok=True)
	os.makedirs(PREVIEWS, exist_ok=True)
	clear_meshes()
	setup_stage()

	manifest = {"keys": [], "eggs": [], "pets": []}
	keys_dir = os.path.join(OUT, "keys")
	eggs_dir = os.path.join(OUT, "eggs")
	pets_dir = os.path.join(OUT, "pets")

	key_objs = []
	for spec in key_specs():
		obj = build_key(spec)
		export_obj(obj, keys_dir)
		manifest["keys"].append({"id": spec["id"], "file": f"keys/{spec['id']}.obj", "shape": spec.get("shape", "Square")})
		key_objs.append(obj)
		print("KEY", spec["id"])

	egg_objs = []
	for spec in egg_specs():
		obj = build_egg(spec)
		export_obj(obj, eggs_dir)
		manifest["eggs"].append({"id": spec["id"], "file": f"eggs/{spec['id']}.obj"})
		egg_objs.append(obj)
		print("EGG", spec["id"])

	pet_objs = []
	for spec in pet_specs():
		obj = build_pet(spec)
		export_obj(obj, pets_dir)
		manifest["pets"].append({"id": spec["id"], "charm_id": spec["charm_id"], "file": f"pets/{spec['id']}.obj"})
		pet_objs.append(obj)
		print("PET", spec["id"])

	with open(MANIFEST, "w", encoding="utf-8") as f:
		json.dump(manifest, f, indent=2)

	# Preview sheets
	render_sheet(key_objs[:14], os.path.join(PREVIEWS, "keys_common_uncommon.png"), 7)
	render_sheet(key_objs[14:28], os.path.join(PREVIEWS, "keys_rare_epic.png"), 7)
	render_sheet(key_objs[28:], os.path.join(PREVIEWS, "keys_legendary_mythic_secret.png"), 8)
	render_sheet(egg_objs, os.path.join(PREVIEWS, "eggs_all.png"), 5)
	render_sheet(pet_objs[:13], os.path.join(PREVIEWS, "pets_common_to_rare.png"), 7)
	render_sheet(pet_objs[13:], os.path.join(PREVIEWS, "pets_epic_to_mythic.png"), 7)

	# Final overview: sample mix staged
	overview = key_objs[0:3] + egg_objs + pet_objs[0:3] + key_objs[-3:] + pet_objs[-2:]
	render_sheet(overview, os.path.join(PREVIEWS, "roster_overview.png"), 6)

	print(
		"DONE",
		len(manifest["keys"]),
		"keys",
		len(manifest["eggs"]),
		"eggs",
		len(manifest["pets"]),
		"pets",
	)


main()
