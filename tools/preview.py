"""Renders what Zmap's art draws to a PNG, so the stitching can be looked at without the game: the "art"
test scenario dumps every visible texture of a view (tests/out/<name>.txt: file, place, size, texture
coordinates, layer, alpha, colour, mask) and this composes them in the game's order with the game's own
textures (downloaded and cached by build_data.py) and Zmap's masks.

    python tests/run.py art && python tools/preview.py [name ...] [--width 1400]
Writes tests/out/<name>.png."""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_data  # noqa: E402  (its texture cache)

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "tests" / "out"
SEA = (79, 79, 69)
_masks = {}


def mask_image(path):
    name = path.replace("\\", "/").split("/Masks/")[-1]   # (Caves/38: a subfolder's)
    if name not in _masks:
        _masks[name] = Image.open(ROOT / "Media" / "Masks" / f"{name}.tga").getchannel("A")
    return _masks[name]


def render(name, width):
    lines = (OUT / f"{name}.txt").read_text(encoding="utf-8").splitlines()
    _, l, t, r, b = lines[0].split("|")
    l, t, r, b = map(float, (l, t, r, b))
    scale = width / (r - l)
    height = int(round((b - t) * scale))
    canvas = Image.new("RGBA", (width, height), SEA + (255,))
    items = []
    for line in lines[1:]:
        f = line.split("|")
        items.append({"file": f[0], "x": float(f[1]), "y": float(f[2]), "w": float(f[3]), "h": float(f[4]),
                      "tc": tuple(map(float, f[5:9])), "level": int(f[9]), "layer": int(f[10]), "sub": int(f[11]),
                      "alpha": float(f[12]), "color": tuple(map(float, f[13:16])), "desat": float(f[16]),
                      "mask": f[17], "id": int(f[18])})
    items.sort(key=lambda i: (i["level"], i["layer"], i["sub"], i["id"]))
    from concurrent.futures import ThreadPoolExecutor
    with ThreadPoolExecutor(8) as pool:   # fetch the textures first
        list(pool.map(build_data.texture, sorted({int(i["file"]) for i in items if i["file"].isdigit()})))
    for it in items:
        x0, y0 = (it["x"] - l) * scale, (it["y"] - t) * scale
        w, h = it["w"] * scale, it["h"] * scale
        if x0 > width or y0 > height or x0 + w < 0 or y0 + h < 0 or w < 0.5 or h < 0.5:
            continue
        # only the part in the picture (far in, a texture is many times the picture's size)
        fx0, fx1 = max(0, -x0) / w, min(w, width - x0) / w
        fy0, fy1 = max(0, -y0) / h, min(h, height - y0) / h
        if fx0 > 0 or fy0 > 0 or fx1 < 1 or fy1 < 1:
            tl, tr, tt, tb = it["tc"]
            it = dict(it, x=it["x"] + it["w"] * fx0, y=it["y"] + it["h"] * fy0, w=it["w"] * (fx1 - fx0), h=it["h"] * (fy1 - fy0),
                      tc=(tl + (tr - tl) * fx0, tl + (tr - tl) * fx1, tt + (tb - tt) * fy0, tt + (tb - tt) * fy1))
            x0, y0 = (it["x"] - l) * scale, (it["y"] - t) * scale
            w, h = it["w"] * scale, it["h"] * scale
            if w < 0.5 or h < 0.5:
                continue
        img = build_data.texture(int(it["file"])).convert("RGBA")
        tl, tr, tt, tb = it["tc"]
        fw, fh = img.size
        img = img.crop((int(round(tl * fw)), int(round(tt * fh)), int(round(tr * fw)), int(round(tb * fh))))
        size = (max(1, int(round(w))), max(1, int(round(h))))
        img = img.resize(size, Image.BILINEAR)
        a = np.array(img).astype(float)
        if it["desat"] > 0:
            grey = a[..., :3].mean(axis=2, keepdims=True)
            a[..., :3] = a[..., :3] * (1 - it["desat"]) + grey * it["desat"]
        a[..., :3] *= np.array(it["color"])
        alpha = a[..., 3] * it["alpha"]
        if it["mask"] != "-":
            mfile, mx, my, mw, mh = it["mask"].split(";")
            mx, my, mw, mh = map(float, (mx, my, mw, mh))
            m = mask_image(mfile)
            # the part of the mask under this texture
            sx0 = (it["x"] - mx) / mw * m.width
            sy0 = (it["y"] - my) / mh * m.height
            sx1 = (it["x"] + it["w"] - mx) / mw * m.width
            sy1 = (it["y"] + it["h"] - my) / mh * m.height
            part = m.transform(size, Image.EXTENT, (sx0, sy0, sx1, sy1), Image.BILINEAR)
            alpha *= np.array(part).astype(float) / 255
        a[..., 3] = alpha
        layer = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
        canvas.alpha_composite(layer, (int(round(x0)), int(round(y0)))) if x0 >= 0 and y0 >= 0 else _paste(canvas, layer, x0, y0)
    canvas.convert("RGB").save(OUT / f"{name}.png")
    print(f"{name}.png: {len(items)} textures")


def _paste(canvas, layer, x0, y0):
    big = Image.new("RGBA", canvas.size)
    big.paste(layer, (int(round(x0)), int(round(y0))))
    canvas.alpha_composite(big)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("names", nargs="*")
    ap.add_argument("--width", type=int, default=1400)
    args = ap.parse_args()
    names = args.names or sorted(p.stem for p in OUT.glob("*.txt"))
    for name in names:
        render(name, args.width)


if __name__ == "__main__":
    main()
