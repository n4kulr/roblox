import json
import math
import sys

from PIL import Image, ImageDraw

source = sys.argv[1]
target = sys.argv[2]
extent = 215.0
scale = 4.0
side = int(extent * 2 * scale)


def project(x, z):
    return ((x + extent) * scale, (z + extent) * scale)


def hull(points):
    points = sorted(set(points))
    if len(points) < 3:
        return points
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower = []
    for p in points:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    upper = []
    for p in reversed(points):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def samples(shape, size):
    sx, sy, sz = (value / 2 for value in size)
    if "Ball" in shape:
        out = []
        for i in range(16):
            for j in range(8):
                a = i / 16 * math.tau
                b = (j / 7 - 0.5) * math.pi
                out.append((math.cos(a) * math.cos(b) * sx, math.sin(b) * sy, math.sin(a) * math.cos(b) * sz))
        return out
    if "Cylinder" in shape:
        out = []
        for i in range(24):
            a = i / 24 * math.tau
            for x in (-sx, sx):
                out.append((x, math.cos(a) * sy, math.sin(a) * sz))
        return out
    return [(x, y, z) for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)]


parts = json.load(open(source))
items = []
for part in parts:
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = part["cframe"]
    world = []
    top = -1e9
    for lx, ly, lz in samples(part["shape"], part["size"]):
        wx = x + r00 * lx + r01 * ly + r02 * lz
        wy = y + r10 * lx + r11 * ly + r12 * lz
        wz = z + r20 * lx + r21 * ly + r22 * lz
        world.append((wx, wz))
        top = max(top, wy)
    items.append((top, part, hull(world)))
items.sort(key=lambda item: item[0])

image = Image.new("RGB", (side, side), (60, 120, 50))
draw = ImageDraw.Draw(image)
for _, part, polygon in items:
    if len(polygon) >= 3:
        color = tuple(part["color"])
        draw.polygon([project(px, pz) for px, pz in polygon], fill=color, outline=tuple(max(0, c - 50) for c in color))
image = image.resize((1024, 1024), Image.LANCZOS)
image.save(target)
