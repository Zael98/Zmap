"""Generates Zmap's world data from QuestieDB's Forever database and Warcraft DB:

  Data/Npcs.lua     NPCs with where they stand (search, townsfolk, rares)
  Data/Objects.lua  herbs and ore veins (with the item they give and the skill they need), mailboxes, anvils,
                    forges, meeting stones, and the objects quests use
  Data/Quests.lua   quests: who gives and takes them, level, races, classes, prerequisites, and where their
                    objectives are (mobs, objects, the mobs and objects that drop the items asked for)

Sources:
  * QuestieDB's Forever database (from the latest Questie release on GitHub; Questie is GPL-3.0). Its data is
    CBOR in base64 stored as the TOC's metadata: "## X-<Entity>-<id>-<field>[-<part>]: <base64>".
  * Warcraft DB (forever.warcraftdb.com), sniffed from Forever itself: fewer NPCs, but where it places one its
    spawn points, title and services win.

    python tools/build_npcs.py            (downloads what is not cached in tools/cache)
    python tools/build_npcs.py --fresh    (the latest Questie release, not the one cached)

Names come in English; in game Zmap shows the client's own names where it can (items, quests) and learns NPC
names in the client's language (Modules/Npcs.lua). Warcraft DB's certificate does not verify on some
machines, so it is fetched without verifying it (public data, nothing is sent)."""
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
MAX_SPAWNS = 24          # an NPC or object standing in many places keeps this many (herbs and ore keep all)
MAX_DROPPERS = 12        # mobs (or objects) kept per item a quest asks for
HOLIDAYS = {-22, -284, -364, -366, -369}   # quest sorts: seasonal, special (Children's Week...), Darkmoon Faire,
                                            # Lunar Festival, Midsummer
MAX_VENDORS = 8          # an item sold by more (water, thread...) is anyone's: its vendors are not marked

# services, in the order of the flag bits Modules/Npcs.lua reads
SERVICES = ["Innkeeper", "Vendor", "Repair", "Trainer", "Flight Master", "Banker", "Auctioneer", "Stable Master",
            "Spirit Healer", "Battlemaster", "Guild Banker", "Mailbox"]
# QuestieDB's npcFlags (Forever / classic) -> our services
QUESTIE_FLAGS = {4: "Vendor", 8: "Flight Master", 16: "Trainer", 32: "Spirit Healer", 128: "Innkeeper",
                 256: "Banker", 2048: "Battlemaster", 4096: "Auctioneer", 8192: "Stable Master", 16384: "Repair"}

# gathering nodes: the skill each needs (the original game's), by node name
HERBS = {
    "Peacebloom": 1, "Silverleaf": 1, "Earthroot": 15, "Mageroyal": 50, "Briarthorn": 70, "Stranglekelp": 85,
    "Bruiseweed": 100, "Wild Steelbloom": 115, "Grave Moss": 120, "Kingsblood": 125, "Liferoot": 150,
    "Fadeleaf": 160, "Goldthorn": 170, "Khadgar's Whisker": 185, "Wintersbite": 195, "Firebloom": 205,
    "Purple Lotus": 210, "Arthas' Tears": 220, "Sungrass": 230, "Blindweed": 235, "Ghost Mushroom": 245,
    "Gromsblood": 250, "Golden Sansam": 260, "Dreamfoil": 270, "Mountain Silversage": 280, "Plaguebloom": 285,
    "Icecap": 290, "Black Lotus": 300,
}
ORES = {   # node name -> (ore it gives, skill)
    "Copper Vein": ("Copper Ore", 1), "Tin Vein": ("Tin Ore", 65), "Incendicite Mineral Vein": ("Incendicite Ore", 65),
    "Silver Vein": ("Silver Ore", 75), "Lesser Bloodstone Deposit": ("Lesser Bloodstone Ore", 75),
    "Iron Deposit": ("Iron Ore", 125), "Indurium Mineral Vein": ("Indurium Ore", 150), "Gold Vein": ("Gold Ore", 155),
    "Mithril Deposit": ("Mithril Ore", 175), "Truesilver Deposit": ("Truesilver Ore", 230),
    "Dark Iron Deposit": ("Dark Iron Ore", 230), "Small Thorium Vein": ("Thorium Ore", 245),
    "Rich Thorium Vein": ("Thorium Ore", 275),
}
# other objects worth having on the map, by name
UTILITY = {"Mailbox": "mailbox", "Anvil": "anvil", "Forge": "forge", "Meeting Stone": "stone"}


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


def as_map(x):
    """A Lua table keyed 1..n is stored as an array: back to {index: value} (None where empty)."""
    if isinstance(x, list):
        return {i + 1: v for i, v in enumerate(x) if v is not None}
    return x or {}


def as_list(x):
    if isinstance(x, dict):
        return [x[k] for k in sorted(x)]
    return [v for v in (x or []) if v is not None]


def questie_release():
    """The latest Questie release (as cached: --fresh asks GitHub again)."""
    return json.loads(fetch("https://api.github.com/repos/Questie/Questie/releases/latest", CACHE / "questie" / "release.json"))


def questie_toc():
    """The Forever QuestieDB's TOC (its data), from the latest Questie release."""
    path = CACHE / "questie" / "QuestieDB_Forever.toc"
    if path.exists():
        return path.read_text(encoding="utf-8")
    info = questie_release()
    asset = next(a for a in info["assets"] if a["name"].endswith(".zip"))
    print(f"downloading {asset['name']} ({asset['size'] // 1_000_000} MB)")
    data = fetch(asset["browser_download_url"], CACHE / "questie" / asset["name"])
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        text = z.read("QuestieDB/QuestieDB_Forever.toc").decode("utf-8")
    path.write_text(text, encoding="utf-8")
    return text


_entities = None


def entities(kind):
    """{id: {field: value}} for one kind of QuestieDB entity (Npc, Object, Quest, Item)."""
    global _entities
    if _entities is None:
        raw = {}
        for line in questie_toc().splitlines():
            m = re.match(r"## X-(Npc|Object|Quest|Item)-(\d+)-(S|\d+)(?:-(\d+))?: (.*)", line)
            if m:
                k, ident, field, part, value = m.groups()
                slot = raw.setdefault(k, {}).setdefault(int(ident), {})
                if part:
                    slot.setdefault((field, "parts"), []).append((int(part), value.strip()))
                else:
                    slot[field] = value.strip()
        _entities = {}
        for k, items in raw.items():
            out = _entities.setdefault(k, {})
            for ident, fields in items.items():
                row = as_map(cbor(base64.b64decode(fields["S"]))[0]) if "S" in fields else {}
                for key, value in fields.items():
                    if key == "S" or isinstance(key, tuple):
                        continue
                    if value.startswith("~"):   # split over several keys
                        value = "".join(v for _, v in sorted(fields[(key, "parts")]))
                    row[int(key)] = cbor(base64.b64decode(value))[0]
                out[ident] = row
    return _entities.get(kind, {})


_zone_maps = None


def zone_maps():
    """AreaTable zone ID (what QuestieDB keys spawns by) -> uiMapID of that zone's map."""
    global _zone_maps
    if _zone_maps is None:
        _zone_maps = {}
        for r in sorted(build_data.table("UiMapAssignment"), key=lambda r: int(r["OrderIndex"])):
            area = int(r["AreaID"])
            if area and area not in _zone_maps:
                _zone_maps[area] = int(r["UiMapID"])
    return _zone_maps


def spawns_by_map(spawns):
    """QuestieDB spawns {zoneID: [[x%, y%], ...]} -> {uiMapID: [(x, y), ...]} (share of the map)."""
    maps = zone_maps()
    by_map = {}
    for zone, pts in as_map(spawns).items():
        m = maps.get(zone)
        if m:
            for p in as_list(pts):
                if p and len(p) >= 2 and 0 <= p[0] <= 100 and 0 <= p[1] <= 100:
                    by_map.setdefault(m, []).append((p[0] / 100, p[1] / 100))
    return by_map


def from_questie():
    npcs = {}
    for npc, row in entities("Npc").items():
        flags = 0
        for bit, service in QUESTIE_FLAGS.items():
            if (row.get(15) or 0) & bit:
                flags |= 1 << SERVICES.index(service)
        rank = row.get(6) or 0   # cmangos ranks: 1 elite, 2 rare elite, 3 boss, 4 rare
        lo, hi = row.get(4), row.get(5)
        npcs[npc] = {
            "id": npc, "name": row.get(1) or "", "title": row.get(14) or "", "flags": flags,
            "friendly": row.get(13) or "", "rare": rank in (2, 4), "elite": rank in (1, 2, 3),
            "level": (f"{lo}" if lo == hi else f"{lo}-{hi}") if lo else "", "spawns": spawns_by_map(row.get(7)),
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


# --------------------------------------------------------------------------------------------------------------
# Objects and quests
# --------------------------------------------------------------------------------------------------------------

def build_objects(quest_objects):
    """Herbs, ore, utility objects and the objects quests use: {id: {name, kind, item, skill, spawns}}."""
    item_by_name = {}
    for iid, row in entities("Item").items():
        item_by_name.setdefault(row.get(1), iid)
    out = {}
    for oid, row in entities("Object").items():
        name = row.get(1) or ""
        spawns = spawns_by_map(row.get(4))
        if not spawns:
            continue
        kind, item, skill = "", 0, 0
        base = name.replace("Ooze Covered ", "")
        if base in HERBS:
            kind, item, skill = "herb", item_by_name.get(base, 0), HERBS[base]
        elif base in ORES:
            kind, item, skill = "ore", item_by_name.get(ORES[base][0], 0), ORES[base][1]
        elif name in UTILITY:
            kind = UTILITY[name]
        elif oid not in quest_objects:
            continue
        out[oid] = {"name": name, "kind": kind, "item": item, "skill": skill, "spawns": spawns}
    return out


def ids_of(group):
    """Objective rows ({{id, text}, ...}, maps or arrays) -> their ids."""
    out = []
    for entry in as_list(group):
        entry = as_list(entry) if isinstance(entry, (list, dict)) else [entry]
        if entry and isinstance(entry[0], int):
            out.append(entry[0])
    return out


def questie_blacklist():
    """The quests Questie never shows (duplicates, not in the game, GM island...), its list read as it reads it on
    Forever: Era content. {questID} (those it only hides on the map are left: they may be in your log)."""
    from lupa import lua51
    zips = sorted((CACHE / "questie").glob("Questie-*.zip"))
    with zipfile.ZipFile(zips[-1]) as z:
        src = z.read("Questie/Database/Corrections/QuestieQuestBlacklist.lua").decode("utf-8")
    L = lua51.LuaRuntime(unpack_returned_tuples=True)
    L.execute("""
        local function Off() return false end
        Questie = setmetatable({ IsForever = true }, { __index = function() return false end })
        local expansions = { Era = 1, Tbc = 2, Wotlk = 3, Cata = 4, MoP = 5, Current = 1 }
        local phases = setmetatable({ activePhases = {} }, { __index = function() return Off end })
        local modules = { Expansions = expansions, ContentPhases = phases }
        QuestieLoader = {
            CreateModule = function(_, name) modules[name] = modules[name] or {} return modules[name] end,
            ImportModule = function(_, name) return modules[name] or setmetatable({}, { __index = function() return Off end }) end,
        }
    """)
    L.execute(src)
    listed = L.eval('QuestieLoader:ImportModule("QuestieQuestBlacklist"):Load()')
    return {int(k) for k, v in listed.items() if v is True}


def build_quests(npcs):
    items = entities("Item")
    quests = {}
    quest_objects = set()
    blacklist = questie_blacklist()
    print(f"Questie's blacklist (Era): {len(blacklist)} quests left out")
    # the quests Forever's client has (QuestV2: those with a "done" bit; repeatable ones have none, so they are
    # kept): a non-repeatable quest it lacks was taken out of Forever
    in_client = {int(r["ID"]) for r in build_data.table("QuestV2")}
    gone = 0
    for qid, row in entities("Quest").items():
        if qid in blacklist:
            continue
        if qid not in in_client and not (row.get(24) or 0) & 1:
            gone += 1
            continue
        starts = as_map(row.get(2))
        ends = as_map(row.get(3))
        objectives = as_map(row.get(10))
        mobs = list(ids_of(objectives.get(1)))
        objs = list(ids_of(objectives.get(2)))
        vendors = []
        for iid in ids_of(objectives.get(3)):   # the items asked for: who drops them, or who sells them
            item = items.get(iid, {})
            mobs += [n for n in as_list(item.get(2)) if n in npcs][:MAX_DROPPERS]
            objs += as_list(item.get(3))[:MAX_DROPPERS]
            sellers = [n for n in as_list(item.get(14)) if isinstance(n, int)]
            if len(sellers) <= MAX_VENDORS:
                vendors += [n for n in sellers if n in npcs]
        # places to reach (explore, escort...): {zoneID: [[x%, y%]]}
        trigger = as_list(row.get(9))
        explore = spawns_by_map(trigger[1]) if len(trigger) > 1 else {}
        for credit in as_list(objectives.get(5)):   # kill credit: {{npcIds}, baseNpc, text}
            credit = as_list(credit)
            if credit:
                mobs += [n for n in as_list(credit[0]) if isinstance(n, int)]
        flags = 0
        if (row.get(24) or 0) & 1:
            flags |= 1   # repeatable
        if row.get(18) or row.get(31) or row.get(30):
            flags |= 2   # needs a profession, a specialization or a spell: not offered on the map
        if (row.get(24) or 0) & 2:
            flags |= 4   # done by something happening (reaching a place, an escort...): still offered
        if row.get(17) in HOLIDAYS:
            flags |= 8   # a holiday's: its givers are only there then
        quest = {
            "name": row.get(1) or "", "level": row.get(5) or 0, "req": row.get(4) or 0,
            "races": row.get(6) or 0, "classes": row.get(7) or 0,
            "starts": as_list(starts.get(1)), "startObjs": as_list(starts.get(2)),
            "ends": as_list(ends.get(1)), "endObjs": as_list(ends.get(2)),
            "mobs": sorted(set(mobs)), "objs": sorted(set(objs)),
            "vendors": sorted(set(vendors) - set(mobs)), "explore": explore,
            "pre": as_list(row.get(13)), "preAll": as_list(row.get(12)), "excl": as_list(row.get(16)),
            "maxLevel": row.get(32) or 0, "flags": flags,
        }
        quest_objects.update(quest["startObjs"] + quest["endObjs"] + quest["objs"])
        quests[qid] = quest
    print(f"not in Forever's client: {gone} quests left out")
    return quests, quest_objects


# --------------------------------------------------------------------------------------------------------------
# Lua output
# --------------------------------------------------------------------------------------------------------------

def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def lua_list(values):
    return "{ " + ", ".join(str(v) for v in values) + " }" if values else "{}"


def spawn_parts(spawns, cap):
    parts, kept = [], 0
    for m, pts in sorted(spawns.items(), key=lambda kv: -len(kv[1])):
        pts = pts[:max(0, cap - kept)]
        if not pts:
            break
        kept += len(pts)
        parts.append(f"{m}, {{ {', '.join(f'{round(u * 1000)}, {round(v * 1000)}' for u, v in pts)} }}")
    return ", ".join(parts)


def header():
    """The data files' first lines; the Questie release named (tools/check_updates.py reads it)."""
    return (f"-- Generated by tools/build_npcs.py from QuestieDB's Forever database (Questie {questie_release()['tag_name']},\n"
            "-- GPL-3.0) and Warcraft DB (forever.warcraftdb.com). Regenerate rather than edit.\n")


def write_npcs(npcs):
    lines = [header() + "local _, ns = ...", "",
             "-- the services' flag bits, in order: " + ", ".join(SERVICES),
             "-- [npcID] = { name (English), title, flags, friendly to (A, H, AH or \"\"), level, rare (1) / elite (2),",
             "--             uiMapID, { x1, y1, x2, y2, ... } (per thousand of its map), another uiMapID, { ... }, ... }",
             "ns.NPCS = {"]
    for n in sorted(npcs.values(), key=lambda n: n["id"]):
        rank = (1 if n["rare"] else 0) + (2 if n["elite"] else 0)
        lines.append(f'    [{n["id"]}] = {{ {lua_str(n["name"])}, {lua_str(n["title"])}, {n["flags"]}, "{n["friendly"]}", '
                     f'"{n["level"]}", {rank}, {spawn_parts(n["spawns"], MAX_SPAWNS)} }},')
    lines.append("}")
    (ROOT / "Data" / "Npcs.lua").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_objects(objects):
    lines = [header() + "local _, ns = ...", "",
             "-- [objectID] = { name (English), kind (herb, ore, mailbox, anvil, forge, stone or \"\" for a quest's),",
             "--                item it gives (herbs, ore), skill it needs, uiMapID, { x1, y1, ... } (per thousand), ... }",
             "ns.OBJECTS = {"]
    for oid, o in sorted(objects.items()):
        cap = 100000 if o["kind"] in ("herb", "ore", "mailbox") else MAX_SPAWNS
        lines.append(f'    [{oid}] = {{ {lua_str(o["name"])}, "{o["kind"]}", {o["item"]}, {o["skill"]}, {spawn_parts(o["spawns"], cap)} }},')
    lines.append("}")
    (ROOT / "Data" / "Objects.lua").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_quests(quests):
    lines = [header() + "local _, ns = ...", "",
             "-- [questID] = { name (English), level, required level, races (mask, 0: all), classes (mask, 0: all),",
             "--   { NPCs who give it }, { objects that give it }, { NPCs who take it }, { objects that take it },",
             "--   { mobs for its objectives }, { objects for its objectives }, { any of these done first },",
             "--   { all of these done first }, { not if one of these }, highest level it is offered at (0: none),",
             "--   flags (1 repeatable, 2 needs a profession or spell, 4 done by reaching a place or an event, 8 a holiday's),",
             "--   { NPCs who sell what it asks for },",
             "--   places to reach (uiMapID, { x, y per thousand }, ...) }",
             "ns.QUESTS = {"]
    for qid, q in sorted(quests.items()):
        if not q["name"]:
            continue
        lines.append(f'    [{qid}] = {{ {lua_str(q["name"])}, {q["level"]}, {q["req"]}, {q["races"]}, {q["classes"]}, '
                     f'{lua_list(q["starts"])}, {lua_list(q["startObjs"])}, {lua_list(q["ends"])}, {lua_list(q["endObjs"])}, '
                     f'{lua_list(q["mobs"])}, {lua_list(q["objs"])}, {lua_list(q["pre"])}, {lua_list(q["preAll"])}, '
                     f'{lua_list(q["excl"])}, {q["maxLevel"]}, {q["flags"]}, {lua_list(q["vendors"])}, '
                     f'{{ {spawn_parts(q["explore"], 20)} }} }},')
    lines.append("}")
    (ROOT / "Data" / "Quests.lua").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    if "--fresh" in sys.argv[1:]:   # the latest Questie release again (its zip is cached by its own name)
        for name in ("release.json", "QuestieDB_Forever.toc"):
            (CACHE / "questie" / name).unlink(missing_ok=True)
    questie = from_questie()
    print(f"QuestieDB Forever: {len(questie)} NPCs, {sum(1 for n in questie.values() if n['spawns'])} placed on Zmap's maps")
    wdbs = from_wdb()
    print(f"Warcraft DB: {len(wdbs)} NPCs, {sum(1 for n in wdbs.values() if n['spawns'])} placed")
    npcs = merge(questie, wdbs)
    print(f"merged: {len(npcs)} NPCs with spawn points")
    write_npcs(npcs)
    quests, quest_objects = build_quests(npcs)
    write_quests(quests)
    print(f"quests: {len(quests)}")
    objects = build_objects(quest_objects)
    write_objects(objects)
    kinds = {}
    for o in objects.values():
        kinds[o["kind"] or "quest"] = kinds.get(o["kind"] or "quest", 0) + sum(len(p) for p in o["spawns"].values())
    print("objects:", len(objects), "spawns by kind:", kinds)
    services = {}
    for n in npcs.values():
        for i, s in enumerate(SERVICES):
            if n["flags"] & (1 << i):
                services[s] = services.get(s, 0) + 1
    print("services:", services)
    print("rares:", sum(n["rare"] for n in npcs.values()), "elites:", sum(n["elite"] for n in npcs.values()))


if __name__ == "__main__":
    sys.exit(main())
