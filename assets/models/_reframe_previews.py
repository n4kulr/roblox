# Re-render all SAE pet previews on a dark contrasting backdrop.
import os
import bpy
from mathutils import Vector

PREVIEWS = r"C:\Users\zatch\dev\roblox\assets\models\previews"
PET_NAMES = [
	"KeycapKitty", "ClickyChick", "ThockPup", "BrassBear", "LuckyFrog", "SpringSquirrel", "GoldenHamster",
	"ThockPanda", "LuckyLizard", "TurboHare", "GoldGecko", "StickyRaccoon", "LaserOwl",
	"RainbowParrot", "FourLeafFawn", "SwitchFox", "GoldenGorilla", "GhostFerret", "LaserLynx",
	"SpacebarBunny", "CrownKoala", "LightningLeopard", "GoldenGoose", "PhantomWolf", "MegaLaserShark",
	"DiamondDragon",
]


def dark_stage():
	scene = bpy.context.scene
	world = scene.world or bpy.data.worlds.new("World")
	scene.world = world
	world.use_nodes = True
	nt = world.node_tree
	nt.nodes.clear()
	bg = nt.nodes.new("ShaderNodeBackground")
	# SAE-ish deep purple so pale pets pop
	bg.inputs[0].default_value = (0.12, 0.08, 0.22, 1.0)
	bg.inputs[1].default_value = 0.35
	out = nt.nodes.new("ShaderNodeOutputWorld")
	nt.links.new(bg.outputs[0], out.inputs[0])
	# punchy key / fill / rim
	specs = [
		("Area", (5, 8, 10), 900, 6),
		("Area.001", (-7, 4, 6), 350, 5),
		("Area.002", (2, -6, 5), 220, 4),
		("Area.003", (-2, 2, 14), 160, 12),
	]
	for name, loc, energy, size in specs:
		if name not in bpy.data.objects:
			bpy.ops.object.light_add(type="AREA", location=loc)
			bpy.context.active_object.name = name
		light = bpy.data.objects[name]
		light.location = loc
		light.data.energy = energy
		light.data.size = size
		try:
			light.data.color = (1.0, 0.97, 0.92)
		except Exception:
			pass


def world_bounds(objects):
	mins = Vector((1e9, 1e9, 1e9))
	maxs = Vector((-1e9, -1e9, -1e9))
	for obj in objects:
		for corner in obj.bound_box:
			w = obj.matrix_world @ Vector(corner)
			mins = Vector((min(mins.x, w.x), min(mins.y, w.y), min(mins.z, w.z)))
			maxs = Vector((max(maxs.x, w.x), max(maxs.y, w.y), max(maxs.z, w.z)))
	return mins, maxs


def layout_grid(objects, cols, gap=4.2):
	for i, obj in enumerate(objects):
		row, col = divmod(i, cols)
		obj.location = ((col - (cols - 1) / 2) * gap, -row * (gap + 1.0), 0)
		obj.rotation_euler = (0, 0, -0.45)


def setup_cam(center, size, hero=False):
	cam = bpy.data.objects["Cam"]
	if hero:
		cam.location = (center.x + size * 0.95, center.y + size * 1.55, center.z + size * 0.38)
		cam.data.lens = 50
	else:
		cam.location = (center.x + size * 0.35, center.y + size * 1.35, center.z + size * 0.42)
		cam.data.lens = 40
	cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
	bpy.context.scene.camera = cam


def prep_render(w=1920, h=1080, samples=96):
	scene = bpy.context.scene
	try:
		scene.render.engine = "BLENDER_EEVEE_NEXT"
	except Exception:
		scene.render.engine = "BLENDER_EEVEE"
	scene.render.resolution_x = w
	scene.render.resolution_y = h
	scene.render.film_transparent = False
	scene.render.image_settings.file_format = "PNG"
	try:
		scene.eevee.taa_render_samples = samples
	except Exception:
		pass


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
	setup_cam(center, size, hero=False)
	prep_render(1920, 1080, 96)
	bpy.context.scene.render.filepath = path
	bpy.ops.render.render(write_still=True)
	for o in objects:
		o.hide_render = o.hide_viewport = False
	print("SHEET", path)


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
	setup_cam(center, size, hero=True)
	prep_render(1200, 1200, 96)
	bpy.context.scene.render.filepath = path
	bpy.ops.render.render(write_still=True)
	print("HERO", obj.name)


def main():
	dark_stage()
	pets = []
	for name in PET_NAMES:
		o = bpy.data.objects.get(name)
		if o:
			pets.append(o)
		else:
			print("MISSING", name)
	print("FOUND", len(pets))
	os.makedirs(PREVIEWS, exist_ok=True)
	render_sheet(pets[:7], os.path.join(PREVIEWS, "sae_pets_common_uncommon.png"), 7)
	render_sheet(pets[7:13], os.path.join(PREVIEWS, "sae_pets_rare.png"), 6)
	render_sheet(pets[13:19], os.path.join(PREVIEWS, "sae_pets_epic.png"), 6)
	render_sheet(pets[19:], os.path.join(PREVIEWS, "sae_pets_legendary_mythic.png"), 7, gap=4.6)
	flyers = [o for o in pets if o.name in {"ClickyChick", "LaserOwl", "RainbowParrot", "GoldenGoose", "MegaLaserShark", "DiamondDragon"}]
	render_sheet(flyers, os.path.join(PREVIEWS, "sae_pets_flyers_flex.png"), min(5, len(flyers)), gap=4.8)
	render_sheet(pets, os.path.join(PREVIEWS, "sae_pets_all.png"), 7, gap=4.4)
	for name in ("ClickyChick", "ThockPup", "StickyRaccoon", "DiamondDragon", "LaserOwl", "LuckyFrog", "RainbowParrot", "GoldenGorilla"):
		obj = bpy.data.objects.get(name)
		if obj:
			render_hero(obj, os.path.join(PREVIEWS, f"sae_hero_{name}.png"))
	print("DARK_PREVIEWS_DONE")


main()
