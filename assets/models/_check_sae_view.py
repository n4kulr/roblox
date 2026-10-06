import sys
sys.path.insert(0, r"C:\Users\zatch\dev\roblox\assets\models")
from _blender_rpc import code, screenshot
import os

src = r"""
import bpy
from collections import Counter

# Check face material indices
for name in ["ClickyChick", "LuckyFrog", "DiamondDragon"]:
	obj = bpy.data.objects.get(name)
	counts = Counter(p.material_index for p in obj.data.polygons)
	mat_names = [m.name if m else None for m in obj.data.materials]
	print(name, "slots", mat_names)
	print("  face_counts", dict(counts))

# Frame ClickyChick for viewport shot
obj = bpy.data.objects["ClickyChick"]
for o in bpy.data.objects:
	if o.type == "MESH":
		o.hide_viewport = o.name != "ClickyChick"
obj.hide_viewport = False
obj.location = (0, 0, 0)
obj.rotation_euler = (0, 0, 0.4)
bpy.context.view_layer.update()
cam = bpy.data.objects["Cam"]
cam.location = (2.8, -3.2, 2.2)
import mathutils
target = mathutils.Vector((0, 0, 1.0))
cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
bpy.context.scene.camera = cam
print("FRAMED ClickyChick")
"""
print(code(src))
path = r"C:\Users\zatch\dev\roblox\assets\models\previews\sae_check_chick.png"
print(screenshot(path, max_size=900))
