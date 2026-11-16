"""Build the outlined leaf at the same resolution as GatherGlow's ore crystal."""

from pathlib import Path

from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]

size = 64
scale = 4
canvas = Image.new("RGBA", (size * scale, size * scale))
draw = ImageDraw.Draw(canvas)


def curve(start, first, second, end):
    points = []
    for step in range(1, 13):
        t = step / 12
        u = 1 - t
        weights = (u**3, 3 * u**2 * t, 3 * u * t**2, t**3)
        x, y = (sum(weight * coordinate for weight, coordinate in zip(weights, axis))
                for axis in zip(start, first, second, end))
        points.append((x, y))
    return points


def face(points, color):
    draw.polygon([(round(x * scale), round(y * scale)) for x, y in points], fill=color)


tip = (59, 5)
shoulder = (10, 31)
heel = (15, 47)
stem = [(7, 56), (12, 61), (23, 51)]
face(
    [tip]
    + curve(tip, (46, 9), (16, 9), shoulder)
    + curve(shoulder, (8, 38), (10, 44), heel)
    + stem
    + curve(stem[-1], (42, 56), (58, 34), tip),
    "#132c25",
)

tip = (53, 12)
shoulder = (15, 32)
heel = (21, 46)
face(
    [tip]
    + curve(tip, (39, 15), (20, 14), shoulder)
    + curve(shoulder, (13, 38), (15, 44), heel)
    + curve(heel, (34, 52), (50, 37), tip),
    "#83d775",
)

# Pale upper face, with a larger green face on the lower side of the midrib.
face(
    [tip] + curve(tip, (39, 15), (20, 14), shoulder)
    + [(18, 38), (28, 36), (38, 25)],
    "#ccf9a9",
)
face([(18, 38), (28, 36), (33, 46), heel], "#61ba69")
face(
    [(11, 56), (21, 44), (29, 34), (42, 23), tip, (35, 33),
     (23, 48), (13, 58)],
    "#e8ffd4",
)

texture = canvas.resize((size, size), Image.Resampling.LANCZOS)
texture.save(root / "HerbLeaf.tga")
