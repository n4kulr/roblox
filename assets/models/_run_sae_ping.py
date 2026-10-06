import sys
sys.path.insert(0, r"C:\Users\zatch\dev\roblox\assets\models")
from _blender_rpc import code

r = code("import bpy\nprint('OK', bpy.app.version_string, len(bpy.data.objects))")
print(r)
