#!/usr/bin/env python3
"""Validate the complete canonical Figma BattleBackGround export."""

from pathlib import Path
import binascii
import hashlib
import struct
import zlib


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "battle" / "backgrounds" / "canonical"

TIMED_FAMILIES = (
    "oak_lab",
    "grass",
    "road",
    "viridian_forest",
    "mt_moon",
    "cerulean_bridge",
    "ss_anne",
    "power_plant_exterior",
    "pokemon_tower",
    "safari",
    "sea",
    "pokemon_mansion",
)
TIMES = ("sunrise", "day", "sunset", "night")
FIXED = (
    "cave_dark",
    "cave_cerulean",
    "cave_victory_road",
    "cave_seafoam",
    "power_plant_1",
    "power_plant_2",
    "power_plant_3",
    "power_plant_4",
    "gym_pewter",
    "gym_cerulean",
    "gym_vermilion",
    "gym_celadon",
    "gym_fuchsia",
    "gym_saffron_fighting",
    "gym_saffron_psychic",
    "gym_cinnabar",
    "gym_viridian",
    "league_lorelei",
    "league_bruno",
    "league_agatha",
    "league_lance",
    "league_champion",
    "silph_co",
    "rocket_hideout",
)

EXPECTED = {
    f"{family}_{time}.png" for family in TIMED_FAMILIES for time in TIMES
} | {f"{name}.png" for name in FIXED}

FIGMA_SOURCE_SHA256 = {
    "silph_co.png": "0d629ea1a8119f122b34d5541174b111fb8504fb1dfbddc21bc384d99b0dfe1b",
    "rocket_hideout.png": "8e4460d3a53b5424707d018514b903210e3453065670a57dafd039029b5846b9",
}


def png_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n":
        raise AssertionError(f"{path.name}: invalid PNG signature")

    pos = 8
    idat = bytearray()
    size = None
    saw_iend = False
    while pos + 12 <= len(data):
        length = struct.unpack(">I", data[pos : pos + 4])[0]
        kind = data[pos + 4 : pos + 8]
        end = pos + 12 + length
        if end > len(data):
            raise AssertionError(f"{path.name}: truncated {kind!r} chunk")
        payload = data[pos + 8 : pos + 8 + length]
        expected_crc = struct.unpack(">I", data[pos + 8 + length : end])[0]
        actual_crc = binascii.crc32(kind + payload) & 0xFFFFFFFF
        if actual_crc != expected_crc:
            raise AssertionError(f"{path.name}: corrupt {kind!r} chunk")
        if kind == b"IHDR":
            size = struct.unpack(">II", payload[:8])
        elif kind == b"IDAT":
            idat.extend(payload)
        elif kind == b"IEND":
            saw_iend = True
            break
        pos = end

    if size is None or not saw_iend or not idat:
        raise AssertionError(f"{path.name}: invalid PNG signature/IHDR")
    try:
        zlib.decompress(idat)
    except zlib.error as exc:
        raise AssertionError(f"{path.name}: corrupt image stream: {exc}") from exc
    return size


def main() -> None:
    actual = {p.name for p in ASSET_DIR.glob("*.png")}
    missing = sorted(EXPECTED - actual)
    extra = sorted(actual - EXPECTED)
    assert not missing, f"missing canonical BBGs: {missing}"
    assert not extra, f"unexpected canonical BBGs: {extra}"
    assert len(actual) == 72, f"expected 72 BBGs, found {len(actual)}"

    sizes = {name: png_size(ASSET_DIR / name) for name in sorted(actual)}
    invalid = {name: size for name, size in sizes.items() if size != (1920, 950)}
    assert not invalid, f"unexpected BBG dimensions: {invalid}"
    invalid_hashes = {
        name: hashlib.sha256((ASSET_DIR / name).read_bytes()).hexdigest()
        for name, expected in FIGMA_SOURCE_SHA256.items()
        if hashlib.sha256((ASSET_DIR / name).read_bytes()).hexdigest() != expected
    }
    assert not invalid_hashes, f"new Figma BBG source hashes changed: {invalid_hashes}"
    print("72 canonical Figma battle backgrounds validated at 1920x950")


if __name__ == "__main__":
    main()
