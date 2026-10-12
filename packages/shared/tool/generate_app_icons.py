"""Renders the barber pole app icon and writes the launcher icons of the apps.

Usage: python3 tool/generate_app_icons.py <app dir>   (needs Pillow)
The pole geometry matches AppLogo in lib/src/widgets/app_logo.dart.
"""
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

BLUE = (19, 34, 90, 255)
RED = (214, 40, 40, 255)
WHITE = (255, 255, 255, 255)
POLE_BLUE = (36, 72, 184, 255)
CHROME = (220, 226, 236, 255)
SHADE = (174, 184, 202, 255)
STRIPES = [RED, WHITE, POLE_BLUE, WHITE]
SS = 4


def draw_pole(img, scale=1.0, dy=0.0):
    """Draws the pole on `img`; scale and dy (fraction of the tile) are used for the adaptive icon."""
    size = img.width
    d = ImageDraw.Draw(img)

    def p(x, y):
        return ((0.5 + (x - 0.5) * scale) * size, (0.5 + (y - 0.5) * scale + dy) * size)

    def rect(l, t, r, b):
        return [*p(l, t), *p(r, b)]

    d.ellipse([*p(0.5 - 0.085, 0.215 - 0.085), *p(0.5 + 0.085, 0.215 + 0.085)], fill=WHITE)
    d.rectangle(rect(0.46, 0.295, 0.54, 0.33), fill=SHADE)
    d.polygon([p(0.44, 0.725), p(0.56, 0.725), p(0.535, 0.78), p(0.465, 0.78)], fill=SHADE)

    left, right, top, bottom, band = 0.39, 0.61, 0.385, 0.665, 0.0525
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    width = right - left
    c, i = top - width, 0
    while c < bottom + width:
        ld.polygon([p(left, c), p(right, c - width), p(right, c - width + band), p(left, c + band)], fill=STRIPES[i % 4])
        c += band
        i += 1
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rectangle(rect(left, top, right, bottom), fill=255)
    img.paste(layer, (0, 0), ImageChops.multiply(layer.split()[3], mask))

    radius = 0.03 * scale * size
    d.rounded_rectangle(rect(0.33, 0.325, 0.67, 0.385), radius, fill=CHROME)
    d.rounded_rectangle(rect(0.33, 0.665, 0.67, 0.725), radius, fill=CHROME)


def render(size, background=True, rounded=0.0, scale=1.0, dy=0.0):
    big = size * SS
    img = Image.new("RGBA", (big, big), BLUE if background else (0, 0, 0, 0))
    draw_pole(img, scale, dy)
    if rounded:
        mask = Image.new("L", (big, big), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, big - 1, big - 1], rounded * big, fill=255)
        out = Image.new("RGBA", (big, big), (0, 0, 0, 0))
        out.paste(img, (0, 0), mask)
        img = out
    return img.resize((size, size), Image.LANCZOS)


def save(img, path, flatten=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    if flatten:
        base = Image.new("RGB", img.size, BLUE[:3])
        base.paste(img, (0, 0), img)
        img = base
    img.save(path)


def main(app):
    app = Path(app)
    ios = app / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for f in ios.glob("Icon-App-*.png"):
        edge, _, scale = f.stem.replace("Icon-App-", "").partition("@")
        side = float(edge.split("x")[0])
        factor = int(scale.rstrip("x")) if scale else 1
        px = round(side * factor)
        save(render(px, rounded=0.0), f, flatten=True)

    res = app / "android/app/src/main/res"
    for name, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        save(render(px, rounded=0.22), res / f"mipmap-{name}/ic_launcher.png")
    for name, px in {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}.items():
        save(render(px, background=False, scale=0.78, dy=0.045), res / f"mipmap-{name}/ic_launcher_foreground.png")

    web = app / "web"
    save(render(32, rounded=0.22), web / "favicon.png")
    save(render(192, rounded=0.22), web / "icons/Icon-192.png")
    save(render(512, rounded=0.22), web / "icons/Icon-512.png")
    save(render(192, scale=0.8, dy=0.04), web / "icons/Icon-maskable-192.png")
    save(render(512, scale=0.8, dy=0.04), web / "icons/Icon-maskable-512.png")


if __name__ == "__main__":
    main(sys.argv[1])
