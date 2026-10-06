import json
import socket

code = r'''
import math
import os
from mathutils import Vector
import bpy

OUT = r"C:\Users\zatch\dev\roblox\assets\models\previews\phoenix_angles"
os.makedirs(OUT, exist_ok=True)

phoenix = bpy.data.objects.get("DiamondDragon")
if phoenix is None:
    raise Exception("DiamondDragon not in scene")

for o in bpy.data.objects:
    if o.type == "MESH":
        o.hide_render = o.hide_viewport = (o.name != "DiamondDragon")

phoenix.location = (0, 0, 0)
phoenix.rotation_euler = (0, 0, 0)
bpy.context.view_layer.update()

mins = Vector((1e9, 1e9, 1e9))
maxs = Vector((-1e9, -1e9, -1e9))
for c in phoenix.bound_box:
    w = phoenix.matrix_world @ Vector(c)
    mins = Vector((min(mins.x, w.x), min(mins.y, w.y), min(mins.z, w.z)))
    maxs = Vector((max(maxs.x, w.x), max(maxs.y, w.y), max(maxs.z, w.z)))
center = (mins + maxs) * 0.5
size = max(maxs.x - mins.x, maxs.y - mins.y, maxs.z - mins.z, 2.0)
dist = size * 1.85

cam = bpy.data.objects.get("Cam")
if cam is None:
    bpy.ops.object.camera_add()
    cam = bpy.context.active_object
    cam.name = "Cam"
bpy.context.scene.camera = cam
cam.data.lens = 28

scene = bpy.context.scene
try:
    scene.render.engine = "BLENDER_EEVEE_NEXT"
except Exception:
    scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1200
scene.render.resolution_y = 1200
scene.render.image_settings.file_format = "PNG"
try:
    scene.eevee.taa_render_samples = 48
except Exception:
    pass

views = [
    ("01_front", 0, 12),
    ("02_front_threequarter_right", 40, 18),
    ("03_right", 90, 10),
    ("04_back_threequarter_right", 140, 18),
    ("05_back", 180, 12),
    ("06_back_threequarter_left", 220, 18),
    ("07_left", 270, 10),
    ("08_front_threequarter_left", 320, 18),
    ("09_top", 30, 72),
    ("10_low_hero", 35, -8),
]

paths = []
for name, az, el in views:
    azr = math.radians(az)
    elr = math.radians(el)
    x = center.x + dist * math.sin(azr) * math.cos(elr)
    y = center.y - dist * math.cos(azr) * math.cos(elr)
    z = center.z + dist * math.sin(elr) + size * 0.15
    cam.location = (x, y, z)
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    path = os.path.join(OUT, name + ".png")
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    paths.append(path)
    print("VIEW", name)

for o in bpy.data.objects:
    if o.type == "MESH":
        o.hide_render = o.hide_viewport = False

print("DONE")
for p in paths:
    print(p)
'''

cmd = {"type": "execute_code", "params": {"code": code}}
s = socket.socket()
s.settimeout(180)
s.connect(("127.0.0.1", 9876))
s.sendall(json.dumps(cmd).encode("utf-8"))
buf = b""
while True:
	d = s.recv(65536)
	if not d:
		break
	buf += d
	try:
		r = json.loads(buf.decode("utf-8"))
		break
	except json.JSONDecodeError:
		pass
s.close()
print(json.dumps(r, indent=2)[-3500:])
