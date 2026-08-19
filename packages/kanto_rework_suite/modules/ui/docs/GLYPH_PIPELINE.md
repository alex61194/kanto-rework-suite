# KRS Type / Status Glyph Pipeline — 0.4.11

## Source of truth

Figma file key: `X9gkkR1wKZKUyK5xtBSiKF`.

Canonical glyph-only component sets:

- `KRS / Icon / Type Glyph` — node `625:2266`; 18 variants; transparent `20×20` canvas; SVG `viewBox="0 0 20 20"`.
- `KRS / Icon / Status Glyph` — node `627:2304`; 7 variants; transparent `32×32` canvas; SVG `viewBox="0 0 32 32"`.

The canonical SVG canvas is preserved. Runtime code must not crop to the visible trace bounding box: that padding is part of the approved optical geometry.

Canonical composition sets:

- Type Token Full — `618:2865`, `148×36`, 2 px white outline, 20 px glyph.
- Type Icon Compact — `618:2641`, `32×32` semantic circle containing the same 20 px glyph.
- Status Token Full — `149:116`, `188×40`, 2 px semantic outline, 32 px compact status icon.
- Status Icon Compact — `405:3994`, `32×32` semantic circle containing the same 32 px status glyph canvas.
- Badly Poisoned semantic marker — node `618:2549`, `12×12`, positioned at `x=20,y=0` in the 32 px compact frame, with 1 px white inside stroke. The exclamation itself belongs to canonical glyph node `627:2278` and is not reconstructed in Lua.

The Status Token/Icon family also contains a canonical `None` variant (`393:3814`). It represents the absence of an ailment and therefore does not create an eighth ailment glyph asset. Runtime values `NONE`, `OK`, `HEALTHY` and empty status resolve to no status badge.

## Canonical nodes

### Types

| Type | Node | Canvas | Visible trace in canvas |
|---|---|---:|---|
| Normal | `625:2224` | 20×20 | x0 y0 20×20 |
| Fire | `625:2226` | 20×20 | x2.5 y0 15×20 |
| Water | `625:2228` | 20×20 | x3.5 y0 13×20 |
| Electric | `625:2230` | 20×20 | x3.5 y0 13×20 |
| Grass | `625:2232` | 20×20 | x0.5 y0 19×20 |
| Ice | `625:2234` | 20×20 | x0 y1.25 20×17.5 |
| Fighting | `625:2242` | 20×20 | x0.5 y0 19×20 |
| Poison | `625:2244` | 20×20 | x0 y0 20×20 |
| Ground | `625:2246` | 20×20 | x0 y2.5 20×15 |
| Flying | `625:2248` | 20×20 | x0 y1.5 20×17 |
| Psychic | `625:2250` | 20×20 | x0.5 y0 19×20 |
| Bug | `625:2252` | 20×20 | x1.5 y0 17×20 |
| Rock | `625:2254` | 20×20 | x0 y2 20×16 |
| Ghost | `625:2256` | 20×20 | x0 y0 20×20 |
| Dragon | `625:2258` | 20×20 | x1.5 y0 17×20 |
| Dark | `625:2260` | 20×20 | x0 y0 20×20 |
| Steel | `625:2262` | 20×20 | x0 y1.5 20×17 |
| Fairy | `625:2264` | 20×20 | x0 y0 20×20 |

### Statuses

| Status | Node | Canvas | Visible trace in canvas |
|---|---|---:|---|
| Poisoned | `627:2272` | 32×32 | x6.9072 y7.2998 18.1941×17.9150 |
| Badly Poisoned | `627:2278` | 32×32 | x6.9072 y3.1816 19.7761×22.0332 |
| Burned | `627:2285` | 32×32 | x9.2007 y6.6411 13.5691×18.9717 |
| Paralyzed | `627:2287` | 32×32 | x9.7974 y6.1904 12.3167×19.5444 |
| Asleep | `627:2289` | 32×32 | x5.6543 y8.2729 20.6904×15.7271 |
| Frozen | `627:2295` | 32×32 | x7.6387 y5.4150 16.6987×21.2139 |
| Fainted | `627:2300` | 32×32 | x7.5225 y11.4160 17.1179×9.7129 |

## Files and regeneration boundary

```text
assets/source/type_glyphs/*.svg      # canonical Figma exports
assets/source/status_glyphs/*.svg    # canonical Figma exports
assets/runtime/type_glyphs/{1x..4x}  # generated PNGs
assets/runtime/status_glyphs/{1x..4x}
generated/glyph_manifest.json        # generated Figma/runtime mapping
generated/assets.lua                 # generated runtime asset registry
tools/glyph_sources.json             # Figma node/canvas/trace inventory
tools/generate_glyph_assets.py       # generator
components/*.lua                     # manual; generator never writes here
```

`tools/generate_glyph_assets.py` deletes and rebuilds only the two runtime glyph directories plus the generated glyph manifest/registry. It validates canvas/viewBox and rejects non-white baked SVG paints.

Runtime raster densities:

- Type: 20, 40, 60, 80 px (`1x..4x`).
- Status: 32, 64, 96, 128 px (`1x..4x`).

The generator preserves SVG antialiasing in alpha and forces RGB to white even in fully transparent texels. This prevents dark RGB bleed when LÖVE linearly filters transparent edges.

## Runtime rules

- `generated/assets.lua` is the only runtime glyph registry.
- `components/type_icon.lua`, `components/type_chip.lua` and `components/status_token.lua` never hardcode an individual glyph path.
- Glyph textures use `linear` filtering, never `nearest`.
- Runtime selects a vector-derived raster with approximately two source pixels per displayed pixel when available, then downsamples it.
- No profile-specific raster assets exist. Standard, Protanopia, Deuteranopia and Tritanopia use the same glyph file and canvas geometry.
- Type glyphs and status glyphs remain literal white because the validated Figma Type Token / Status Icon components use white glyphs. Semantic color belongs to the surrounding container/token.
- `TypeChip` and compact `TypeIcon` both resolve the background through the same `theme.typeColors[kind]`. Fire therefore cannot diverge between those components unless the semantic token itself changes.

## Runtime QA board

Mod option: `glyph_test_board` (default `false`).

When enabled, `components/glyph_test_board.lua` renders all 18 Type Tokens, all 7 Status Tokens, compact type icons and compact status icons using the same production components and current accessibility profile.

The offline validation command is:

```text
python tests/validate_glyph_pipeline.py --json glyph-validation.json
```

The offline evidence renderer is:

```text
python tools/render_glyph_evidence.py --out evidence
```

Neither command constitutes an in-game Gen1Recomp test.
