import sys
sys.path.insert(0, r"C:\Users\zatch\dev\roblox\assets\models")
from _blender_rpc import code

src = r"""
import bpy
pets = [o for o in bpy.data.objects if o.type == "MESH" and not o.name.startswith("Area") and o.name != "Cam"]
print("COUNT", len(pets))
total = 0
for o in sorted(pets, key=lambda x: x.name):
	v = len(o.data.vertices)
	total += v
	print(o.name, v)
print("TOTAL_VERTS", total)
"""
print(code(src))
