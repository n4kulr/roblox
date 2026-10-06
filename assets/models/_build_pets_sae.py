# THOCK pets — SAE high-detail batch
# Dense studs, multi-segment anatomy, bevels, rarity-scaled complexity.

import json
import math
import os

import bpy
from mathutils import Euler, Vector

ROOT = r"C:\Users\zatch\dev\roblox\assets\models"
OUT = os.path.join(ROOT, "roster")
PETS_DIR = os.path.join(OUT, "pets_sae")
PREVIEWS = os.path.join(ROOT, "previews")
MANIFEST = os.path.join(OUT, "manifest_sae_pets.json")
KEEP = {"Cam", "Area", "Area.001", "Area.002", "Area.003"}


def clear_pets():
	for obj in list(bpy.data.objects):
		if obj.name in KEEP or obj.type != "MESH":
			continue
		bpy.data.objects.remove(obj, do_unlink=True)
	for coll in (bpy.data.meshes, bpy.data.materials):
		for block in list(coll):
			if block.users == 0:
				coll.remove(block)


def mat(name, color, roughness=0.28, metallic=0.0, coat=0.55, emit=0.0):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	bsdf = m.node_tree.nodes.get("Principled BSDF")
	bsdf.inputs["Base Color"].default_value = (*color, 1.0)
	bsdf.inputs["Roughness"].default_value = roughness
	bsdf.inputs["Metallic"].default_value = metallic
	try:
		bsdf.inputs["Coat Weight"].default_value = coat
		bsdf.inputs["Coat Roughness"].default_value = 0.08
	except Exception:
		pass
	if emit > 0:
		try:
			bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
			bsdf.inputs["Emission Strength"].default_value = emit
		except Exception:
			pass
	return m


def assign(obj, material):
	if obj.data.materials:
		obj.data.materials[0] = material
	else:
		obj.data.materials.append(material)


def finish(obj, bevel_w=0.03, segments=3, subsurf=0):
	bpy.context.view_layer.objects.active = obj
	obj.select_set(True)
	if bevel_w > 0:
		mod = obj.modifiers.new("Bevel", "BEVEL")
		mod.width = bevel_w
		mod.segments = segments
		mod.limit_method = "ANGLE"
		mod.angle_limit = math.radians(30)
		try:
			bpy.ops.object.modifier_apply(modifier=mod.name)
		except Exception:
			pass
	if subsurf > 0:
		mod = obj.modifiers.new("Sub", "SUBSURF")
		mod.levels = subsurf
		mod.render_levels = subsurf
		try:
			bpy.ops.object.modifier_apply(modifier=mod.name)
		except Exception:
			pass
	try:
		bpy.ops.object.shade_smooth()
	except Exception:
		pass
	obj.select_set(False)
	return obj


def box(name, size, loc, material, rot=(0, 0, 0), bevel=0.028, segs=3, sub=0):
	bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
	o = bpy.context.active_object
	o.name = name
	sx, sy, sz = size if not isinstance(size, (int, float)) else (size, size, size)
	o.scale = (sx, sy, sz)
	o.rotation_euler = rot
	bpy.ops.object.transform_apply(scale=True, rotation=True)
	assign(o, material)
	return finish(o, bevel, segs, sub)


def cyl(name, radius, depth, loc, material, verts=24, rot=(0, 0, 0), bevel=0.02, sub=0):
	bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=loc, vertices=verts)
	o = bpy.context.active_object
	o.name = name
	o.rotation_euler = rot
	bpy.ops.object.transform_apply(rotation=True)
	assign(o, material)
	return finish(o, bevel, 2, sub)


def sphere(name, r, loc, material, seg=32, rings=16, sub=0):
	bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=seg, ring_count=rings)
	o = bpy.context.active_object
	o.name = name
	assign(o, material)
	return finish(o, 0.0, 0, sub)


def cone(name, r1, depth, loc, material, verts=16, rot=(0, 0, 0)):
	bpy.ops.mesh.primitive_cone_add(radius1=r1, radius2=0.02, depth=depth, location=loc, vertices=verts)
	o = bpy.context.active_object
	o.name = name
	o.rotation_euler = rot
	bpy.ops.object.transform_apply(rotation=True)
	assign(o, material)
	return finish(o, 0.015, 2, 0)


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
	alive = [p for p in parts if p is not None]
	for p in alive:
		p.select_set(True)
	bpy.context.view_layer.objects.active = alive[0]
	bpy.ops.object.join()
	obj = bpy.context.active_object
	obj.name = name
	obj.data.name = name
	origin_bottom(obj)
	return obj


def stud_face(parts, material, origin, face, cols, rows, spacing, size=0.11, depth=0.045, bevel=0.012):
	ox0, oy0, oz0 = origin
	for i in range(cols):
		for j in range(rows):
			u = (i - (cols - 1) / 2) * spacing
			v = (j - (rows - 1) / 2) * spacing
			if face == "px":
				parts.append(box(f"st{i}{j}px", (depth, size, size), (ox0, oy0 + u, oz0 + v), material, bevel=bevel, segs=2))
			elif face == "nx":
				parts.append(box(f"st{i}{j}nx", (depth, size, size), (ox0, oy0 + u, oz0 + v), material, bevel=bevel, segs=2))
			elif face == "py":
				parts.append(box(f"st{i}{j}py", (size, depth, size), (ox0 + u, oy0, oz0 + v), material, bevel=bevel, segs=2))
			elif face == "top":
				parts.append(box(f"st{i}{j}t", (size, size, depth), (ox0 + u, oy0 + v, oz0), material, bevel=bevel, segs=2))


def stud_block(parts, material, cx, cy, cz, half_x, half_y, half_z, density=3, size=0.12):
	"""Cover a block's sides + top with dense studs."""
	sp = (min(half_x, half_y, half_z) * 1.6) / max(density - 1, 1)
	sp = max(sp, size * 1.35)
	stud_face(parts, material, (cx + half_x + size * 0.2, cy, cz), "px", density, density, sp, size)
	stud_face(parts, material, (cx - half_x - size * 0.2, cy, cz), "nx", density, density, sp, size)
	stud_face(parts, material, (cx, cy + half_y + size * 0.2, cz), "py", density, density, sp, size)
	stud_face(parts, material, (cx, cy, cz + half_z + size * 0.15), "top", density, density, sp, size)


def face_eyes(parts, y, z, eye_m, white_m, spacing=0.28, size=0.22, deep=0.06):
	for sign, tag in ((-1, "L"), (1, "R")):
		parts.append(box(f"socket{tag}", (size * 1.15, deep * 0.6, size * 1.15), (sign * spacing, y - 0.01, z), eye_m, bevel=0.02, segs=2))
		parts.append(box(f"eye{tag}", (size, deep, size), (sign * spacing, y, z), eye_m, bevel=0.015, segs=2))
		parts.append(box(f"hi{tag}", (size * 0.32, deep + 0.01, size * 0.32), (sign * spacing - size * 0.25, y + 0.015, z + size * 0.25), white_m, bevel=0.008, segs=2))
		parts.append(box(f"hi2{tag}", (size * 0.14, deep + 0.012, size * 0.14), (sign * spacing + size * 0.2, y + 0.018, z - size * 0.22), white_m, bevel=0.005, segs=1))


def open_mouth(parts, y, z, w, dark_m, white_m, tongue_m=None, teeth=4):
	parts.append(box("mouth", (w, 0.14, 0.16), (0, y, z), dark_m, bevel=0.02, segs=2))
	if tongue_m:
		parts.append(box("tongue", (w * 0.55, 0.08, 0.06), (0, y + 0.02, z - 0.04), tongue_m, bevel=0.015, segs=2))
	for i in range(teeth):
		tx = -w * 0.35 + i * (w * 0.7 / max(teeth - 1, 1))
		parts.append(box(f"tooth{i}", (0.07, 0.05, 0.1), (tx, y + 0.04, z + 0.06), white_m, bevel=0.01, segs=2))


def toe_foot(parts, x, y, z, material, white_m, scale=1.0, toes=3):
	parts.append(box(f"foot{x}", (0.22 * scale, 0.32 * scale, 0.1 * scale), (x, y, z), white_m, bevel=0.02, segs=2))
	for t in range(toes):
		parts.append(box(f"toe{x}{t}", (0.06 * scale, 0.14 * scale, 0.06 * scale), (x + (t - (toes - 1) / 2) * 0.08 * scale, y + 0.18 * scale, z), white_m, bevel=0.01, segs=1))


def spine_plates(parts, material, path, size=(0.14, 0.1, 0.22)):
	for i, (x, y, z) in enumerate(path):
		h = size[2] * (1.0 + 0.08 * math.sin(i))
		parts.append(box(f"sp{i}", (size[0], size[1], h), (x, y, z + h * 0.3), material, bevel=0.015, segs=2))


def armor_shell(parts, material, cx, cy, cz, w, d, h, layers=3, inset=0.06):
	"""Stacked offset plates so the body isn't one big cube."""
	for i in range(layers):
		t = (i + 1) / (layers + 1)
		parts.append(
			box(
				f"plate{i}",
				(w * (1.0 - i * 0.08), d * 0.35, h * 0.28),
				(cx, cy - d * 0.35 + i * (d * 0.55 / max(layers - 1, 1)), cz + h * 0.15 - i * inset * 0.5),
				material,
				bevel=0.03,
				segs=3,
			)
		)
	# shoulder pads
	for sign in (-1, 1):
		parts.append(box(f"shoulder{sign}", (w * 0.28, d * 0.3, h * 0.22), (cx + sign * w * 0.48, cy + d * 0.1, cz + h * 0.35), material, bevel=0.03, segs=3))
		parts.append(box(f"hip{sign}", (w * 0.22, d * 0.25, h * 0.18), (cx + sign * w * 0.42, cy - d * 0.25, cz - h * 0.15), material, bevel=0.025, segs=2))


def cheek_brow(parts, body_m, acc_m, hy, hz, hs, s=1.0):
	for sign in (-1, 1):
		parts.append(sphere(f"cheek{sign}", 0.12 * s, (sign * hs * 0.42, hy + hs * 0.35, hz - 0.05), body_m, 20, 12))
		parts.append(box(f"brow{sign}", (0.16 * s, 0.08, 0.07), (sign * 0.22 * s, hy + hs * 0.48, hz + 0.28), body_m, bevel=0.015, segs=2))
	parts.append(box("browBridge", (0.2 * s, 0.06, 0.06), (0, hy + hs * 0.5, hz + 0.3), body_m, bevel=0.012, segs=2))


# ---------------- builders ----------------

def build_biped(spec, body_m, acc_m, eye_m, white_m, dark_m, tongue_m):
	s = spec.get("scale", 1.0)
	d = spec.get("detail", 3)
	parts = []
	# head
	hx, hy, hz = 0, 0.4 * s, 1.45 * s
	hh = 0.5 * s
	parts.append(box("head", (0.95 * s, 0.95 * s, 0.95 * s), (hx, hy, hz), body_m, bevel=0.04, segs=4))
	stud_block(parts, body_m, hx, hy, hz, 0.475 * s, 0.475 * s, 0.475 * s, density=d, size=0.11)
	face_eyes(parts, hy + 0.5 * s, hz + 0.08 * s, eye_m, white_m, spacing=0.26 * s, size=0.2 * s)
	parts.append(box("beak", (0.3 * s, 0.36 * s, 0.2 * s), (0, hy + 0.58 * s, hz - 0.12 * s), acc_m, bevel=0.025, segs=3))
	parts.append(box("beakTip", (0.18 * s, 0.16 * s, 0.12 * s), (0, hy + 0.78 * s, hz - 0.14 * s), acc_m, bevel=0.02, segs=2))
	# comb / crest
	if spec.get("comb"):
		for i, (dx, h) in enumerate(((-0.2, 0.22), (-0.08, 0.32), (0.08, 0.36), (0.2, 0.28))):
			parts.append(box(f"comb{i}", (0.1, 0.12, h), (dx * s, hy, hz + 0.55 * s + h * 0.35), acc_m, bevel=0.02, segs=3))
		parts.append(box("wattle", (0.1, 0.12, 0.2), (0, hy + 0.55 * s, hz - 0.4 * s), acc_m, bevel=0.02, segs=2))
	if spec.get("crest"):
		for i in range(spec["crest"]):
			parts.append(box(f"cr{i}", (0.12, 0.12, 0.35 + i * 0.06), (-0.3 + i * 0.15, hy - 0.05, hz + 0.65 * s), acc_m, bevel=0.02, segs=3))
	# neck + body
	parts.append(box("neck", (0.35 * s, 0.35 * s, 0.32 * s), (0, 0.15 * s, 0.95 * s), body_m, bevel=0.03, segs=3))
	parts.append(box("body", (0.8 * s, 1.05 * s, 0.75 * s), (0, -0.35 * s, 0.75 * s), body_m, bevel=0.04, segs=4))
	stud_block(parts, body_m, 0, -0.35 * s, 0.75 * s, 0.4 * s, 0.525 * s, 0.375 * s, density=d, size=0.1)
	# wings / stubs
	for sign, tag in ((-1, "L"), (1, "R")):
		parts.append(box(f"wing{tag}", (0.14, 0.45 * s, 0.35 * s), (sign * 0.5 * s, -0.2 * s, 0.85 * s), acc_m, bevel=0.025, segs=3, rot=(0.1, sign * 0.15, 0)))
		parts.append(box(f"wingTip{tag}", (0.1, 0.28 * s, 0.22 * s), (sign * 0.58 * s, -0.4 * s, 0.75 * s), acc_m, bevel=0.02, segs=2))
	# legs
	for sign, tag in ((-1, "L"), (1, "R")):
		parts.append(box(f"thigh{tag}", (0.14, 0.14, 0.28), (sign * 0.22 * s, 0.05, 0.35), acc_m, bevel=0.02, segs=2))
		parts.append(box(f"shin{tag}", (0.11, 0.11, 0.28), (sign * 0.22 * s, 0.12, 0.18), acc_m, bevel=0.018, segs=2))
		toe_foot(parts, sign * 0.22 * s, 0.22, 0.05, acc_m, white_m, scale=0.95, toes=3)
	# tail feathers
	for i in range(4):
		parts.append(box(f"tf{i}", (0.12, 0.16, 0.4 + i * 0.05), (-0.24 + i * 0.16, -0.95 * s, 0.7 * s), acc_m, bevel=0.02, segs=2, rot=(0.2, 0, 0)))
	return parts


def build_quad(spec, body_m, acc_m, eye_m, white_m, dark_m, tongue_m):
	s = spec.get("scale", 1.0)
	d = spec.get("detail", 3)
	parts = []
	bw = spec.get("body_w", 0.9) * s
	bd = spec.get("body_d", 1.1) * s
	bh = spec.get("body_h", 0.75) * s
	hs = spec.get("head", 1.0) * s
	hy = 0.58 * bd
	hz = 1.25 * s

	parts.append(box("body", (bw, bd, bh), (0, 0, 0.6 * s), body_m, bevel=0.045, segs=4))
	stud_block(parts, body_m, 0, 0, 0.6 * s, bw * 0.5, bd * 0.5, bh * 0.5, density=d, size=0.11)
	armor_shell(parts, body_m, 0, 0, 0.6 * s, bw, bd, bh, layers=max(2, d - 1))
	if spec.get("belly", True):
		parts.append(box("belly", (bw * 0.7, bd * 0.75, bh * 0.25), (0, 0.05, 0.35 * s), white_m, bevel=0.03, segs=3))

	parts.append(box("head", (hs, hs * 0.92, hs), (0, hy, hz), body_m, bevel=0.045, segs=4))
	stud_block(parts, body_m, 0, hy, hz, hs * 0.5, hs * 0.46, hs * 0.5, density=d, size=0.11)
	cheek_brow(parts, body_m, acc_m, hy, hz, hs, s)
	face_eyes(parts, hy + hs * 0.5, hz + 0.1, eye_m, white_m, spacing=0.28 * s, size=0.22 * s)

	# layered snout
	parts.append(box("snout1", (0.48 * s, 0.38 * s, 0.32 * s), (0, hy + hs * 0.55, hz - 0.12), white_m if spec.get("snout_accent") else body_m, bevel=0.03, segs=3))
	parts.append(box("snout2", (0.36 * s, 0.22 * s, 0.22 * s), (0, hy + hs * 0.72, hz - 0.1), white_m if spec.get("snout_accent") else body_m, bevel=0.025, segs=3))
	parts.append(cyl("nose", 0.07, 0.08, (0, hy + hs * 0.82, hz - 0.02), dark_m, 16, (math.pi / 2, 0, 0), bevel=0.01))
	if spec.get("mouth", True):
		open_mouth(parts, hy + hs * 0.68, hz - 0.28, 0.32 * s, dark_m, white_m, tongue_m, teeth=4)
	if spec.get("forehead"):
		parts.append(box("blaze", (0.26 * s, 0.06, 0.4 * s), (0, hy + hs * 0.5, hz + 0.2), white_m, bevel=0.02, segs=2))

	ear = spec.get("ears", "round")
	for sign in (-1, 1):
		ex, ey, ez = sign * hs * 0.48, hy, hz + hs * 0.52
		if ear == "long":
			parts.append(box(f"ear{sign}", (0.2, 0.16, 0.75 * s), (ex, ey, ez + 0.2), body_m, bevel=0.03, segs=3))
			parts.append(box(f"earIn{sign}", (0.12, 0.08, 0.5 * s), (ex, ey + 0.05, ez + 0.15), acc_m, bevel=0.02, segs=2))
		elif ear == "point":
			parts.append(box(f"ear{sign}", (0.28, 0.14, 0.48 * s), (ex, ey, ez), body_m, bevel=0.03, segs=3, rot=(0, sign * 0.25, 0)))
			parts.append(box(f"earIn{sign}", (0.14, 0.06, 0.28 * s), (ex, ey + 0.05, ez), acc_m, bevel=0.015, segs=2))
		elif ear == "diamond":
			parts.append(box(f"ear{sign}", (0.36, 0.12, 0.36), (ex, ey, ez), body_m, bevel=0.03, segs=3, rot=(0, 0, math.pi / 4)))
			parts.append(box(f"earIn{sign}", (0.18, 0.06, 0.18), (ex, ey + 0.04, ez), dark_m, bevel=0.015, segs=2, rot=(0, 0, math.pi / 4)))
		elif ear == "floppy":
			parts.append(box(f"ear{sign}", (0.22, 0.14, 0.65 * s), (ex, ey - 0.2, ez - 0.05), body_m, bevel=0.03, segs=3, rot=(0.75, sign * 0.2, 0)))
			parts.append(box(f"earIn{sign}", (0.12, 0.06, 0.4 * s), (ex, ey - 0.15, ez - 0.08), acc_m, bevel=0.015, segs=2, rot=(0.75, sign * 0.2, 0)))
		else:
			parts.append(box(f"ear{sign}", (0.28, 0.2, 0.28), (ex, ey, ez), body_m, bevel=0.035, segs=3))
			parts.append(box(f"earIn{sign}", (0.14, 0.08, 0.14), (ex, ey + 0.06, ez), acc_m, bevel=0.015, segs=2))

	# articulated legs
	leg_xy = [(-0.34 * s, 0.35 * s), (0.34 * s, 0.35 * s), (-0.34 * s, -0.35 * s), (0.34 * s, -0.35 * s)]
	for i, (dx, dy) in enumerate(leg_xy):
		parts.append(box(f"thigh{i}", (0.22 * s, 0.22 * s, 0.28 * s), (dx, dy, 0.38 * s), body_m, bevel=0.025, segs=3))
		parts.append(box(f"shin{i}", (0.18 * s, 0.18 * s, 0.28 * s), (dx, dy + 0.02, 0.18 * s), body_m, bevel=0.02, segs=2))
		toe_foot(parts, dx, dy + 0.06, 0.05, body_m, white_m, scale=s * 0.95, toes=3)

	tail = spec.get("tail", "blob")
	if tail == "stripe":
		for i, (dy, col) in enumerate([(-0.55, body_m), (-0.75, dark_m), (-0.95, body_m), (-1.15, dark_m), (-1.3, body_m)]):
			parts.append(box(f"tail{i}", (0.26, 0.22, 0.26), (0, dy * bd / 1.1, 0.8 * s), col, bevel=0.025, segs=3))
	elif tail == "bush":
		parts.append(sphere("tailBase", 0.22 * s, (0, -0.65 * bd, 0.85 * s), acc_m, 24, 12))
		parts.append(sphere("tailMid", 0.28 * s, (0, -0.85 * bd, 0.95 * s), acc_m, 24, 12))
		parts.append(sphere("tailTip", 0.2 * s, (0, -1.05 * bd, 1.05 * s), white_m, 20, 10))
	elif tail == "long":
		for i in range(5):
			parts.append(box(f"t{i}", (0.16 - i * 0.015, 0.28, 0.16 - i * 0.015), (0, -0.65 * bd - i * 0.22, 0.7 * s + i * 0.06), body_m, bevel=0.02, segs=2))
	elif tail != "none":
		parts.append(box("tail", (0.24, 0.35, 0.24), (0, -0.7 * bd, 0.75 * s), body_m, bevel=0.03, segs=3))
		parts.append(box("tailTip", (0.18, 0.2, 0.18), (0, -0.95 * bd, 0.85 * s), body_m, bevel=0.025, segs=2))

	if spec.get("mask"):
		parts.append(box("mask", (hs * 1.02, 0.1, hs * 0.4), (0, hy + hs * 0.5, hz + 0.02), dark_m, bevel=0.02, segs=2))
	if spec.get("spots"):
		spot_m = dark_m if spec.get("dark_spots") else acc_m
		for i, (dx, dy, dz) in enumerate(((-0.32, 0.15, 0.75), (0.3, -0.2, 0.8), (0.05, 0.35, 0.6), (-0.15, -0.3, 0.9), (0.2, 0.1, 0.95), (-0.25, 0.0, 0.55))):
			parts.append(sphere(f"sp{i}", 0.1 * s, (dx * s, dy * s, dz * s), spot_m, 16, 8))

	g = spec.get("gimmick")
	top = hz + hs * 0.62
	if g == "keycap":
		parts.append(box("cap", (0.42, 0.42, 0.22), (0, hy, top), acc_m, bevel=0.03, segs=3))
		stud_face(parts, acc_m, (0, hy, top + 0.14), "top", 3, 3, 0.12, 0.09, 0.04)
	elif g == "collar":
		parts.append(cyl("col", hs * 0.55, 0.12, (0, hy - 0.05, hz - hs * 0.5), acc_m, 24))
		parts.append(box("tag", (0.14, 0.06, 0.18), (0, hy + 0.35, hz - hs * 0.55), white_m, bevel=0.015, segs=2))
	elif g == "bolt":
		parts.append(box("b1", (0.22, 0.12, 0.5), (0.06, hy, top), acc_m, bevel=0.02, segs=2))
		parts.append(box("b2", (0.36, 0.12, 0.16), (-0.06, hy, top - 0.18), acc_m, bevel=0.02, segs=2))
		parts.append(box("b3", (0.18, 0.12, 0.35), (-0.12, hy, top - 0.4), acc_m, bevel=0.02, segs=2))
	elif g == "crown":
		parts.append(cyl("band", 0.38, 0.12, (0, hy, top - 0.05), acc_m, 20))
		for i in range(7):
			a = i * math.tau / 7
			parts.append(box(f"pt{i}", (0.08, 0.08, 0.28 if i % 2 == 0 else 0.18), (math.cos(a) * 0.32, hy + math.sin(a) * 0.32, top + 0.1), acc_m, bevel=0.015, segs=2))
		parts.append(sphere("gem", 0.1, (0, hy, top + 0.28), mat(spec["id"] + "_gem", (0.4, 0.9, 1.0), 0.12, 0.3, 0.8, 0.4), 16, 10))
	elif g == "clover":
		for i, (dx, dy) in enumerate(((-0.16, 0.1), (0.16, 0.1), (0, 0.28), (0, -0.06))):
			parts.append(sphere(f"lv{i}", 0.12, (dx, hy + dy, top), acc_m, 16, 10))
		parts.append(box("stem", (0.06, 0.06, 0.18), (0, hy, top - 0.15), acc_m, bevel=0.01, segs=1))
	elif g == "spring":
		for i in range(5):
			parts.append(cyl(f"coil{i}", 0.1, 0.06, (0, -0.85 * bd, 0.7 * s + i * 0.1), acc_m, 16))
	elif g == "coin":
		parts.append(cyl("coin", 0.18, 0.06, (0.5 * s, hy, 0.8 * s), acc_m, 24, (0, math.pi / 2, 0)))
		parts.append(cyl("coin2", 0.12, 0.05, (0.55 * s, hy - 0.15, 0.65 * s), acc_m, 20, (0, math.pi / 2, 0)))
	elif g == "sticky":
		parts.append(box("loot", (0.24, 0.24, 0.24), (0.55 * s, hy, 0.65 * s), acc_m, bevel=0.03, segs=3))
		parts.append(box("loot2", (0.16, 0.16, 0.16), (0.65 * s, hy - 0.15, 0.5 * s), white_m, bevel=0.02, segs=2))
	elif g == "spacebar":
		parts.append(box("bar", (0.85, 0.2, 0.14), (0, hy, top), acc_m, bevel=0.025, segs=3))
		parts.append(box("notch", (0.22, 0.14, 0.1), (0, hy + 0.12, top + 0.08), acc_m, bevel=0.015, segs=2))
	elif g == "switch":
		parts.append(cyl("swBody", 0.16, 0.2, (0, hy, top), acc_m, 20))
		parts.append(box("swStem", (0.1, 0.1, 0.18), (0, hy, top + 0.18), white_m, bevel=0.015, segs=2))
	elif g == "laser":
		parts.append(cyl("las", 0.07, 0.65, (0, hy + hs * 0.8, hz), mat(spec["id"] + "_L", (1, 0.25, 0.3), 0.15, 0.1, 0.7, 1.2), 16, (math.pi / 2, 0, 0)))
		parts.append(sphere("lens", 0.1, (0, hy + hs * 0.55, hz + 0.05), mat(spec["id"] + "_lens", (1, 0.4, 0.45), 0.1, 0.2, 0.8, 0.8), 16, 10))
	elif g == "antler":
		for sign in (-1, 1):
			parts.append(box(f"ant{sign}", (0.1, 0.1, 0.55), (sign * 0.28, hy, top), acc_m, bevel=0.02, segs=2))
			parts.append(box(f"brA{sign}", (0.28, 0.08, 0.08), (sign * 0.4, hy, top + 0.2), acc_m, bevel=0.015, segs=2))
			parts.append(box(f"brB{sign}", (0.2, 0.08, 0.08), (sign * 0.35, hy - 0.1, top + 0.35), acc_m, bevel=0.015, segs=2))
	return parts


def build_frog(spec, body_m, acc_m, eye_m, white_m, dark_m, tongue_m):
	s = spec.get("scale", 1.0)
	d = spec.get("detail", 3)
	parts = []
	parts.append(box("body", (1.25 * s, 1.05 * s, 0.6 * s), (0, 0, 0.45 * s), body_m, bevel=0.05, segs=4))
	stud_block(parts, body_m, 0, 0, 0.45 * s, 0.625 * s, 0.525 * s, 0.3 * s, density=d, size=0.12)
	parts.append(box("belly", (0.9 * s, 0.8 * s, 0.2), (0, 0.1, 0.2), white_m, bevel=0.03, segs=3))
	parts.append(box("head", (1.05 * s, 0.8 * s, 0.55 * s), (0, 0.45 * s, 0.9 * s), body_m, bevel=0.045, segs=4))
	for sign, tag in ((-1, "L"), (1, "R")):
		parts.append(sphere(f"eyeBulb{tag}", 0.22 * s, (sign * 0.35 * s, 0.55 * s, 1.3 * s), body_m, 24, 12))
		parts.append(box(f"eye{tag}", (0.18, 0.06, 0.18), (sign * 0.35 * s, 0.75 * s, 1.32 * s), eye_m, bevel=0.015, segs=2))
		parts.append(box(f"hi{tag}", (0.06, 0.07, 0.06), (sign * 0.35 * s - 0.05, 0.78 * s, 1.38 * s), white_m, bevel=0.008, segs=1))
	open_mouth(parts, 0.9 * s, 0.75 * s, 0.4 * s, dark_m, white_m, tongue_m, teeth=2)
	for sign in (-1, 1):
		parts.append(box(f"thigh{sign}", (0.4, 0.45, 0.32), (sign * 0.65 * s, 0.25 * s, 0.3 * s), body_m, bevel=0.035, segs=3))
		parts.append(box(f"calf{sign}", (0.28, 0.5, 0.22), (sign * 0.75 * s, 0.55 * s, 0.2 * s), body_m, bevel=0.03, segs=3))
		toe_foot(parts, sign * 0.8 * s, 0.85 * s, 0.06, body_m, white_m, scale=1.2, toes=4)
	for i, (dx, dy) in enumerate(((-0.18, 0.12), (0.18, 0.12), (0, 0.3), (0, -0.08))):
		parts.append(sphere(f"lv{i}", 0.13, (dx, dy, 1.55 * s), acc_m, 16, 10))
	return parts


def build_lizard(spec, body_m, acc_m, eye_m, white_m, dark_m, tongue_m):
	s = spec.get("scale", 1.0)
	d = spec.get("detail", 3)
	parts = []
	# multi-segment body
	for i, (dy, sc) in enumerate([(0.4, 1.0), (0.0, 1.05), (-0.4, 0.95), (-0.8, 0.8)]):
		parts.append(box(f"seg{i}", (0.55 * s * sc, 0.45 * s, 0.42 * s * sc), (0, dy * s, 0.45 * s), body_m, bevel=0.035, segs=3))
	stud_block(parts, body_m, 0, 0, 0.45 * s, 0.28 * s, 0.5 * s, 0.22 * s, density=max(2, d - 1), size=0.1)
	parts.append(box("head", (0.55 * s, 0.65 * s, 0.45 * s), (0, 0.95 * s, 0.55 * s), body_m, bevel=0.04, segs=4))
	face_eyes(parts, 1.28 * s, 0.62 * s, eye_m, white_m, spacing=0.18 * s, size=0.14 * s)
	open_mouth(parts, 1.3 * s, 0.4 * s, 0.28 * s, dark_m, white_m, tongue_m, teeth=3)
	# long tapering tail
	for i in range(6):
		sc = 1.0 - i * 0.12
		parts.append(box(f"tail{i}", (0.28 * sc, 0.32, 0.28 * sc), (0, -1.15 * s - i * 0.28, 0.4 * s + i * 0.03), body_m, bevel=0.02, segs=2))
	spine_plates(parts, acc_m, [(0, 0.3 * s - i * 0.25, 0.7 * s) for i in range(5)], (0.12, 0.08, 0.18))
	leg_xy = [(-0.32 * s, 0.4 * s), (0.32 * s, 0.4 * s), (-0.32 * s, -0.35 * s), (0.32 * s, -0.35 * s)]
	for i, (dx, dy) in enumerate(leg_xy):
		parts.append(box(f"leg{i}", (0.16, 0.16, 0.28), (dx, dy, 0.2), body_m, bevel=0.02, segs=2))
		toe_foot(parts, dx, dy + 0.05, 0.05, body_m, white_m, scale=0.75, toes=3)
	if spec.get("spots"):
		for i, (dx, dy) in enumerate(((-0.2, 0.3), (0.22, 0.0), (-0.15, -0.35), (0.18, -0.6), (0, 0.6))):
			parts.append(sphere(f"sp{i}", 0.09 * s, (dx * s, dy * s, 0.62 * s), acc_m, 14, 8))
	g = spec.get("gimmick")
	if g == "clover":
		for i, (dx, dy) in enumerate(((-0.12, 0.08), (0.12, 0.08), (0, 0.22), (0, -0.05))):
			parts.append(sphere(f"lv{i}", 0.1, (dx, 1.0 * s + dy, 0.9 * s), acc_m, 14, 8))
	elif g == "gold":
		parts.append(cyl("coin", 0.15, 0.05, (0.35 * s, 0.5 * s, 0.7 * s), acc_m, 20, (0, math.pi / 2, 0)))
	return parts


def wing_complex(parts, material, membrane_m, sign, tag, root, span=1.8, lift=0.0, s=1.0):
	"""Multi-bone wing with membrane panels — SAE Ice Dragon language."""
	rx, ry, rz = root
	bones = [
		(0.55, 0.12, 0.12, 0.0, 0.15),
		(0.7, 0.1, 0.1, 0.2, 0.25),
		(0.55, 0.08, 0.08, 0.35, 0.3),
		(0.35, 0.07, 0.07, 0.45, 0.22),
	]
	cursor = 0.0
	joints = []
	for i, (length, bw, bh, pitch, flare) in enumerate(bones):
		length *= span * 0.35 * s
		bw *= s
		bh *= s
		x = rx + sign * (0.35 * s + cursor + length * 0.5)
		y = ry - i * 0.08 * s
		z = rz + lift + i * pitch * s
		w = box(f"bone{tag}{i}", (length, bw, bh), (x, y, z), material, bevel=0.02, segs=2, rot=(0.1, sign * flare, sign * 0.05))
		parts.append(w)
		joints.append((x, y, z, length))
		cursor += length * 0.85
		# claw at joint
		parts.append(cone(f"claw{tag}{i}", 0.05 * s, 0.14 * s, (x + sign * length * 0.4, y, z + 0.08 * s), material, 10))
	# membrane panels between bones
	for i in range(len(joints) - 1):
		x0, y0, z0, _ = joints[i]
		x1, y1, z1, _ = joints[i + 1]
		mx = (x0 + x1) * 0.5
		my = (y0 + y1) * 0.5 - 0.15 * s
		mz = (z0 + z1) * 0.5 - 0.1 * s
		parts.append(box(f"mem{tag}{i}", (abs(x1 - x0) * 0.9, 0.06, abs(z1 - z0) * 0.5 + 0.45 * s), (mx, my, mz), membrane_m, bevel=0.015, segs=2, rot=(0.25, sign * 0.3, 0)))
	return joints


def build_flyer(spec, body_m, acc_m, eye_m, white_m, dark_m, tongue_m):
	s = spec.get("scale", 1.0)
	d = spec.get("detail", 3)
	span = spec.get("wing_span", 1.7)
	parts = []
	parts.append(box("body", (0.8 * s, 0.7 * s, 1.0 * s), (0, 0, 1.1 * s), body_m, bevel=0.045, segs=4))
	stud_block(parts, body_m, 0, 0, 1.1 * s, 0.4 * s, 0.35 * s, 0.5 * s, density=d, size=0.1)
	parts.append(box("belly", (0.55 * s, 0.2, 0.7 * s), (0, 0.4 * s, 1.0 * s), white_m, bevel=0.03, segs=3))
	parts.append(box("head", (0.72 * s, 0.72 * s, 0.72 * s), (0, 0.25, 1.9 * s), body_m, bevel=0.04, segs=4))
	stud_block(parts, body_m, 0, 0.25, 1.9 * s, 0.36 * s, 0.36 * s, 0.36 * s, density=max(2, d - 1), size=0.1)
	eye_sz = 0.26 * s if spec.get("big_eyes") else 0.18 * s
	face_eyes(parts, 0.62 * s, 1.95 * s, eye_m, white_m, spacing=0.22 * s, size=eye_sz)
	parts.append(box("beak", (0.2 * s, 0.38 * s, 0.18 * s), (0, 0.7 * s, 1.8 * s), acc_m, bevel=0.025, segs=3))
	parts.append(box("beakTip", (0.12 * s, 0.16 * s, 0.1 * s), (0, 0.92 * s, 1.75 * s), acc_m, bevel=0.015, segs=2))
	mem = mat(spec["id"] + "_mem", tuple(min(1, c + 0.2) for c in spec.get("accent", (0.8, 0.8, 0.9))), 0.22, 0.05, 0.6)
	wing_complex(parts, acc_m, mem, -1, "L", (0, 0, 1.2 * s), span=span, s=s)
	wing_complex(parts, acc_m, mem, 1, "R", (0, 0, 1.2 * s), span=span, s=s)
	for i in range(5):
		parts.append(box(f"tf{i}", (0.1, 0.14, 0.5 + i * 0.06), (-0.28 + i * 0.14, -0.5, 0.7 * s), acc_m, bevel=0.02, segs=2, rot=(0.3, 0, 0)))
	for sign, tag in ((-1, "L"), (1, "R")):
		parts.append(box(f"thigh{tag}", (0.12, 0.12, 0.28), (sign * 0.2, 0.05, 0.45), acc_m, bevel=0.015, segs=2))
		toe_foot(parts, sign * 0.2, 0.15, 0.05, acc_m, white_m, scale=0.85, toes=3)
	if spec.get("tuft"):
		for sign in (-1, 1):
			parts.append(box(f"tuft{sign}", (0.12, 0.12, 0.35), (sign * 0.22, 0.15, 2.4 * s), body_m, bevel=0.02, segs=2))
	g = spec.get("gimmick")
	if g == "laser":
		parts.append(cyl("las", 0.06, 0.7, (0, 0.9 * s, 1.8 * s), mat(spec["id"] + "_L", (1, 0.25, 0.3), 0.12, 0.1, 0.7, 1.5), 16, (math.pi / 2, 0, 0)))
	elif g == "rainbow":
		for i, c in enumerate([(1, 0.25, 0.35), (1, 0.55, 0.15), (1, 0.9, 0.2), (0.3, 0.9, 0.4), (0.3, 0.5, 1), (0.6, 0.3, 1)]):
			parts.append(box(f"rb{i}", (0.1, 0.1, 0.28), (-0.35 + i * 0.14, -0.6, 0.95 * s), mat(f"rb{i}", c, 0.2, 0.05, 0.6, 0.3), bevel=0.015, segs=2))
	return parts


def build_gorilla(spec, body_m, acc_m, eye_m, white_m, dark_m, tongue_m):
	s = spec.get("scale", 1.0)
	d = spec.get("detail", 3)
	parts = []
	parts.append(box("body", (1.15 * s, 0.8 * s, 1.1 * s), (0, 0, 0.85 * s), body_m, bevel=0.05, segs=4))
	stud_block(parts, body_m, 0, 0, 0.85 * s, 0.575 * s, 0.4 * s, 0.55 * s, density=d, size=0.12)
	parts.append(box("chest", (0.85 * s, 0.25, 0.7 * s), (0, 0.45 * s, 0.9 * s), white_m, bevel=0.035, segs=3))
	parts.append(box("head", (0.9 * s, 0.8 * s, 0.8 * s), (0, 0.2, 1.7 * s), body_m, bevel=0.045, segs=4))
	stud_block(parts, body_m, 0, 0.2, 1.7 * s, 0.45 * s, 0.4 * s, 0.4 * s, density=max(2, d - 1), size=0.11)
	parts.append(box("brow", (0.85 * s, 0.2, 0.18), (0, 0.5 * s, 1.95 * s), dark_m, bevel=0.025, segs=2))
	parts.append(box("muzzle", (0.6 * s, 0.45 * s, 0.4 * s), (0, 0.6 * s, 1.5 * s), dark_m, bevel=0.035, segs=3))
	face_eyes(parts, 0.62 * s, 1.85 * s, eye_m, white_m, spacing=0.24 * s, size=0.16 * s)
	open_mouth(parts, 0.85 * s, 1.4 * s, 0.35 * s, dark_m, white_m, tongue_m, teeth=4)
	for sign in (-1, 1):
		parts.append(sphere(f"ear{sign}", 0.14 * s, (sign * 0.55 * s, 0.1, 1.75 * s), body_m, 16, 10))
		# big arms with knuckles
		parts.append(box(f"upperArm{sign}", (0.32 * s, 0.35 * s, 0.55 * s), (sign * 0.8 * s, 0.25, 1.0 * s), body_m, bevel=0.035, segs=3))
		parts.append(box(f"foreArm{sign}", (0.28 * s, 0.32 * s, 0.55 * s), (sign * 0.85 * s, 0.4, 0.5 * s), body_m, bevel=0.03, segs=3))
		parts.append(box(f"hand{sign}", (0.32 * s, 0.4 * s, 0.18), (sign * 0.85 * s, 0.55, 0.15), white_m, bevel=0.025, segs=2))
		for t in range(4):
			parts.append(box(f"knuckle{sign}{t}", (0.06, 0.1, 0.08), (sign * 0.85 * s + (t - 1.5) * 0.07, 0.75, 0.12), white_m, bevel=0.01, segs=1))
	for i, (dx, dy) in enumerate(((-0.3, 0.15), (0.3, 0.15))):
		parts.append(box(f"leg{i}", (0.3 * s, 0.3 * s, 0.45 * s), (dx * s, dy * s, 0.3 * s), body_m, bevel=0.03, segs=3))
		toe_foot(parts, dx * s, dy * s + 0.1, 0.05, body_m, white_m, scale=1.15, toes=3)
	return parts


def build_shark(spec, body_m, acc_m, eye_m, white_m, dark_m, tongue_m):
	s = spec.get("scale", 1.0)
	d = spec.get("detail", 3)
	parts = []
	for i, (dy, sc) in enumerate([(0.5, 1.0), (0.0, 1.1), (-0.5, 0.95), (-0.95, 0.75)]):
		parts.append(box(f"seg{i}", (0.7 * s * sc, 0.55 * s, 0.6 * s * sc), (0, dy * s, 0.55 * s), body_m, bevel=0.04, segs=4))
	stud_block(parts, body_m, 0, 0, 0.55 * s, 0.35 * s, 0.7 * s, 0.3 * s, density=d, size=0.1)
	parts.append(box("belly", (0.55 * s, 1.6 * s, 0.22), (0, 0.05, 0.22), white_m, bevel=0.03, segs=3))
	parts.append(box("head", (0.72 * s, 0.65 * s, 0.58 * s), (0, 1.05 * s, 0.55 * s), body_m, bevel=0.04, segs=4))
	face_eyes(parts, 1.4 * s, 0.7 * s, eye_m, white_m, spacing=0.24 * s, size=0.16 * s)
	open_mouth(parts, 1.4 * s, 0.35 * s, 0.45 * s, dark_m, white_m, None, teeth=6)
	# gills
	for i in range(4):
		parts.append(box(f"gillL{i}", (0.04, 0.02, 0.18), (-0.4 * s, 0.7 * s - i * 0.08, 0.55 * s), dark_m, bevel=0.008, segs=1))
		parts.append(box(f"gillR{i}", (0.04, 0.02, 0.18), (0.4 * s, 0.7 * s - i * 0.08, 0.55 * s), dark_m, bevel=0.008, segs=1))
	parts.append(box("dorsal", (0.12, 0.4, 0.65 * s), (0, 0.1, 1.25 * s), acc_m, bevel=0.025, segs=3, rot=(0.15, 0, 0)))
	parts.append(box("dorsal2", (0.08, 0.25, 0.35 * s), (0, -0.4, 1.0 * s), acc_m, bevel=0.02, segs=2))
	parts.append(box("tailU", (0.1, 0.35, 0.55 * s), (0, -1.25 * s, 0.95 * s), acc_m, bevel=0.025, segs=3))
	parts.append(box("tailL", (0.1, 0.3, 0.4 * s), (0, -1.2 * s, 0.35 * s), acc_m, bevel=0.025, segs=3))
	parts.append(box("finL", (0.55 * s, 0.12, 0.25), (-0.65 * s, 0.25, 0.4 * s), acc_m, bevel=0.02, segs=2, rot=(0, 0.3, -0.2)))
	parts.append(box("finR", (0.55 * s, 0.12, 0.25), (0.65 * s, 0.25, 0.4 * s), acc_m, bevel=0.02, segs=2, rot=(0, -0.3, 0.2)))
	laser = mat(spec["id"] + "_L", (1, 0.2, 0.28), 0.12, 0.1, 0.8, 2.0)
	parts.append(cyl("las", 0.08, 0.9, (0, 1.55 * s, 0.55 * s), laser, 20, (math.pi / 2, 0, 0)))
	parts.append(sphere("beamTip", 0.12, (0, 2.05 * s, 0.55 * s), laser, 16, 10))
	return parts


def build_dragon(spec, body_m, acc_m, eye_m, white_m, dark_m, tongue_m):
	"""Mythic — Ice/Cosmic/Phoenix density."""
	s = spec.get("scale", 1.0)
	d = spec.get("detail", 4)
	flame = mat(spec["id"] + "_F", spec.get("flame", (1.0, 0.45, 0.15)), 0.2, 0.05, 0.55, 0.6)
	glow = mat(spec["id"] + "_G", spec.get("glow", (0.4, 1.0, 1.0)), 0.1, 0.25, 0.85, 1.8)
	mem = mat(spec["id"] + "_mem", spec.get("glow", (0.5, 0.95, 1.0)), 0.15, 0.1, 0.7, 0.5)
	parts = []

	# torso plates
	parts.append(box("torso", (1.1 * s, 1.0 * s, 1.2 * s), (0, 0, 1.3 * s), body_m, bevel=0.05, segs=4))
	stud_block(parts, body_m, 0, 0, 1.3 * s, 0.55 * s, 0.5 * s, 0.6 * s, density=d, size=0.12)
	armor_shell(parts, body_m, 0, 0, 1.3 * s, 1.1 * s, 1.0 * s, 1.2 * s, layers=4)
	# rib / belly plates
	for i in range(5):
		parts.append(box(f"rib{i}", (0.7 * s - i * 0.04, 0.12, 0.18), (0, 0.55 * s, (0.95 + i * 0.16) * s), white_m, bevel=0.02, segs=2))
	parts.append(box("chest", (0.75 * s, 0.25, 0.9 * s), (0, 0.55 * s, 1.25 * s), white_m, bevel=0.035, segs=3))
	# glowing chest stars
	for i, (dx, dz, sc) in enumerate([(0, 0.15, 0.28), (-0.25, -0.1, 0.14), (0.25, -0.1, 0.14), (0, -0.3, 0.12), (-0.35, 0.2, 0.1), (0.35, 0.2, 0.1)]):
		parts.append(box(f"star{i}", (sc, 0.08, sc), (dx * s, 0.7 * s, (1.3 + dz) * s), glow, bevel=0.02, segs=2, rot=(0, 0, math.pi / 4)))

	# segmented neck — denser
	for i in range(7):
		sc = 1.0 - i * 0.06
		parts.append(box(f"neck{i}", (0.52 * s * sc, 0.4 * s * sc, 0.28 * s), (0, 0.32 * s + i * 0.16, 1.95 * s + i * 0.24), body_m, bevel=0.03, segs=3))
		parts.append(box(f"throat{i}", (0.36 * s * sc, 0.1, 0.22 * s), (0, 0.52 * s + i * 0.16, 1.9 * s + i * 0.24), white_m, bevel=0.02, segs=2))
		parts.append(box(f"nape{i}", (0.2 * s * sc, 0.08, 0.16 * s), (0, 0.15 * s + i * 0.16, 2.1 * s + i * 0.24), glow, bevel=0.015, segs=2))

	# head
	parts.append(box("head", (0.8 * s, 0.85 * s, 0.65 * s), (0, 1.4 * s, 3.55 * s), body_m, bevel=0.045, segs=4))
	stud_block(parts, body_m, 0, 1.4 * s, 3.55 * s, 0.4 * s, 0.425 * s, 0.325 * s, density=3, size=0.1)
	cheek_brow(parts, body_m, glow, 1.4 * s, 3.55 * s, 0.8 * s, s)
	parts.append(box("snout", (0.55 * s, 0.55 * s, 0.4 * s), (0, 1.9 * s, 3.4 * s), body_m, bevel=0.035, segs=3))
	parts.append(box("snoutRidge", (0.2 * s, 0.4 * s, 0.12), (0, 1.95 * s, 3.6 * s), glow, bevel=0.02, segs=2))
	parts.append(box("jaw", (0.5 * s, 0.4 * s, 0.22 * s), (0, 1.85 * s, 3.15 * s), body_m, bevel=0.03, segs=3))
	open_mouth(parts, 2.1 * s, 3.25 * s, 0.4 * s, dark_m, white_m, tongue_m or mat(spec["id"] + "_tong", (1, 0.3, 0.35), 0.4), teeth=6)
	face_eyes(parts, 1.85 * s, 3.7 * s, eye_m, white_m, spacing=0.24 * s, size=0.18 * s)

	# horns + crest
	for sign in (-1, 1):
		parts.append(box(f"horn{sign}", (0.14, 0.14, 0.65 * s), (sign * 0.28 * s, 1.25 * s, 4.05 * s), glow, bevel=0.02, segs=3, rot=(0.4, sign * 0.25, 0)))
		parts.append(box(f"hornMid{sign}", (0.1, 0.1, 0.35 * s), (sign * 0.38 * s, 1.1 * s, 4.45 * s), glow, bevel=0.015, segs=2, rot=(0.55, sign * 0.3, 0)))
		parts.append(box(f"hornTip{sign}", (0.07, 0.07, 0.22 * s), (sign * 0.45 * s, 0.95 * s, 4.7 * s), glow, bevel=0.012, segs=2, rot=(0.65, sign * 0.35, 0)))
	for i in range(9):
		parts.append(box(f"crest{i}", (0.1, 0.1, 0.32 + i * 0.06), (-0.4 + i * 0.1, 1.2, 4.1 * s), flame, bevel=0.015, segs=2))

	# spine spikes denser
	spine_plates(parts, glow, [(0, -0.05 * s - i * 0.12, 2.05 * s - i * 0.06) for i in range(12)], (0.12, 0.1, 0.3))

	# complex wings
	wing_complex(parts, body_m, mem, -1, "L", (0, 0.1, 1.6 * s), span=2.5, lift=0.2, s=s)
	wing_complex(parts, body_m, mem, 1, "R", (0, 0.1, 1.6 * s), span=2.5, lift=0.2, s=s)
	# extra flame wing overlays
	for sign, tag in ((-1, "L"), (1, "R")):
		for i in range(5):
			parts.append(box(f"flameW{tag}{i}", (0.48 * s, 0.08, 0.32 * s), (sign * (1.15 + i * 0.42) * s, -0.3 - i * 0.05, (1.75 + i * 0.14) * s), flame, bevel=0.015, segs=2, rot=(0.2, sign * (0.4 + i * 0.1), 0)))

	# flame tail plumes
	for i in range(11):
		parts.append(box(f"plume{i}", (0.14, 0.16, 0.9 + i * 0.1), (-0.6 + i * 0.12, -0.95 - i * 0.11, (1.0 + i * 0.04) * s), flame, bevel=0.02, segs=2, rot=(0.35, 0, 0)))

	# legs with claws
	for sign in (-1, 1):
		parts.append(box(f"thigh{sign}", (0.32 * s, 0.35 * s, 0.55 * s), (sign * 0.4 * s, 0.25, 0.55 * s), body_m, bevel=0.03, segs=3))
		parts.append(box(f"knee{sign}", (0.28 * s, 0.28 * s, 0.22 * s), (sign * 0.42 * s, 0.32, 0.35 * s), body_m, bevel=0.025, segs=2))
		parts.append(box(f"shin{sign}", (0.26 * s, 0.28 * s, 0.45 * s), (sign * 0.42 * s, 0.35, 0.22 * s), body_m, bevel=0.025, segs=3))
		toe_foot(parts, sign * 0.42 * s, 0.45, 0.06, body_m, white_m, scale=1.3, toes=4)
		for t in range(4):
			parts.append(cone(f"claw{sign}{t}", 0.04, 0.14, (sign * 0.42 * s + (t - 1.5) * 0.1, 0.7, 0.1), dark_m, 10, (math.pi / 2, 0, 0)))

	# floating shard ornaments
	for i, (dx, dy, dz) in enumerate([(-1.3, -0.2, 2.3), (1.3, -0.2, 2.3), (-0.9, 0.3, 2.9), (0.9, 0.3, 2.9), (-1.5, 0.1, 1.8), (1.5, 0.1, 1.8), (0, -0.5, 2.5)]):
		parts.append(box(f"shard{i}", (0.1, 0.1, 0.4), (dx * s, dy * s, dz * s), glow, bevel=0.015, segs=2, rot=(0.3, 0.2 * i, 0.4)))

	return parts


def fx_ring(parts, material, z, radius=0.85, thick=0.08, segs=24):
	"""Horizontal halo torus under / around pet."""
	bpy.ops.mesh.primitive_torus_add(
		major_radius=radius,
		minor_radius=thick * 0.55,
		major_segments=segs,
		minor_segments=10,
		location=(0, 0, z),
	)
	o = bpy.context.active_object
	o.name = "halo"
	assign(o, material)
	finish(o, 0.01, 2, 0)
	parts.append(o)


def fx_orbit_orbs(parts, material, z, count=6, radius=1.1, size=0.12):
	for i in range(count):
		a = i * math.tau / count
		parts.append(sphere(f"orb{i}", size, (math.cos(a) * radius, math.sin(a) * radius * 0.55, z + math.sin(a * 2) * 0.15), material, 16, 10))


def fx_bolt_arc(parts, material, x, y, z, scale=1.0):
	"""Zigzag lightning bolt floating beside pet."""
	pts = [(0, 0, 0.5), (0.15, 0, 0.2), (-0.1, 0, 0.0), (0.12, 0, -0.25), (-0.05, 0, -0.5)]
	for i, (dx, dy, dz) in enumerate(pts[:-1]):
		nx, ny, nz = pts[i + 1]
		mx, my, mz = (dx + nx) * 0.5, (dy + ny) * 0.5, (dz + nz) * 0.5
		parts.append(box(f"bolt{i}", (0.1 * scale, 0.08 * scale, abs(nz - dz) * scale + 0.12), (x + mx * scale, y + my * scale, z + mz * scale), material, bevel=0.02, segs=2))


def fx_spark_field(parts, material, count=12, radius=1.0, z=1.2):
	for i in range(count):
		a = i * math.tau / count + i * 0.3
		r = radius * (0.55 + (i % 3) * 0.2)
		parts.append(box(f"spark{i}", (0.08, 0.08, 0.18), (math.cos(a) * r, math.sin(a) * r * 0.6, z + (i % 4) * 0.18), material, bevel=0.01, segs=1, rot=(0.4, 0.2 * i, 0.5)))


def fx_wisp_trail(parts, material, count=8):
	for i in range(count):
		parts.append(sphere(f"wisp{i}", 0.1 - i * 0.008, (0.15 * math.sin(i), -0.4 - i * 0.18, 0.7 + i * 0.12), material, 14, 8))


def fx_laser_beams(parts, material, count=3):
	for i in range(count):
		a = -0.4 + i * 0.4
		parts.append(cyl(f"beam{i}", 0.05, 1.4, (a * 0.3, 1.2 + i * 0.05, 0.9 + i * 0.15), material, 12, (math.pi / 2 + a * 0.2, a * 0.15, 0)))
		parts.append(sphere(f"beamTip{i}", 0.1, (a * 0.3, 1.9 + i * 0.05, 0.9 + i * 0.15), material, 12, 8))


def fx_keycap_orbit(parts, material, accent_m, z=1.6):
	"""THOCK signature: tiny floating keycaps."""
	for i, ang in enumerate((0.3, 2.1, 4.0)):
		x, y = math.cos(ang) * 1.0, math.sin(ang) * 0.7
		parts.append(box(f"fkey{i}", (0.28, 0.28, 0.14), (x, y, z + i * 0.12), material, bevel=0.02, segs=2))
		parts.append(box(f"fleg{i}", (0.14, 0.08, 0.04), (x, y + 0.02, z + i * 0.12 + 0.1), accent_m, bevel=0.01, segs=1))


def fx_diamond_crown(parts, material, z=3.8):
	for i in range(6):
		a = i * math.tau / 6
		parts.append(box(f"dia{i}", (0.14, 0.14, 0.28), (math.cos(a) * 0.45, math.sin(a) * 0.45, z), material, bevel=0.015, segs=2, rot=(0, 0, math.pi / 4)))
	parts.append(sphere("diaCore", 0.16, (0, 0, z + 0.2), material, 16, 10))


def apply_rarity_fx(parts, spec, pid):
	"""Legendary+ mesh FX — THOCK flavored, not SAE clones."""
	rarity = spec.get("rarity", "Common")
	if rarity not in {"Legendary", "Mythic"}:
		return
	fx = spec.get("fx", "gold")
	s = spec.get("scale", 1.0)
	glow_c = spec.get("fx_color", (1.0, 0.85, 0.3))
	glow = mat(pid + "_FX", glow_c, 0.12, 0.15, 0.85, 2.2)
	soft = mat(pid + "_FXS", tuple(min(1, c + 0.15) for c in glow_c), 0.2, 0.05, 0.7, 1.0)
	gold = mat(pid + "_FXG", (1.0, 0.82, 0.25), 0.15, 0.7, 0.6, 0.8)

	# shared ground halo + orbit
	fx_ring(parts, glow, 0.08, radius=0.95 * s, thick=0.07)
	fx_orbit_orbs(parts, soft, 1.35 * s, count=7 if rarity == "Mythic" else 5, radius=1.15 * s, size=0.11 * s)

	if fx == "gold":
		fx_spark_field(parts, gold, count=14, radius=1.15 * s, z=1.1 * s)
		fx_keycap_orbit(parts, gold, soft, z=1.85 * s)
	elif fx == "luck":
		# floating clovers
		for i, a in enumerate((0.5, 2.2, 3.8, 5.2)):
			x, y = math.cos(a) * 1.05 * s, math.sin(a) * 0.7 * s
			for j, (dx, dy) in enumerate(((-0.1, 0.06), (0.1, 0.06), (0, 0.16), (0, -0.05))):
				parts.append(sphere(f"clv{i}{j}", 0.08, (x + dx, y + dy, 1.7 * s + i * 0.08), glow, 12, 8))
		fx_keycap_orbit(parts, gold, glow, z=2.0 * s)
	elif fx == "bolt":
		fx_bolt_arc(parts, glow, 1.15 * s, 0.2, 1.6 * s, scale=s)
		fx_bolt_arc(parts, soft, -1.2 * s, -0.1, 1.4 * s, scale=0.85 * s)
		fx_spark_field(parts, glow, count=10, radius=1.2 * s, z=1.3 * s)
	elif fx == "midas":
		fx_spark_field(parts, gold, count=16, radius=1.25 * s, z=1.4 * s)
		fx_ring(parts, gold, 0.22, radius=1.15 * s, thick=0.05)
		for i in range(5):
			parts.append(cyl(f"coin{i}", 0.12, 0.04, (math.cos(i) * 1.0, math.sin(i) * 0.7, 1.5 + i * 0.15), gold, 16, (0, math.pi / 2, i * 0.4)))
	elif fx == "phantom":
		fx_wisp_trail(parts, soft, count=9)
		fx_orbit_orbs(parts, glow, 2.0 * s, count=4, radius=0.7 * s, size=0.08)
		# translucent-looking shell plates offset
		for i, a in enumerate((0.8, 2.5, 4.2)):
			parts.append(box(f"ghost{i}", (0.35, 0.08, 0.5), (math.cos(a) * 0.7, math.sin(a) * 0.5, 1.2 * s), soft, bevel=0.02, segs=2, rot=(0.2, a, 0)))
	elif fx == "laser":
		fx_laser_beams(parts, glow, count=3)
		fx_ring(parts, glow, 0.18, radius=1.2 * s, thick=0.06)
		fx_spark_field(parts, soft, count=8, radius=1.3 * s, z=0.9 * s)
	elif fx == "mythic":
		fx_diamond_crown(parts, glow, z=4.6 * s)
		fx_spark_field(parts, soft, count=18, radius=1.5 * s, z=1.8 * s)
		fx_ring(parts, glow, 0.12, radius=1.35 * s, thick=0.08)
		fx_ring(parts, soft, 0.28, radius=1.55 * s, thick=0.05)
		fx_keycap_orbit(parts, glow, soft, z=2.4 * s)
		fx_bolt_arc(parts, glow, 1.6 * s, 0.3, 2.5 * s, scale=1.1 * s)
		for i in range(8):
			a = i * math.tau / 8
			parts.append(box(f"crystal{i}", (0.12, 0.12, 0.45), (math.cos(a) * 1.4 * s, math.sin(a) * 0.9 * s, 2.2 * s), glow, bevel=0.015, segs=2, rot=(0.5, a, 0.3)))


BUILDERS = {
	"biped": build_biped,
	"quad": build_quad,
	"frog": build_frog,
	"lizard": build_lizard,
	"flyer": build_flyer,
	"gorilla": build_gorilla,
	"shark": build_shark,
	"dragon": build_dragon,
}


def build_pet(spec):
	pid = spec["id"]
	color = spec["color"]
	accent = spec.get("accent", tuple(min(1, c + 0.15) for c in color))
	body_m = mat(pid + "_B", color, 0.28, spec.get("metallic", 0.0), 0.55)
	acc_m = mat(pid + "_A", accent, 0.24, spec.get("accent_metal", 0.0), 0.6)
	eye_m = mat(pid + "_E", (0.04, 0.04, 0.05), 0.5)
	white_m = mat(pid + "_W", (0.96, 0.96, 0.98), 0.32, 0.0, 0.4)
	dark_m = mat(pid + "_D", (0.08, 0.07, 0.1), 0.45)
	tongue_m = mat(pid + "_T", (0.95, 0.35, 0.4), 0.4)
	parts = BUILDERS[spec["kind"]](spec, body_m, acc_m, eye_m, white_m, dark_m, tongue_m)
	apply_rarity_fx(parts, spec, pid)
	obj = join_parts(parts, pid)
	print("VERTS", pid, len(obj.data.vertices), spec.get("rarity", "?"), spec.get("fx", "-"))
	return obj


def pet_specs():
	g = lambda *rgb: tuple(c / 255 for c in rgb)
	return [
		# Common — clean THOCK starters
		{"id": "KeycapKitty", "charm_id": "KeycapPin", "rarity": "Common", "kind": "quad", "color": g(235, 185, 120), "accent": g(120, 185, 245), "ears": "point", "tail": "blob", "gimmick": "keycap", "snout_accent": True, "forehead": True, "detail": 3},
		{"id": "ClickyChick", "charm_id": "CloverFob", "rarity": "Common", "kind": "biped", "color": g(255, 248, 235), "accent": g(235, 70, 55), "comb": True, "detail": 3},
		{"id": "ThockPup", "charm_id": "TinySwitch", "rarity": "Common", "kind": "quad", "color": g(230, 130, 140), "accent": g(255, 210, 195), "ears": "floppy", "tail": "blob", "gimmick": "collar", "snout_accent": True, "forehead": True, "detail": 3},
		# Uncommon
		{"id": "BrassBear", "charm_id": "BrassStab", "rarity": "Uncommon", "kind": "quad", "color": g(210, 155, 65), "accent": g(255, 215, 90), "metallic": 0.45, "ears": "round", "tail": "none", "body_w": 1.1, "body_d": 0.95, "head": 1.05, "detail": 3},
		{"id": "LuckyFrog", "charm_id": "LuckyLube", "rarity": "Uncommon", "kind": "frog", "color": g(50, 185, 75), "accent": g(255, 235, 55), "detail": 3},
		{"id": "SpringSquirrel", "charm_id": "QuickSpring", "rarity": "Uncommon", "kind": "quad", "color": g(210, 120, 55), "accent": g(240, 220, 185), "ears": "point", "tail": "bush", "gimmick": "spring", "body_d": 0.85, "snout_accent": True, "detail": 3},
		{"id": "GoldenHamster", "charm_id": "GoldenTick", "rarity": "Uncommon", "kind": "quad", "color": g(255, 205, 70), "accent": g(255, 235, 130), "metallic": 0.4, "ears": "round", "tail": "none", "gimmick": "coin", "body_w": 0.95, "body_d": 0.8, "head": 1.1, "detail": 3},
		# Rare
		{"id": "ThockPanda", "charm_id": "ThockPad", "rarity": "Rare", "kind": "quad", "color": g(252, 252, 255), "accent": g(28, 28, 34), "ears": "round", "mask": True, "tail": "none", "body_w": 1.1, "dark_spots": True, "spots": True, "detail": 4},
		{"id": "LuckyLizard", "charm_id": "LuckyCable", "rarity": "Rare", "kind": "lizard", "color": g(75, 220, 115), "accent": g(255, 225, 50), "spots": True, "gimmick": "clover", "detail": 3},
		{"id": "TurboHare", "charm_id": "TurboSpring", "rarity": "Rare", "kind": "quad", "color": g(240, 220, 200), "accent": g(255, 85, 60), "ears": "long", "tail": "blob", "gimmick": "bolt", "forehead": True, "detail": 4},
		{"id": "GoldGecko", "charm_id": "GoldTab", "rarity": "Rare", "kind": "lizard", "color": g(255, 200, 55), "accent": g(255, 235, 130), "metallic": 0.45, "spots": True, "gimmick": "gold", "detail": 3},
		{"id": "StickyRaccoon", "charm_id": "StickyFingers", "rarity": "Rare", "kind": "quad", "color": g(115, 150, 195), "accent": g(220, 235, 255), "ears": "diamond", "mask": True, "tail": "stripe", "gimmick": "sticky", "snout_accent": True, "forehead": True, "detail": 4},
		{"id": "LaserOwl", "charm_id": "LaserLens", "rarity": "Rare", "kind": "flyer", "color": g(100, 75, 52), "accent": g(255, 90, 100), "big_eyes": True, "tuft": True, "gimmick": "laser", "wing_span": 1.8, "detail": 4},
		# Epic
		{"id": "RainbowParrot", "charm_id": "RainbowCoil", "rarity": "Epic", "kind": "flyer", "color": g(255, 85, 120), "accent": g(55, 210, 255), "gimmick": "rainbow", "wing_span": 2.0, "scale": 1.12, "detail": 4},
		{"id": "FourLeafFawn", "charm_id": "FourLeafCap", "rarity": "Epic", "kind": "quad", "color": g(205, 155, 100), "accent": g(65, 210, 90), "ears": "point", "spots": True, "tail": "blob", "gimmick": "antler", "body_d": 1.1, "forehead": True, "detail": 4},
		{"id": "SwitchFox", "charm_id": "HyperSwitch", "rarity": "Epic", "kind": "quad", "color": g(240, 115, 45), "accent": g(55, 180, 255), "ears": "point", "tail": "bush", "gimmick": "switch", "snout_accent": True, "forehead": True, "detail": 4},
		{"id": "GoldenGorilla", "charm_id": "GoldenGear", "rarity": "Epic", "kind": "gorilla", "color": g(255, 195, 55), "accent": g(255, 235, 130), "metallic": 0.5, "scale": 1.18, "detail": 4},
		{"id": "GhostFerret", "charm_id": "GhostHand", "rarity": "Epic", "kind": "lizard", "color": g(230, 240, 255), "accent": g(175, 130, 255), "scale": 1.12, "detail": 3},
		{"id": "LaserLynx", "charm_id": "LaserCore", "rarity": "Epic", "kind": "quad", "color": g(230, 165, 85), "accent": g(255, 75, 90), "ears": "point", "tail": "blob", "gimmick": "laser", "spots": True, "detail": 4},
		# Legendary — FX
		{"id": "SpacebarBunny", "charm_id": "GoldSpacebar", "rarity": "Legendary", "fx": "gold", "fx_color": g(255, 210, 70), "kind": "quad", "color": g(250, 242, 248), "accent": g(255, 205, 55), "ears": "long", "tail": "blob", "gimmick": "spacebar", "scale": 1.12, "forehead": True, "detail": 4},
		{"id": "CrownKoala", "charm_id": "CloverCrown", "rarity": "Legendary", "fx": "luck", "fx_color": g(90, 230, 110), "kind": "quad", "color": g(190, 190, 198), "accent": g(255, 205, 55), "ears": "round", "tail": "none", "gimmick": "crown", "head": 1.12, "body_d": 0.75, "detail": 4},
		{"id": "LightningLeopard", "charm_id": "LightningSwitch", "rarity": "Legendary", "fx": "bolt", "fx_color": g(255, 230, 80), "kind": "quad", "color": g(250, 190, 65), "accent": g(255, 240, 100), "ears": "round", "spots": True, "dark_spots": True, "tail": "long", "gimmick": "bolt", "scale": 1.18, "body_d": 1.3, "detail": 4},
		{"id": "GoldenGoose", "charm_id": "MidasKey", "rarity": "Legendary", "fx": "midas", "fx_color": g(255, 215, 80), "kind": "biped", "color": g(255, 210, 70), "accent": g(255, 245, 160), "metallic": 0.5, "crest": 6, "scale": 1.28, "detail": 4},
		{"id": "PhantomWolf", "charm_id": "PhantomPaw", "rarity": "Legendary", "fx": "phantom", "fx_color": g(180, 210, 255), "kind": "quad", "color": g(145, 155, 195), "accent": g(215, 230, 255), "ears": "point", "tail": "bush", "scale": 1.22, "body_d": 1.25, "snout_accent": True, "detail": 4},
		{"id": "MegaLaserShark", "charm_id": "MegaLaser", "rarity": "Legendary", "fx": "laser", "fx_color": g(255, 70, 110), "kind": "shark", "color": g(75, 135, 190), "accent": g(255, 75, 100), "scale": 1.32, "detail": 4},
		# Mythic
		{
			"id": "DiamondDragon",
			"charm_id": "DiamondSpacebar",
			"rarity": "Mythic",
			"fx": "mythic",
			"fx_color": g(80, 255, 255),
			"kind": "dragon",
			"color": g(150, 215, 255),
			"accent": g(90, 185, 255),
			"flame": g(255, 130, 45),
			"glow": g(50, 255, 255),
			"metallic": 0.25,
			"scale": 1.4,
			"detail": 5,
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
	scene = bpy.context.scene
	world = scene.world or bpy.data.worlds.new("World")
	scene.world = world
	world.use_nodes = True
	nt = world.node_tree
	nt.nodes.clear()
	bg = nt.nodes.new("ShaderNodeBackground")
	bg.inputs[0].default_value = (0.12, 0.08, 0.22, 1.0)
	bg.inputs[1].default_value = 0.35
	out = nt.nodes.new("ShaderNodeOutputWorld")
	nt.links.new(bg.outputs[0], out.inputs[0])
	if "Cam" not in bpy.data.objects:
		bpy.ops.object.camera_add()
		bpy.context.active_object.name = "Cam"
	scene.camera = bpy.data.objects["Cam"]
	lights = [
		("Area", (6, -9, 11), 750, 7),
		("Area.001", (-8, 5, 8), 320, 6),
		("Area.002", (2, 8, 4), 200, 5),
		("Area.003", (-3, -5, 14), 180, 10),
	]
	for name, loc, energy, size in lights:
		if name not in bpy.data.objects:
			bpy.ops.object.light_add(type="AREA", location=loc)
			bpy.context.active_object.name = name
		light = bpy.data.objects[name]
		light.location = loc
		light.data.energy = energy
		light.data.size = size


def layout_grid(objects, cols, gap=4.2):
	for i, obj in enumerate(objects):
		row, col = divmod(i, cols)
		obj.location = ((col - (cols - 1) / 2) * gap, -row * (gap + 1.0), 0)
		obj.rotation_euler = (0, 0, -0.45)


def world_bounds(objects):
	mins = Vector((1e9, 1e9, 1e9))
	maxs = Vector((-1e9, -1e9, -1e9))
	for obj in objects:
		for corner in obj.bound_box:
			w = obj.matrix_world @ Vector(corner)
			mins = Vector((min(mins.x, w.x), min(mins.y, w.y), min(mins.z, w.z)))
			maxs = Vector((max(maxs.x, w.x), max(maxs.y, w.y), max(maxs.z, w.z)))
	return mins, maxs


def render_sheet(objects, path, cols, gap=4.2):
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
	cam.location = (center.x + size * 0.35, center.y + size * 1.35, center.z + size * 0.42)
	cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
	cam.data.lens = 40
	scene = bpy.context.scene
	try:
		scene.render.engine = "BLENDER_EEVEE_NEXT"
	except Exception:
		scene.render.engine = "BLENDER_EEVEE"
	scene.render.resolution_x = 1920
	scene.render.resolution_y = 1080
	scene.render.filepath = path
	scene.render.image_settings.file_format = "PNG"
	scene.render.film_transparent = False
	try:
		scene.eevee.taa_render_samples = 96
	except Exception:
		pass
	os.makedirs(os.path.dirname(path), exist_ok=True)
	bpy.ops.render.render(write_still=True)
	for o in objects:
		o.hide_render = o.hide_viewport = False
	print("SHEET", path, len(objects))


def render_hero(obj, path):
	for o in bpy.data.objects:
		if o.type == "MESH":
			o.hide_render = o.hide_viewport = o != obj
	obj.hide_render = obj.hide_viewport = False
	obj.location = (0, 0, 0)
	obj.rotation_euler = (0, 0, -0.4)
	bpy.context.view_layer.update()
	mins, maxs = world_bounds([obj])
	center = (mins + maxs) * 0.5
	size = max(maxs.x - mins.x, maxs.y - mins.y, maxs.z - mins.z, 1.0)
	cam = bpy.data.objects["Cam"]
	cam.location = (center.x + size * 0.95, center.y + size * 1.55, center.z + size * 0.38)
	cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
	cam.data.lens = 50
	scene = bpy.context.scene
	scene.render.resolution_x = 1200
	scene.render.resolution_y = 1200
	scene.render.filepath = path
	bpy.ops.render.render(write_still=True)
	print("HERO", obj.name, "verts", len(obj.data.vertices))


def main():
	clear_pets()
	setup_stage()
	pet_objs = []
	pet_meta = []
	for spec in pet_specs():
		obj = build_pet(spec)
		export_obj(obj, PETS_DIR)
		export_obj(obj, os.path.join(OUT, "pets"))
		pet_objs.append(obj)
		pet_meta.append({"id": spec["id"], "charm_id": spec["charm_id"], "file": f"pets/{spec['id']}.obj", "kind": spec["kind"], "batch": "sae-hi", "verts": len(obj.data.vertices)})
		print("PET", spec["id"], spec["kind"], "verts", len(obj.data.vertices))

	json.dump({"pets": pet_meta, "style": "steal-an-egg-hi", "count": len(pet_meta)}, open(MANIFEST, "w", encoding="utf-8"), indent=2)
	main_manifest = os.path.join(OUT, "manifest.json")
	if os.path.isfile(main_manifest):
		old = json.load(open(main_manifest, encoding="utf-8"))
		old["pets"] = pet_meta
		json.dump(old, open(main_manifest, "w", encoding="utf-8"), indent=2)

	render_sheet(pet_objs[:7], os.path.join(PREVIEWS, "sae_pets_common_uncommon.png"), 7)
	render_sheet(pet_objs[7:13], os.path.join(PREVIEWS, "sae_pets_rare.png"), 6)
	render_sheet(pet_objs[13:19], os.path.join(PREVIEWS, "sae_pets_epic.png"), 6)
	render_sheet(pet_objs[19:], os.path.join(PREVIEWS, "sae_pets_legendary_mythic.png"), 7, gap=4.6)
	flyers = [o for o, s in zip(pet_objs, pet_specs()) if s["kind"] in {"flyer", "dragon", "shark", "biped"}]
	render_sheet(flyers, os.path.join(PREVIEWS, "sae_pets_flyers_flex.png"), min(5, len(flyers)), gap=4.8)
	render_sheet(pet_objs, os.path.join(PREVIEWS, "sae_pets_all.png"), 7, gap=4.4)
	for name in ("ClickyChick", "ThockPup", "StickyRaccoon", "DiamondDragon", "LaserOwl", "LuckyFrog", "RainbowParrot", "GoldenGorilla"):
		obj = bpy.data.objects.get(name)
		if obj:
			render_hero(obj, os.path.join(PREVIEWS, f"sae_hero_{name}.png"))
	print("DONE", len(pet_objs), "hi-detail SAE pets")


main()
