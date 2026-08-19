#!/usr/bin/env python3
"""Static validation checks for all Kanto Rework Suite packages."""
from __future__ import annotations

import json
import pathlib
import sys

# Ensure UTF-8 output on Windows consoles
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

ROOT = pathlib.Path(__file__).resolve().parents[1]
PACKAGES_DIR = ROOT / "packages"

REQUIRED_BY_PACKAGE = {
    "kanto_rework_core": (
        "main.lua",
        "core/layout.lua",
        "core/theme.lua",
        "core/profile.lua",
        "core/i18n.lua",
        "core/presenter.lua",
        "core/native_pointer.lua",
        "core/pointer.lua",
        "core/safe_save.lua",
        "data/types.lua",
        "data/moves.lua",
        "data/items.lua",
        "data/pokedex.lua",
        "locales/en.lua",
        "locales/es.lua",
    ),
    "kanto_rework_ui": (
        "main.lua",
        "ui/summary_presenter.lua",
        "ui/bag_presenter.lua",
        "ui/battle_presenter.lua",
    ),
    "kanto_rework_compat": (
        "main.lua",
        "compat/mod_options_presenter.lua",
    ),
    "kanto_rework_suite": (
        "main.lua",
        "manifest.json",
        "config/modules.lua",
        "modules/core/main.lua",
        "modules/ui/main.lua",
        "modules/gameplay/main.lua",
        "modules/graphics/main.lua",
        "modules/compatibility/main.lua",
        "modules/battle_animations/entry.lua",
    ),
}


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def validate_manifest(package_path: pathlib.Path) -> None:
    manifest_path = package_path / "manifest.json"
    if not manifest_path.is_file():
        fail(f"manifest.json is missing in {package_path.name}")
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except Exception as e:
        fail(f"invalid JSON in manifest.json ({package_path.name}): {e}")

    for key in ("id", "name", "version", "api", "entry", "profile"):
        if key not in manifest:
            fail(f"manifest missing required key '{key}' in {package_path.name}")


def validate_files(package_path: pathlib.Path) -> None:
    req_files = REQUIRED_BY_PACKAGE.get(package_path.name, ("main.lua",))
    for relative in req_files:
        if not (package_path / relative).is_file():
            fail(f"missing package file in {package_path.name}: {relative}")

    forbidden = {".gb", ".gbc", ".sav", ".srm"}
    offenders = [path for path in package_path.rglob("*") if path.suffix.lower() in forbidden]
    if offenders:
        fail(f"ROM/save files forbidden in {package_path.name}: " + ", ".join(map(str, offenders)))


def main() -> None:
    for pkg in sorted(PACKAGES_DIR.iterdir()):
        if pkg.is_dir() and (pkg / "manifest.json").is_file():
            print(f"Validating package: {pkg.name}")
            validate_manifest(pkg)
            validate_files(pkg)

    print("[OK] All static package validations passed successfully!")


if __name__ == "__main__":
    main()
