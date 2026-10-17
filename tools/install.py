"""Copies the addon into the game's AddOns folder (WoW Forever), to test it in game:
    python tools/install.py [--dest "D:/World of Warcraft/_classic_beta_/Interface/AddOns"]"""
import argparse
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FILES = ["Zmap.toc", "Bindings.xml", "*.lua", "Locales", "Data", "Modules", "Media"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", default="D:/World of Warcraft/_classic_beta_/Interface/AddOns")
    dest = Path(ap.parse_args().dest) / "Zmap"
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    for pattern in FILES:
        for src in ROOT.glob(pattern):
            if src.is_dir():
                shutil.copytree(src, dest / src.name)
            else:
                shutil.copy2(src, dest / src.name)
    print(f"installed in {dest}")


if __name__ == "__main__":
    main()
