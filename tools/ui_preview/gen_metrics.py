import sys

from PIL import ImageFont

fonts = {
    "FredokaOne": ".cache/FredokaOne.ttf",
    "LuckiestGuy": ".cache/LuckiestGuy.ttf",
    "Gotham": ".cache/Montserrat800.ttf",
}

lines = ["return {"]
for name, path in fonts.items():
    font = ImageFont.truetype(path, 1000)
    widths = [str(round(font.getlength(chr(code)))) for code in range(32, 127)]
    ascent, descent = font.getmetrics()
    lines.append(
        f"\t{name} = {{ Ascent = {ascent}, Descent = {descent}, Widths = {{ {', '.join(widths)} }} }},"
    )
lines.append("}")
sys.stdout.write("\n".join(lines) + "\n")
