"""NPC names in every client language, from the Battle.net API (static-forever: creature by id gives its name in all
locales). Writes Data/NpcNames.lua: per client locale, the names that differ from the data's English one. The game
keeps only your client's table. Needs the API client in the env vars BLIZZARD_ID and BLIZZARD_SECRET; answers are
cached in tools/cache/npc_names.json (a name never changes; rerun after build_npcs.py adds NPCs).

    python tools/npc_names.py
"""
import base64
import json
import os
import re
import sys
import threading
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / "cache" / "npc_names.json"
OUT = ROOT / "Data" / "NpcNames.lua"
# client locale -> the API's
LOCALES = {"esES": "es_ES", "esMX": "es_MX", "deDE": "de_DE", "frFR": "fr_FR", "itIT": "it_IT", "ptBR": "pt_BR",
           "ruRU": "ru_RU", "koKR": "ko_KR", "zhCN": "zh_CN", "zhTW": "zh_TW"}


def token():
    cid, sec = os.environ.get("BLIZZARD_ID"), os.environ.get("BLIZZARD_SECRET")
    if not (cid and sec):
        sys.exit("BLIZZARD_ID and BLIZZARD_SECRET are needed")
    req = urllib.request.Request("https://oauth.battle.net/token", data=b"grant_type=client_credentials",
                                 headers={"Authorization": "Basic " + base64.b64encode(f"{cid}:{sec}".encode()).decode()})
    return json.load(urllib.request.urlopen(req, timeout=30))["access_token"]


def npcs():
    """id -> English name, from Data/Npcs.lua"""
    text = (ROOT / "Data" / "Npcs.lua").read_text(encoding="utf-8")
    return {int(i): n for i, n in re.findall(r'^\s*\[(\d+)\] = \{ "((?:[^"\\]|\\.)*)"', text, re.M)}


def fetch(tok, nid):
    url = f"https://eu.api.blizzard.com/data/wow/creature/{nid}?namespace=static-forever-eu"
    for attempt in range(4):
        try:
            r = urllib.request.urlopen(urllib.request.Request(url, headers={"Authorization": "Bearer " + tok}), timeout=30)
            return json.load(r).get("name") or {}
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return {}
            if e.code == 429:
                time.sleep(2 + attempt * 3)
                continue
            time.sleep(1 + attempt)
        except Exception:
            time.sleep(1 + attempt)
    return None   # (not known: asked again next time)


def lua(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ") + '"'


def main():
    english = npcs()
    cache = json.loads(CACHE.read_text(encoding="utf-8")) if CACHE.exists() else {}
    todo = [i for i in english if str(i) not in cache]
    print(f"{len(english)} NPCs, {len(todo)} to ask")
    if todo:
        tok, lock, done = token(), threading.Lock(), [0]

        def one(nid):
            names = fetch(tok, nid)
            with lock:
                if names:   # (a 404 is asked again next time: the API is still filling in, 631 of 8543 on 2026-11-13)
                    cache[str(nid)] = names
                done[0] += 1
                if done[0] % 500 == 0:
                    print(f"  {done[0]}/{len(todo)}")
                    CACHE.parent.mkdir(parents=True, exist_ok=True)
                    CACHE.write_text(json.dumps(cache, ensure_ascii=False), encoding="utf-8")

        with ThreadPoolExecutor(8) as pool:
            list(pool.map(one, todo))
        CACHE.parent.mkdir(parents=True, exist_ok=True)
        CACHE.write_text(json.dumps(cache, ensure_ascii=False), encoding="utf-8")
    lines = ["-- NPC names in the client's language (tools/npc_names.py, Battle.net API). Generated: do not edit.",
             "local _, ns = ...", "local locale = GetLocale()", "local T = {}"]
    found = 0
    for client, api in LOCALES.items():
        rows = []
        for nid in sorted(english):
            name = (cache.get(str(nid)) or {}).get(api)
            if name and name != english[nid]:
                rows.append(f"[{nid}]={lua(name)}")
        found += len(rows)
        lines.append(f"T.{client} = {{" + ",".join(rows) + "}")
        print(f"  {client}: {len(rows)} names")
    lines.append("ns.NPC_NAMES = T[locale] or {}")
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"wrote {OUT.name}: {found} names, {OUT.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
