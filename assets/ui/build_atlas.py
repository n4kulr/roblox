import glob
import math
import subprocess
import sys
import tempfile
from pathlib import Path

LINE = "#0E1018"
GREEN = "#3CCB5A"
RED = "#F0435A"
BLUE = "#3A8DFF"
GOLD = "#FFC233"
PURPLE = "#9B5CFF"
SLATE = "#6B7494"
ORANGE = "#FF8A1F"
TEAL = "#12B5B0"
MARKET = "#FF6A2B"
ICON_CELL = 128
GLYPH_CELL = 64
COLUMNS = 8


def gear():
    s = '<circle cx="32" cy="30" r="5"/><circle cx="32" cy="30" r="11"/>'
    for k in range(8):
        a = math.radians(k * 45)
        s += '<path d="M%.1f %.1fL%.1f %.1f"/>' % (
            32 + 11 * math.cos(a),
            30 + 11 * math.sin(a),
            32 + 16 * math.cos(a),
            30 + 16 * math.sin(a),
        )
    return s


def dot(x, y):
    return f'<circle cx="{x}" cy="{y}" r="2.6" fill="currentColor" stroke="none"/>'


GLYPHS = {
    "upgrades": '<path d="M32 45V19M20 30 32 18 44 30"/>',
    "keys": '<circle cx="22" cy="30" r="8"/><path d="M30 30H47M40 30v8M47 30v6"/>',
    "index": '<path d="M17 21c6-3 11-2 15 2 4-4 9-5 15-2v22c-6-3-11-2-15 2-4-4-9-5-15-2Z"/><path d="M32 23v22"/>',
    "settings": gear(),
    "rebirth": '<path d="M20 29a12 12 0 0 1 21-7M44 31a12 12 0 0 1-21 7"/><path d="M43 14v9h-9M21 46v-9h9"/>',
    "pass": '<path d="M16 22H48V28a3.5 3.5 0 0 0 0 7V42H16V35a3.5 3.5 0 0 0 0-7Z"/><path d="M38 24v3M38 30v3M38 36v3"/>',
    "daily": '<rect x="16" y="20" width="32" height="26" rx="5"/><path d="M16 29H48M25 15v9M39 15v9"/>',
    "shop": '<path d="M13 17h6l4 21h20l4-15H22"/><circle cx="26" cy="45" r="2.5"/><circle cx="40" cy="45" r="2.5"/>',
    "leaders": '<path d="M23 16h18v12a9 9 0 0 1-18 0Z"/><path d="M23 20h-7a7 7 0 0 0 8 9M41 20h7a7 7 0 0 1-8 9M32 37v6M24 45h16"/>',
    "base": '<path d="M15 31 32 16l17 15M21 28v17h22V28"/><path d="M28 45V36h8v9"/>',
    "clicks": '<circle cx="32" cy="30" r="16"/><path d="M24 30h14M34 30v6"/>',
    "luck": '<circle cx="26.5" cy="23.5" r="5"/><circle cx="37.5" cy="23.5" r="5"/><circle cx="26.5" cy="34.5" r="5"/><circle cx="37.5" cy="34.5" r="5"/><path d="M32 30l6 15"/>',
    "speed": '<path d="M36 14 21 33h10l-3 14 16-21H34Z"/>',
    "income": '<ellipse cx="32" cy="21" rx="13" ry="5"/><path d="M19 21v9c0 3 6 5 13 5s13-2 13-5v-9M19 30v9c0 3 6 5 13 5s13-2 13-5v-9"/>',
    "roll": '<rect x="17" y="16" width="30" height="30" rx="8"/>'
    + dot(26, 25)
    + dot(38, 25)
    + dot(32, 31)
    + dot(26, 37)
    + dot(38, 37),
    "auto": '<path d="M46 31A14 14 0 1 1 41 20"/><path d="M43 13v9h-9"/>',
    "gift": '<rect x="17" y="27" width="30" height="18" rx="3"/><rect x="14" y="20" width="36" height="8" rx="3"/><path d="M32 20v25M32 20c-5-8-13-6-10 0M32 20c5-8 13-6 10 0"/>',
    "trade": '<path d="M17 24h27M37 17l7 7-7 7M47 38H20M27 31l-7 7 7 7"/>',
    "close": '<path d="M21 19 43 41M43 19 21 41"/>',
    "lock": '<rect x="20" y="29" width="24" height="17" rx="4"/><path d="M25 29v-5a7 7 0 0 1 14 0v5"/>',
    "check": '<path d="M18 31l9 9 19-20"/>',
    "market": '<path d="M16 25 20 16H44L48 25"/><path d="M16 25c0 4 5 4 5.3 0 .4 4 5.3 4 5.4 0 .2 4 5.4 4 5.4 0 .2 4 5.3 4 5.4 0 .2 4 5.3 4 5.2 0"/><path d="M19 33v13h26V33M27 46V38h10v8"/>',
    "star": '<path d="M32 15l4.8 10 11 1.5-8 7.6 2 10.900L32 39.8 22.2 45l2-10.9-8-7.6 11-1.500Z"/>',
    "board": '<rect x="13" y="19" width="38" height="26" rx="6"/><path d="M21 27h1M29 27h1M37 27h1M45 27h1M22 37h20"/>',
    "tag": '<path d="M16 30V19a3 3 0 0 1 3-3h11l18 18-14 14Z"/>' + dot(25, 25),
    "volume": '<path d="M16 26h7l9-8v24l-9-8h-7Z"/><path d="M39 24a9 9 0 0 1 0 12M44 19a16 16 0 0 1 0 22"/>',
    "people": '<circle cx="25" cy="24" r="6"/><path d="M14 46c0-8 5-12 11-12s11 4 11 12"/><circle cx="41" cy="26" r="5"/><path d="M40 35c6 0 10 4 10 11"/>',
    "monitor": '<rect x="14" y="18" width="36" height="24" rx="5"/><path d="M26 47h12M32 42v5"/>',
    "sparkle": '<path d="M30 15c1 9 4 12 13 13-9 1-12 4-13 13-1-9-4-12-13-13 9-1 12-4 13-13Z"/><path d="M44 38v8M40 42h8"/>',
    "crown": '<path d="M15 41 18 22l10 10 4-14 4 14 10-10 3 19Z"/>',
    "flask": '<path d="M27 16h10M29 16v10L19 43a3 3 0 0 0 3 4h20a3 3 0 0 0 3-4L35 26V16"/><path d="M24 38h16"/>',
    "globe": '<circle cx="32" cy="30" r="15"/><path d="M17 30h30M32 15c-7 8-7 22 0 30M32 15c7 8 7 22 0 30"/>',
    "warn": '<path d="M32 16 49 44H15Z"/><path d="M32 27v8M32 40v.5"/>',
    "clock": '<circle cx="32" cy="30" r="15"/><path d="M32 21v10l7 4"/>',
    "wall": '<rect x="14" y="18" width="36" height="28" rx="3"/><path d="M14 27h36M14 36h36M26 18v9M38 27v9M26 36v10"/>',
    "laser": '<rect x="22" y="28" width="20" height="16" rx="4"/><path d="M26 28v-4a6 6 0 0 1 12 0v4M10 36h7M47 36h7M12 27l6 4M52 27l-6 4"/>',
    "plus": '<path d="M32 19v22M21 30h22"/>',
    "minus": '<path d="M21 30h22"/>',
}

ICON_COLORS = {
    "upgrades": GREEN,
    "keys": PURPLE,
    "index": BLUE,
    "settings": SLATE,
    "rebirth": PURPLE,
    "pass": ORANGE,
    "daily": BLUE,
    "shop": RED,
    "leaders": GOLD,
    "base": BLUE,
    "clicks": GOLD,
    "luck": GREEN,
    "speed": BLUE,
    "income": GOLD,
    "roll": GREEN,
    "auto": SLATE,
    "gift": RED,
    "trade": TEAL,
    "close": RED,
    "lock": SLATE,
    "check": GREEN,
    "market": MARKET,
    "star": GOLD,
    "board": PURPLE,
    "tag": RED,
    "volume": BLUE,
    "people": TEAL,
    "monitor": SLATE,
    "sparkle": PURPLE,
    "crown": GOLD,
    "flask": GREEN,
    "globe": BLUE,
    "warn": ORANGE,
    "clock": MARKET,
    "wall": ORANGE,
    "laser": RED,
}


def mix(a, b, t):
    ra = [int(a[i : i + 2], 16) for i in (1, 3, 5)]
    rb = [int(b[i : i + 2], 16) for i in (1, 3, 5)]
    return "#%02X%02X%02X" % tuple(round(ra[i] + (rb[i] - ra[i]) * t) for i in range(3))


def keycap(name, color, size):
    dark = mix(color, "#000000", 0.38)
    glyph = GLYPHS[name]
    return (
        f'<svg width="{size}" height="{size}" viewBox="0 0 64 64">'
        f'<rect x="3" y="10" width="58" height="50" rx="13" fill="{dark}" stroke="{LINE}" stroke-width="3"/>'
        f'<rect x="9" y="4" width="46" height="44" rx="10" fill="{color}" stroke="{LINE}" stroke-width="3"/>'
        f'<rect x="13" y="7.5" width="38" height="7" rx="3.5" fill="#fff" opacity=".25"/>'
        f'<g transform="translate(32 26) scale(.9) translate(-32 -30)" fill="none" stroke-linecap="round" stroke-linejoin="round">'
        f'<g color="{LINE}" stroke="{LINE}" stroke-width="9">{glyph}</g>'
        f'<g color="#fff" stroke="#fff" stroke-width="5">{glyph}</g></g></svg>'
    )


def glyph(name, size):
    return (
        f'<svg width="{size}" height="{size}" viewBox="10 8 44 44">'
        f'<g color="#fff" fill="none" stroke="#fff" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">'
        f"{GLYPHS[name]}</g></svg>"
    )


def find_chrome():
    for pattern in (
        "/opt/pw-browsers/chromium_headless_shell-*/chrome-linux/headless_shell",
        "/opt/pw-browsers/chromium-*/chrome-linux/chrome",
    ):
        found = sorted(glob.glob(pattern))
        if found:
            return found[-1]
    sys.exit("chromium not found")


def render(names, cell, factory, destination):
    rows = math.ceil(len(names) / COLUMNS)
    width = COLUMNS * cell
    height = rows * cell
    body = ""
    for index, name in enumerate(names):
        x = (index % COLUMNS) * cell
        y = (index // COLUMNS) * cell
        body += f'<div style="position:absolute;left:{x}px;top:{y}px;width:{cell}px;height:{cell}px">{factory(name, cell)}</div>'
    html = (
        '<!doctype html><html><head><meta charset="utf-8"><style>'
        "html,body{margin:0;padding:0;background:transparent;overflow:hidden}"
        f"</style></head><body>{body}</body></html>"
    )
    with tempfile.TemporaryDirectory() as temp:
        page = Path(temp) / "atlas.html"
        page.write_text(html)
        subprocess.run(
            [
                find_chrome(),
                "--headless",
                "--no-sandbox",
                "--disable-gpu",
                "--hide-scrollbars",
                "--force-device-scale-factor=1",
                "--default-background-color=00000000",
                f"--window-size={width},{height}",
                f"--screenshot={destination}",
                page.as_uri(),
            ],
            check=True,
            capture_output=True,
        )
    return width, height


def lua_cells(names):
    lines = []
    for index, name in enumerate(names):
        lines.append(f"\t\t{name} = Vector2.new({index % COLUMNS}, {index // COLUMNS}),")
    return "\n".join(lines)


def main():
    out = Path(__file__).parent
    icon_names = list(ICON_COLORS)
    glyph_names = list(GLYPHS)
    iw, ih = render(icon_names, ICON_CELL, lambda n, s: keycap(n, ICON_COLORS[n], s), out / "icons_atlas.png")
    gw, gh = render(glyph_names, GLYPH_CELL, glyph, out / "glyphs_atlas.png")
    print(f"icons_atlas.png {iw}x{ih}")
    print(lua_cells(icon_names))
    print(f"glyphs_atlas.png {gw}x{gh}")
    print(lua_cells(glyph_names))


main()
