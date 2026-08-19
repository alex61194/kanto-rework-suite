# Kanto Rework Graphics 0.3.2

KRS-owned graphics provider for Pokémon presentation, battle art and lightweight world lighting. The module remains `kanto_rework_graphics`; no separate Visuals module is created.

## Context isolation

- `party.icon`, `pc.icon`, `save.icon`, `moves.icon`, `main_menu.icon`, `menu.icon`: supplied Gen5-style 2-frame menu icon sheets, nearest-neighbour, fixed 150 ms/frame (300 ms loop), independent of battle/Live animation speed and battle scaling.
- `party.preview`, `summary.preview`, `pokedex.preview`: selected KRS front generation; animated atlases are used when available and enabled. These are the only regular menu surfaces allowed to own large front Pokémon art.
- `intro.pokemon`: narrative intro presentation context; it is intentionally separate from regular menu ownership.
- `battle.opponent`: selected KRS front generation.
- `battle.player`: selected KRS back generation.
- `intro.trainer`: KRS narrative trainer assets; battle Scale / Real Size never applies.

## Battle art controls

Graphics exposes Pokémon Sprite Mode, Front Generation, Back Generation, Player Art, Sprite Animation, Animation Speed, Battle Scale and Real Size. Front Gen2–5 have supplied animated atlases; Front Gen1 is single-frame. Back Gen3 and Gen5 have supplied animated atlases; Back Gen1/2/4 are single-frame. Missing selected/shiny art falls back within the same family and finally to Gen1Recomp.

The supplied animated atlas archive has no original timing metadata. KRS therefore uses a normalized configurable cadence rather than inventing source-authored timing.

## Time of day

The module owns one Sunrise / Day / Sunset / Night clock with Sync, Cycle and pinned phase modes. The 2D renderer uses Gen1Recomp's world-TOD/composition seams: outdoor world presentation is tinted while KRS/UI canvases remain untouched. Indoor maps remain neutral. Battle backgrounds consume the same KRS phase.

See `BATTLE_ART_SOURCE.md` for provenance limitations of the user-supplied artwork.
