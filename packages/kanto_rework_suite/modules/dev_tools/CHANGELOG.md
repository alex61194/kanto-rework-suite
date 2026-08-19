## 0.2.5 — Live Editor modal isolation and option sync

- Suspends the priority-9000 Dev overlay's render, pointer, wheel and non-F3 keyboard ownership while `graphics_editor` is topmost over an active battle.
- Resumes the still-open Dev overlay session after the editor closes.
- Synchronizes Battle Move Preview from `mod.options_changed` so OFF takes effect immediately in the running session.

## 0.2.4 — Supported toggle option and suite ordering

- Declares Dev overlay and Battle Move Preview with the engine-supported `toggle` option type.
- Keeps Battle Move Preview independently disableable; the UI now pins Dev directly after the other KRS modules.

## 0.2.3 — Gen1Recomp 0.1.86 sandbox migration and battle tools

- Moves all Dev runtime state into the mod-private sandbox and exposes only intentional state/functions through `mod.exports`.
- Keeps `BATTLE MOVE PREVIEW` as an explicit ON/OFF mod option; disabling it hides only the move browser, not the other F3 battle tools.
- Adds `ONE-SHOT ENEMY` to the in-battle F3 tools and routes the KO through BattleState's native `applyDamage` + `onFaint` pipeline.
- Preserves wild/trainer launch, explicit shiny selection, movable/resizable move preview, state dump and session-only Fly override.

## 0.2.2

- Makes the in-battle move-animation browser draggable, viewport-clamped and resizable.
- Adds a collapse/restore control in the header.
- Reduces its default footprint while keeping the complete move list scrollable.

## 0.2.1

- Fixed F3 doing nothing while the Dev overlay was closed.
- Physical F3 and the configurable Core action now share one toggle with de-duplication.
- The Dev input step runs after Core promotes physical binding edges and does not capture pointer input while closed.

# Changelog

## 0.2.0

- Replaces fixed QA battle options with a mouse-interactive F3 overlay.
- Enumerates every loaded Pokémon for wild battle launch, with level and shiny controls.
- Enumerates every loaded trainer party for trainer battle launch.
- Adds an in-battle browser for every loaded move animation, using the live animation player without applying move damage/PP changes.
- Adds a volatile Fly progression override that never writes HM/badge state to the save and resets at game-ready.
- Keeps Insert runtime-state logging.

## 0.1.0

- Initial standalone KRS developer battle harness.
