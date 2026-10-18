"""Is there newer source data than Zmap's data was made from? For the daily workflow (.github/workflows/data.yml),
as GitHub Actions outputs:

    build=<a newer Forever client build on wago.tools>    (empty: none)
    questie=<a newer Questie release>                     (empty: none)
    label=<what is new, for the branch and the pull request>

    python tools/check_updates.py"""
import json
import os
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def get(url):
    headers = {"User-Agent": "Mozilla/5.0 (Zmap check_updates)"}
    if "api.github.com" in url and os.environ.get("GH_TOKEN"):
        headers["Authorization"] = "Bearer " + os.environ["GH_TOKEN"]
    return urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=60).read()


def version_key(v):
    return tuple(int(x) for x in v.split("."))


def newer_forever():
    """The newest client build of Forever's version (the same major.minor) wago.tools lists, if newer."""
    current = re.search(r'^BUILD = "([\d.]+)"', (ROOT / "tools" / "build_data.py").read_text(encoding="utf-8"), re.M)[1]
    prefix = ".".join(current.split(".")[:2]) + "."
    builds = json.loads(get("https://wago.tools/api/builds"))
    versions = {b["version"] for product in builds.values() for b in product if b["version"].startswith(prefix)}
    best = max(versions, key=version_key, default=current)
    return best if version_key(best) > version_key(current) else ""


def newer_questie():
    """The latest Questie release, if not the one Data/Npcs.lua was made from."""
    used = re.search(r"\(Questie (\S+),", (ROOT / "Data" / "Npcs.lua").read_text(encoding="utf-8"))
    latest = json.loads(get("https://api.github.com/repos/Questie/Questie/releases/latest"))["tag_name"]
    return latest if not used or used[1] != latest else ""


def main():
    build, questie = newer_forever(), newer_questie()
    parts = ([f"Forever {build}"] if build else []) + ([f"Questie {questie}"] if questie else [])
    label = re.sub(r"[^\w.+-]+", "-", " ".join(parts)).strip("-")
    print(f"build={build}")
    print(f"questie={questie}")
    print(f"label={label}")


if __name__ == "__main__":
    sys.exit(main())
