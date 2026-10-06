import json
import socket

code = r'''
import math, os
from mathutils import Vector, Euler
import bpy

PREVIEWS = r"C:\Users\zatch\dev\roblox\assets\models\previews"
phoenix = bpy.data.objects.get("DiamondDragon")
if not phoenix:
    print("NO PHOENIX")
else:
    # Hide others
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.hide_render = o.hide_viewport = (o != phoenix)
    phoenix.location = (0, 0, 0)
    phoenix.rotation_euler = (0, 0, math.radians(35))
    bpy.context.view_layer.update()
    mins = Vector((1e9,1e9,1e9)); maxs = Vector((-1e9,-1e9,-1e9))
    for c in phoenix.bound_box:
        w = phoenix.matrix_world @ Vector(c)
        mins = Vector((min(mins.x,w.x), min(mins.y,w.y), min(mins.z,w.z)))
        maxs = Vector((max(maxs.x,w.x), max(maxs.y,w.y), max(maxs.z,w.z)))
    center = (mins+maxs)*0.5
    size = max(maxs.x-mins.x, maxs.y-mins.y, maxs.z-mins.z, 2)
    cam = bpy.data.objects["Cam"]
    cam.location = (center.x + size*0.9, center.y - size*1.4, center.z + size*0.55)
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 28
    scene = bpy.context.scene
    try: scene.render.engine = "BLENDER_EEVEE_NEXT"
    except: scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 1200
    scene.render.filepath = os.path.join(PREVIEWS, "pet_phoenix_hero.png")
    bpy.ops.render.render(write_still=True)
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.hide_render = o.hide_viewport = False
    print("HERO OK", size)
'''
cmd = {"type": "execute_code", "params": {"code": code}}
s = socket.socket(); s.settimeout(60); s.connect(("127.0.0.1", 9876))
s.sendall(json.dumps(cmd).encode())
buf = b""
while True:
	d = s.recv(65536)
	if not d: break
	buf += d
	try:
		r = json.loads(buf.decode()); break
	except: pass
s.close()
print(r)
