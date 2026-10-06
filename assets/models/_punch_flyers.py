# Punch up flyer + phoenix pets only (keys already 1u).
import math
import os
from mathutils import Vector, Euler
import bpy

ROOT = r"C:\Users\zatch\dev\roblox\assets\models"
OUT = os.path.join(ROOT, "roster", "pets")
PREVIEWS = os.path.join(ROOT, "previews")

FLYERS = {"LaserOwl", "RainbowParrot", "GoldenGoose", "MegaLaserShark", "DiamondDragon"}


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


def assign(o, m):
	if o.data.materials:
		o.data.materials[0] = m
	else:
		o.data.materials.append(m)


def shade(o):
	bpy.context.view_layer.objects.active = o
	o.select_set(True)
	try:
		bpy.ops.object.shade_smooth()
	except Exception:
		pass
	o.select_set(False)


def bevel(o, w=0.04):
	mod = o.modifiers.new("Bevel", "BEVEL")
	mod.width = w
	mod.segments = 2
	mod.limit_method = "ANGLE"
	bpy.context.view_layer.objects.active = o
	try:
		bpy.ops.object.modifier_apply(modifier=mod.name)
	except Exception:
		pass


def origin_bottom(o):
	bpy.ops.object.select_all(action="DESELECT")
	o.select_set(True)
	bpy.context.view_layer.objects.active = o
	bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
	min_z = min(v.co.z for v in o.data.vertices)
	for v in o.data.vertices:
		v.co.z -= min_z
	o.data.update()
	o.location = (0, 0, 0)


def join_parts(parts, name):
	bpy.ops.object.select_all(action="DESELECT")
	for p in parts:
		p.select_set(True)
	bpy.context.view_layer.objects.active = parts[0]
	bpy.ops.object.join()
	o = bpy.context.active_object
	o.name = name
	origin_bottom(o)
	return o


def sphere(n, r, loc, m, seg=16, rings=10):
	bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=seg, ring_count=rings)
	o = bpy.context.active_object
	o.name = n
	assign(o, m)
	shade(o)
	return o


def cube(n, size, loc, m):
	bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
	o = bpy.context.active_object
	o.name = n
	o.scale = size if not isinstance(size, (int, float)) else (size, size, size)
	bpy.ops.object.transform_apply(scale=True)
	assign(o, m)
	bevel(o)
	shade(o)
	return o


def cyl(n, r, d, loc, m, v=16):
	bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=d, location=loc, vertices=v)
	o = bpy.context.active_object
	o.name = n
	assign(o, m)
	bevel(o, 0.03)
	shade(o)
	return o


def cone(n, r, d, loc, m):
	bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=0.02, depth=d, location=loc, vertices=12)
	o = bpy.context.active_object
	o.name = n
	assign(o, m)
	shade(o)
	return o


def solid_wing(parts, side, body_z, m, span=1.6, lift=0.25):
	"""One solid wing: flattened sphere + tip, attached at shoulder."""
	sign = -1 if side == "L" else 1
	# shoulder
	parts.append(sphere(f"sh{side}", 0.22, (sign * 0.45, 0.05, body_z + lift), m, 12, 8))
	# main wing panel as scaled sphere (reads as a wing, not a bar)
	w = sphere(f"w{side}", 0.55, (sign * 1.05, -0.05, body_z + lift + 0.15), m, 14, 10)
	w.scale = (span * 0.55, 0.22, 0.45)
	bpy.ops.object.transform_apply(scale=True)
	# tip
	tip = sphere(f"tip{side}", 0.28, (sign * (1.05 + span * 0.45), -0.15, body_z + lift + 0.35), m, 12, 8)
	tip.scale = (0.7, 0.25, 0.55)
	bpy.ops.object.transform_apply(scale=True)
	parts.extend([w, tip])


def face(parts, y, z, eye_m, spacing=0.18, r=0.09):
	parts.append(sphere("eL", r, (-spacing, y, z), eye_m, 10, 8))
	parts.append(sphere("eR", r, (spacing, y, z), eye_m, 10, 8))


def build_flyer(pid, color, accent, scale=1.0, wing_span=1.6, tuft=False, laser=False, switch=False, big_eyes=False):
	body_m = mat(pid + "_B", color, 0.35)
	acc_m = mat(pid + "_A", accent, 0.3)
	eye_m = mat(pid + "_E", (0.1, 0.1, 0.12), 0.4)
	s = scale
	parts = []
	bz = 1.35 * s
	parts.append(sphere("body", 0.5 * s, (0, 0, bz), body_m, 18, 12))
	parts.append(sphere("head", 0.4 * s, (0, 0.3, bz + 0.7 * s), body_m, 16, 12))
	parts.append(cube("beak", (0.16, 0.32, 0.14), (0, 0.65, bz + 0.65 * s), acc_m))
	face(parts, 0.55, bz + 0.8 * s, eye_m, 0.16, 0.11 if big_eyes else 0.08)
	solid_wing(parts, "L", bz, acc_m, span=wing_span, lift=0.2)
	solid_wing(parts, "R", bz, acc_m, span=wing_span, lift=0.2)
	for i in range(3):
		parts.append(cube(f"tail{i}", (0.12, 0.14, 0.4), (-0.2 + i * 0.2, -0.6, bz - 0.15), acc_m))
	parts.append(cube("ftL", (0.1, 0.1, 0.22), (-0.18, 0.1, 0.55 * s), acc_m))
	parts.append(cube("ftR", (0.1, 0.1, 0.22), (0.18, 0.1, 0.55 * s), acc_m))
	if tuft:
		parts.append(cube("tL", (0.1, 0.1, 0.28), (-0.2, 0.2, bz + 1.15 * s), body_m))
		parts.append(cube("tR", (0.1, 0.1, 0.28), (0.2, 0.2, bz + 1.15 * s), body_m))
	if laser:
		parts.append(cyl("las", 0.07, 0.7, (0, 0.85, bz + 0.65 * s), mat(pid + "_L", (1, 0.3, 0.35), 0.2, 0.1, 0.7), 10))
	if switch:
		parts.append(cyl("sw", 0.14, 0.18, (0, 0, bz + 1.15 * s), acc_m, 12))
	return join_parts(parts, pid)


def build_shark(pid, color, accent, scale=1.25):
	body_m = mat(pid + "_B", color, 0.35)
	acc_m = mat(pid + "_A", accent, 0.3)
	eye_m = mat(pid + "_E", (0.1, 0.1, 0.12), 0.4)
	s = scale
	parts = []
	body = sphere("body", 0.6 * s, (0, 0, 0.75 * s), body_m, 18, 12)
	body.scale = (1.0, 1.7, 0.85)
	bpy.ops.object.transform_apply(scale=True)
	parts.append(body)
	parts.append(sphere("head", 0.42 * s, (0, 1.05 * s, 0.8 * s), body_m, 14, 10))
	face(parts, 1.3 * s, 0.9 * s, eye_m, 0.2, 0.09)
	parts.append(cube("dorsal", (0.14, 0.3, 0.6), (0, 0.1, 1.5 * s), acc_m))
	parts.append(cube("tail", (0.14, 0.45, 0.6), (0, -1.25 * s, 0.95 * s), acc_m))
	parts.append(cube("finL", (0.5, 0.14, 0.25), (-0.75, 0.2, 0.65 * s), acc_m))
	parts.append(cube("finR", (0.5, 0.14, 0.25), (0.75, 0.2, 0.65 * s), acc_m))
	parts.append(cyl("las", 0.08, 0.85, (0, 1.5 * s, 0.8 * s), mat(pid + "_L", (1, 0.25, 0.3), 0.2, 0.1, 0.8), 10))
	return join_parts(parts, pid)


def build_phoenix(pid, color, accent, flame_col, scale=1.55):
	body_m = mat(pid + "_B", color, 0.3, 0.15, 0.4)
	acc_m = mat(pid + "_A", accent, 0.25, 0.2, 0.5)
	flame = mat(pid + "_F", flame_col, 0.22, 0.05, 0.55)
	eye_m = mat(pid + "_E", (0.1, 0.1, 0.12), 0.4)
	jewel = mat(pid + "_J", (0.7, 0.92, 1.0), 0.1, 0.5, 0.9)
	s = scale
	parts = []
	bz = 1.8 * s
	parts.append(sphere("body", 0.8 * s, (0, 0, bz), body_m, 20, 14))
	parts.append(sphere("head", 0.5 * s, (0, 0.45, bz + 0.95 * s), body_m, 16, 12))
	parts.append(cube("beak", (0.22, 0.4, 0.2), (0, 0.9, bz + 0.9 * s), acc_m))
	face(parts, 0.8, bz + 1.05 * s, eye_m, 0.2, 0.11)
	# MASSIVE solid wings
	solid_wing(parts, "L", bz, flame, span=2.4, lift=0.35)
	solid_wing(parts, "R", bz, flame, span=2.4, lift=0.35)
	# secondary wing layer
	solid_wing(parts, "L2", bz - 0.15, acc_m, span=1.6, lift=0.05)
	solid_wing(parts, "R2", bz - 0.15, acc_m, span=1.6, lift=0.05)
	# flame tail cascade
	for i in range(8):
		parts.append(cone(f"plume{i}", 0.2 - i * 0.012, 0.9 + i * 0.12, (-0.6 + i * 0.17, -1.1 - i * 0.12, bz - 0.4 - i * 0.05), flame))
	# head crest
	for i in range(5):
		parts.append(cone(f"crest{i}", 0.16, 0.55, (-0.35 + i * 0.17, 0.3, bz + 1.55 * s), flame))
	parts.append(sphere("jewel", 0.28, (0, 0.45, bz + 0.1), jewel, 12, 8))
	parts.append(cube("talL", (0.16, 0.16, 0.4), (-0.3, 0.15, 0.7 * s), acc_m))
	parts.append(cube("talR", (0.16, 0.16, 0.4), (0.3, 0.15, 0.7 * s), acc_m))
	return join_parts(parts, pid)


def export(obj):
	os.makedirs(OUT, exist_ok=True)
	path = os.path.join(OUT, obj.name + ".obj")
	bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj
	bpy.ops.wm.obj_export(filepath=path, export_selected_objects=True, forward_axis="NEGATIVE_Z", up_axis="Y", export_materials=False)


def render_sheet(objects, path, cols, gap=4.5):
	show = set(objects)
	for o in bpy.data.objects:
		if o.type == "MESH":
			o.hide_render = o.hide_viewport = o not in show
	for i, obj in enumerate(objects):
		row, col = divmod(i, cols)
		obj.location = ((col - (cols - 1) / 2) * gap, -row * (gap + 0.8), 0)
	bpy.context.view_layer.update()
	mins = Vector((1e9, 1e9, 1e9))
	maxs = Vector((-1e9, -1e9, -1e9))
	for obj in objects:
		for c in obj.bound_box:
			w = obj.matrix_world @ Vector(c)
			mins = Vector((min(mins.x, w.x), min(mins.y, w.y), min(mins.z, w.z)))
			maxs = Vector((max(maxs.x, w.x), max(maxs.y, w.y), max(maxs.z, w.z)))
	center = (mins + maxs) * 0.5
	size = max(maxs.x - mins.x, maxs.y - mins.y, maxs.z - mins.z, 2.0)
	cam = bpy.data.objects["Cam"]
	cam.location = (center.x, center.y + size * 1.6, center.z + size * 0.85)
	cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
	cam.data.lens = 30
	scene = bpy.context.scene
	try:
		scene.render.engine = "BLENDER_EEVEE_NEXT"
	except Exception:
		scene.render.engine = "BLENDER_EEVEE"
	scene.render.resolution_x = 1920
	scene.render.resolution_y = 1080
	scene.render.filepath = path
	bpy.ops.render.render(write_still=True)
	for o in objects:
		o.hide_render = o.hide_viewport = False
	print("SHEET", path)


def main():
	g = lambda *rgb: tuple(c / 255 for c in rgb)
	# remove old flyer meshes
	for name in list(FLYERS):
		o = bpy.data.objects.get(name)
		if o:
			bpy.data.objects.remove(o, do_unlink=True)

	built = []
	built.append(build_flyer("LaserOwl", g(120, 100, 80), g(255, 90, 100), 1.05, 1.7, tuft=True, laser=True, big_eyes=True))
	built.append(build_flyer("RainbowParrot", g(255, 90, 120), g(80, 200, 255), 1.1, 1.85, switch=True))
	built.append(build_flyer("GoldenGoose", g(255, 205, 70), g(255, 240, 150), 1.15, 1.9))
	built.append(build_shark("MegaLaserShark", g(90, 140, 180), g(255, 80, 100), 1.3))
	built.append(build_phoenix("DiamondDragon", g(255, 140, 60), g(255, 220, 100), g(255, 60, 25), 1.55))

	for o in built:
		export(o)
		print("PET", o.name)

	render_sheet(built, os.path.join(PREVIEWS, "pets_flying_flex.png"), 5, gap=5.0)
	# phoenix solo hero shot
	render_sheet([built[-1]], os.path.join(PREVIEWS, "pet_phoenix_hero.png"), 1, gap=6.0)

	# refresh epic sheet if those objects exist
	epic_names = [
		"RainbowParrot", "FourLeafFawn", "SwitchFox", "GoldenGorilla", "GhostFerret", "LaserLynx",
		"SpacebarBunny", "CrownKoala", "LightningLeopard", "GoldenGoose", "PhantomWolf", "MegaLaserShark", "DiamondDragon",
	]
	epic = [bpy.data.objects[n] for n in epic_names if n in bpy.data.objects]
	if epic:
		render_sheet(epic, os.path.join(PREVIEWS, "pets_epic_to_mythic.png"), 7, gap=4.2)
	print("DONE flyers")


main()
