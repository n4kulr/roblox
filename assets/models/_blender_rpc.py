import json
import socket
import base64
import os

HOST = "127.0.0.1"
PORT = 9876
OUT = r"C:\Users\zatch\dev\roblox\assets\models\previews"


def send(command, timeout=120):
	s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
	s.settimeout(timeout)
	s.connect((HOST, PORT))
	s.sendall(json.dumps(command).encode("utf-8"))
	chunks = []
	while True:
		try:
			data = s.recv(65536)
			if not data:
				break
			chunks.append(data)
			try:
				result = json.loads(b"".join(chunks).decode("utf-8"))
				s.close()
				return result
			except json.JSONDecodeError:
				continue
		except socket.timeout:
			break
	raw = b"".join(chunks).decode("utf-8", errors="replace")
	s.close()
	return {"status": "error", "message": f"incomplete: {raw[:800]}"}


def code(src):
	return send({"type": "execute_code", "params": {"code": src}})


def screenshot(path, max_size=1200):
	r = send(
		{
			"type": "get_viewport_screenshot",
			"params": {"max_size": max_size},
		}
	)
	if r.get("status") != "success":
		return r
	result = r.get("result", r)
	# result may be base64 string or dict with image data
	if isinstance(result, dict):
		b64 = result.get("image") or result.get("data") or result.get("screenshot")
		ext = result.get("format", "png")
	else:
		b64 = result
		ext = "png"
	if not b64:
		return {"status": "error", "message": str(r)[:500]}
	os.makedirs(os.path.dirname(path), exist_ok=True)
	with open(path, "wb") as f:
		f.write(base64.b64decode(b64))
	return {"status": "success", "path": path}


if __name__ == "__main__":
	r = code(
		"""
import bpy
names = [o.name for o in bpy.context.scene.objects]
print("OBJECTS:", names)
"""
	)
	print(json.dumps(r, indent=2)[:2000])
