#!/usr/bin/env python3
"""Static validation for the Figma-canonical KRS Type/Status glyph pipeline.

This validates source/raster integrity and runtime wiring without pretending to
launch Gen1Recomp or LÖVE. It is intentionally independent from the game ROM.
"""
from __future__ import annotations
import argparse, json, re, sys
from io import BytesIO
from pathlib import Path
from xml.etree import ElementTree as ET

import cairosvg
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_TYPES = [
    "NORMAL","FIRE","WATER","ELECTRIC","GRASS","ICE","FIGHTING","POISON","GROUND",
    "FLYING","PSYCHIC","BUG","ROCK","GHOST","DRAGON","DARK","STEEL","FAIRY",
]
EXPECTED_STATUSES = ["POISONED","BADLY_POISONED","BURNED","PARALYZED","ASLEEP","FROZEN","FAINTED"]
OLD_STATUS_FILENAMES = {"poison.png","toxic.png","burn.png","paralyze.png","sleep.png","freeze.png","faint.png"}
RESOLUTIONS = [(1280,720),(1600,900),(1920,1080),(2560,1440)]


def num(v: str) -> float:
    return float(re.sub(r"[^0-9.+-]", "", v))


def fresh_alpha(svg: Path, width: int, height: int) -> Image.Image:
    raw = cairosvg.svg2png(url=str(svg), output_width=width, output_height=height)
    return Image.open(BytesIO(raw)).convert("RGBA").getchannel("A")


def choose_density(runtime: list[dict], draw_size: float) -> dict:
    target = max(1.0, draw_size) * 2.0
    chosen = runtime[-1]
    for variant in runtime:
        if variant["pixels"] >= target:
            chosen = variant
            break
    return chosen


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", dest="json_out", type=Path)
    args = ap.parse_args()
    failures: list[str] = []
    checks: list[dict] = []
    def check(name: str, ok: bool, detail=None):
        checks.append({"name": name, "ok": bool(ok), "detail": detail})
        if not ok: failures.append(name + (f": {detail}" if detail else ""))

    manifest = json.loads((ROOT/"generated/glyph_manifest.json").read_text(encoding="utf-8"))
    check("Figma type set", manifest["figma"].get("typeGlyphSet") == "625:2266", manifest["figma"])
    check("Figma status set", manifest["figma"].get("statusGlyphSet") == "627:2304", manifest["figma"])
    check("18 type glyphs", list(manifest["types"].keys()) == EXPECTED_TYPES, list(manifest["types"].keys()))
    check("7 status glyphs", list(manifest["statuses"].keys()) == EXPECTED_STATUSES, list(manifest["statuses"].keys()))

    all_records = [("type", k, v) for k,v in manifest["types"].items()] + [("status", k, v) for k,v in manifest["statuses"].items()]
    for group, key, rec in all_records:
        src = ROOT/rec["source"]
        check(f"{group}:{key}:source exists", src.is_file(), rec["source"])
        if not src.is_file():
            continue
        root = ET.parse(src).getroot()
        w,h = num(root.attrib["width"]), num(root.attrib["height"])
        vb = [float(x) for x in root.attrib["viewBox"].replace(","," ").split()]
        exp_w,exp_h = rec["canvas"]["width"], rec["canvas"]["height"]
        check(f"{group}:{key}:SVG canvas", (w,h)==(exp_w,exp_h), [w,h])
        check(f"{group}:{key}:SVG viewBox", vb==[0.0,0.0,float(exp_w),float(exp_h)], vb)
        bad_paints=[]
        for el in root.iter():
            for attr in ("fill","stroke"):
                value=el.attrib.get(attr)
                if value and value.lower() not in ("none","white","#fff","#ffffff"):
                    bad_paints.append([attr,value])
        check(f"{group}:{key}:no baked semantic paint", not bad_paints, bad_paints)
        check(f"{group}:{key}:4 runtime densities", [r["scale"] for r in rec["runtime"]]==[1,2,3,4], rec["runtime"])
        for r in rec["runtime"]:
            p=ROOT/r["path"]
            check(f"{group}:{key}:{r['scale']}x exists", p.is_file(), r["path"])
            if not p.is_file(): continue
            im=Image.open(p).convert("RGBA")
            check(f"{group}:{key}:{r['scale']}x dimensions", im.size==(r["width"],r["height"]), im.size)
            rgb=im.convert("RGB")
            lo,hi=rgb.getextrema()[0],rgb.getextrema()[0]
            # all three channels are generated as literal white, including alpha-zero texels
            extrema=rgb.getextrema()
            check(f"{group}:{key}:{r['scale']}x white RGB texels", extrema==((255,255),(255,255),(255,255)), extrema)
            alpha=im.getchannel("A")
            aext=alpha.getextrema()
            check(f"{group}:{key}:{r['scale']}x transparent alpha", aext[0]==0 and aext[1]==255, aext)
            ref=fresh_alpha(src,r["width"],r["height"])
            diff=ImageChops.difference(alpha,ref)
            check(f"{group}:{key}:{r['scale']}x alpha matches SVG raster", diff.getbbox() is None, diff.getbbox())

    # Stale status files must not coexist with the new semantic names.
    runtime_status_names={p.name for p in (ROOT/"assets/runtime/status_glyphs").rglob("*.png")}
    check("legacy status raster names removed", not (runtime_status_names & OLD_STATUS_FILENAMES), sorted(runtime_status_names & OLD_STATUS_FILENAMES))

    type_lua=(ROOT/"components/type_icon.lua").read_text(encoding="utf-8")
    chip_lua=(ROOT/"components/type_chip.lua").read_text(encoding="utf-8")
    status_lua=(ROOT/"components/status_token.lua").read_text(encoding="utf-8")
    party_lua=(ROOT/"ui/party_presenter.lua").read_text(encoding="utf-8")
    profiles_lua=(ROOT/"generated/color_profiles.lua").read_text(encoding="utf-8")
    wiring=type_lua+chip_lua+status_lua+party_lua
    check("modern glyph components use linear filtering", type_lua.count('setFilter("linear","linear")')>=1 and status_lua.count('setFilter("linear","linear")')>=1)
    check("modern glyph components do not use nearest", 'setFilter("nearest"' not in type_lua+chip_lua+status_lua)
    check("type assets use central registry", "Assets.typeGlyphs" in type_lua and "assets/runtime/type_glyphs/" not in type_lua)
    check("status assets use central registry", "Assets.statusGlyphs" in status_lua and "assets/runtime/status_glyphs/" not in status_lua)
    check("Party uses shared TypeChip", "TypeChip.draw" in party_lua)
    check("Party uses shared StatusToken Full/Compact", "StatusToken.drawToken" in party_lua and "StatusToken.drawIcon" in party_lua)
    check("Type compact ratio is canonical 20/32", "local GLYPH_TO_ICON=20/32" in type_lua)
    check("Badly Poisoned exclamation not procedural", 'love.graphics.print("!"' not in status_lua and 'exclamation itself is already part' in status_lua)
    check("Fire uses same semantic type token", 'local background=typeColors[kind]' in chip_lua and 'theme.typeColors[kind]' in party_lua)

    for profile in ("standard","protanopia","deuteranopia","tritanopia"):
        check(f"accessibility profile:{profile}", f"P.{profile}=" in profiles_lua and f"P.{profile}.statusColors=" in profiles_lua)
    # Figma-default colors that were previously inconsistent.
    check("Standard Fire token #FF944C", 'P.standard.typeColors.FIRE={255/255,148/255,76/255,1}' in profiles_lua)
    check("Standard Poison status icon #9354CB", 'POISONED=sc({153/255,46/255,235/255,1},{147/255,84/255,203/255,1})' in profiles_lua)
    check("Standard Frozen status #47C8C8", 'FROZEN=sc({71/255,200/255,200/255,1},{71/255,200/255,200/255,1})' in profiles_lua)

    # Density-selection proof for every validated Wide target. This mirrors the
    # runtime chooser and shows that vector-derived PNGs are only downsampled.
    resolution_results=[]
    type_runtime=manifest["types"]["FIRE"]["runtime"]
    status_runtime=manifest["statuses"]["POISONED"]["runtime"]
    for w,h in RESOLUTIONS:
        s=min(w/1920,h/1080)
        type_draw=20*s
        status_draw=32*s
        tv=choose_density(type_runtime,type_draw)
        sv=choose_density(status_runtime,status_draw)
        row={"resolution":f"{w}x{h}","uiScale":s,"typeGlyphPhysicalPx":type_draw,"typeRasterPx":tv["pixels"],"statusGlyphPhysicalPx":status_draw,"statusRasterPx":sv["pixels"]}
        resolution_results.append(row)
        check(f"{w}x{h}:type no small-raster upscale", tv["pixels"]>=type_draw, row)
        check(f"{w}x{h}:status no small-raster upscale", sv["pixels"]>=status_draw, row)

    result={"ok":not failures,"checks":checks,"failures":failures,"resolutionQA":resolution_results}
    if args.json_out:
        args.json_out.parent.mkdir(parents=True,exist_ok=True)
        args.json_out.write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    passed=sum(1 for c in checks if c["ok"])
    print(f"glyph pipeline: {passed}/{len(checks)} checks passed")
    for row in resolution_results:
        print(f"  {row['resolution']}: type {row['typeGlyphPhysicalPx']:.3f}px <- {row['typeRasterPx']}px; status {row['statusGlyphPhysicalPx']:.3f}px <- {row['statusRasterPx']}px")
    if failures:
        print("FAILURES:")
        for f in failures: print(" -",f)
        return 1
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
