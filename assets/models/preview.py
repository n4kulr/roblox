import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.collections import PolyCollection

HERE = os.path.dirname(os.path.abspath(__file__))
AZIMUTH = 35.0
ELEVATION = 32.0
LIGHT = np.array([-0.4, 0.8, -0.5])


def load_obj(path):
    v, f = [], []
    for line in open(path):
        p = line.split()
        if not p:
            continue
        if p[0] == "v":
            v.append([float(x) for x in p[1:4]])
        elif p[0] == "f":
            f.append([int(x.split("/")[0]) - 1 for x in p[1:4]])
    return np.array(v), np.array(f)


def render(name, size=900, extra_views=()):
    v, f = load_obj(os.path.join(HERE, name + ".obj"))
    views = [(AZIMUTH, ELEVATION)] + list(extra_views)
    fig, axes = plt.subplots(1, len(views), figsize=(size / 100 * len(views), size / 100), dpi=100)
    axes = np.atleast_1d(axes)
    for ax, (az, el) in zip(axes, views):
        a, e = np.radians(az), np.radians(el)
        cam = np.array([np.sin(a) * np.cos(e), np.sin(e), -np.cos(a) * np.cos(e)])
        fwd = -cam
        right = np.cross(fwd, [0, 1, 0])
        right = right / np.linalg.norm(right)
        up = np.cross(right, fwd)
        pts = np.stack([v @ right, v @ up], axis=1)
        depth = v @ fwd
        tri = v[f]
        n = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
        n = n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
        light = LIGHT / np.linalg.norm(LIGHT)
        shade = 0.35 + 0.65 * np.clip(n @ light, 0, 1)
        colors = np.stack([shade * 0.75, shade * 0.8, shade * 0.95], axis=1)
        back = n @ fwd > 0
        order = np.argsort(depth[f].mean(axis=1))[::-1]
        order = order[~back[order]]
        pc = PolyCollection(pts[f][order], facecolors=colors[order], edgecolors=(0, 0, 0, 0.25), linewidths=0.3)
        ax.add_collection(pc)
        ax.set_xlim(pts[:, 0].min(), pts[:, 0].max())
        ax.set_ylim(pts[:, 1].min(), pts[:, 1].max())
        ax.set_aspect("equal")
        ax.axis("off")
    fig.subplots_adjust(0.01, 0.01, 0.99, 0.99, 0.02)
    out = os.path.join(HERE, "previews")
    os.makedirs(out, exist_ok=True)
    fig.savefig(os.path.join(out, name + ".png"))
    plt.close(fig)


def main():
    render("keycap", extra_views=[(35, 8), (180 + 35, 55)])
    render("rollkey", extra_views=[(35, -20), (35, 8)])
    render("keyboard_case", size=700, extra_views=[(20, 55)])


if __name__ == "__main__":
    main()
