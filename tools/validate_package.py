#!/usr/bin/env python3
"""Static validation checks for Kanto Rework Suite packages."""
from __future__ import annotations

import json
import pathlib
import sys

# Ensure UTF-8 output on Windows consoles
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

ROOT = pathlib.Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "packages" / "kanto_rework_core"


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
        fail(f"invalid JSON in manifest.json: {e}")

    required = {
        "id": "kanto_rework_core",
        "api": 2,
        "entry": "main.lua",
        "profile": "overhaul",
    }
    for key, expected in required.items():
        if manifest.get(key) != expected:
            fail(f"manifest {key!r} must be {expected!r}")


def validate_files(package_path: pathlib.Path) -> None:
    required_files = (
        "main.lua",
        "core/layout.lua",
        "core/theme.lua",
        "core/profile.lua",
        "core/i18n.lua",
        "core/presenter.lua",
        "core/native_pointer.lua",
        "core/pointer.lua",
        "core/safe_save.lua",
        "locales/en.lua",
        "locales/es.lua",
    )
    for relative in required_files:
        if not (package_path / relative).is_file():
            fail(f"missing package file: {relative}")

    forbidden = {".gb", ".gbc", ".sav", ".srm"}
    offenders = [path for path in package_path.rglob("*") if path.suffix.lower() in forbidden]
    if offenders:
        fail("ROM/save files are strictly forbidden: " + ", ".join(map(str, offenders)))


def main() -> None:
    print(f"Validating package: {PACKAGE}")
    validate_manifest(PACKAGE)
    validate_files(PACKAGE)
    print("[OK] All static package validations passed successfully!")


if __name__ == "__main__":
    main()
