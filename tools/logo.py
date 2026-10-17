"""Draws Zmap's logo (CurseForge's project image): a folded map in Zmap's blue with a gold Z-shaped route ending
at a map pin, on Zbuilds' dark rounded square. Original drawing, no game art.
    python tools/logo.py [--out logo.png]"""
import argparse
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
S = 2048                      # drawn at 4x, then scaled down to 512
BLUE = (79, 195, 247)
GOLD = (245, 197, 66)
BORDER = (138, 115, 64)


def glow(layer, radius, strength=1.0):
    """The layer with a soft halo of its own colour around it."""
    halo = layer.filter(ImageFilter.GaussianBlur(radius))
    if strength != 1.0:
        a = halo.getchannel("A").point(lambda v: min(255, int(v * strength)))
        halo.putalpha(a)
    return Image.alpha_composite(halo, layer)


def rounded_background():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    # vertical gradient, masked to a rounded square
    grad = Image.new("RGBA", (S, S))
    gd = ImageDraw.Draw(grad)
    for y in range(S):
        t = y / S
        c = tuple(int(a + (b - a) * t) for a, b in zip((26, 28, 34), (11, 12, 15)))
        gd.line([(0, y), (S, y)], fill=c + (255,))
    mask = Image.new("L", (S, S), 0)
    m = 40
    ImageDraw.Draw(mask).rounded_rectangle([m, m, S - m, S - m], radius=360, fill=255)
    img.paste(grad, (0, 0), mask)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([m + 44, m + 44, S - m - 44, S - m - 44], radius=320, outline=BORDER + (200,), width=14)
    return img


def folded_map():
    """Three panels of a folded map, slightly tilted, outlined in blue."""
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x0, x3 = 360, 1688
    w = (x3 - x0) / 3
    top, bottom, dip = 620, 1560, 70
    xs = [x0 + w * i for i in range(4)]
    tops = [top, top + dip, top, top + dip]
    bottoms = [bottom, bottom + dip, bottom, bottom + dip]
    for i in range(3):
        poly = [(xs[i], tops[i]), (xs[i + 1], tops[i + 1]), (xs[i + 1], bottoms[i + 1]), (xs[i], bottoms[i])]
        shade = 34 if i % 2 == 0 else 22
        d.polygon(poly, fill=(BLUE[0] // 5, BLUE[1] // 5 + shade // 3, BLUE[2] // 5 + shade, 150))
    outline = [(xs[0], tops[0]), (xs[1], tops[1]), (xs[2], tops[2]), (xs[3], tops[3]),
               (xs[3], bottoms[3]), (xs[2], bottoms[2]), (xs[1], bottoms[1]), (xs[0], bottoms[0])]
    d.line(outline + [outline[0]], fill=BLUE + (255,), width=34, joint="curve")
    for i in (1, 2):
        d.line([(xs[i], tops[i]), (xs[i], bottoms[i])], fill=BLUE + (190,), width=20)
    # a faint grid on it, like a map's
    for k in range(1, 4):
        y = top + (bottom - top) * k / 4
        for i in range(3):
            ya = y + (tops[i] - top)
            yb = y + (tops[i + 1] - top)
            d.line([(xs[i] + 30, ya), (xs[i + 1] - 30, yb)], fill=BLUE + (55,), width=8)
    return layer, xs, tops


def route(xs, tops):
    """A dashed gold Z across the map, ending at a pin."""
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    a, b = (540, 850), (1230, 850)
    c, e = (540, 1380), (1450, 1380)
    path = [a, b, c, e]
    dash, gap, width = 70, 46, 46
    for p, q in zip(path, path[1:]):
        length = math.dist(p, q)
        ux, uy = (q[0] - p[0]) / length, (q[1] - p[1]) / length
        t = 0
        while t < length:
            t2 = min(length, t + dash)
            d.line([(p[0] + ux * t, p[1] + uy * t), (p[0] + ux * t2, p[1] + uy * t2)], fill=GOLD + (255,), width=width)
            t = t2 + gap
    r = 40
    d.ellipse([a[0] - r, a[1] - r, a[0] + r, a[1] + r], fill=GOLD + (255,))
    return layer, e


def pin(at):
    """A teardrop map pin standing on the route's end."""
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    px, py = at
    R = 150
    cy = py - 300
    d.ellipse([px - R, cy - R, px + R, cy + R], fill=GOLD + (255,))
    # the point: tangents from the tip to the circle
    tip = (px, py - 20)
    dist = tip[1] - cy
    ang = math.asin(R / dist)
    left = (px - R * math.cos(ang), cy + R * math.sin(ang))
    right = (px + R * math.cos(ang), cy + R * math.sin(ang))
    d.polygon([left, right, tip], fill=GOLD + (255,))
    hole = 58
    d.ellipse([px - hole, cy - hole, px + hole, cy + hole], fill=(20, 22, 27, 255))
    # its shadow on the map
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse([px - 110, py - 40, px + 110, py + 10], fill=(0, 0, 0, 150))
    return Image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(14)), layer)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(ROOT / "logo.png"))
    out = Path(ap.parse_args().out)
    img = rounded_background()
    m, xs, tops = folded_map()
    img = Image.alpha_composite(img, glow(m, 40, 1.4))
    r, end = route(xs, tops)
    img = Image.alpha_composite(img, glow(r, 30, 1.2))
    img = Image.alpha_composite(img, glow(pin(end), 50, 1.3))
    img = img.resize((512, 512), Image.LANCZOS)
    img.save(out)
    print(out)


if __name__ == "__main__":
    main()
