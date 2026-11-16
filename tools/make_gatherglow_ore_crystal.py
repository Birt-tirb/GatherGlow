"""Build GatherGlow's opaque, faceted ore core with an antialiased outline."""

from pathlib import Path

from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]

size = 64
scale = 4
canvas = Image.new("RGBA", (size * scale, size * scale))
draw = ImageDraw.Draw(canvas)


def face(points, color):
    draw.polygon([(round(x * scale), round(y * scale)) for x, y in points], fill=color)


tip, upper, lower = (37, 9), (50, 22), (48, 40)
base, bottom_left, top_left = (29, 55), (14, 42), (15, 25)
ridge_top, ridge_bottom = (39, 26), (25, 36)

# The outer edge keeps the shape visible on snow and through the blue halo.
face([(37, 3), (55, 20), (53, 43), (29, 61), (9, 44), (10, 23)], "#101d31")
face([tip, upper, lower, base, bottom_left, top_left], "#a9dcf8")
face([tip, top_left, ridge_bottom, ridge_top], "#e8faff")
face([tip, ridge_top, upper], "#ffffff")
face([upper, ridge_top, ridge_bottom, base, lower], "#c0edff")
face([top_left, bottom_left, base, ridge_bottom], "#76b5e0")
face([tip, ridge_top, ridge_bottom, (36, 26)], "#f5fdff")

texture = canvas.resize((size, size), Image.Resampling.LANCZOS)
texture.save(root / "OreCrystal.tga")
