## 0.3.6 — Trainer Art pipeline and editor defaults

- Adds deterministic Trainer Art resolution across available ROM/Gen I/Gen II/Gen III/Gen V sources with diagnosed fallback.
- Imports the audited Gen V animated trainer subset as LÖVE-compatible atlases while preserving per-frame APNG timing.
- Adds trainer presentation data consumed by the real battle scene and Live Editor.
- Changes only the fresh Live Editor animation-speed default to 15%; existing persisted values remain authoritative.

## 0.3.5 — Battle scene spatial metadata and placement assistant

- Add explicit lightweight Battle Background spatial metadata for horizon, perspective strength, scale reference, relative Player/Opponent depth and useful circle width.
- Add a suggestion-only Pokémon size/placement assistant that combines intrinsic Pokédex height, scene projection, real UI bounds and artistic readability clamps.
- Add safe Battle Background framing controls and preserve aspect ratio; no independent X/Y distortion is introduced.
- Keep battle placement/scale isolated from Party, Summary, PC and other menu presentation contexts.

## 0.3.4 — Live Graphics families, gender tracks and combat Speed stages

- Resolve audited stacked Male/Female battle-art tracks to one rendered sprite.
- Fix compact two-frame menu icon ownership/cadence at 150 ms per frame.
- Share Local calibration across Sunrise/Day/Sunset/Night variants of one background family while preserving structural overrides.
- Add combat-only bounded Speed-stage sprite cadence mapping and Live editor preset/grid support services.

## 0.3.3 — Live Graphics editor services

- Structured Global/Local battle presentation settings and named global profiles.
- Player Back / mirrored Front, Opponent Front, available-generation filtering, continuous Size and animation-speed controls.
- Slow/Normal/Fast Pokémon animation cadence is now deliberately differentiated without time-scaling battle logic or HUD transactions.

## 0.3.2
- Add an explicit player.presentation.front family for Trainer Card / Save.
- Scope player_art replacement to battle backsprite contexts only.
- Add presentation-only Pokémon contexts so battle Scale/Real Size cannot leak into menus.

# Kanto Rework Graphics Changelog

## 0.3.1 — Animated battle art and KRS time of day
- Imports the user-supplied Kanto animated front/back atlas families into the KRS Graphics registry with nearest-neighbour rendering and first-frame/static fallbacks.
- Adds Pokémon Sprite Mode, Front Generation, Back Generation, Player Art, Sprite Animation and Animation Speed controls.
- Front Gen2–5 animate; Front Gen1 remains single-frame. Back Gen3/Gen5 animate; Back Gen1/2/4 remain single-frame.
- Adds player battle-art selection and phase-locked five-pose battle-introduction strips where supplied.
- Preserves Gen5 2-frame Party/PC/Save icons and strict battle-only Scale / Real Size isolation.
- Adds a clean-room Sunrise / Day / Sunset / Night service with Sync, Cycle, pinned phases and 10/20/40-minute cycle lengths.
- Applies time tint only to outdoor 2D world presentation, never the UI; battle backgrounds read the same KRS phase.
- Does not depend on Voxel, Potato Voxel or Kanto First Person.

# Changelog

## 0.2.0 — Kanto Rework Graphics autonomy
- Keeps the visible module as Kanto Rework Graphics with manifest id `kanto_rework_graphics`.
- Owns KRS Pokémon front/back normal/shiny selection through the official `pokemon.sprite` hook, independently of Voxel.
- Adds provider, battle scaling, Real Size and battle-background controls; removes 0.25x.
- Intro Pokémon now resolve as front sprites; menu icons remain isolated to Party/PC contexts.
- Red/Blue trainer intro metadata enforces native 1:1 drawing with nearest filtering; layout clipping/dialogue masking adapts around the source instead of resampling it.

## 0.1.0
- Added the supplied Gen5-style two-frame Pokémon menu icon sheets and normal/shiny front/back families.
- Added KRS intro trainer and laboratory assets from the current validated UI package.
- Added context-scoped graphics resolution with normal/shiny/gender/form fallbacks.
- Normal/shiny filename resolution supports gendered and form-specific variants across both zero-padded and raw numeric form suffixes, with context-local fallback when an exact variant is absent.
