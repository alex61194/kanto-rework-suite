# Kanto Rework Core 0.1.41

Presentation-neutral foundation for Kanto Rework modules.

## 0.1.38 — Per-slot metadata isolation

Save/load summaries decode every persisted slot independently and runtime error rows retain their complete owning-mod context.

## 0.1.37 — Gen1Recomp 0.1.86 sandbox baseline

- Requires Gen1Recomp 0.1.86+ and uses only the sandbox-safe mod facades for KRS-owned files/persistence.
- Cross-module communication is explicit through `mod.exports`/`mod.find`; KRS no longer depends on a process-global `_G` bridge.
- Physical pointer delivery uses the engine `input.pointer` seam; custom keyboard/gamepad observation wraps engine Game methods without assigning `love.*` callbacks.
- Restart/resume uses engine checkpoints and namespaced storage. A process restart returns to the launcher; reopening the same game lets Core resume the pending checkpoint from TitleState.

## 0.1.36 — Two-overlay profile and temporary developer Fly gate

- Removes retired generic overlay coordinates from persistent profiles; only Area Catch List and Capture Odds are serialized.
- Keeps passive overlays from claiming mouse ownership and exposes the session-only developer Fly gate without writing HM/badge progression to the save.

## 0.1.35 — Shared physical-pointer ingress

Compatibility adapters can route a captured physical pointer sequence through
the same Core service used by Gen1Recomp's `input.pointer` hook. This keeps
Hover, click capture, overlays, active-device detection and native fallback in
one ordered path.


## 0.1.32 — Shared typography registry

- Registers UI-owned font families without moving visual policy into Core.
- Resolves Regular, Medium, SemiBold, Bold and Black weight fallbacks.
- Caches LÖVE font instances by family, resolved weight and pixel size.

## 0.1.31 — Gen1Recomp 0.1.76 save-slot foundation

- Requires Gen1Recomp 0.1.76.
- Exposes the engine-native save-slot registry through a presentation-neutral API for Kanto UI Save/Load screens.
- Keeps restart/resume, accessibility, input, field-action and compatibility services unchanged.

## 0.1.29 verified restart request

`Restart Now` no longer treats a non-throwing Lua call as proof of restart. It
verifies the real `quit("restart")` request, uses the engine's native routing
state to avoid the launcher, clears stale launcher markers, and applies a
direct official-event fallback if the wrapper emitted nothing.

## 0.1.28 plug-and-play discovery and restart resume

Core now accepts a provenance discovery provider from Compatibility. Standard
third-party Start Menu actions can be attached automatically to their owning
Installed Mods model without storing third-party ids or labels in Core.

`Restart Now` is a save/restart/resume transaction on supported desktop
platforms: save progress, preserve the active game and slot for one relaunch,
then restore that save before gameplay resumes. Unsupported platform paths are
rejected before restart.

## 0.1.27 declarative presentation contracts

Normalized utilities can carry optional presentation intent. Core transports
that metadata without knowing third-party names or choosing a renderer.

## 0.1.26 third-party presentation adapters

Core exposes a generic integration registry that lets Compatibility attach
option metadata and utility models to an installed mod. Core contains no
Ascendant-specific names, settings or callbacks.

## 0.1.25 cooperative Start-menu extensions

Mod-authored rows from the official `ui.start_menu.items` hook are exposed as
external actions with their original callback. Their presence no longer marks
the Kanto presenter unsupported or triggers a vanilla fallback.

## 0.1.24 compatibility foundation

Core now exposes cooperative capability providers, versioned compatibility
diagnostics and a guarded save-and-restart path for the Mods manager. These
services describe ownership and conflicts without patching third-party mods.

## 0.1.23 direct F8 layout and F9 context settings

Expanded overlay headers and resize corners are interactive whenever F8 shows
the layer. F9 no longer unlocks placement: it exposes only Overworld, Battle,
Both and None. Core stores preferred expanded and collapsed geometry; temporary
collision-free tab placement remains a UI rendering concern and never rewrites
the profile.

## 0.1.22 independent collapsed-tab placement

Every overlay now stores its collapsed edge and along-edge position separately
from its expanded geometry. A short pointer activation restores the window; a
drag moves the reduced tab between and along safe-area edges without F9. The
next collapse reuses that stored tab placement.

## 0.1.21 direct collapse access

Expanded overlays can be collapsed through their normal-use header control;
the pointer service no longer requires F9 for that action. The focused overlay
can also be toggled through a configurable logical input action owned by the UI
module.

## 0.1.20 edge collapse

Every widget can persist an expanded or collapsed state. Collapsed widgets are
represented by the UI module as edge tabs; Core keeps their expanded position
and width/height unchanged so restoration is lossless.

## 0.1.19 diagonal resize correction

Corner dragging now resolves the horizontal and vertical deltas together from
the displayed widget rectangle. Both dimensions therefore react during one
diagonal gesture while remaining independently persisted.

## Public architecture services

- shared focus/pointer/input-mode services
- Input Action Registry (`mod.find("kanto_rework_core").exports.inputActions`)
- Field Action Registry (`exports.fieldActions`)
- generic notification/event bus (`exports.notifications`)
- confirmed move history (`confirmedMoves`, `recordConfirmedMove`)
- explicitly separate theoretical relearn set (`inferredRelearnMoves`)
- full-frame color accessibility, trainer/options/mod runtime models, save and video services
- modular overlay visibility, focus, placement, free width/height sizing,
  Overworld/Battle/Both/None context and independent collapsed-tab placement

## 0.1.18 free-aspect contextual overlays

Every widget persists independent `Width` and `Height` factors plus its context
mode. Legacy `Scale` profiles migrate to equal width/height values. `F8` is the
global switch and direct layout surface; since 0.1.23, `F9` is context-only.

Core provides mechanisms only. It does **not** implement Run, Cut, Surf, Strength, Flash, Fly, Dig, Teleport, poison rules or item-use rules. Those belong to `kanto_rework_gameplay`.

## 0.1.16 grouped option metadata

The generic mod runtime preserves optional option `group`/`section` metadata and exposes a validated setter. Product UIs can therefore build nested settings such as `Kanto Rework UI > Overlays` without adding presentation policy to Core.

## 0.1.15 contextual overlay slots

Core manages six independent slots: `player`, `party`, `encounters`, `type_chart`, `capture` and `session`. Persistent placement now covers the contextual overworld/battle widgets, and `F9` move mode is accepted in both contexts. The retired `location` profile fields are ignored safely.

## 0.1.14 modular overlays

Core introduced four independent overlay slots (`player`, `party`, `location`, `session`) with normalized persistent positions.


## 0.1.13 color accessibility

The selected Standard/Protanopia/Deuteranopia/Tritanopia profile now applies after final composition, so every engine color mode, tileset, `trueColor` region, imported battle background and native screen is covered. The same shader is applied to Kanto screen-space HUD layers and mobile touch controls. Standard bypasses the shader.

`COLOR_ACCESSIBILITY_CYCLE` is a normal Input Action Registry entry and appears in Options → Controls. Its defaults are `F7` on keyboard and `R3` (`rightstick`) on controller; either slot can be rebound.

## 0.1.12 input additions
Custom controller actions can capture L2/R2 as axis-backed logical buttons and unmapped DualSense raw buttons such as Touchpad. Custom actions bound to Gen1Recomp non-GB engine hotkeys reserve those inputs, preventing dual side effects such as R1 changing Game Speed.
