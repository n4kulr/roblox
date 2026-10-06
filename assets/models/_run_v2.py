import json
import socket

SCRIPT = r"C:\Users\zatch\dev\roblox\assets\models\_build_keys_pets_v2.py"
code = f'exec(open(r"{SCRIPT}", encoding="utf-8").read())'
cmd = {"type": "execute_code", "params": {"code": code}}
s = socket.socket()
s.settimeout(600)
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
out = json.dumps(r, indent=2)
print(out[-4500:] if len(out) > 4500 else out)
