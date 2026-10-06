import sys
import os

sys.path.insert(0, r"C:\Users\zatch\dev\roblox\assets\models")
from _blender_rpc import code, send

SCRIPT = r"C:\Users\zatch\dev\roblox\assets\models\_build_pets_sae.py"

# Load file inside Blender and exec it
src = f"""
import runpy
result = runpy.run_path(r"{SCRIPT}", run_name="__main__")
print("RAN_SAE_BATCH")
"""

print("Sending SAE pet batch to Blender (timeout 600s)...")
r = send({"type": "execute_code", "params": {"code": src}}, timeout=600)
print("STATUS:", r.get("status"))
result = r.get("result", r)
if isinstance(result, dict):
	print("RESULT:", str(result)[:3000])
else:
	print("RESULT:", str(result)[:3000])
if r.get("status") != "success":
	print("FULL:", str(r)[:4000])
