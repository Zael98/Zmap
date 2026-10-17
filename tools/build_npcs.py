"""Generates Data/Npcs.lua: the NPCs of WoW Forever with where they stand, for Zmap's NPC search, the townsfolk
layer and the rares layer. Two sources, merged NPC by NPC:

  * QuestieDB's Forever database (from the latest Questie release on GitHub; Questie is GPL-3.0): ~13,000
    NPCs, ~10,000 of them with spawn points. Its data is CBOR in base64, stored as the TOC's metadata.
  * Warcraft DB (forever.warcraftdb.com), sniffed from Forever itself: fewer NPCs, but where it places one
    its spawn points, title and services win.

    python tools/build_npcs.py            (downloads what is not cached in tools/cache)

Names come in English; in game Zmap learns each NPC's name in the client's language (Modules/Npcs.lua).
Warcraft DB's certificate does not verify on some machines, so it is fetched without verifying it (public
data, nothing is sent)."""
import base64
import io
import json
import re
import ssl
import struct
import sys
import time
import urllib.request
import zipfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_data  # noqa: E402  (the client's tables: which uiMap each zone of QuestieDB is)

ROOT = Path(__file__).resolve().parent.parent
CACHE = Path(__file__).resolve().parent / "cache"
SITE = "https://forever.warcraftdb.com"
CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE
MAX_SPAWNS = 24          # an NPC standing in many places (a mob, the spirit healers) keeps this many

# services, in the order of the flag bits Modules/Npcs.lua reads
SERVICES = ["Innkeeper", "Vendor", "Repair", "Trainer", "Flight Master", "Banker", "Auctioneer", "Stable Master",
            "Spirit Healer", "Battlemaster", "Guild Banker", "Mailbox"]
# QuestieDB's npcFlags (Forever / classic) -> our services
QUESTIE_FLAGS = {4: "Vendor", 8: "Flight Master", 16: "Trainer", 32: "Spirit Healer", 128: "Innkeeper",
                 256: "Banker", 2048: "Battlemaster", 4096: "Auctioneer", 8192: "Stable Master", 16384: "Repair"}


def fetch(url, path, context=None):
    if path.exists():
        return path.read_bytes()
    path.parent.mkdir(parents=True, exist_ok=True)
    for attempt in range(5):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (Zmap build_npcs)"})
            data = urllib.request.urlopen(req, timeout=300, context=context).read()
            path.write_bytes(data)
            return data
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            time.sleep(2 + attempt * 3)
        except Exception:
            time.sleep(2 + attempt * 3)
    raise RuntimeError(f"{url}: no answer")


# --------------------------------------------------------------------------------------------------------------
# QuestieDB (Forever)
# --------------------------------------------------------------------------------------------------------------

def cbor(data, i=0):
    """A small CBOR decoder: what QuestieDB stores (ints, floats, strings, arrays, maps)."""
    b = data[i]
    i += 1
    major, info = b >> 5, b & 31
    if major == 7:
        if info == 25:
            return struct.unpack(">e", data[i:i + 2])[0], i + 2
        if info == 26:
            return struct.unpack(">f", data[i:i + 4])[0], i + 4
        if info == 27:
            return struct.unpack(">d", data[i:i + 8])[0], i + 8
        return {20: False, 21: True, 22: None}.get(info), i
    if info < 24:
        n = info
    else:
        size = {24: 1, 25: 2, 26: 4, 27: 8}[info]
        n, i = int.from_bytes(data[i:i + size], "big"), i + size
    if major == 0:
        return n, i
    if major == 1:
        return -1 - n, i
    if major in (2, 3):
        return data[i:i + n].decode("utf-8", "replace"), i + n
    if major == 4:
        out = []
        for _ in range(n):
            v, i = cbor(data, i)
            out.append(v)
        return out, i
    if major == 5:
        out = {}
        for _ in range(n):
            k, i = cbor(data, i)
            v, i = cbor(data, i)
            out[k] = v
        return out, i
    if major == 6:
        return cbor(data, i)
    raise ValueError(f"CBOR major type {major}")


def questie_toc():
    """The Forever QuestieDB's TOC (its data), from the latest Questie release."""
    path = CACHE / "questie" / "QuestieDB_Forever.toc"
    if path.exists():
        return path.read_text(encoding="utf-8")
    info = json.loads(fetch("https://api.github.com/repos/Questie/Questie/releases/latest", CACHE / "questie" / "release.json"))
    asset = next(a for a in info["assets"] if a["name"].endswith(".zip"))
    print(f"downloading {asset['name']} ({asset['size'] // 1_000_000} MB)")
    data = fetch(asset["browser_download_url"], CACHE / "questie" / asset["name"])
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        text = z.read("QuestieDB/QuestieDB_Forever.toc").decode("utf-8")
    path.write_text(text, encoding="utf-8")
    return text


def zone_maps():
    """AreaTable zone ID (what QuestieDB keys spawns by) -> uiMapID of that zone's map."""
    out = {}
    for r in sorted(build_data.table("UiMapAssignment"), key=lambda r: int(r["OrderIndex"])):
        area = int(r["AreaID"])
        if area and area not in out:
            out[area] = int(r["UiMapID"])
    return out


def from_questie():
    fields = {}
    for line in questie_toc().splitlines():
        m = re.match(r"## X-Npc-(\d+)-(S|7|7-\d+): (.*)", line)
        if m:
            fields.setdefault(int(m.group(1)), {})[m.group(2)] = m.group(3).strip()
    maps = zone_maps()
    npcs = {}
    for npc, f in fields.items():
        row = cbor(base64.b64decode(f["S"]))[0] if "S" in f else {}
        if isinstance(row, list):   # (same: fields 1..n with none missing come as an array)
            row = {i + 1: v for i, v in enumerate(row)}
        spawns_raw = f.get("7")
        if spawns_raw and spawns_raw.startswith("~"):   # split over several keys: 7-1, 7-2, ...
            parts = sorted((int(k.split("-")[1]), v) for k, v in f.items() if k.startswith("7-"))
            spawns_raw = "".join(v for _, v in parts)
        spawns = cbor(base64.b64decode(spawns_raw))[0] if spawns_raw else {}
        if isinstance(spawns, list):   # (a Lua table keyed 1..n is stored as an array: zone 1 is Dun Morogh)
            spawns = {i + 1: pts for i, pts in enumerate(spawns) if pts}
        by_map = {}
        for zone, pts in spawns.items():
            m = maps.get(zone)
            if m:
                for p in pts:
                    if 0 <= p[0] <= 100 and 0 <= p[1] <= 100:
                        by_map.setdefault(m, []).append((p[0] / 100, p[1] / 100))
        flags = 0
        for bit, service in QUESTIE_FLAGS.items():
            if row.get(15, 0) & bit:
                flags |= 1 << SERVICES.index(service)
        rank = row.get(6, 0)   # cmangos ranks: 1 elite, 2 rare elite, 3 boss, 4 rare
        lo, hi = row.get(4), row.get(5)
        npcs[npc] = {
            "id": npc, "name": row.get(1, ""), "title": row.get(14, ""), "flags": flags,
            "friendly": row.get(13, "") or "", "rare": rank in (2, 4), "elite": rank in (1, 2, 3),
            "level": (f"{lo}" if lo == hi else f"{lo}-{hi}") if lo else "", "spawns": by_map,
        }
    return npcs


# --------------------------------------------------------------------------------------------------------------
# Warcraft DB
# --------------------------------------------------------------------------------------------------------------

def wdb(path, cache):
    cached = cache.exists()
    data = fetch(SITE + path, cache, CTX)
    if not cached:
        time.sleep(0.15)   # (be gentle with the site)
    if data is None or data[:4] == b"null":
        return None
    return json.loads(data)


def wdb_ids():
    first = wdb("/api/data/list/npcs?page=1&per_page=100", CACHE / "wdb" / "list" / "1.json")
    ids = [r["record_id"] for r in first["rows"]]
    for page in range(2, first["pages"] + 1):
        ids += [r["record_id"] for r in wdb(f"/api/data/list/npcs?page={page}&per_page=100", CACHE / "wdb" / "list" / f"{page}.json")["rows"]]
    return ids


def strip(html):
    return re.sub(r"<[^>]+>", "", html or "").strip()


def from_wdb_node(npc_id, node):
    if not node:
        return None
    data = node.get("data") or {}
    pins = ((node.get("extra") or {}).get("npc_map") or {}).get("pins") or []
    if not data.get("name"):
        return None
    services = [s.strip() for s in (data.get("services") or "").split(",") if s.strip()]
    flags = 0
    for i, s in enumerate(SERVICES):
        if s in services:
            flags |= 1 << i
    reaction = data.get("reaction") or ""
    friendly = set(re.findall(r"faction-(\w+)", reaction)) if "Friendly" in strip(reaction) else set()
    classification = (data.get("classification") or "").lower()
    level = re.findall(r"\d+", str(data.get("level") or ""))
    by_map = {}
    for p in pins:
        by_map.setdefault(p["ui_map_id"], []).append((p["u"], p["v"]))
    return {
        "id": npc_id, "name": data["name"], "title": data.get("title") or "", "flags": flags,
        "friendly": "".join(sorted(f[0].upper() for f in friendly)),
        "rare": "rare" in classification, "elite": "elite" in classification,
        "level": "-".join(level[:2]) if level else "", "spawns": by_map,
    }


def from_wdb():
    ids = wdb_ids()
    with ThreadPoolExecutor(4) as pool:
        nodes = list(pool.map(lambda i: wdb(f"/api/data/node/npc/{i}", CACHE / "wdb" / "npc" / f"{i}.json"), ids))
    return {n["id"]: n for n in (from_wdb_node(i, node) for i, node in zip(ids, nodes)) if n}


# --------------------------------------------------------------------------------------------------------------
# Merge and write
# --------------------------------------------------------------------------------------------------------------

def merge(questie, wdbs):
    out = {}
    for npc in set(questie) | set(wdbs):
        q, w = questie.get(npc), wdbs.get(npc)
        if q and w:
            n = dict(q)
            if w["spawns"]:
                n["spawns"] = w["spawns"]
            for key in ("name", "title", "level", "friendly"):
                if w[key]:
                    n[key] = w[key]
            n["flags"] = q["flags"] | w["flags"]
            n["rare"], n["elite"] = q["rare"] or w["rare"], q["elite"] or w["elite"]
        else:
            n = q or w
        if n["spawns"] and n["name"]:
            out[npc] = n
    return out


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    questie = from_questie()
    print(f"QuestieDB Forever: {len(questie)} NPCs, {sum(1 for n in questie.values() if n['spawns'])} placed on Zmap's maps")
    wdbs = from_wdb()
    print(f"Warcraft DB: {len(wdbs)} NPCs, {sum(1 for n in wdbs.values() if n['spawns'])} placed")
    npcs = merge(questie, wdbs)
    print(f"merged: {len(npcs)} NPCs with spawn points")
    lines = ["-- Generated by tools/build_npcs.py from QuestieDB's Forever database (Questie, GPL-3.0) and Warcraft DB",
             "-- (forever.warcraftdb.com). Regenerate rather than edit.",
             "local _, ns = ...", "",
             "-- the services' flag bits, in order: " + ", ".join(SERVICES),
             "-- [npcID] = { name (English), title, flags, friendly to (A, H, AH or \"\"), level, rare (1) / elite (2),",
             "--             uiMapID, { x1, y1, x2, y2, ... } (per thousand of its map), another uiMapID, { ... }, ... }",
             "ns.NPCS = {"]
    for n in sorted(npcs.values(), key=lambda n: n["id"]):
        rank = (1 if n["rare"] else 0) + (2 if n["elite"] else 0)
        parts, kept = [], 0
        for m, pts in sorted(n["spawns"].items(), key=lambda kv: -len(kv[1])):
            pts = pts[:max(0, MAX_SPAWNS - kept)]
            if not pts:
                break
            kept += len(pts)
            coords = ", ".join(f"{round(u * 1000)}, {round(v * 1000)}" for u, v in pts)
            parts.append(f"{m}, {{ {coords} }}")
        lines.append(f'    [{n["id"]}] = {{ {lua_str(n["name"])}, {lua_str(n["title"])}, {n["flags"]}, "{n["friendly"]}", '
                     f'"{n["level"]}", {rank}, {", ".join(parts)} }},')
    lines.append("}")
    (ROOT / "Data" / "Npcs.lua").write_text("\n".join(lines) + "\n", encoding="utf-8")
    services = {}
    for n in npcs.values():
        for i, s in enumerate(SERVICES):
            if n["flags"] & (1 << i):
                services[s] = services.get(s, 0) + 1
    print("services:", services)
    print("rares:", sum(n["rare"] for n in npcs.values()), "elites:", sum(n["elite"] for n in npcs.values()))


if __name__ == "__main__":
    sys.exit(main())
