import sys
sys.path.insert(0, r"C:\Users\zatch\dev\roblox\assets\models")
from _blender_rpc import code

src = r"""
import runpy
# reuse render_hero from reframe by importing functions via exec of file pieces
import bpy, os
from mathutils import Vector

PREVIEWS = r"C:\Users\zatch\dev\roblox\assets\models\previews"

def world_bounds(objects):
	mins = Vector((1e9,1e9,1e9)); maxs = Vector((-1e9,-1e9,-1e9))
	for obj in objects:
		for c in obj.bound_box:
			w = obj.matrix_world @ Vector(c)
			mins = Vector((min(mins.x,w.x),min(mins.y,w.y),min(mins.z,w.z)))
			maxs = Vector((max(maxs.x,w.x),max(maxs.y,w.y),max(maxs.z,w.z)))
	return mins, maxs

def hero(name):
	for o in bpy.data.objects:
		if o.type == "MESH":
			o.hide_render = o.hide_viewport = o.name != name
	obj = bpy.data.objects[name]
	obj.hide_render = obj.hide_viewport = False
	obj.location = (0,0,0)
	obj.rotation_euler = (0,0,-0.4)
	bpy.context.view_layer.update()
	mins, maxs = world_bounds([obj])
	center = (mins+maxs)*0.5
	size = max(maxs.x-mins.x, maxs.y-mins.y, maxs.z-mins.z, 1.0)
	cam = bpy.data.objects["Cam"]
	cam.location = (center.x + size*1.05, center.y + size*1.65, center.z + size*0.4)
	cam.rotation_euler = (center - cam.location).to_track_quat("-Z","Y").to_euler()
	cam.data.lens = 45
	scene = bpy.context.scene
	try: scene.render.engine = "BLENDER_EEVEE_NEXT"
	except: scene.render.engine = "BLENDER_EEVEE"
	scene.render.resolution_x = 1200
	scene.render.resolution_y = 1200
	scene.render.filepath = os.path.join(PREVIEWS, f"sae_hero_{name}.png")
	bpy.ops.render.render(write_still=True)
	print("HERO", name, len(obj.data.vertices))

for n in ["SpacebarBunny","CrownKoala","LightningLeopard","GoldenGoose","PhantomWolf","MegaLaserShark","DiamondDragon"]:
	hero(n)
print("LEGENDARY_HEROES_DONE")
"""
print(code(src))
