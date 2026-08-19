#!/usr/bin/env python3
"""Build and package distributable ZIP archives for Kanto Rework Suite."""
from __future__ import annotations

import hashlib
import json
import pathlib
import sys
import zipfile

# Ensure UTF-8 output on Windows consoles
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

ROOT = pathlib.Path(__file__).resolve().parents[1]
PACKAGES_DIR = ROOT / "packages"
DIST_DIR = ROOT / "dist"


def sha256_file(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    h.update(path.read_bytes())
    return h.hexdigest()


def package_mod(package_dir: pathlib.Path, output_zip: pathlib.Path) -> None:
    manifest_path = package_dir / "manifest.json"
    if not manifest_path.is_file():
        print(f"Skipping {package_dir.name} (no manifest.json)")
        return

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    version = manifest.get("version", "0.1.0")
    mod_id = manifest.get("id", package_dir.name)

    output_zip.parent.mkdir(parents=True, exist_ok=True)
    print(f"Packaging {mod_id} v{version} -> {output_zip.name}...")

    with zipfile.ZipFile(output_zip, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        # manifest.json must be first in the zip archive
        zf.write(manifest_path, "manifest.json")
        for file_path in sorted(package_dir.rglob("*")):
            if file_path.is_file() and file_path != manifest_path:
                rel_path = file_path.relative_to(package_dir).as_posix()
                zf.write(file_path, rel_path)


def main() -> None:
    DIST_DIR.mkdir(exist_ok=True)
    checksums = []

    for pkg in PACKAGES_DIR.iterdir():
        if pkg.is_dir() and (pkg / "manifest.json").is_file():
            manifest = json.loads((pkg / "manifest.json").read_text(encoding="utf-8"))
            version = manifest.get("version", "0.1.0")
            mod_id = manifest.get("id", pkg.name)
            zip_name = f"{mod_id}-{version}.zip"
            zip_path = DIST_DIR / zip_name

            package_mod(pkg, zip_path)
            digest = sha256_file(zip_path)
            checksums.append(f"{digest}  {zip_name}")
            print(f"[OK] Built {zip_name} (SHA-256: {digest})")

    sums_file = DIST_DIR / "SHA256SUMS.txt"
    sums_file.write_text("\n".join(checksums) + "\n", encoding="utf-8")
    print(f"\nGenerated checksums in {sums_file}")


if __name__ == "__main__":
    main()
