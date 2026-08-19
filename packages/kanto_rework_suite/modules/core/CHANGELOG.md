## 0.1.44 — Additive Mods utilities

- Keeps the highest-priority adapter for primary mod decoration/options ownership.
- Aggregates and deduplicates utility rows from every matching integration adapter so a Compatibility self-adapter cannot hide the UI Live Graphics Editor utility.

## 0.1.43 — Shared controller Back and active-device stabilization

- Add one-frame physical native-action fallback used by KRS native-menu navigation.
- Stabilize keyboard/controller vs pointer ownership so tiny mouse motion does not steal Controller footer mode.
- Route compact Pokémon menu contexts to icon providers without broad battle-art leakage.

## 0.1.42 — Graphics editor request metadata

- Preserve neutral extra Pokémon-art request metadata so first-party providers can consume live background/time/editor overrides without Core learning Graphics-specific policy.

## 0.1.41
- Separate full Map location models from per-row Fly capability.
- Route Pokémon art requests through context-scoped Graphics providers instead of treating every front sprite as battle art.
- Resolve player presentation-front art through the KRS Graphics registry before the native fallback.

## 0.1.40 — Transactional Mods restart, Visuals-first art arbitration and Move Memory bridge

- Restart Now saves, unwinds active screens back to the overworld, prepares/verifies the official checkpoint identity, then dispatches the engine restart; a successful Lua call is not treated as proof of a completed second boot.
- Exposes `rememberKnownMove` so Gameplay's existing recursive level-up/pre-evolution Move Memory migration reaches Core's persistent move library again.
- Resolves Pokémon presentation from the KRS graphics registry first, then the official Gen1Recomp sprite path, with legacy compatibility providers last.

## 0.1.39 — Context-scoped Graphics registry and naming input back path

- Adds a neutral graphics-provider registry with explicit context ownership (`party.icon`, `pc.icon`, `intro.pokemon`, etc.), provider priority and safe fallback; Core stores no concrete artwork.
- Exposes the registry through `Core.graphics` so UI and future modules can resolve presentation assets without hard-coded cross-module paths.
- Keeps physical-keyboard naming exclusive and maps Escape from direct naming back to the engine-owned preset step while preserving Enter/Backspace semantics.
- Adds regression coverage for provider arbitration, context isolation and fallback.

## 0.1.38 — Per-slot metadata and readable mod errors

- Decodes each save slot from its own persisted main/tmp/backup file so load/save cards never inherit the current playthrough's money, badges, Pokédex, location or party.
- Exposes complete de-duplicated runtime errors grouped by owning mod for the UI reader.

## 0.1.37 — Gen1Recomp 0.1.86 sandbox migration

- Migrates all secondary-module loading from `love.filesystem.load` to the public `mod:read()` + sandbox-bound `load()` contract.
- Replaces shared `_G` coordination with explicit `mod.exports` / `mod.find()` APIs and moves overlay-profile persistence to namespaced `mod.storage`.
- Replaces direct LÖVE callback patching with Gen1Recomp Game/input seams, including the public `input.pointer` hook and engine-owned wheel/key handlers.
- Rebuilds Restart Now around `mod.checkpoints`, `mod.storage` and `Game:restartWithMods()`; the checkpoint resumes at the title session after the same game is reopened.
- Removes raw filesystem, FFI, debug, environment and `love.event` dependencies from Core.

## 0.1.36 — Overlay contract cleanup and developer Fly override

- Reduces persistent overlay state to `encounters` and `capture`; obsolete generic/player placement fields are no longer parsed or serialized.
- Adds a volatile developer Fly override consumed by map interaction only; it never mutates inventory, badges or save progression.
- Keeps shared pointer ingress unchanged for normal menus while allowing UI/Compatibility to distinguish passive overlay display from interactive pointer ownership.

## 0.1.35 — Shared physical-pointer ingress

- Exposes the complete Core pointer pipeline to versioned compatibility
  adapters when a third-party camera owns the raw LOVE mouse callbacks.
- Preserves input-mode promotion, pointer-sequence capture, KRS input-layer
  dispatch, overlays and native fallback instead of bypassing them through a
  non-existent `Game:mousemoved` seam.

## 0.1.34 — Shared elevation profiles

- Adds deterministic, presentation-neutral drop-shadow samples and the canonical card elevation profile used by Hover and Selected UI states.

## 0.1.32 — Shared typography registry

- Adds a presentation-neutral font-family registry with Regular, Medium,
  SemiBold, Bold and Black weight fallback resolution.
- Caches LÖVE Font instances by family, resolved weight and pixel size while
  leaving the owning UI module responsible for the actual font assets.

## 0.1.31 — Save-slot registry integrity

- Synchronizes the persistent save-slot registry with the live `game.save.options` snapshot before and after `Game:writeSave()`, preventing later targeted saves from rolling earlier slots out of `options.lua`.
- Keeps explicit KRS save targets stable: saving visual slot 2 writes and registers `slot2`, rather than leaving it visually empty after refresh.
- Restores the previous active slot when a targeted progress write fails.

## 0.1.30 — Gen1Recomp 0.1.76

- Raises engine compatibility to `>=0.1.76 <0.2.0`.
- Adds a native SaveData slot facade with list/read/save/load/delete/rename/status operations.
- Supplies rich slot summaries to presentation modules without duplicating save serialization.

# Changelog

## 0.1.33 — Cross-mod Pokémon art contract

- Adds a presentation-neutral Pokémon art resolver after Gen1Recomp's live
  sprite hooks, allowing versioned Compatibility adapters to supply the active
  third-party menu artwork without teaching Core any external asset layout.
- Preserves the resolved `trueColor` flag and provider provenance for every UI
  consumer.

## 0.1.29 — Verified restart request

- Replaces the previous `pcall` false-positive with verification that the
  engine actually emitted `quit("restart")`.
- Uses Gen1Recomp's own quit-routing state for the explicit restart and keeps
  the one-shot wrapper only as a compatible fallback.
- Removes a stale `relaunch_to_launcher.txt` marker before restarting so it
  cannot override the requested game/slot resume.
- Queues the official LÖVE restart event directly if an engine wrapper returns
  without emitting one.

## 0.1.28 — Automatic integration and restart resume

- Adds a neutral discovery-provider contract and per-mod automatic feature
  registry for standard `ui.start_menu.items` extensions.
- Moves provenance-resolved third-party actions into their Installed Mods
  model while retaining the original callback and adaptive-reader policy.
- Adds a guarded desktop save/restart/resume bridge that relaunches the active
  game and slot, then restores the saved overworld on the first game step.
- Refuses unsupported platform restart-resume paths instead of returning to the
  launcher after claiming success.

## 0.1.27 — Declarative presentation contracts

- Preserves optional presentation metadata on normalized mod utilities.
- Keeps rendering policy out of Core while allowing UI modules to select a
  safe presenter for an adapter-owned feature.

## 0.1.26 — Third-party presentation adapters

- Adds a presentation-neutral registry for versioned third-party mod adapters.
- Lets Compatibility attach option grouping and utility trees to installed-mod
  models without copying third-party code into Core.
- Allows an adapter-owned Start-menu gateway to be removed from the main menu
  when the same functionality is available under Mods.

## 0.1.25 — Cooperative Start-menu extensions

- Treats mod-authored Start-menu rows as supported external actions instead of
  forcing the complete Start Menu back to vanilla.
- Preserves each external row's original callback for UI presenters.

## 0.1.24 — Cooperative compatibility foundation

- Adds a typed capability registry for exclusive, middleware, additive and
  advisory providers without patching third-party mods.
- Adds versioned compatibility policies and diagnostics to the Mods runtime.
- Guards automatic save-and-restart behind a stable overworld-state check and
  exposes an explicit reason when restart must be deferred.
- Publishes provider claims and compatibility findings through the Core API.

## 0.1.23 — Direct layout and context-only F9

- Makes expanded overlay movement and free-aspect resizing available directly while the F8 layer is visible.
- Restricts F9 to the four per-widget context choices: Overworld, Battle, Both and None.
- Removes the layout lock gate from pointer movement and resizing while preserving the old action name as a compatibility alias.
- Keeps the preferred collapsed-tab placement persistent while allowing the UI to resolve temporary visual collisions without writing profile data.

## 0.1.22 — Independent collapsed-tab placement

- Persists a separate edge and along-edge position for every collapsed overlay tab.
- Distinguishes a short restore click from a drag, allowing reduced tabs to move without F9.
- Keeps expanded position and free-aspect dimensions unchanged while a tab is moved.
- Lets keyboard/controller editing move a collapsed tab independently from its expanded window.

## 0.1.21 — Direct overlay collapse and restore

- Allows an expanded overlay's collapse control to work during normal gameplay, without entering F9 edit mode.
- Adds a focused-overlay collapse toggle for configurable keyboard and controller actions.
- Keeps direct mouse/touch restoration from the collapsed edge tab.

## 0.1.20 — Persistent edge-collapsible overlays

- Persists an independent expanded/collapsed state for every modular overlay.
- Restores a collapsed overlay from its edge tab without changing its saved expanded position or dimensions.
- Exposes collapse state and controls through the shared Core API and pointer layer.
- Keeps mouse, keyboard and controller restoration on the same persisted state.

## 0.1.19 — Immediate diagonal overlay resizing

- Resolves width and height from the same pointer event during corner dragging.
- Uses the displayed responsive rectangle as the resize origin so neither axis waits for an invisible minimum-size threshold.
- Preserves independent width/height persistence, 60–160% bounds and contextual display modes.

## 0.1.18 — Free-aspect contextual overlays

- Replaces each widget's single scale with independently persisted width and height factors.
- Persists a per-widget context mode: Overworld, Battle, Both or None.
- Migrates legacy per-widget scale values into matching width/height values without executing profile data.
- Adds direct mouse hit regions for the four context choices shown in F9 edit mode.

## 0.1.17 — Fly gate and resizable overlays

- Centralizes Kanto Map/Fly eligibility: HM02 Fly, Thunder Badge, outdoor context and a discovered destination are mandatory.
- Exposes the validated Fly status/activation service so product UIs cannot bypass progression with a direct `flyTo` call.
- Persists an individual scale for every modular overlay and adds mouse resize interactions in edit mode.

## 0.1.16 — Grouped mod options

- Preserves optional group metadata from mod option schemas for product UIs.
- Adds a validated generic option setter used by configurable overlay scale shortcuts.

## 0.1.15 — Contextual overlay foundation

- Replaced the retired Location slot with Wild Encounters and added Type Chart and Capture slots.
- Persisted all six overlay positions through the strict non-executable profile format.
- Allowed `F9` move/lock mode in overworld and battle contexts.
- Safely resets a legacy Location focus to Player.

## 0.1.14 — Modular overlay foundation

- Replaced the former single-panel placement model with four independent persistent widget slots: Player, Party, Location and Session.
- Added shared overlay focus, hit-region, position and movement exports for mouse, keyboard and controller consumers.
- Kept `F8` as global visibility and `F9` as overworld-only move/lock mode.
- Migrates the former widget position safely into the Player slot without executing legacy profile data.

## 0.1.13 — Full-frame color accessibility

- Replaced Advanced-only four-color palette wrapping with one final-pixel compensation pass.
- Covers every engine color mode, all tilesets, `trueColor` regions, imported battle backgrounds, native screens, Kanto Wide HUD layers and touch controls.
- Added the configurable `COLOR_ACCESSIBILITY_CYCLE` action with keyboard and controller defaults (`F7` / `R3`).
- Kept Standard as an exact zero-pass fallback and synchronized live cycling with persistent mod options.

## 0.1.10 — Architecture registries

- Added presentation-neutral Input Action Registry with persistent keyboard/controller bindings.
- Added generic Field Action Registry with known/disabled/available evaluation.
- Added inter-mod notification bus.
- Explicitly separated confirmed move history from theoretical inferred relearn sets.
- Confirmed move history now records `pokemon.move_learned` events in addition to active-move observations.
- Added physical-input listener seam to the shared InputDevice service.
- Preserves the 0.1.9 controller release fix and 0.1.7 true borderless implementation.

## 0.1.9

- Controller release no longer reverts active-device prompts to keyboard/mouse.

## 0.1.12
- Extended logical controller capture to Square/Triangle, L3/R3, L2/R2 axis triggers and unmapped raw controller buttons such as DualSense Touchpad.
- Added trigger hysteresis so analog L2/R2 generate one logical press/release pair.
- Raw events from recognized gamepads now discard SDL-mapped duplicates while retaining extra buttons.
- Physical listeners can consume an outer event during capture or when a custom action reserves a non-GB engine hotkey.
- Custom actions bound to shoulders/triggers no longer also change Gen1Recomp Game Speed.
