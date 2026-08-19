# Kanto Rework UI 0.8.52


## 0.8.39 — Canonical Figma fidelity and PC/Bag correction

- Current Party / Summary / Moves, Bag, PC, Options and Mods presentation follows the canonical Figma measurements/tokens audited for this release.
- PC search/sort is functional and box edits no longer write the save file from the UI layer.
- Bag uses the exact item icon assets currently authored in the canonical Figma mockups and preserves quantity while favorited.
- Header interaction states are centralized and theme-aware; Retro header focus/selection is monochrome as authored.

## 0.8.38 — Validated interaction and metadata pass

Bag/Options/Mods/PC inputs now follow the canonical focus hierarchy, PC search/sort and drag feedback are functional, and save cards consume Core's isolated per-slot metadata.

## 0.8.37 — Validated menu structural freeze pass 1

Runtime shell alignment for the validated Bag, Options, Mods and PC Figma families. Functional PC Search/Sort and final item/Pokémon asset pipelines remain separate roadmap phases.
## 0.8.36 — Gen1Recomp 0.1.86 sandbox baseline

- KRS-owned modules and images now resolve through `mod:read` / `mod.assets` instead of direct filesystem access.
- Pointer/UI coordination uses public Core/Compatibility/Dev exports rather than shared globals.
- All 0.8.35 battle-art scaling, shiny handling and per-background bottom-centre battle-circle grounding remain intact.

## 0.8.35 — Native Voxel scale + stable frame grounding

- Battle Art Voxel DEFAULT is strict authored-frame x1. Fixed multipliers remain literal; AUTO is computed per Pokémon by Compatibility.
- Front/back Pokémon are anchored by the bottom-centre of their complete frame to the calibrated battle-circle centre for the active canonical background.

## 0.8.34 — Per-background battle-circle grounding

- Adds calibrated player/enemy ground-contact anchors for all 72 canonical BattleBackGround assets through 36 geometry profiles; time-of-day variants reuse the same scene geometry.
- Pokémon front/back sprites are bottom-centred on the selected background's own battle circles instead of one global pair of coordinates.
- Reads Compatibility's Voxel presentation policy so DEFAULT uses the 380px KRS fit while X2/X3 preserve exact authored-pixel upscale.
- Pokédex-height sizing is now optional and applies only to DEFAULT Voxel fit mode.

## 0.8.33 — Voxel species-size calibration

- Voxel battle sprites no longer all read as if their atlas cell represented the same physical-size Pokémon.
- Uses Gen1Recomp's extracted Pokédex height with a bounded fourth-root scale (72%–125%) only for the Voxel provider.
- Keeps the existing bottom-centre circle anchor, animation metrics and source pixel art untouched.

## 0.8.32 — Overlay redesign and battle sprite grounding

- Rebuilds Area Catch List and Capture Odds as responsive KRS editorial widgets instead of scaling/clipping the old card stack.
- Grounds the bottom-center of the full Pokémon battle frame on the authored battle-circle center.
- Uses the live selected sprite-provider frame during battle so animated providers remain animated.
- Bag pocket spine is vertical: UP/DOWN chooses a pocket, RIGHT/confirm opens it, LEFT returns from items.

## 0.8.31 — Battle input, full-size sprites and responsive utility overlays

- Restores mouse ownership for the wide battle UI without stealing relative mouse look from Voxel first/third-person gameplay.
- Removes the battle-only 50% Pokémon-art scale; front/back provider art again uses the full 380×380 authored battle slot.
- Removes Money, Play Time, Type Chart and Party overlays. The retained Area Catch List and Capture Odds overlays fully reflow from both width and height, including typography, sprites, card grid and spacing, with no resize-to-reveal clipping path.
- Uses the semantic EXP token in battle HUDs, including Retro, so EXP remains blue instead of inheriting a black/structural theme role.

## 0.8.30 — Silph Co, Rocket Hideout and complete BBG coverage

- Adds the exact 1920×950 Figma BattleBackGrounds for Silph Co and the Team
  Rocket Hideout as fixed, windowless interiors.
- Routes every `SILPH_CO_*` floor to Silph Co and every
  `ROCKET_HIDEOUT_*` floor to the Rocket Hideout; the Game Corner Rocket
  encounter uses the same authored Rocket scene.
- Gives every Gen1Recomp 0.1.80 tileset a location-logical canonical fallback,
  including forest, ship, cemetery, mansion, laboratory, cavern, gym and
  facility families. Unknown mod-authored maps receive a time-aware Kanto road
  fallback instead of the obsolete generated colour bands.
- Validates 72 packaged canonical images, all 24 vanilla tilesets and all 74
  vanilla maps containing a trainer or static Pokémon battle object.

## 0.8.29 — Event, pointer and battle-scale release hotfix

- Keeps KRS presentation active across fullscreen/windowed swapchain changes by
  treating the current render viewport as authoritative.
- Extends pointer ownership to visible interactive modular overlays while the
  overworld remains the stack owner.
- Resolves scripted dialogue from the exact event text key and current actor,
  including Professor Oak's three starter prompts and both of Blue's post-lab-
  battle lines; narration deliberately has no speaker chip.
- Renders Pokémon at exactly 50% of the previous KRS battle size while keeping
  their slot centre, feet baseline, animation and every non-battle view intact.
- Supplies field notes for the complete Gen I item-name table in the Bag,
  Shop and Player PC; TM/HM entries continue to show their taught move, effect
  and battle statistics from the active game data.
- Shows the contextual Pokémon's learned moves and current/max PP beneath its
  sprite in Box storage, whether context comes from focus, hover or drag.
- Covers Gen1Recomp Link and Tournament states with four theme-coherent Wide
  interfaces while leaving all protocol and peer-state ownership native.

## 0.8.28 — Canonical battle scenes and final release fixes

- Integrates all 70 canonical Figma BattleBackGrounds with map-aware routing,
  sunrise/day/sunset/night selection and deterministic per-battle variants for
  windowless interiors.
- Keeps Oak's starter preview on one stable native entry and synthetic Pokémon
  identity so the selected art provider can advance its real animation.
- Restores Retro HP and EXP semantic colours in menus and battles.
- Preserves the authoritative trainer identity when Kanto Ascendant prefixes a
  rematch dialogue with rank metadata.
- Shows the taught move name, type, power, accuracy, PP and ROM-aware
  description for TM/HM items in the Bag.
- Adapts modular overlay surfaces, rails, accents and typography to Cream,
  Graphite, Purple Night and Retro.

## 0.8.27 — Four-theme Figma fidelity and starter presentation

- Bundles the canonical Inter faces used by Cream, Graphite and Purple Night,
  plus Pixelify Sans Regular/Medium/Bold for Retro. All four themes now resolve
  their declared Figma family instead of falling back to an engine font or an
  approximate raster atlas.
- Uses the 27 exported textless Figma component variants for the nine Main
  Menu cards and their Default/Hover/Selected states. Runtime text remains
  dynamic and no longer reconstructs desaturation, gradients or borders.
- Keeps coloured type badges/icons and status icons in Retro as the explicit
  product exception to the monochrome mockup layers.
- Presents native starter DexEntry states inside the KRS Pokédex DATA frame
  while preserving the engine-owned cry, A/B update and script callback.
- Resolves the starter image through the active shared Pokémon-art provider.

## 0.8.17 — Explicit KRS pointer-surface ownership

- Exposes the live KRS pointer-surface owner to versioned compatibility
  adapters so a camera mod cannot keep consuming menu motion and clicks.
- Restores a keyboard/mouse cursor when releasing first/third-person capture,
  while pure controller navigation remains cursor-free.

## 0.8.16 — Menu pointer and responsive mod information

First/third-person camera capture is released while a KRS menu covers the
overworld. Long mod descriptions use measured flow, a card that can grow only
to an 8 px safe gap inside the white panel, and an internal scrollbar when the
complete metadata still exceeds that viewport.

## 0.8.5 — Figma-faithful Pokédex

This release reconstructs the Wide Pokédex INDEX, DATA and AREA frames from
the canonical Figma mockups, bundles the Inter font family, preserves active
Kanto Ascendant front sprites and icons through Gen1Recomp's live resolver,
and adds Professor Oak's native-data evaluation in a complete modal flow.

## 0.8.4 — Party recovery / cross-box storage

This release fixes the Wide Party Summary/Moves renderer, restores complete
move metadata, adds inter-box PC transfers for mouse, keyboard and controller,
uses the Figma grass/forest/cave/water battle backgrounds, and resolves the focused Main Menu
Pokémon through the active runtime sprite provider (including Kanto Ascendant).


## 0.8.3 — Figma reconciliation / inverse hierarchy

- Reconciles generated Figma implementation hints against the canonical mockups and validated KRS behavior instead of treating generated specs as authoritative.
- Restores the validated Bag inverse Pocket Spine: dark structural rail, cream active pocket, turquoise transient focus, distinct hover/pressed semantics.
- Uses the canonical gold category-selection token for Options/Mods rather than borrowing the Electric type color.
- Aligns Battle command selection and focused move rows with the canonical Commands/Fight frames, including contextual battle glyphs.
- Tightens Pokédex DATA to the validated editorial field-record composition and replaces unsupported Unicode status/location markers with runtime vector geometry or safe text.
- Preserves Save inverse cards while using the elevated cream selected card from Figma.
- Save/Load cards keep the Figma trainer portrait and active-Party icon preview through engine sprite resolution.
- Wide footers use safe textual direction labels where the runtime font cannot render the Figma arrow glyphs.

## 0.8.2 — Wide controller ownership / input integrity

- Gives KRS handled Wide `Menu`, `ListMenu`, `QuantityBox` and `ChoiceBox` states a single KRS-owned controller while preserving native callbacks and local vanilla fallback.
- Makes Pokédex and Save-slot hover visual-only; pointer movement no longer commits a species or save slot.
- Maps the four Save/Load cards explicitly to `slot1` through `slot4`, so an empty card keeps its visible slot number when saved.
- Removes the post-load stack pop that could delete the overworld immediately after `restoreSave()` and leave an empty-stack softlock.
- Routes the custom `pc_storage` screen through the KRS menu input layer.
- Keeps Summary stat-tab changes click/confirm-driven instead of changing tabs on hover.
- Aligns direct Bill’s PC transfers with Gen1Recomp 0.1.77 BoxMenu semantics: restored party stats for withdrawn box Pokémon, Yellow deposit-happiness handling, and Save SFX on box changes.
- Restores the native Pokédex as the explicit fallback outside supported Wide layouts.

## 0.8.0 — Menu rework / Gen1Recomp 0.1.76

- Implements the current Figma `Menu rework` direction across Start, Pokédex, Party/Summary/Moves, Bag, Shop, Bill’s PC, Options, Mods, Save/Load and battle command surfaces.
- Uses Gen1Recomp 0.1.76 native save slots for four-card Save/Load management.
- Adds direct Wide Bill’s PC storage management over the Gameplay 20×180 box model, while retaining native fallbacks outside supported Wide layouts.
- Adds Bag registration UI, battle information overlay and last-ball context.
- Preserves multi-input pointer/focus infrastructure and existing Map/Fly/dialogue/third-party compatibility paths.

## 0.7.7 — Verified Restart Now

The restart overlay closes only after Core confirms that the official LÖVE
restart event was emitted or queued directly. A successful request displays
`GAME SAVED · RESTART REQUESTED`; a failure remains visible in the Mods UI.

## 0.7.6 — Plug-and-play mod features and restart resume

Standard third-party options and Start Menu features now appear under the
owning Installed Mods card automatically when Compatibility can establish hook
provenance. Their standard ListMenu/TextBox descendants use the existing Wide
reader. `Restart Now` explicitly saves, restarts and restores the active save
on supported desktop platforms.

## 0.7.5 — Adaptive Wide reader

Legacy TextBox pages now become an ordered Wide document. Narrow line wraps
are recomposed, long content scrolls inside a bounded reader, choices remain at
the document end, and keyboard/controller, mouse and touch share the same
navigation model.

## 0.7.4 — Third-party mod trees

Versioned adapters can now attach native settings and feature trees to the
corresponding Installed Mods card. Kanto Ascendant 6.0.11 is the first complete
adapter: its option schema stays authoritative, its parallel Main Menu gateway
is removed, and its ListMenu/TextBox utility path is rendered by Kanto UI.

## 0.7.3 — Third-party Start-menu actions

Kanto UI now keeps its Wide Start Menu when a mod extends the official native
menu. Unclaimed external actions appear in the Kanto System row and invoke the
mod's original callback. Claimed actions such as Ascendant now live under Mods.

## 0.7.2 — Compatibility diagnostics and guarded restart

The Mods panel exposes compatibility findings and capability claims. Applying
changes now offers explicit Restart Now, Later and Discard Changes actions;
automatic restart is attempted only from a safe overworld state.

## 0.7.1 — Bounded lists and shared overflow behavior

- Dynamic rows stay clipped inside their owning panel and cannot be activated
  through a header or footer.
- Options, compatibility Controls, Mods/Profiles/Errors, Map/Fly destinations
  and Field Actions expose scrollbars only when their content exceeds the
  available viewport.
- Keyboard/controller focus keeps the active row visible. Mouse wheels and
  draggable scrollbar thumbs cover mouse and touch input with 44 px hit areas.
- Learned Moves no longer silently stops after eight entries; its scrolling
  window follows the focused move and remains draggable with mouse or touch.

## 0.7.0 — Direct overlays and collision-safe tabs

- F8 shows the configured overlay layer. Expanded headers move their window,
  bottom-right grips resize it, and the header control collapses it directly.
- F9 shows only the four context choices. It does not move, resize or collapse
  overlays; reduced widgets appear as temporary cards so their context remains
  configurable without changing their saved reduced state.
- A reduced tab covered by an expanded window moves temporarily to the nearest
  free position on its saved edge. It returns automatically when that space is
  free, and the saved edge/position never changes.
- Tabs draw above windows, and collapse/resize targets have a 44 px minimum.
- Keyboard/controller users can invoke `ADJUST OVERLAY LAYOUT` directly on the
  F8 layer (`F6` / DualSense Touchpad by default). Directions move; Confirm
  switches Move/Resize; Select changes widget; Start collapses/restores; Cancel
  exits. The action is rebindable in Controls.

## 0.6.9 — Draggable persistent collapsed tabs

- Drag a reduced tab directly during normal gameplay to move it along any safe
  edge or across a corner to another edge.
- A short click/touch still restores the overlay; dragging leaves it collapsed.
- Expanded position and size remain untouched, while the reduced edge and
  position persist independently and return on the next collapse.
- In F9, keyboard/controller directions move a focused reduced tab along its
  current edge or switch it to the opposite edge.

## 0.6.8 — Story-ordered Map/Fly navigation

- Orders Kanto destinations by first-playthrough story progression instead of
  geographic coordinates or the ROM's numeric town order.
- Uses conventional vertical-list navigation: Up selects the previous visible
  destination and Down selects the next one on keyboard and controller.
- Preserves unknown or mod-authored destinations after the curated Kanto towns
  without changing their relative source order.
- Keeps the validated full-height cream sheet, compact anchored POI labels and
  full-bleed map composition from 0.6.7.

## 0.6.7 — Map/Fly full-bleed polish

- Extends the canonical Kanto map beneath the complete 16:9 frame, removing
  the black gutters around the destination list.
- Integrates Fly destinations into a full-height cream paper sheet with a
  subtle divider instead of a detached black-backed panel.
- Uses compact POI labels, short anchor lines and explicit `CURRENT`,
  `AVAILABLE` and `LOCKED` text states.
- Keeps automatic centering and map dragging inside the uncovered safe area,
  so the paper sheet never hides the selected POI.

## 0.6.6 — Direct collapse and restore

- Every expanded overlay shows a compact minimize control during normal play;
  mouse/touch activation no longer requires F9.
- The edge tab restores the overlay directly.
- `F12` or left-stick click toggles the last targeted visible overlay by
  default, and both bindings can be changed in Controls.

## 0.6.5 — Edge collapse and responsive overflow

- In F9 edit mode, `COLLAPSE` reduces an individual widget to a persistent tab
  on the nearest screen edge. Clicking/tapping the tab restores the exact
  previous position and dimensions.
- Keyboard/controller users can focus tabs with Select, restore with Confirm,
  and toggle collapse with Start.
- Focused widgets render above overlapping widgets. Narrow context controls use
  two rows, dense lists report hidden rows, and the type chart uses a compact
  matrix rather than overflowing its box.

## 0.6.4 — Title, complete map towns and diagonal resize corrections

- `LOAD GAME` receives initial focus when an active save exists. Without one,
  the disabled Load action is skipped and `NEW GAME` remains selected.
- The map draws every curated Kanto town independently from the visited Fly
  list, so locations such as Pallet Town remain visible when they are not in
  the destination panel.
- The live overworld sprite has no surrounding circle, is rendered at exact
  2× integer scale and is composited after location boxes.
- One bottom-right diagonal drag updates visible width and height together.
  Party, encounter and capture layouts choose columns from both available
  width and height; widget content is clipped to its own responsive surface.

## 0.6.3 — Free-aspect contextual overlay editing

- Map selection uses the blue focused-box border only; no circle, arrow or extra pointer is drawn.
- F8 opens/closes the complete configured overlay set.
- F9 shows every widget and exposes `OVERWORLD`, `BATTLE`, `BOTH` and `NONE` directly on each window.
- The bottom-right handle changes width and height independently. Party, encounter and capture content uses responsive columns/breakpoints; dense content retains a readable minimum.
- Per-widget ON/OFF settings were removed from the mod options. `PAPER`/`GLASS` and the global 50–100% scale remain there.

## 0.6.2 — Gated Fly and mouse-resizable overlays

- Map/Fly confirmations require HM02 Fly, the Thunder Badge, an outdoor map and a discovered destination.
- The Map selection used a directional cursor instead of a circular marker; 0.6.3 removes that extra cursor.
- In F9 edit mode, drag a widget's bottom-right handle to resize it; content reflows from the responsive scale and the individual size persists.


## 0.8.25 — Visual themes

The Wide interface exposes four product themes from the canonical Figma mockups: `CREAM` (default / Field Journal), `GRAPHITE`, `PURPLE NIGHT` (Figma Sombre), and `RETRO`. Theme choice is available in Options → Graphics as `UI THEME` and applies live. Accessibility color profiles remain an independent Core-owned layer. The Figma technical Rouge mode is not a product theme and is not exposed by Kanto Rework UI.

The 0.8.25 distribution is an **overlay update for an existing 0.8.24 installation**: the unchanged Inter/fallback font assets are reused from 0.8.24 rather than duplicated in the update archive. Apply 0.8.25 over the existing `kanto_rework_ui` directory. Retro does not add a font file; it uses Gen1Recomp's built-in PlainPixel face.

Retro uses the pixel typeface already shipped with Gen1Recomp so the mod package does not redistribute an additional font file.

Kanto Rework UI is the Wide UI module for the Kanto Rework Suite. It preserves the existing Main/Options/Mods/Controls/Party/Summary/Moves behavior and keeps screen-specific presentation outside `kanto_rework_core`.

## 0.6.1 — Floating title, pannable map and responsive overlays

- The Red title keeps only four independent startup boxes over the canonical artwork. There is no shared popup background, tint, header or footer bar.
- Map/Fly removes its black header/footer bars. The canonical map pans by mouse or touch, while keyboard/controller selection keeps the selected destination visible.
- The Fly list uses a narrower panel and compact rows without decorative icon circles.
- Kanto Rework UI options are grouped into `APPEARANCE`, `DEVELOPMENT` and `OVERLAYS` subcategories. `APPEARANCE` exposes the live Cream / Graphite / Purple Night / Retro theme selector.
- Overlay scale is adjustable from 50–100% and can also be cycled with the configurable `OVERLAY_SCALE_CYCLE` action (`F11` by default; `F10` remains owned by Gen1Recomp's mod manager).
- Overlay surfaces can use the opaque `PAPER` style or semi-transparent `GLASS` style.

## 0.6.0 — Figma title/map and contextual overlays

- The Wide Start Screen is version-aware. Red uses the canonical KRS artwork; Blue uses the supplied Blue Version artwork; Yellow keeps the engine's version-correct Yellow title plate underneath the same KRS `NEW GAME`, `LOAD GAME`, `OPTIONS`, third-party title actions and `EXIT GAME` component until a dedicated 16:9 Yellow plate is supplied. Outside Wide, the native title remains authoritative.
- Map/Fly now uses the canonical `685:1619` Figma map artwork. Fly targets, the selected target and the live native `16×16` player sprite remain runtime layers.
- Party now shows each Pokémon's native icon, types, HP bar and exact current/max HP.
- Current Location was removed. Wild Encounters replaces it contextually with encounter shares, levels and caught state, and stays hidden on maps with no encounter data.
- Added an opt-in 15×15 Generation 1 Type Chart for overworld and battles.
- Added contextual wild-battle Capture Odds for each available Ball, calculated from the current enemy HP/status and the merged Gen 1 ball rules.
- `F8` still toggles the overlay layer. `F9` now moves/locks contextual overlays in overworld and battle.

## 0.5.0 — Field Actions, Map/Fly and modular overlays

- `FIELD_ACTIONS` (default `F`) opens a contextual popup over gameplay. It contains labels and HM markers only—no descriptions or menu detour—and uses the same focus for mouse, keyboard and controller.
- `MAP` (default `M`) opens the themed Map/Fly screen and can be rebound in Options → Controls for keyboard or controller.
- The player marker is pulled at runtime from the active overworld `SpriteRenderer` and drawn at its physical `16×16` size without engine enlargement. No Red artwork is embedded in the Figma map.
- Player Status, Party Status, Current Location and Session were introduced as independent theme-aware overlays.
- ROM-specific title-screen resources were retained as planned assets.

## 0.4.13 — Context-sensitive Mods details

The Mods panel now follows the same focused-setting information model as Options: a mod row presents the mod summary, while an inline option row presents its current value and option-specific description. Parent runtime, compatibility and permission metadata remain visible.

## 0.4.12 — Full-frame accessibility integration

Core 0.1.13 applies the selected color-accessibility profile to the final pixels. UI therefore draws its canonical Standard semantic tokens into that pass instead of pre-correcting them a second time. Wide menus, Party/Summary/Moves, overlays and imported UI assets remain in the same global correction path in every engine color mode.

## 0.4.11 — Figma-canonical Type / Status glyph pipeline

Type and status iconography now comes directly from the validated glyph-only Figma component families:

- Type Glyph `625:2266`: 18 transparent `20×20` SVG variants.
- Status Glyph `627:2304`: 7 transparent `32×32` SVG variants.
- Type Token Full `618:2865`: `148×36`.
- Type Icon Compact `618:2641`: `32×32`, with the same `20×20` glyph canvas.
- Status Token Full `149:116`: `188×40`.
- Status Icon Compact `405:3994`: `32×32`.

Canonical SVGs live in `assets/source/`. Runtime PNGs are generated at 1x/2x/3x/4x from vector source, retain antialiasing, use white RGB in transparent texels, and are sampled with linear filtering. Semantic Type/Status color stays in runtime tokens. Standard, Protanopia, Deuteranopia and Tritanopia therefore reuse exactly the same glyph geometry and files.

All glyph loading is centralized through `generated/assets.lua`; production components do not hardcode per-glyph paths. The previous approximate type rasters and old status `poison/toxic/burn/paralyze/sleep/freeze/faint` rasters are no longer active.

For source nodes, trace bounds, regeneration boundaries and QA instructions, see `docs/GLYPH_PIPELINE.md`.

## Existing Controls architecture

Options → Controls exposes the native Gen1Recomp bindings for the eight Game Boy actions plus Kanto logical actions registered through Core. Core provides `COLOR_ACCESSIBILITY_CYCLE` (default `F7` / `R3`); UI-owned actions include `FIELD_ACTIONS` (default `F`), `MAP` (default `M`) and `OVERLAY_SCALE_CYCLE` (default `F11`). If `kanto_rework_gameplay` is installed, its `RUN` action appears through the shared action registry.
