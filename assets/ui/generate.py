import math
from pathlib import Path

from PIL import Image

size = 256
scale = 4
out = Path(__file__).parent


def pattern():
    big = size * scale
    period = float(size)
    cuts = [0.0, 38.0, 64.0, 118.0, 150.0, 206.0, 256.0]
    alphas = [0.16, 0.42, 0.10, 0.55, 0.22, 0.34]
    half = [1.0, 0.55]
    edge = 0.6
    edge_width = 1.6
    image = Image.new("RGBA", (big, big), (255, 255, 255, 0))
    pixels = image.load()
    for py in range(big):
        y = py / scale
        for px in range(big):
            x = px / scale
            u = (x + y) % period
            v = (x - y) % period
            band = 0
            while band < len(alphas) - 1 and u >= cuts[band + 1]:
                band += 1
            start = cuts[band]
            stop = cuts[band + 1]
            local = (u - start) / (stop - start)
            alpha = alphas[band] * (0.75 + 0.5 * local)
            alpha *= half[int(v // 128) % 2]
            if min(u - start, stop - u) < edge_width:
                alpha = max(alpha, edge)
            if min(v % 128, 128 - v % 128) < edge_width * 0.6:
                alpha = max(alpha, 0.3)
            alpha = min(alpha, 0.6)
            pixels[px, py] = (255, 255, 255, int(alpha * 255))
    return image.resize((size, size), Image.BOX)


def burst():
    big = size * 2
    center = big / 2
    rays = 14
    image = Image.new("RGBA", (big, big), (255, 255, 255, 0))
    pixels = image.load()
    for py in range(big):
        for px in range(big):
            dx = px + 0.5 - center
            dy = py + 0.5 - center
            radius = math.hypot(dx, dy) / center
            if radius >= 1:
                continue
            angle = math.atan2(dy, dx)
            wave = 0.5 + 0.5 * math.cos(rays * angle)
            ray = wave**1.6
            fade = (1 - radius) ** 0.9
            glow = max(0.0, 1 - radius / 0.35) ** 2
            alpha = min(1.0, 0.85 * ray * fade + 0.6 * glow)
            pixels[px, py] = (255, 255, 255, int(alpha * 255))
    return image.resize((size, size), Image.LANCZOS)


if __name__ == "__main__":
    pattern().save(out / "pattern.png")
    burst().save(out / "burst.png")
