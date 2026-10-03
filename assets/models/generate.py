import math
import numpy as np

KEYCAP_BOTTOM = 1.0
KEYCAP_TOP = 0.78
KEYCAP_HEIGHT = 0.6
KEYCAP_CORNER_BOTTOM = 0.12
KEYCAP_CORNER_TOP = 0.16
KEYCAP_DISH_DEPTH = 0.07
KEYCAP_TOP_BEVEL = 0.04
CORNER_SEGMENTS = 6

ROLLKEY_HEIGHT = 1.0
ROLLKEY_CAP_HEIGHT = 0.45
ROLLKEY_CAP_DISH_DEPTH = 0.05
STEM_ARM = 0.40
STEM_THICK = 0.14

CASE_LENGTH = 31.0
CASE_DEPTH = 9.6
CASE_HEIGHT = 1.5
CASE_WALL = 0.6
CASE_FLOOR_Y = 1.1
CASE_CORNER = 0.9
CASE_BOTTOM_CHAMFER = 0.2
CASE_TOP_ROUND = 0.2


def rounded_rect(w, d, r, y, n=CORNER_SEGMENTS):
    r = min(r, w / 2 - 1e-3, d / 2 - 1e-3)
    cx, cz = w / 2 - r, d / 2 - r
    pts = []
    for qx, qz, a0 in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        for k in range(n + 1):
            a = math.radians(a0 + 90 * k / n)
            pts.append(((cx if qx > 0 else -cx) + r * math.cos(a), y, (cz if qz > 0 else -cz) + r * math.sin(a)))
    return np.array(pts)


def cross_ring(arm, thick, y):
    a, t = arm / 2, thick / 2
    return np.array([(a, y, t), (t, y, t), (t, y, a), (-t, y, a), (-t, y, t), (-a, y, t),
                     (-a, y, -t), (-t, y, -t), (-t, y, -a), (t, y, -a), (t, y, -t), (a, y, -t)])


def ang(p):
    return math.atan2(p[2], p[0]) % (2 * math.pi)


class Mesh:
    def __init__(self):
        self.v = []
        self.f = []

    def add_ring(self, ring):
        base = len(self.v)
        self.v.extend(map(tuple, np.atleast_2d(ring)))
        return list(range(base, base + len(np.atleast_2d(ring))))

    def band(self, A, B):
        n, m = len(A), len(B)
        if n == 1 or m == 1:
            for i in range(max(n, m)):
                a0, a1 = A[i % n], A[(i + 1) % n]
                b0, b1 = B[i % m], B[(i + 1) % m]
                if n == 1:
                    self.f.append((a0, b1, b0))
                else:
                    self.f.append((a0, a1, b0))
            return
        if n == m:
            for i in range(n):
                j = (i + 1) % n
                self.f.append((A[i], A[j], B[j]))
                self.f.append((A[i], B[j], B[i]))
            return
        va, vb = np.array(self.v)[A], np.array(self.v)[B]
        ia = int(np.argmin([ang(p) for p in va]))
        ib = int(np.argmin([ang(p) for p in vb]))
        A = A[ia:] + A[:ia]
        B = B[ib:] + B[:ib]
        va = [ang(self.v[i]) for i in A]
        vb = [ang(self.v[i]) for i in B]
        i = j = 0
        while i < n or j < m:
            na = va[i + 1] if i + 1 < n else va[0] + 2 * math.pi
            nb = vb[j + 1] if j + 1 < m else vb[0] + 2 * math.pi
            if j >= m or (i < n and na <= nb):
                self.f.append((A[i % n], A[(i + 1) % n], B[j % m]))
                i += 1
            else:
                self.f.append((A[i % n], B[(j + 1) % m], B[j % m]))
                j += 1

    def path(self, rings):
        ids = [self.add_ring(r) for r in rings]
        for a, b in zip(ids, ids[1:]):
            self.band(a, b)

    def arrays(self):
        return np.array(self.v, dtype=float), np.array(self.f, dtype=int)[:, ::-1].copy()


def cap_rings(y0, height, bottom, top, dish):
    ys = [0.0, 0.5, 1.0]
    rings = []
    for t in ys:
        w = bottom + (top - bottom) * t
        r = KEYCAP_CORNER_BOTTOM + (KEYCAP_CORNER_TOP - KEYCAP_CORNER_BOTTOM) * t
        rings.append(rounded_rect(w, w, r, y0 + height * t * 0.92))
    wt = top
    rings.append(rounded_rect(wt - 0.04, wt - 0.04, KEYCAP_CORNER_TOP, y0 + height - KEYCAP_TOP_BEVEL * 0.0))
    top_y = y0 + height
    rings[-1] = rounded_rect(wt - 2 * KEYCAP_TOP_BEVEL, wt - 2 * KEYCAP_TOP_BEVEL, KEYCAP_CORNER_TOP - 0.02, top_y)
    rings[-2] = rounded_rect(wt, wt, KEYCAP_CORNER_TOP, y0 + height - KEYCAP_TOP_BEVEL)
    w0 = wt - 2 * KEYCAP_TOP_BEVEL
    for s in (0.72, 0.42):
        rings.append(rounded_rect(w0 * s, w0 * s, max(KEYCAP_CORNER_TOP * s, 0.05), top_y - dish * (1 - s * s)))
    rings.append(np.array([[0.0, top_y - dish, 0.0]]))
    return rings


def build_keycap():
    m = Mesh()
    bottom = [np.array([[0.0, 0.0, 0.0]]), rounded_rect(KEYCAP_BOTTOM, KEYCAP_BOTTOM, KEYCAP_CORNER_BOTTOM, 0.0)]
    m.path(bottom + cap_rings(0.0, KEYCAP_HEIGHT, KEYCAP_BOTTOM, KEYCAP_TOP, KEYCAP_DISH_DEPTH)[1:])
    return m


def build_rollkey():
    m = Mesh()
    cap_h = ROLLKEY_CAP_HEIGHT
    y0 = ROLLKEY_HEIGHT - cap_h
    cr = cap_rings(y0, cap_h, 1.0, KEYCAP_TOP, ROLLKEY_CAP_DISH_DEPTH)
    rings = [np.array([[0.0, 0.0, 0.0]]), cross_ring(STEM_ARM, STEM_THICK, 0.0), cross_ring(STEM_ARM, STEM_THICK, y0)]
    rings += [rounded_rect(1.0, 1.0, KEYCAP_CORNER_BOTTOM, y0)] + cr[1:]
    m.path(rings)
    return m


def build_case():
    m = Mesh()
    L, D = CASE_LENGTH, CASE_DEPTH
    c = CASE_CORNER
    def rr(inset, y):
        return rounded_rect(L - 2 * inset, D - 2 * inset, max(c - inset, 0.12), y)
    t = CASE_TOP_ROUND
    rings = [
        np.array([[0.0, 0.0, 0.0]]),
        rr(CASE_BOTTOM_CHAMFER, 0.0),
        rr(0.0, CASE_BOTTOM_CHAMFER),
        rr(0.0, CASE_HEIGHT - t),
        rr(t * 0.3, CASE_HEIGHT - t * 0.45),
        rr(t, CASE_HEIGHT),
        rr(CASE_WALL, CASE_HEIGHT),
        rr(CASE_WALL, CASE_FLOOR_Y),
        np.array([[0.0, CASE_FLOOR_Y, 0.0]]),
    ]
    m.path(rings)
    return m


def write_obj(path, mesh):
    v, f = mesh.arrays()
    fn = np.zeros_like(v)
    tri = v[f]
    fnorm = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    for k in range(3):
        np.add.at(fn, f[:, k], fnorm)
    fn /= np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-12)
    with open(path, "w") as fh:
        fh.write("# generated by generate.py\n")
        for p in v:
            fh.write("v %.5f %.5f %.5f\n" % tuple(p))
        for n in fn:
            fh.write("vn %.5f %.5f %.5f\n" % tuple(n))
        for a, b, c in f + 1:
            fh.write("f %d//%d %d//%d %d//%d\n" % (a, a, b, b, c, c))


def main():
    import os
    here = os.path.dirname(os.path.abspath(__file__))
    for name, b in (("keycap", build_keycap), ("rollkey", build_rollkey), ("keyboard_case", build_case)):
        mesh = b()
        write_obj(os.path.join(here, name + ".obj"), mesh)
        print(name, len(mesh.v), "verts", len(mesh.f), "tris")


if __name__ == "__main__":
    main()
