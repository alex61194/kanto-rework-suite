# Kanto Rework Suite Changelog

## 0.1.0-candidate.6 — Candidate.5 USER TEST Live Editor corrections

### Fixed
- Makes the visible `LOCAL` segment in the off-battle Mods Live Editor a real pointer target using the existing Global/Local scope backend; combat Local behavior is preserved.
- Splits the production Battle Action Menu composition into independent FIGHT / POKéMON / BAG / RUN child positions while preserving the existing parent group transform and shared scale.
- Removes the generic ±960/±540 UI movement wall. Player/Enemy HUD movement now derives its legal offsets from the component's actual rendered bounds and the full 1920×1080 viewport, so each box can reach the opposite/top/bottom directions while remaining fully on-screen.
- Preserves Trainer semantic scene bounds separately from generic UI movement.

### Runtime qualification
- Gen1Recomp 0.1.99 / Pokémon Red / 1920×1080: off-battle GLOBAL → LOCAL → GLOBAL via real mouse ingress PASS.
- Player HUD crossed the former (+960,-540) wall and Enemy HUD crossed (-960,+540) through the real editor keyboard position path.
- Real mouse drag moved FIGHT independently while POKéMON/BAG/RUN remained unchanged; after SAVE CHANGES a genuine trainer BattleState rendered the same independent FIGHT transform.
- New Candidate.6 USER TEST remains pending.

### Versioning
- Suite: 0.1.0-candidate.6
- UI: 0.8.58
- Graphics: 0.3.6 (unchanged)
- Core: 0.1.44
- Gameplay: 0.3.18
- Battle Animations: 0.1.7
- Compatibility: 0.4.20
- Dev Tools: 0.2.5

## 0.1.0-candidate.5 — Battle Live Editor, Trainer Art and runtime qualification

### Fixed
- Makes Live Editor settings genuinely navigable through the shared keyboard, mouse and controller action/focus path without free numeric entry.
- Adds independent Player/Enemy Info Box scale controls and correct left/right edge anchoring.
- Exposes the production Battle Action Menu and Move Selection/description components for live position/scale editing and persistence.
- Sets the fresh Live Editor animation-speed default to 15% while preserving existing saved values.
- Fixes trainer-preview Intro/Battle/Post semantic phase selection and animated-atlas Canvas lifetime.
- Makes semantic battle/menu footers resolve the active device and current bindings dynamically.

### Added
- Trainer Art source selection with deterministic ROM/Gen I/Gen II/Gen III/Gen V resolution and diagnosed fallback.
- Audited Gen V animated trainer battle art for supported trainer classes, preserving APNG frame timing in LÖVE-compatible atlases.
- Optional persistent opponent trainer during battle with independent Intro, Battle and Post-Battle transforms, scale and animation speed.
- Global KRS persistence for Live Editor visual composition so settings survive save-slot changes and process restarts.

### Runtime qualification
- Gen1Recomp 0.1.99 / Pokémon Red: keyboard/mouse Live Editor, 1920x1080 HUD/action/move composition, Trainer Art, persistent trainer, trainer scale/speed, cross-slot/restart persistence and dynamic footer paths exercised in runtime.
- Targeted genuine `BattleState:onFaint` victory queue restores the Post-Battle trainer while BattleState remains active.
- Physical controller hardware and current-build USER TEST remain pending; synthetic DualSense gamepad-path validation is not presented as hardware validation.

### Versioning
- Suite: 0.1.0-candidate.5
- UI: 0.8.57
- Graphics: 0.3.6
- Core: 0.1.44
- Gameplay: 0.3.18
- Battle Animations: 0.1.7
- Compatibility: 0.4.20
- Dev Tools: 0.2.5

## 0.1.0-candidate.4 — Live Mockup Editor user-test corrections

### Fixed
- Restores the Live Battle Graphics Editor utility inside the Suite Mods integration even when the higher-priority Compatibility adapter owns the primary mod decoration.
- Makes live battle editing modal for input: KRS battle controls and the priority-9000 Dev overlay yield pointer/wheel/non-F3 keyboard ownership while `graphics_editor` is topmost.
- Synchronizes `BATTLE MOVE PREVIEW` with `mod.options_changed`, so OFF immediately suppresses the move-animation browser while leaving the compact F3 battle tools available.
- Keeps the Live Editor accessible from both the Mods preview path and an active battle without creating duplicate battle UI renderers.

### Versioning
- Core: 0.1.44
- UI: 0.8.56
- Graphics: 0.3.5 (runtime diagnostic version aligned with the already-declared Candidate.3 module version; no Graphics behavior change in this correction pass)
- Dev Tools: 0.2.5

### Evidence
- Candidate.3 failures: USER TEST from the supplied 2026-08-17 recording.
- Corrected behavior: STATIC + headless regression harness; real Gen1Recomp re-test remains NOT TESTED until user qualification.

## 0.1.0-candidate.3 — Live Mockup Editor restoration and extension

### Restored
- Restored direct access to the battle Live Mockup Editor from an active KRS battle.
- Preserved the existing Mods utility preview path and the production BattlePresenter renderer pipeline.

### Added
- Live composition controls for Player Pokémon, Enemy Pokémon, Battle Background, Enemy Info Box, Player Info Box, Battle Action Menu, and Move Selection + description.
- Independent Pokémon X/Y, battle-only scale, direct drag, fine/coarse adjustment, reset and lock.
- Aspect-preserving Battle Background zoom/crop plus X/Y framing offsets.
- Resizable responsive settings window with scroll and minimum usable dimensions.
- Numeric values are display-only; editing now uses sliders, drag, nudge/buttons and reset rather than free numeric typing.
- Explicit background spatial metadata and a suggestion-only Pokémon size/placement assistant.
- Explicit Save Changes, Discard Unsaved, per-element reset, scene reset and dirty-exit protection.

### Architecture
- Core remains unchanged.
- Graphics owns background spatial metadata, Pokémon presentation configuration and placement suggestions.
- UI owns editor interaction, composition offsets and production battle UI placement.
- Battle Animations continues to consume live battler bounds/anchors and remains a separate internal module.

### Validation
- 130/130 headless Lua tests passed before release preparation.
- 266/266 Lua syntax checks passed before release preparation.
- 72/72 canonical Battle Backgrounds validated at 1920x950.
- Internal dependency graph: 7 modules, 0 cycles.
- Real Gen1Recomp/OpenGL/controller/user acceptance remains NOT TESTED in this workspace.

### Known limitations
- Placement suggestions are heuristics and still require visual tuning in the real game.
- Unknown/mod-authored backgrounds use neutral spatial metadata until explicitly authored.
- Graphics/UI persistence spans two owner services; rollback is compensating rather than engine-atomic.

## 0.1.0-candidate.2
- Consolidated single-install Kanto Rework Suite Candidate with Battle Animations 0.1.7.
