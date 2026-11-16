"""Build the outlined blue fish for GatherGlow's minimap pins."""

from pathlib import Path

from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]

size = 64
scale = 4
canvas = Image.new("RGBA", (size * scale, size * scale))
draw = ImageDraw.Draw(canvas)


def face(points, color):
    draw.polygon([(round(x * scale), round(y * scale)) for x, y in points], fill=color)


face(
    [(2, 10), (9, 12), (23, 23), (27, 18), (34, 10), (44, 13),
     (54, 18), (61, 25), (63, 32), (61, 38), (54, 45), (45, 50),
     (34, 51), (22, 44), (9, 53), (2, 54), (4, 44), (10, 32), (4, 21)],
    "#11273c",
)
face(
    [(8, 17), (19, 26), (27, 29), (26, 39), (19, 39), (8, 47), (15, 32)],
    "#62c9f4",
)
face(
    [(23, 32), (30, 22), (35, 15), (44, 17), (52, 22), (57, 27),
     (59, 32), (57, 36), (51, 42), (44, 46), (35, 47), (29, 43)],
    "#93e4ff",
)
face(
    [(27, 27), (35, 15), (44, 17), (52, 22), (55, 25), (43, 24), (33, 31)],
    "#d5f8ff",
)
face([(24, 33), (34, 38), (47, 40), (53, 40), (44, 46), (35, 47), (29, 43)], "#5cbcec")

draw.ellipse((45 * scale, 25 * scale, 52 * scale, 32 * scale), fill="#16334b")

texture = canvas.resize((size, size), Image.Resampling.LANCZOS)
texture.save(root / "FishingPoolFish.tga")
