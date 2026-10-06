# Build a small THOCK showcase batch: 3 keys, 3 eggs, 3 pets.
# Roblox-first: chunky, glossy, cute, readable. No neon / no overdetail.

import math
import os
from mathutils import Vector, Euler

import bpy

KEYCAP_OBJ = r"C:\Users\zatch\dev\roblox\assets\models\keycap.obj"
OUT_DIR = r"C:\Users\zatch\dev\roblox\assets\models\batch"
PREVIEW = r"C:\Users\zatch\dev\roblox\assets\models\previews\thock_batch.png"


def clear_meshes():
	bpy.ops.object.select_all(action="DESELECT")
	for obj in list(bpy.data.objects):
		if obj.type in {"MESH", "EMPTY", "CURVE", "FONT"}:
			bpy.data.objects.remove(obj, do_unlink=True)
	for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
		for b in list(block):
			if b.users == 0:
				block.remove(b)


def mat(name, color, roughness=0.28, metallic=0.0, alpha=1.0, emission=None):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	nt = m.node_tree
	bsdf = nt.nodes.get("Principled BSDF")
	bsdf.inputs["Base Color"].default_value = (*color, 1.0)
	bsdf.inputs["Roughness"].default_value = roughness
	bsdf.inputs["Metallic"].default_value = metallic
	if alpha < 1.0:
		bsdf.inputs["Alpha"].default_value = alpha
		m.blend_method = "BLEND"
		try:
			bsdf.inputs["Transmission Weight"].default_value = 0.85
		except Exception:
			pass
	if emission is not None:
		try:
			bsdf.inputs["Emission Color"].default_value = (*emission[0], 1.0)
			bsdf.inputs["Emission Strength"].default_value = emission[1]
		except Exception:
			pass
	return m


def assign(obj, material):
	if obj.data.materials:
		obj.data.materials[0] = material
	else:
		obj.data.materials.append(material)


def bevel(obj, width=0.04, segments=2):
	mod = obj.modifiers.new("Bevel", "BEVEL")
	mod.width = width
	mod.segments = segments
	mod.limit_method = "ANGLE"
	mod.angle_limit = math.radians(30)
	bpy.context.view_layer.objects.active = obj
	bpy.ops.object.modifier_apply(modifier=mod.name)


def smooth(obj):
	for poly in obj.data.polygons:
		poly.use_smooth = True
	mod = obj.modifiers.new("Smooth", "SUBSURF")
	mod.levels = 1
	mod.render_levels = 1


def shade_auto(obj):
	bpy.context.view_layer.objects.active = obj
	obj.select_set(True)
	try:
		bpy.ops.object.shade_smooth()
		mesh = obj.data
		if hasattr(mesh, "use_auto_smooth"):
			mesh.use_auto_smooth = True
			mesh.auto_smooth_angle = math.radians(50)
	except Exception:
		pass
	obj.select_set(False)


def move(obj, x, y, z):
	obj.location = (x, y, z)


def join_selected(name):
	bpy.ops.object.join()
	obj = bpy.context.view_layer.objects.active
	obj.name = name
	obj.data.name = name
	return obj


def uv_sphere(name, radius, loc, material, segments=24, rings=16):
	bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=loc, segments=segments, ring_count=rings)
	obj = bpy.context.active_object
	obj.name = name
	assign(obj, material)
	shade_auto(obj)
	return obj


def cube(name, size, loc, material, scale=None):
	bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
	obj = bpy.context.active_object
	obj.name = name
	if isinstance(size, (int, float)):
		obj.scale = (size, size, size)
	else:
		obj.scale = size
	if scale:
		obj.scale = Vector(obj.scale) * Vector(scale)
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	assign(obj, material)
	bevel(obj, 0.05, 2)
	shade_auto(obj)
	return obj


def cylinder(name, radius, depth, loc, material, vertices=24):
	bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=loc, vertices=vertices)
	obj = bpy.context.active_object
	obj.name = name
	assign(obj, material)
	bevel(obj, 0.03, 2)
	shade_auto(obj)
	return obj


def import_keycap(name, color, roughness=0.25, metallic=0.0, alpha=1.0, accent=None, coat=0.4):
	before = set(bpy.data.objects)
	bpy.ops.wm.obj_import(filepath=KEYCAP_OBJ, forward_axis="NEGATIVE_Z", up_axis="Y")
	imported = [o for o in bpy.data.objects if o not in before]
	obj = imported[0]
	obj.name = name
	obj.scale = (2.4, 2.4, 2.4)
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	m = mat(name + "_Mat", color, roughness=roughness, metallic=metallic, alpha=alpha)
	try:
		bsdf = m.node_tree.nodes.get("Principled BSDF")
		bsdf.inputs["Coat Weight"].default_value = coat
		bsdf.inputs["Coat Roughness"].default_value = 0.15
	except Exception:
		pass
	assign(obj, m)
	shade_auto(obj)

	top_z = max(v.co.z for v in obj.data.vertices) + 0.03
	bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.05, top_z))
	legend = bpy.context.active_object
	legend.name = name + "_Legend"
	legend.scale = (0.7, 0.28, 0.1)
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	leg_col = accent if accent else tuple(min(1.0, c * 0.55) for c in color)
	lm = mat(name + "_LegendMat", leg_col, roughness=0.4)
	assign(legend, lm)
	bevel(legend, 0.04, 2)
	shade_auto(legend)

	bpy.ops.object.select_all(action="DESELECT")
	legend.select_set(True)
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj
	bpy.ops.object.join()
	obj = bpy.context.active_object
	obj.name = name
	# Origin at bottom
	bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
	min_z = min(v.co.z for v in obj.data.vertices)
	for v in obj.data.vertices:
		v.co.z -= min_z
	obj.data.update()
	obj.location = (0, 0, 0)
	return obj


def make_egg(name, body_color, accent_color, personality="linear"):
	# personality changes silhouette
	if personality == "linear":
		# Smooth classic egg
		bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, location=(0, 0, 1.15), segments=28, ring_count=18)
		egg = bpy.context.active_object
		egg.name = name
		# Stretch into egg
		for v in egg.data.vertices:
			v.co.z *= 1.25
			v.co.x *= 0.92
			v.co.y *= 0.92
		egg.data.update()
		assign(egg, mat(name + "_Mat", body_color, roughness=0.22))
		# Thin clean band
		band = cylinder(name + "_Band", 0.78, 0.16, (0, 0, 1.05), mat(name + "_BandMat", accent_color, roughness=0.3))
	elif personality == "tactile":
		# Chunky / bouncy
		bpy.ops.mesh.primitive_uv_sphere_add(radius=1.1, location=(0, 0, 1.2), segments=24, ring_count=16)
		egg = bpy.context.active_object
		egg.name = name
		for v in egg.data.vertices:
			v.co.z *= 1.15
		egg.data.update()
		assign(egg, mat(name + "_Mat", body_color, roughness=0.35))
		# Bumpy ring of nubs
		band = None
		for i in range(8):
			a = i * math.tau / 8
			nub = uv_sphere(
				f"{name}_Nub{i}",
				0.18,
				(math.cos(a) * 0.95, math.sin(a) * 0.95, 1.15),
				mat(name + f"_NubMat{i}", accent_color, roughness=0.4),
				segments=12,
				rings=8,
			)
			if band is None:
				band = nub
			else:
				bpy.ops.object.select_all(action="DESELECT")
				nub.select_set(True)
				band.select_set(True)
				bpy.context.view_layer.objects.active = band
				bpy.ops.object.join()
				band = bpy.context.active_object
	else:  # golden / premium
		bpy.ops.mesh.primitive_uv_sphere_add(radius=1.05, location=(0, 0, 1.2), segments=28, ring_count=18)
		egg = bpy.context.active_object
		egg.name = name
		for v in egg.data.vertices:
			v.co.z *= 1.22
		egg.data.update()
		assign(egg, mat(name + "_Mat", body_color, roughness=0.18, metallic=0.85))
		# Crown tip jewel
		band = uv_sphere(name + "_Jewel", 0.28, (0, 0, 2.35), mat(name + "_JewelMat", accent_color, roughness=0.15, metallic=0.4), segments=16, rings=10)
		# Gold belt
		belt = cylinder(name + "_Belt", 0.86, 0.14, (0, 0, 1.1), mat(name + "_BeltMat", (1.0, 0.82, 0.25), roughness=0.2, metallic=0.9))
		bpy.ops.object.select_all(action="DESELECT")
		belt.select_set(True)
		band.select_set(True)
		bpy.context.view_layer.objects.active = band
		bpy.ops.object.join()
		band = bpy.context.active_object

	shade_auto(egg)
	bpy.ops.object.select_all(action="DESELECT")
	if band:
		band.select_set(True)
	egg.select_set(True)
	bpy.context.view_layer.objects.active = egg
	bpy.ops.object.join()
	egg = bpy.context.active_object
	egg.name = name
	# Origin at bottom
	bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
	min_z = min(v.co.z for v in egg.data.vertices)
	for v in egg.data.vertices:
		v.co.z -= min_z
	egg.data.update()
	egg.location = (0, 0, 0)
	return egg


def make_kitty(name):
	# Keycap Kitty — big head, compact body, keycap ears vibe
	fur = mat(name + "_Fur", (0.92, 0.78, 0.55), roughness=0.45)
	pink = mat(name + "_Pink", (1.0, 0.62, 0.72), roughness=0.35)
	dark = mat(name + "_Dark", (0.15, 0.12, 0.12), roughness=0.4)
	key = mat(name + "_Key", (0.55, 0.75, 0.95), roughness=0.25)

	body = uv_sphere("body", 0.55, (0, 0, 0.55), fur, 20, 12)
	body.scale = (1.0, 0.85, 0.9)
	bpy.ops.object.transform_apply(scale=True)

	head = uv_sphere("head", 0.72, (0, 0.1, 1.35), fur, 24, 14)
	# ears
	ear_l = cube("earL", 0.35, (-0.38, 0.05, 1.95), fur)
	ear_l.rotation_euler = (0.2, 0.35, 0.2)
	ear_r = cube("earR", 0.35, (0.38, 0.05, 1.95), fur)
	ear_r.rotation_euler = (0.2, -0.35, -0.2)
	for e in (ear_l, ear_r):
		bpy.context.view_layer.objects.active = e
		bpy.ops.object.transform_apply(rotation=True)

	# inner ear
	ie_l = cube("ieL", 0.18, (-0.38, 0.12, 1.92), pink)
	ie_r = cube("ieR", 0.18, (0.38, 0.12, 1.92), pink)

	# face
	eye_l = uv_sphere("eyeL", 0.11, (-0.22, 0.62, 1.4), dark, 12, 8)
	eye_r = uv_sphere("eyeR", 0.11, (0.22, 0.62, 1.4), dark, 12, 8)
	nose = uv_sphere("nose", 0.08, (0, 0.72, 1.25), pink, 10, 8)

	# tiny keycap on head (gimmick)
	cap = cube("cap", 0.35, (0, 0, 2.15), key)
	cap.scale = (1.0, 1.0, 0.55)
	bpy.ops.object.transform_apply(scale=True)

	parts = [body, head, ear_l, ear_r, ie_l, ie_r, eye_l, eye_r, nose, cap]
	bpy.ops.object.select_all(action="DESELECT")
	for p in parts:
		p.select_set(True)
	bpy.context.view_layer.objects.active = head
	bpy.ops.object.join()
	pet = bpy.context.active_object
	pet.name = name
	bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
	min_z = min(v.co.z for v in pet.data.vertices)
	for v in pet.data.vertices:
		v.co.z -= min_z
	pet.data.update()
	pet.location = (0, 0, 0)
	return pet


def make_chick(name):
	# Clicky Chick — round body, big head, clicky keycap beak
	yellow = mat(name + "_Y", (1.0, 0.86, 0.28), roughness=0.35)
	orange = mat(name + "_O", (1.0, 0.45, 0.12), roughness=0.3)
	dark = mat(name + "_D", (0.12, 0.1, 0.1), roughness=0.4)
	blue = mat(name + "_B", (0.35, 0.65, 1.0), roughness=0.25)

	body = uv_sphere("body", 0.65, (0, 0, 0.65), yellow, 22, 14)
	head = uv_sphere("head", 0.55, (0, 0.15, 1.45), yellow, 22, 14)
	# beak as tiny keycap wedge
	beak = cube("beak", 0.28, (0, 0.65, 1.4), orange)
	beak.scale = (0.7, 1.1, 0.55)
	bpy.ops.object.transform_apply(scale=True)
	eye_l = uv_sphere("eyeL", 0.1, (-0.2, 0.55, 1.55), dark, 10, 8)
	eye_r = uv_sphere("eyeR", 0.1, (0.2, 0.55, 1.55), dark, 10, 8)
	# crest = clicky switch top
	crest = cylinder("crest", 0.18, 0.22, (0, 0, 2.0), blue, 16)
	# feet nubs
	foot_l = cube("footL", 0.22, (-0.25, 0.25, 0.1), orange)
	foot_r = cube("footR", 0.22, (0.25, 0.25, 0.1), orange)

	parts = [body, head, beak, eye_l, eye_r, crest, foot_l, foot_r]
	bpy.ops.object.select_all(action="DESELECT")
	for p in parts:
		p.select_set(True)
	bpy.context.view_layer.objects.active = body
	bpy.ops.object.join()
	pet = bpy.context.active_object
	pet.name = name
	bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
	min_z = min(v.co.z for v in pet.data.vertices)
	for v in pet.data.vertices:
		v.co.z -= min_z
	pet.data.update()
	pet.location = (0, 0, 0)
	return pet


def make_pup(name):
	# Thock Pup — loyal chunky dog, soft ears, keycap collar
	brown = mat(name + "_Br", (0.72, 0.48, 0.28), roughness=0.4)
	cream = mat(name + "_Cr", (0.95, 0.88, 0.75), roughness=0.4)
	dark = mat(name + "_D", (0.12, 0.1, 0.1), roughness=0.4)
	collar = mat(name + "_C", (0.85, 0.35, 0.45), roughness=0.3)

	body = uv_sphere("body", 0.7, (0, 0, 0.7), brown, 22, 14)
	body.scale = (1.15, 0.9, 0.85)
	bpy.ops.object.transform_apply(scale=True)
	head = uv_sphere("head", 0.58, (0, 0.55, 1.35), brown, 22, 14)
	snout = uv_sphere("snout", 0.28, (0, 0.95, 1.2), cream, 14, 10)
	ear_l = cube("earL", 0.28, (-0.4, 0.4, 1.7), brown)
	ear_l.scale = (0.7, 0.35, 1.1)
	ear_r = cube("earR", 0.28, (0.4, 0.4, 1.7), brown)
	ear_r.scale = (0.7, 0.35, 1.1)
	for e in (ear_l, ear_r):
		bpy.context.view_layer.objects.active = e
		bpy.ops.object.transform_apply(scale=True)
	eye_l = uv_sphere("eyeL", 0.09, (-0.18, 0.95, 1.45), dark, 10, 8)
	eye_r = uv_sphere("eyeR", 0.09, (0.18, 0.95, 1.45), dark, 10, 8)
	nose = uv_sphere("nose", 0.08, (0, 1.18, 1.25), dark, 10, 8)
	band = cylinder("collar", 0.42, 0.12, (0, 0.35, 1.0), collar, 20)
	# tiny thock tag
	tag = cube("tag", 0.16, (0, 0.7, 0.95), mat(name + "_Tag", (0.95, 0.85, 0.25), roughness=0.25, metallic=0.6))

	parts = [body, head, snout, ear_l, ear_r, eye_l, eye_r, nose, band, tag]
	bpy.ops.object.select_all(action="DESELECT")
	for p in parts:
		p.select_set(True)
	bpy.context.view_layer.objects.active = body
	bpy.ops.object.join()
	pet = bpy.context.active_object
	pet.name = name
	bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
	min_z = min(v.co.z for v in pet.data.vertices)
	for v in pet.data.vertices:
		v.co.z -= min_z
	pet.data.update()
	pet.location = (0, 0, 0)
	return pet


def setup_world():
	world = bpy.context.scene.world
	world.use_nodes = True
	bg = world.node_tree.nodes.get("Background")
	bg.inputs[0].default_value = (0.88, 0.90, 0.94, 1.0)
	bg.inputs[1].default_value = 0.85

	if "Cam" not in bpy.data.objects:
		bpy.ops.object.camera_add()
		cam = bpy.context.active_object
		cam.name = "Cam"
	else:
		cam = bpy.data.objects["Cam"]
	# Look from front (+Y) so pet faces read
	cam.location = (0.0, 14.5, 9.5)
	cam.rotation_euler = Euler((math.radians(52), 0, math.radians(180)), "XYZ")
	cam.data.lens = 40
	bpy.context.scene.camera = cam

	for name, loc, energy, size in [
		("Area", (4, 10, 12), 400, 10),
		("Area.001", (-8, 2, 8), 180, 7),
		("Area.002", (6, -6, 6), 120, 6),
	]:
		if name in bpy.data.objects:
			light = bpy.data.objects[name]
		else:
			bpy.ops.object.light_add(type="AREA", location=loc)
			light = bpy.context.active_object
			light.name = name
		light.location = loc
		light.data.energy = energy
		light.data.size = size


def arrange_and_export(objects_by_row):
	os.makedirs(OUT_DIR, exist_ok=True)
	gap = 3.4
	# Front row = keys (closest to camera at +Y), then eggs, then pets at back
	# Camera looks from +Y toward origin, so higher Y = closer
	y = 3.4
	for row in objects_by_row:
		x = -((len(row) - 1) * gap) / 2
		for obj in row:
			obj.location = (x, y, 0)
			# Face camera (+Y)
			obj.rotation_euler = (0, 0, 0)
			bpy.ops.object.select_all(action="DESELECT")
			obj.select_set(True)
			bpy.context.view_layer.objects.active = obj
			path = os.path.join(OUT_DIR, obj.name + ".obj")
			bpy.ops.wm.obj_export(
				filepath=path,
				export_selected_objects=True,
				forward_axis="NEGATIVE_Z",
				up_axis="Y",
				export_materials=False,
			)
			x += gap
		y -= 3.6


def render_preview():
	os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
	scene = bpy.context.scene
	try:
		scene.render.engine = "BLENDER_EEVEE_NEXT"
	except Exception:
		try:
			scene.render.engine = "BLENDER_EEVEE"
		except Exception:
			pass
	scene.render.resolution_x = 1800
	scene.render.resolution_y = 1200
	scene.render.filepath = PREVIEW
	scene.render.image_settings.file_format = "PNG"
	try:
		scene.eevee.taa_render_samples = 64
	except Exception:
		pass
	# Frame all meshes
	bpy.ops.object.select_all(action="DESELECT")
	for o in bpy.data.objects:
		if o.type == "MESH":
			o.select_set(True)
	bpy.ops.view3d.camera_to_view_selected() if False else None
	bpy.ops.render.render(write_still=True)
	print("PREVIEW", PREVIEW)


def main():
	clear_meshes()
	setup_world()

	plain = import_keycap("PlainClack", (0.78, 0.80, 0.84), roughness=0.28, accent=(0.35, 0.38, 0.42), coat=0.35)
	creamy = import_keycap("CreamyThock", (0.97, 0.92, 0.80), roughness=0.2, accent=(0.72, 0.55, 0.35), coat=0.5)
	# Readable "glass" — glossy cyan plastic, not invisible alpha soup
	glass = import_keycap("GlassTink", (0.55, 0.88, 0.95), roughness=0.08, metallic=0.2, alpha=1.0, accent=(0.95, 0.98, 1.0), coat=0.85)

	linear = make_egg("LinearEgg", (0.90, 0.93, 0.97), (0.45, 0.65, 0.85), "linear")
	tactile = make_egg("TactileEgg", (0.45, 0.82, 0.62), (0.25, 0.55, 0.40), "tactile")
	golden = make_egg("GoldenEgg", (1.0, 0.78, 0.22), (1.0, 0.95, 0.55), "golden")

	kitty = make_kitty("KeycapKitty")
	chick = make_chick("ClickyChick")
	pup = make_pup("ThockPup")

	# Face pets toward camera (+Y). Kitty/chick/pup snouts built on +Y already.
	arrange_and_export(
		[
			[plain, creamy, glass],
			[linear, tactile, golden],
			[kitty, chick, pup],
		]
	)
	render_preview()
	print("DONE")
	print("OBJECTS", [o.name for o in bpy.data.objects if o.type == "MESH"])


main()
