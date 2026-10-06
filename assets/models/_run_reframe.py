import sys
sys.path.insert(0, r"C:\Users\zatch\dev\roblox\assets\models")
from _blender_rpc import send

SCRIPT = r"C:\Users\zatch\dev\roblox\assets\models\_reframe_previews.py"
src = f'import runpy\nrunpy.run_path(r"{SCRIPT}", run_name="__main__")\nprint("RAN_REFRAME")'
print("Reframing previews to show faces...")
r = send({"type": "execute_code", "params": {"code": src}}, timeout=300)
print("STATUS:", r.get("status"))
result = r.get("result", {})
if isinstance(result, dict):
	print(str(result.get("result", result))[-2500:])
else:
	print(str(result)[-2500:])
