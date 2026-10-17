"""Builds the release zip for CurseForge: Zmap-<version>.zip with a Zmap folder inside (what tools/install.py
copies, plus LICENSE), and its changelog section from CHANGELOG.md next to it. It does not upload anything.
    python tools/package.py [--out "C:/Users/Domi/Desktop/Zmap_zips"]
The version is the TOC's; CHANGELOG.md must have a section for it."""
import argparse
import re
import sys
import zipfile
from pathlib import Path

from install import FILES, ROOT


def version():
    m = re.search(r"^## Version: (\S+)", (ROOT / "Zmap.toc").read_text(encoding="utf-8"), re.M)
    return m.group(1)


def changelog(ver):
    text = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
    m = re.search(rf"^## {re.escape(ver)}\b.*?$(.*?)(?=^## |\Z)", text, re.M | re.S)
    if not m:
        raise SystemExit(f"CHANGELOG.md has no section for {ver}")
    return f"## Zmap {ver}\n{m.group(1).strip()}\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(Path.home() / "Desktop" / "Zmap_zips"))
    out = Path(ap.parse_args().out)
    out.mkdir(parents=True, exist_ok=True)
    ver = version()
    notes = changelog(ver)
    files = []
    for pattern in FILES + ["LICENSE"]:
        for src in sorted(ROOT.glob(pattern)):
            files += sorted(p for p in src.rglob("*") if p.is_file()) if src.is_dir() else [src]
    files = [f for f in files if "__pycache__" not in f.parts]
    target = out / f"Zmap-{ver}.zip"
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as z:
        for f in files:
            z.write(f, "Zmap/" + f.relative_to(ROOT).as_posix())
    (out / f"Zmap_changelog_{ver}.md").write_text(notes, encoding="utf-8")
    print(f"{target}: {len(files)} files, {target.stat().st_size / 1e6:.1f} MB")
    print(f"changelog: {out / f'Zmap_changelog_{ver}.md'}")


if __name__ == "__main__":
    sys.exit(main())
