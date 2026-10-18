"""Generates Zmap's data from the WoW Forever client's own tables (wago.tools exports of its DB2 files) and
the masks that stitch the zone maps into one map. Run it again when Forever patches its maps:

    python tools/build_data.py [--build 1.60.1.70374]

Writes Data/Maps.lua, Data/Flights.lua, Data/Minimap.lua and Media/Masks/*.tga. Downloads (tables, the
exploration overlays the masks are cut from, the continents' WDT files) are cached in tools/cache.

How the stitching works (Art.lua draws it): every zone map is the zone's painted art plus "overlays", the
pieces you reveal by exploring. The base art carries a parchment frame and the neighbours' names, so it
is drawn through two masks cut from the union of the zone's overlays: a wide soft "halo" (its mountains
and coasts, under every other zone's own land) and a tighter "core" (its land). The overlays go on top.
"""
import argparse
import csv
import io
import math
import struct
import sys
import time
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
CACHE = Path(__file__).resolve().parent / "cache"
BUILD = "1.60.1.70374"
LOCALES = ["enUS", "esES", "esMX", "deDE", "frFR", "ptBR", "itIT", "ruRU", "koKR", "zhCN", "zhTW"]
WORLD = 947
CONTINENT_MAPS = {0: 1415, 1: 1414}       # instance map -> its continent uiMap
ART_W, ART_H, TILE = 1002, 668, 256       # every map art here: 1002x668 in 256 px tiles (UiMapArtStyleLayer 1)
HALO_SIZE, CORE_SIZE = 64, 128            # mask textures (stretched over the zone)
SPEED = 30                                # flights, yards a second (calibrated in game by Modules/Flights.lua)


def fetch(url, path):
    if path.exists():
        return path.read_bytes()
    path.parent.mkdir(parents=True, exist_ok=True)
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (Zmap build_data)"})
            data = urllib.request.urlopen(req, timeout=90).read()
            path.write_bytes(data)
            return data
        except Exception as e:  # wago.tools throttles bursts: retry
            if attempt == 3:
                raise RuntimeError(f"{url}: {e}") from e
            time.sleep(2 + attempt * 3)


def table(name, locale="enUS", build=None):
    build = build or BUILD
    data = fetch(f"https://wago.tools/db2/{name}/csv?build={build}&locale={locale}",
                 CACHE / build / f"{name}.{locale}.csv")
    rows = list(csv.DictReader(io.StringIO(data.decode("utf-8"))))
    if not rows:
        raise RuntimeError(f"{name}: empty table for build {build}")
    return rows


def casc(fdid):
    return fetch(f"https://wago.tools/api/casc/{fdid}?version={BUILD}", CACHE / "casc" / f"{fdid}.bin")


def texture(fdid):
    png = CACHE / "tex" / f"{fdid}.png"
    if not png.exists():
        img = Image.open(io.BytesIO(casc(fdid)))
        img.load()
        png.parent.mkdir(parents=True, exist_ok=True)
        img.convert("RGBA").save(png)
    return Image.open(png)


def num(v):
    """A Lua number literal, short."""
    f = float(v)
    if f == int(f):
        return str(int(f))
    return f"{f:.5f}".rstrip("0")


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def names_by_locale(name, key="Name_lang", id_key="ID"):
    out = {}
    for loc in LOCALES:
        for r in table(name, loc):
            out.setdefault(r[id_key], {})[loc] = r[key]
    return out


def loc_names(entry):
    """{enUS, esES, esMX, deDE, frFR, ptBR, itIT, ruRU, koKR, zhCN, zhTW} -> Lua table, dropping translations equal to English."""
    en = entry.get("enUS", "")
    parts = [lua_str(en)]
    for loc in LOCALES[1:]:
        v = entry.get(loc) or en
        parts.append(lua_str(v) if v != en else "nil")
    while parts[-1] == "nil":
        parts.pop()
    return "{ " + ", ".join(parts) + " }"


# --------------------------------------------------------------------------------------------------------------
# Maps
# --------------------------------------------------------------------------------------------------------------

def build_maps():
    uimap = {r["ID"]: r for r in table("UiMap")}
    names = names_by_locale("UiMap")
    assign = {}
    world_assign = {}
    for r in sorted(table("UiMapAssignment"), key=lambda r: int(r["OrderIndex"])):
        if r["UiMapID"] == str(WORLD):
            world_assign[int(r["MapID"])] = r
        else:
            assign.setdefault(r["UiMapID"], r)
    xart = {r["UiMapID"]: r["UiMapArtID"] for r in table("UiMapXMapArt") if r["PhaseID"] == "0"}
    tiles = {}
    for r in table("UiMapArtTile"):
        if r["LayerIndex"] == "0":
            tiles.setdefault(r["UiMapArtID"], []).append(r)
    overlays = {}
    for r in table("WorldMapOverlay"):
        overlays.setdefault(r["UiMapArtID"], []).append(r)
    otiles = {}
    for r in table("WorldMapOverlayTile"):
        if r["LayerIndex"] == "0":
            otiles.setdefault(r["WorldMapOverlayID"], []).append(r)

    # instance map -> 947 placement: u = a + b * worldY, v = c + d * worldX (the continents' affine maps)
    transforms = {}
    for inst, r in world_assign.items():
        min_x, min_y, max_x, max_y = (float(r[k]) for k in ("Region_0", "Region_1", "Region_3", "Region_4"))
        u0, v0, u1, v1 = (float(r[k]) for k in ("UiMin_0", "UiMin_1", "UiMax_0", "UiMax_1"))
        b = -(u1 - u0) / (max_y - min_y)
        d = -(v1 - v0) / (max_x - min_x)
        transforms[inst] = (u0 - b * max_y, b, v0 - d * max_x, d)

    def rect_on_world(m):
        a = assign[m]
        inst = int(a["MapID"])
        if inst not in transforms:
            return None
        ta, tb, tc, td = transforms[inst]
        min_x, min_y, max_x, max_y = (float(a[k]) for k in ("Region_0", "Region_1", "Region_3", "Region_4"))
        return ta + tb * max_y, ta + tb * min_y, tc + td * max_x, tc + td * min_x   # l, r, t, b

    def art_tiles(m):
        rows = sorted(tiles.get(xart.get(m), []), key=lambda r: (int(r["RowIndex"]), int(r["ColIndex"])))
        return [int(r["FileDataID"]) for r in rows]

    maps = {}
    world_rows = art_tiles(str(WORLD))
    maps[WORLD] = {"kind": "world", "rect": (0, 1, 0, 1), "art": world_rows, "parent": 0, "inst": -1}
    for inst, m in CONTINENT_MAPS.items():
        maps[m] = {"kind": "continent", "rect": rect_on_world(str(m)), "art": art_tiles(str(m)), "parent": WORLD, "inst": inst}
    area_ids = set()
    for m, r in uimap.items():
        if r["Type"] != "3" or m not in assign:
            continue
        inst = int(assign[m]["MapID"])
        if inst not in CONTINENT_MAPS:
            continue   # its own instance (Zephras Isle, Darkspear Islands): not on the continents
        art = xart.get(m)
        ovs = []
        for o in sorted(overlays.get(art, []), key=lambda o: int(o["ID"])):
            ts = sorted(otiles.get(o["ID"], []), key=lambda t: (int(t["RowIndex"]), int(t["ColIndex"])))
            if not ts:
                continue
            areas = [int(o[f"AreaID_{i}"]) for i in range(4) if o[f"AreaID_{i}"] != "0"]
            area_ids.update(areas)
            ovs.append({"w": int(o["TextureWidth"]), "h": int(o["TextureHeight"]), "x": int(o["OffsetX"]),
                        "y": int(o["OffsetY"]), "areas": areas, "fdids": [int(t["FileDataID"]) for t in ts]})
        a = assign[m]
        maps[int(m)] = {
            "kind": "zone" if ovs else "city",
            "rect": rect_on_world(m),
            "parent": int(r["ParentUiMapID"]),
            "inst": inst,
            "world": tuple(float(a[k]) for k in ("Region_0", "Region_1", "Region_3", "Region_4")),
            "art": art_tiles(m),
            "overlays": ovs,
        }
    return maps, transforms, names, area_ids


def compose_overlays(zone):
    """The union of a zone's overlays, as an alpha image the size of its art."""
    img = Image.new("RGBA", (ART_W + TILE * 2, ART_H + TILE * 2))
    for o in zone["overlays"]:
        cols = math.ceil(o["w"] / TILE)
        for i, fdid in enumerate(o["fdids"]):
            row, col = divmod(i, cols)
            img.alpha_composite(texture(fdid), (o["x"] + col * TILE, o["y"] + row * TILE))
    return img.crop((0, 0, ART_W, ART_H)).getchannel("A")


def disk(r):
    y, x = np.mgrid[-r:r + 1, -r:r + 1]
    return np.hypot(x, y) <= r


def edge_ramp(w, h, inset=18, ramp=48):
    """1 inside, falling to 0 at the art's frame: no straight cut where the zone's rectangle ends."""
    xs = np.minimum(np.arange(w), np.arange(w)[::-1]).astype(float)
    ys = np.minimum(np.arange(h), np.arange(h)[::-1]).astype(float)
    return np.outer(np.clip((ys - inset) / ramp, 0, 1), np.clip((xs - inset) / ramp, 0, 1))


def save_mask(alpha, size, path):
    a = Image.fromarray(np.clip(alpha, 0, 255).astype(np.uint8)).resize((size, size), Image.LANCZOS)
    white = Image.new("L", a.size, 255)
    Image.merge("RGBA", (white, white, white, a)).save(path)


def rects_overlap(a, b):
    return a[0] < b[1] and a[1] > b[0] and a[2] < b[3] and a[3] > b[2]


def resample(mask, src_rect, dst_rect):
    """A mask over one zone's map, as it falls on another zone's map (both in their art's pixels)."""
    sl, sr, st, sb = src_rect
    dl, dr, dt, db = dst_rect
    a = (dr - dl) / (sr - sl)
    c = (dl - sl) / (sr - sl) * ART_W
    e = (db - dt) / (sb - st)
    f = (dt - st) / (sb - st) * ART_H
    img = Image.fromarray(mask.astype(np.uint8) * 255)
    out = img.transform((ART_W, ART_H), Image.AFFINE, (a, 0, c, 0, e, f), Image.BILINEAR, fillcolor=0)
    return np.array(out).astype(float) / 255


def edge_depth(rect, grid_rect):
    """How far inside `rect` each pixel of the map over `grid_rect` is (to its nearest edge, in world map
    pixels); 0 outside it."""
    gl, gr, gt, gb = grid_rect
    us = gl + (np.arange(ART_W) + 0.5) / ART_W * (gr - gl)
    vs = gt + (np.arange(ART_H) + 0.5) / ART_H * (gb - gt)
    l, r, t, b = rect
    dx = np.minimum(us - l, r - us) * ART_W
    dy = np.minimum(vs - t, b - vs) * ART_H
    return np.clip(np.minimum.outer(dy, dx), 0, None)


def land(zone):
    """The zone's land in its art's pixels: its overlays joined up (the gaps between them closed) and filled."""
    a = np.array(compose_overlays(zone)) > 40
    close = 30
    a = ndimage.binary_closing(np.pad(a, close), structure=disk(close))[close:-close, close:-close]
    return ndimage.binary_fill_holes(a)


def build_masks(maps, write=True):
    """Writes each zone's halo and core masks (and the shared city / frame masks); returns each zone's label
    point: the most inland spot of its land, as a share of its map (where its name goes)."""
    out = ROOT / "Media" / "Masks"
    out.mkdir(parents=True, exist_ok=True)
    from concurrent.futures import ThreadPoolExecutor
    wanted = {f for z in maps.values() for o in z.get("overlays", []) for f in o["fdids"]}
    with ThreadPoolExecutor(8) as pool:   # download them all first, in parallel
        list(pool.map(texture, sorted(wanted)))
    ramp = edge_ramp(ART_W, ART_H)
    zones = {m: z for m, z in sorted(maps.items()) if z["kind"] == "zone"}
    grounds = {m: land(z) for m, z in zones.items()}
    labels = {}
    for m, zone in zones.items():
        ground = grounds[m]
        dist = ndimage.distance_transform_edt(np.pad(ground, 1))[1:-1, 1:-1]   # (the frame counts as shore)
        y, x = np.unravel_index(np.argmax(dist), dist.shape)
        labels[m] = (x / ART_W, y / ART_H)
        if not write:
            continue
        # Neighbours: a zone's rectangle runs into theirs, and cut straight there it showed as a line. So its
        # core stops where their land begins, and where both claim the land (the strip their rectangles share)
        # each fades out towards its own edge: a cross-fade between the two paintings, deeper in wins.
        others = np.zeros((ART_H, ART_W))
        deep = edge_depth(zone["rect"], zone["rect"])
        rivals = np.zeros((ART_H, ART_W))
        for n, other in zones.items():
            if n != m and rects_overlap(zone["rect"], other["rect"]):
                theirs = resample(grounds[n], other["rect"], zone["rect"])
                others = np.maximum(others, theirs)
                rivals += edge_depth(other["rect"], zone["rect"]) * theirs
        others = np.array(Image.fromarray((others * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))).astype(float) / 255
        share = deep / (deep + rivals + 1e-6)
        for suffix, grow, blur, size in (("h", 55, 25, HALO_SIZE), ("c", 12, 8, CORE_SIZE)):
            g = ndimage.binary_dilation(ground, structure=disk(grow)).astype(np.uint8) * 255
            g = np.array(Image.fromarray(g).filter(ImageFilter.GaussianBlur(blur))).astype(float)
            if suffix == "c":
                g = g * np.maximum(1 - others, ground) * np.clip(share * 2, 0, 1)
            save_mask(g * ramp, size, out / f"{m}{suffix}.tga")
    if write:
        # cities: their map without its frame, faded round; continents: their art without the frame
        y, x = np.mgrid[0:ART_H, 0:ART_W]
        ell = np.hypot((x - ART_W / 2) / (ART_W * 0.47), (y - ART_H / 2) / (ART_H * 0.47))
        save_mask(np.clip((1 - ell) / 0.25, 0, 1) * 255, CORE_SIZE, out / "city.tga")
        save_mask(edge_ramp(ART_W, ART_H, inset=24, ramp=90) * 255, CORE_SIZE, out / "frame.tga")
    return labels


# --------------------------------------------------------------------------------------------------------------
# Minimap tiles (the close-up terrain): the continents' WDT lists each ADT tile's minimap texture
# --------------------------------------------------------------------------------------------------------------

def build_minimap():
    wdt_of = {int(r["ID"]): int(r["WdtFileDataID"]) for r in table("Map")}
    out = {}
    for inst in CONTINENT_MAPS:
        data = casc(wdt_of[inst])
        i = 0
        while i + 8 <= len(data):
            tag = data[i:i + 4][::-1]
            size = struct.unpack("<I", data[i + 4:i + 8])[0]
            if tag == b"MAID":
                ids = struct.unpack(f"<{size // 4}I", data[i + 8:i + 8 + size])
                per = size // (64 * 64 * 4)
                out[inst] = {k: ids[k * per + 7] for k in range(64 * 64) if ids[k * per + 7]}
            i += 8 + size
        if inst not in out:
            raise RuntimeError(f"WDT {wdt_of[inst]} has no MAID chunk")
    return out


# --------------------------------------------------------------------------------------------------------------
# Flights
# --------------------------------------------------------------------------------------------------------------

def simplify(points, eps):
    """Ramer-Douglas-Peucker on [(x, y)]."""
    if len(points) < 3:
        return points
    (x1, y1), (x2, y2) = points[0], points[-1]
    dx, dy = x2 - x1, y2 - y1
    norm = math.hypot(dx, dy) or 1e-9
    best, idx = 0, 0
    for i in range(1, len(points) - 1):
        x, y = points[i]
        d = abs(dy * x - dx * y + x2 * y1 - y2 * x1) / norm
        if d > best:
            best, idx = d, i
    if best <= eps:
        return [points[0], points[-1]]
    return simplify(points[:idx + 1], eps)[:-1] + simplify(points[idx:], eps)


def build_flights():
    names = names_by_locale("TaxiNodes")
    nodes = {}
    for r in table("TaxiNodes"):
        inst, flags, name = int(r["ContinentID"]), int(r["Flags"]), r["Name_lang"]
        if inst not in CONTINENT_MAPS or not flags & 3:
            continue
        if name.startswith(("zzOLD", "Quest Path", "Transport", "Generic")):
            continue
        nodes[int(r["ID"])] = {"inst": inst, "x": float(r["Pos_0"]), "y": float(r["Pos_1"]),
                               "fac": {1: "A", 2: "H", 3: "N"}[flags & 3], "names": names[r["ID"]]}
    points = {}
    for r in table("TaxiPathNode"):
        points.setdefault(r["PathID"], []).append((int(r["NodeIndex"]), float(r["Loc_0"]), float(r["Loc_1"]), int(r["ContinentID"])))
    paths = []
    for r in table("TaxiPath"):
        a, b = int(r["FromTaxiNode"]), int(r["ToTaxiNode"])
        if a not in nodes or b not in nodes or nodes[a]["inst"] != nodes[b]["inst"]:
            continue
        pts = [(x, y) for _, x, y, c in sorted(points.get(r["ID"], [])) if c == nodes[a]["inst"]]
        if len(pts) < 2:
            continue
        length = sum(math.hypot(x2 - x1, y2 - y1) for (x1, y1), (x2, y2) in zip(pts, pts[1:]))
        paths.append({"from": a, "to": b, "len": length, "cost": int(r["Cost"]), "poly": simplify(pts, 40)})
    return nodes, paths


# Boats and zeppelins sail the "Transport" taxi paths: points per continent, docking where a point has a delay.
# The tables don't say which route a path is, so they are named here (by the docks their points reach).
TRANSPORTS = {   # path: kind, faction, name (the key), the areas at its ends (their names, in each language)
    241: ("boat", "N", "Booty Bay - Ratchet", (35, 392)),
    285: ("zeppelin", "H", "Grom'gol - Orgrimmar", (117, 1637)),
    292: ("boat", "A", "Menethil Harbor - Theramore", (150, 513)),
    293: ("boat", "A", "Rut'theran Village - Auberdine", (702, 442)),
    295: ("boat", "A", "Menethil Harbor - Auberdine", (150, 442)),
    301: ("zeppelin", "H", "Undercity - Grom'gol", (1497, 117)),
    302: ("zeppelin", "H", "Orgrimmar - Undercity", (1637, 1497)),
    303: ("boat", "A", "Feathermoon Stronghold - Feralas", (1116, 357)),
}


def build_transports():
    points = {}
    for r in table("TaxiPathNode"):
        points.setdefault(r["PathID"], []).append(r)
    out = []
    areas = names_by_locale("AreaTable", "AreaName_lang")
    for pid, (kind, fac, name, ends) in sorted(TRANSPORTS.items()):
        pts = sorted(points.get(str(pid), []), key=lambda r: int(r["NodeIndex"]))
        if not pts:
            raise RuntimeError(f"transport path {pid} is gone: check TRANSPORTS against TaxiPath")
        pieces, docks = [], []
        for r in pts:
            inst, x, y = int(r["ContinentID"]), float(r["Loc_0"]), float(r["Loc_1"])
            if inst not in CONTINENT_MAPS:
                continue
            # a new piece on another continent, or where the path jumps (the vessel is moved at sea)
            if not pieces or pieces[-1][0] != inst or math.dist(pieces[-1][1][-1], (x, y)) > 2000:
                pieces.append((inst, []))
            pieces[-1][1].append((x, y))
            if r["Delay"] != "0":
                docks.append((inst, x, y))
        if len(docks) > 2:   # its two docks: the stops farthest apart (a ferry's path is a loop)
            docks = list(max(((a, b) for i, a in enumerate(docks) for b in docks[i + 1:]),
                             key=lambda ab: (ab[0][0] != ab[1][0], math.dist(ab[0][1:], ab[1][1:]))))
        a, b = (areas[str(e)] for e in ends)
        out.append({"kind": kind, "fac": fac, "name": name,
                    "names": {loc: f"{a.get(loc) or a['enUS']} - {b.get(loc) or b['enUS']}" for loc in LOCALES},
                    "pieces": [(inst, simplify(p, 25)) for inst, p in pieces], "docks": docks})
    return out


def fold(text):
    """The search's form of a name (Core.lua's ns.Fold): lower case, no accents."""
    import unicodedata
    return "".join(c for c in unicodedata.normalize("NFD", text) if unicodedata.category(c) != "Mn").lower()


def build_dungeons():
    """Entrances (where a ghost returns to: Map.db2's corpse point) and the levels Forever tunes each
    dungeon to (its group finder entry's ContentTuning), matched by name."""
    tuning = {r["ID"]: int(r["MinLevelSquish"]) for r in table("ContentTuning")}
    lfg = names_by_locale("LFGDungeons")
    levels = {}
    for r in table("LFGDungeons"):
        level = tuning.get(r["ContentTuningID"], 0)
        if r["TypeID"] in ("0", "1", "2") and level:
            for name in set(lfg[r["ID"]].values()):
                levels[fold(name)] = level
    map_names = names_by_locale("Map", key="MapName_lang")
    entrances = []
    for r in table("Map"):
        inst = int(r["CorpseMapID"])
        x, y = float(r["Corpse_0"]), float(r["Corpse_1"])
        if r["InstanceType"] not in ("1", "2") or inst not in CONTINENT_MAPS or (x == 0 and y == 0):
            continue
        if r["MapName_lang"].startswith("<"):
            continue
        names = map_names[r["ID"]]
        # its level: the group finder's entry of the same name (or its wings: "Dire Maul - East")
        key = fold(names["enUS"])
        level = levels.get(key) or min((lv for k, lv in levels.items() if key in k or k in key), default=0)
        entrances.append({"map": int(r["ID"]), "inst": inst, "x": x, "y": y, "raid": r["InstanceType"] == "2",
                          "names": names, "level": level})
    return entrances, levels


# --------------------------------------------------------------------------------------------------------------
# Lua output
# --------------------------------------------------------------------------------------------------------------

HEADER = ("-- Generated by tools/build_data.py from the WoW Forever client's tables (build {build}).\n"
          "-- Regenerate rather than edit.\n")


def write_maps(maps, transforms, names, area_ids, labels):
    area_names = names_by_locale("AreaTable", key="AreaName_lang")
    L = [HEADER.format(build=BUILD), "local _, ns = ...", "", f'ns.DATA_BUILD = "{BUILD}"', ""]
    L.append("-- instance map -> where its world positions (yards) land on Azeroth's map (947, 0..1):")
    L.append("--   u = a + b * worldY, v = c + d * worldX")
    L.append("ns.WORLD_TRANSFORM = {")
    for inst, (a, b, c, d) in sorted(transforms.items()):
        L.append(f"    [{inst}] = {{ {a!r}, {b!r}, {c!r}, {d!r} }},")
    L.append("}")
    L.append("")
    L.append("-- [uiMapID] = { kind, parent, instance, { l, r, t, b on 947 }, { art tiles, row by row },")
    L.append("--               { names enUS, esES, esMX, deDE, frFR, ptBR, itIT, ruRU, koKR, zhCN, zhTW }, overlays = { { w, h, x, y, { areaIDs }, fileIDs... } } }")
    L.append("ns.MAPS = {")
    for m, z in sorted(maps.items()):
        rect = "{ " + ", ".join(repr(round(v, 7)) for v in z["rect"]) + " }"
        art = "{ " + ", ".join(str(f) for f in z["art"]) + " }"
        line = f'    [{m}] = {{ "{z["kind"]}", {z["parent"]}, {z["inst"]}, {rect}, {art}, {loc_names(names.get(str(m), {}))}'
        if z.get("overlays"):
            L.append(line + ", {")
            for o in z["overlays"]:
                areas = "{ " + ", ".join(str(a) for a in o["areas"]) + " }"
                L.append(f'        {{ {o["w"]}, {o["h"]}, {o["x"]}, {o["y"]}, {areas}, {", ".join(str(f) for f in o["fdids"])} }},')
            L.append("    } },")
        else:
            L.append(line + " },")
    L.append("}")
    L.append("")
    L.append("-- where each zone's name goes: [uiMapID] = { x, y } on its own map (the most inland spot of its land)")
    L.append("ns.LABELS = {")
    for m, (x, y) in sorted(labels.items()):
        L.append(f"    [{m}] = {{ {x:.3f}, {y:.3f} }},")
    L.append("}")
    L.append("")
    L.append("-- subzone names (the overlays' areas), for the search: [areaID] = { enUS, esES, esMX, deDE, frFR, ptBR, itIT, ruRU, koKR, zhCN, zhTW }")
    L.append("ns.AREAS = {")
    for a in sorted(area_ids):
        if str(a) in area_names:
            L.append(f"    [{a}] = {loc_names(area_names[str(a)])},")
    L.append("}")
    (ROOT / "Data" / "Maps.lua").write_text("\n".join(L) + "\n", encoding="utf-8")


def write_minimap(tiles):
    L = [HEADER.format(build=BUILD), "local _, ns = ...", "",
         "-- [instance map] = { [row * 64 + col] = minimap texture (fileID) }: each ADT tile's top-down terrain",
         "ns.MINIMAP = {"]
    for inst, t in sorted(tiles.items()):
        L.append(f"    [{inst}] = {{")
        items = [f"[{k}]={v}" for k, v in sorted(t.items())]
        for i in range(0, len(items), 8):
            L.append("        " + ", ".join(items[i:i + 8]) + ",")
        L.append("    },")
    L.append("}")
    (ROOT / "Data" / "Minimap.lua").write_text("\n".join(L) + "\n", encoding="utf-8")


def write_flights(nodes, paths):
    L = [HEADER.format(build=BUILD), "local _, ns = ...", "", f"ns.FLIGHT_SPEED = {SPEED}   -- yards a second, until flights measured in game refine it", "",
         "-- [nodeID] = { instance, worldX, worldY, faction (A, H or N), { names enUS, esES, esMX, deDE, frFR, ptBR, itIT, ruRU, koKR, zhCN, zhTW } }",
         "ns.TAXI_NODES = {"]
    for i, n in sorted(nodes.items()):
        L.append(f'    [{i}] = {{ {n["inst"]}, {num(round(n["x"], 1))}, {num(round(n["y"], 1))}, "{n["fac"]}", {loc_names(n["names"])} }},')
    L.append("}")
    L.append("")
    L.append("-- { from, to, length (yards), cost (copper), { x1, y1, x2, y2, ... } (world yards, simplified) }")
    L.append("ns.TAXI_PATHS = {")
    for p in sorted(paths, key=lambda p: (p["from"], p["to"])):
        poly = ", ".join(f"{num(round(x))}, {num(round(y))}" for x, y in p["poly"])
        L.append(f'    {{ {p["from"]}, {p["to"]}, {round(p["len"])}, {p["cost"]}, {{ {poly} }} }},')
    L.append("}")
    (ROOT / "Data" / "Flights.lua").write_text("\n".join(L) + "\n", encoding="utf-8")


def write_places(transports, entrances, levels):
    L = [HEADER.format(build=BUILD), "local _, ns = ...", "",
         "-- boats and zeppelins: { kind, faction (A, H or N), route (its key), { { instance, { x1, y1, x2, y2, ... } },",
         "--   ... } (the way it sails, per continent, world yards), { { instance, x, y } at each end } (its docks),",
         "--   { route names, one per language } }",
         "ns.TRANSPORTS = {"]
    for t in transports:
        pieces = ", ".join("{ %d, { %s } }" % (inst, ", ".join(f"{num(round(x))}, {num(round(y))}" for x, y in pts))
                           for inst, pts in t["pieces"])
        docks = ", ".join(f"{{ {inst}, {num(round(x))}, {num(round(y))} }}" for inst, x, y in t["docks"])
        L.append(f'    {{ "{t["kind"]}", "{t["fac"]}", {lua_str(t["name"])}, {{ {pieces} }}, {{ {docks} }}, {loc_names(t["names"])} }},')
    L.append("}")
    L.append("")
    L.append("-- dungeon and raid entrances: { instance map, continent, worldX, worldY, raid, level, { names } }")
    L.append("ns.DUNGEONS = {")
    for e in sorted(entrances, key=lambda e: e["map"]):
        L.append(f'    {{ {e["map"]}, {e["inst"]}, {num(round(e["x"], 1))}, {num(round(e["y"], 1))}, {"true" if e["raid"] else "false"}, '
                 f'{e["level"]}, {loc_names(e["names"])} }},')
    L.append("}")
    L.append("")
    L.append("-- the level Forever tunes each dungeon to, by its name as the search folds it (any language)")
    L.append("ns.DUNGEON_LEVELS = {")
    for k, v in sorted(levels.items()):
        L.append(f"    [{lua_str(k)}] = {v},")
    L.append("}")
    (ROOT / "Data" / "Places.lua").write_text("\n".join(L) + "\n", encoding="utf-8")


# --------------------------------------------------------------------------------------------------------------
# Dungeon maps: Forever's tables have none, but its install has the pictures. Mists Classic's tables say which
# pictures make each instance's floors and where its bosses are. Left out: the dungeons Pandaria rebuilt
# (their maps are not Forever's), and bosses that are not NPCs of Forever (Cataclysm's, in the Deadmines).
# --------------------------------------------------------------------------------------------------------------

MISTS = "5.5.4.70449"
REBUILT = {311, 316, 246}   # journal instances: Scarlet Halls, Scarlet Monastery, Scholomance (Pandaria's)


def build_dungeon_maps():
    um = {r["ID"]: r for r in table("UiMap", build=MISTS)}
    inst_of = {}
    for r in table("UiMapAssignment", build=MISTS):
        if um.get(r["UiMapID"], {}).get("Type") == "4":
            inst_of.setdefault(r["UiMapID"], int(r["MapID"]))
    art = {r["UiMapID"]: r["UiMapArtID"] for r in table("UiMapXMapArt", build=MISTS) if r["PhaseID"] == "0"}
    tiles = {}
    for r in table("UiMapArtTile", build=MISTS):
        if r["LayerIndex"] == "0":
            tiles.setdefault(r["UiMapArtID"], []).append(r)
    floor_names = {loc: {r["UiMapID"]: r["Name_lang"] for r in table("UiMapGroupMember", loc, MISTS)} for loc in LOCALES}
    order = {r["UiMapID"]: int(r["FloorIndex"]) for r in table("UiMapGroupMember", build=MISTS)}
    journal = {r["ID"]: r for r in table("JournalInstance", build=MISTS)}
    out = {}
    for m, inst in inst_of.items():
        ts = sorted(tiles.get(art.get(m), []), key=lambda r: (int(r["RowIndex"]), int(r["ColIndex"])))
        if len(ts) != 12:
            continue   # (not the 4 x 3 classic picture)
        out.setdefault(inst, []).append({"ui": int(m), "order": order.get(m, 0), "tiles": [int(t["FileDataID"]) for t in ts],
                                         "names": {loc: floor_names[loc].get(m, "") for loc in LOCALES}, "bosses": []})
    rebuilt = {int(j["MapID"]) for jid, j in journal.items() if int(jid) in REBUILT}
    forever = {int(r["ID"]) for r in table("Map") if r["InstanceType"] in ("1", "2")}
    for inst in list(out):
        if inst in rebuilt or inst not in forever:
            del out[inst]
    for floors in out.values():
        floors.sort(key=lambda f: f["order"])
    # make sure the pictures are in Forever's install (the first tile of each floor)
    for inst in list(out):
        out[inst] = [f for f in out[inst] if casc(f["tiles"][0])]
        if not out[inst]:
            del out[inst]
    # The bosses: Forever's own encounters (every one, in order, in each language). Where they stand, from Mists'
    # journal: by the encounter's ID, else by its English name; Mists has the Cataclysm versions of some dungeons
    # (the Deadmines, Shadowfang Keep, the Stockade...), so their bosses stay without a place.
    names = {loc: {r["ID"]: r["Name_lang"] for r in table("DungeonEncounter", loc)} for loc in LOCALES}
    encounters = {}
    for r in sorted(table("DungeonEncounter"), key=lambda r: (int(r["OrderIndex"]), int(r["ID"]))):
        inst = int(r["MapID"])
        if inst in out and all(e["names"]["enUS"] != r["Name_lang"] for e in encounters.get(inst, [])):
            encounters.setdefault(inst, []).append({"id": r["ID"], "names": {loc: names[loc].get(r["ID"], r["Name_lang"]) for loc in LOCALES}})
    journal_by_id, journal_by_name = {}, {}
    for r in table("JournalEncounter", build=MISTS):
        journal_by_id.setdefault(r["DungeonEncounterID"], r)
        journal_by_name.setdefault(r["Name_lang"], r)
    result = {}
    for inst, floors in out.items():
        index = {f["ui"]: i + 1 for i, f in enumerate(floors)}
        bosses = []
        for e in encounters.get(inst, []):
            j = journal_by_id.get(e["id"]) or journal_by_name.get(e["names"]["enUS"])
            floor = j and index.get(int(j["UiMapID"]))
            bosses.append({"names": e["names"], "floor": floor or 0,
                           "x": float(j["Map_0"]) if floor else 0, "y": float(j["Map_1"]) if floor else 0})
        result[inst] = {"floors": floors, "bosses": bosses}
    return result


# --------------------------------------------------------------------------------------------------------------
# Caves and the ways into some dungeons: Blizzard's micro maps (Mists Classic's tables; their pictures are in
# Forever's install), placed at their world box. Where several floors share a place, the first; Blackrock
# Mountain's deeper ones never by themselves.
# --------------------------------------------------------------------------------------------------------------

CAVE_SKIP = {34, 35}   # Blackrock Mountain's lower floors (under its main one)


def build_caves():
    um = {r["ID"]: r for r in table("UiMap", build=MISTS)}
    names = {loc: {r["ID"]: r["Name_lang"] for r in table("UiMap", loc, MISTS)} for loc in LOCALES}
    boxes = {}
    for r in sorted(table("UiMapAssignment", build=MISTS), key=lambda r: int(r["OrderIndex"])):
        m = r["UiMapID"]
        if um.get(m, {}).get("Type") == "5" and int(r["MapID"]) in CONTINENT_MAPS and m not in boxes:
            boxes[m] = (int(r["MapID"]), float(r["Region_0"]), float(r["Region_1"]), float(r["Region_3"]), float(r["Region_4"]))
    art = {r["UiMapID"]: r["UiMapArtID"] for r in table("UiMapXMapArt", build=MISTS) if r["PhaseID"] == "0"}
    tiles = {}
    for r in table("UiMapArtTile", build=MISTS):
        if r["LayerIndex"] == "0":
            tiles.setdefault(r["UiMapArtID"], []).append(r)
    out, first = {}, {}
    for m, box in sorted(boxes.items(), key=lambda kv: int(kv[0])):
        ts = sorted(tiles.get(art.get(m), []), key=lambda r: (int(r["RowIndex"]), int(r["ColIndex"])))
        name = names["enUS"].get(m, "")
        if int(m) in CAVE_SKIP or len(ts) != 12 or name in first:
            continue
        if not casc(int(ts[0]["FileDataID"])):
            continue
        first[name] = m
        out[int(m)] = {"names": {loc: names[loc].get(m, name) for loc in LOCALES}, "box": box,
                       "tiles": [int(t["FileDataID"]) for t in ts]}
    return out


def write_caves(caves):
    L = [HEADER.format(build=BUILD + " / Mists Classic " + MISTS), "local _, ns = ...", "",
         "-- caves and the ways into some dungeons: [micro map] = { { names enUS, esES, esMX, deDE, frFR, ptBR, itIT,",
         "--   ruRU, koKR, zhCN, zhTW }, instance, minX, minY, maxX, maxY (its picture's world box, yards),",
         "--   { 12 tile file IDs, row by row } }",
         "ns.CAVES = {"]
    for m, c in sorted(caves.items()):
        inst, x0, y0, x1, y1 = c["box"]
        L.append(f"    [{m}] = {{ {loc_names(c['names'])}, {inst}, {num(x0)}, {num(y0)}, {num(x1)}, {num(y1)}, "
                 f"{{ {', '.join(str(t) for t in c['tiles'])} }} }},")
    L.append("}")
    (ROOT / "Data" / "Caves.lua").write_text("\n".join(L) + "\n", encoding="utf-8")


def write_dungeon_maps(dmaps):
    L = [HEADER.format(build=BUILD + " / Mists Classic " + MISTS), "local _, ns = ...", "",
         "-- [instance map] = { floors = { { tiles (12 file IDs, row by row), { floor names enUS, esES, esMX, deDE, frFR, ptBR, itIT, ruRU, koKR, zhCN, zhTW } }, ... },",
         "--   bosses = { { { names }, floor (0: its place is not known), x, y }, ... } } (floors and bosses in order)",
         "ns.DUNGEON_MAPS = {"]
    for inst, d in sorted(out_sorted(dmaps)):
        L.append(f"    [{inst}] = {{ floors = {{")
        for f in d["floors"]:
            L.append(f"        {{ {{ {', '.join(str(t) for t in f['tiles'])} }}, {loc_names(f['names'])} }},")
        L.append("    }, bosses = {")
        for b in d["bosses"]:
            L.append(f"        {{ {loc_names(b['names'])}, {b['floor']}, {b['x']:.3f}, {b['y']:.3f} }},")
        L.append("    } },")
    L.append("}")
    (ROOT / "Data" / "DungeonMaps.lua").write_text("\n".join(L) + "\n", encoding="utf-8")


def out_sorted(d):
    return sorted(d.items())


# --------------------------------------------------------------------------------------------------------------
# Colour: each zone is painted in its own palette, and their borders show it. A tint per zone (vertex colour:
# it can only darken a channel) moves its land halfway towards the zones' common colour.
# --------------------------------------------------------------------------------------------------------------

def build_tints(maps):
    means = {}
    for m, zone in maps.items():
        if zone["kind"] != "zone":
            continue
        img = Image.new("RGBA", (ART_W + TILE * 2, ART_H + TILE * 2))
        for o in zone["overlays"]:
            cols = math.ceil(o["w"] / TILE)
            for i, fdid in enumerate(o["fdids"]):
                row, col = divmod(i, cols)
                img.alpha_composite(texture(fdid), (o["x"] + col * TILE, o["y"] + row * TILE))
        a = np.array(img.crop((0, 0, ART_W, ART_H))).astype(float)
        w = a[..., 3] / 255
        if w.sum() > 0:
            means[m] = np.array([(a[..., c] * w).sum() / w.sum() for c in range(3)])
    target = np.median(np.array(list(means.values())), axis=0)
    tints = {}
    for m, mean in means.items():
        f = np.clip(target / np.maximum(mean, 1), 0, 4)
        f = f / f.max()
        tints[m] = tuple(1 - 0.5 * (1 - f))
    return tints


def main():
    global BUILD
    ap = argparse.ArgumentParser()
    ap.add_argument("--build", default=BUILD)
    ap.add_argument("--no-masks", action="store_true")
    args = ap.parse_args()
    BUILD = args.build
    maps, transforms, names, area_ids = build_maps()
    zones = sum(1 for z in maps.values() if z["kind"] == "zone")
    print(f"maps: {len(maps)} ({zones} zones with overlays)")
    labels = build_masks(maps, write=not args.no_masks)
    print(f"masks: {len(labels)} zones")
    write_maps(maps, transforms, names, area_ids, labels)
    tiles = build_minimap()
    print("minimap tiles:", {k: len(v) for k, v in tiles.items()})
    write_minimap(tiles)
    nodes, paths = build_flights()
    print(f"flights: {len(nodes)} nodes, {len(paths)} paths")
    write_flights(nodes, paths)
    transports = build_transports()
    entrances, levels = build_dungeons()
    print(f"places: {len(transports)} transports, {len(entrances)} dungeon entrances, {len(levels)} dungeon levels")
    write_places(transports, entrances, levels)
    dmaps = build_dungeon_maps()
    print(f"dungeon maps: {len(dmaps)} instances, {sum(len(d['floors']) for d in dmaps.values())} floors, "
          f"{sum(len(d['bosses']) for d in dmaps.values())} bosses, "
          f"{sum(1 for d in dmaps.values() for b in d['bosses'] if b['floor'])} placed")
    write_dungeon_maps(dmaps)
    caves = build_caves()
    print(f"caves: {len(caves)}")
    write_caves(caves)
    tints = build_tints(maps)
    with open(ROOT / "Data" / "Maps.lua", "a", encoding="utf-8") as f:
        f.write("\n-- each zone's tint towards the zones' common colour (its painting's own palette shows at its borders)\n")
        f.write("ns.TINTS = {\n")
        for m, (r, g, b) in sorted(tints.items()):
            f.write(f"    [{m}] = {{ {r:.3f}, {g:.3f}, {b:.3f} }},\n")
        f.write("}\n")
    print(f"tints: {len(tints)} zones")


if __name__ == "__main__":
    sys.exit(main())
