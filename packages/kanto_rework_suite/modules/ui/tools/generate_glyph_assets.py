#!/usr/bin/env python3
"""Regenerate runtime glyph assets from canonical Figma SVG exports.

Writes only assets/runtime/{type_glyphs,status_glyphs} and generated/*.
It never modifies components/*.lua.
"""
from __future__ import annotations
import json, re, shutil
from io import BytesIO
from pathlib import Path
from xml.etree import ElementTree as ET

import cairosvg
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE_SPEC = ROOT / "tools" / "glyph_sources.json"
SCALES = (1, 2, 3, 4)

def number(value: str) -> float:
    return float(re.sub(r"[^0-9.+-]", "", value))

def validate_svg(path: Path, canvas: dict) -> list[float]:
    root = ET.parse(path).getroot()
    width = number(root.attrib["width"])
    height = number(root.attrib["height"])
    viewbox = [float(x) for x in root.attrib["viewBox"].replace(",", " ").split()]
    expected = [0.0, 0.0, float(canvas["width"]), float(canvas["height"])]
    if [width, height] != expected[2:]:
        raise ValueError(f"{path}: root size {width}x{height} != {canvas}")
    if viewbox != expected:
        raise ValueError(f"{path}: viewBox {viewbox} != {expected}")
    # No baked semantic color, matte, or explicit non-white stroke is allowed.
    for elem in root.iter():
        fill = elem.attrib.get("fill")
        stroke = elem.attrib.get("stroke")
        if fill and fill.lower() not in ("none", "white", "#fff", "#ffffff"):
            raise ValueError(f"{path}: non-white baked fill {fill}")
        if stroke and stroke.lower() not in ("none", "white", "#fff", "#ffffff"):
            raise ValueError(f"{path}: non-white baked stroke {stroke}")
    return viewbox

def rasterize(svg_path: Path, png_path: Path, width: int, height: int) -> None:
    raw = cairosvg.svg2png(url=str(svg_path), output_width=width, output_height=height)
    rgba = Image.open(BytesIO(raw)).convert("RGBA")
    alpha = rgba.getchannel("A")
    # Preserve antialiasing alpha but make even transparent texels white to
    # eliminate dark color bleed under linear texture filtering.
    out = Image.new("RGBA", rgba.size, (255, 255, 255, 255))
    out.putalpha(alpha)
    png_path.parent.mkdir(parents=True, exist_ok=True)
    out.save(png_path, optimize=True)

def build_group(group_name: str, entries: list[dict]) -> dict:
    out = {}
    source_dir = ROOT / "assets" / "source" / group_name
    runtime_dir = ROOT / "assets" / "runtime" / group_name
    if runtime_dir.exists():
        shutil.rmtree(runtime_dir)
    for item in entries:
        name = item["name"]
        canvas = item["canvas"]
        svg = source_dir / f"{name}.svg"
        viewbox = validate_svg(svg, canvas)
        runtime = []
        for scale in SCALES:
            width = canvas["width"] * scale
            height = canvas["height"] * scale
            png = runtime_dir / f"{scale}x" / f"{name}.png"
            rasterize(svg, png, width, height)
            runtime.append({
                "scale": scale, "pixels": max(width, height),
                "width": width, "height": height,
                "path": png.relative_to(ROOT).as_posix(),
            })
        out[name.upper()] = {
            "node": item["node"],
            "canvas": canvas,
            "viewBox": viewbox,
            "trace": item["trace"],
            "source": svg.relative_to(ROOT).as_posix(),
            "runtime": runtime,
        }
    return out

def lua_number(v):
    if int(v) == v: return str(int(v))
    return f"{v:.12g}"

def lua_entry(table_name: str, key: str, rec: dict) -> str:
    c, t = rec["canvas"], rec["trace"]
    runtime = ",".join(
        f'{{scale={r["scale"]},pixels={r["pixels"]},width={r["width"]},height={r["height"]},path="{r["path"]}"}}'
        for r in rec["runtime"]
    )
    return (
        f'A.{table_name}["{key}"]={{node="{rec["node"]}",'
        f'canvas={{width={c["width"]},height={c["height"]}}},'
        f'viewBox={{0,0,{c["width"]},{c["height"]}}},'
        f'trace={{x={lua_number(t["x"])},y={lua_number(t["y"])},'
        f'width={lua_number(t["width"])},height={lua_number(t["height"])}}},'
        f'source="{rec["source"]}",runtime={{{runtime}}}}}'
    )

def main() -> None:
    source = json.loads(SOURCE_SPEC.read_text(encoding="utf-8"))
    manifest = {
        "schemaVersion": 1,
        "figma": source["figma"],
        "pipeline": {
            "source": "Figma SVG transparent white-vector glyph",
            "runtime": "PNG white-alpha raster at 1x/2x/3x/4x",
            "filter": "linear",
            "transparentTexelRgb": "white",
            "semanticColor": "runtime container/token; no profile-specific geometry assets",
        },
        "types": build_group("type_glyphs", source["types"]),
        "statuses": build_group("status_glyphs", source["statuses"]),
    }
    gen = ROOT / "generated"
    gen.mkdir(parents=True, exist_ok=True)
    (gen / "glyph_manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    lines = [
        "-- GENERATED by tools/generate_glyph_assets.py. Do not edit manually.",
        "-- Canonical geometry comes from Figma; semantic colors remain runtime tokens.",
        "local A={typeGlyphs={},statusGlyphs={}}",
    ]
    for key, rec in manifest["types"].items():
        lines.append(lua_entry("typeGlyphs", key, rec))
    for key, rec in manifest["statuses"].items():
        lines.append(lua_entry("statusGlyphs", key, rec))
    lines += [
        "A.statusGlyphs.BADLYPOISONED=A.statusGlyphs.BADLY_POISONED",
        "return A",
        "",
    ]
    (gen / "assets.lua").write_text("\n".join(lines), encoding="utf-8")

if __name__ == "__main__":
    main()
