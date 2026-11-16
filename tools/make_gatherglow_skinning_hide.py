"""Build the amber hide at the same resolution as the leaf and crystal."""

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
    [(9, 7), (15, 5), (24, 11), (35, 12), (47, 7), (54, 8),
     (56, 17), (52, 23), (44, 29), (43, 35), (46, 42), (54, 46),
     (58, 53), (53, 59), (46, 58), (35, 53), (25, 54), (14, 59),
     (8, 57), (5, 51), (9, 44), (17, 40), (20, 33), (18, 26),
     (10, 22), (6, 15)],
    "#362317",
)

face(
    [(13, 11), (15, 10), (23, 15), (36, 16), (48, 11), (51, 12),
     (52, 16), (49, 20), (40, 27), (39, 35), (43, 45), (51, 49),
     (53, 53), (51, 55), (47, 54), (35, 49), (24, 50), (14, 55),
     (11, 54), (10, 51), (12, 47), (20, 43), (24, 34), (21, 23),
     (13, 19), (10, 15)],
    "#f7b653",
)
face(
    [(13, 11), (15, 10), (23, 15), (36, 16), (48, 11), (51, 12),
     (52, 16), (44, 19), (36, 22), (26, 22), (16, 17), (10, 15)],
    "#ffe4a6",
)
face(
    [(24, 34), (29, 39), (26, 46), (35, 45), (47, 51), (53, 53),
     (51, 55), (47, 54), (35, 49), (24, 50), (14, 55), (11, 54),
     (10, 51), (12, 47), (20, 43)],
    "#d78337",
)

texture = canvas.resize((size, size), Image.Resampling.LANCZOS)
texture.save(root / "SkinningHide.tga")
