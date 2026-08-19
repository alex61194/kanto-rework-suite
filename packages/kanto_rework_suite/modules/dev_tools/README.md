# Kanto Rework Dev Tools 0.2.5

Optional developer/QA companion. Production KRS modules do not depend on it.

## 0.2.5 — Live Editor modal input isolation

- Suspends Dev battle overlay rendering and input ownership while the Live Graphics Editor is the top state.
- Keeps the Dev overlay session intact so it resumes when the editor closes.
- Synchronizes Battle Move Preview immediately with the Mods option event.

## 0.2.4 — Supported mod option declarations

Dev options use the supported toggle type and Battle Move Preview remains independently disableable.

## 0.2.3 — Gen1Recomp 0.1.86 + battle utility controls

- Dev runtime is private to its sandbox and communicates with KRS only through exports.
- `BATTLE MOVE PREVIEW` can be switched ON/OFF from the Dev mod options without disabling the rest of F3.
- In battle, F3 also exposes `ONE-SHOT ENEMY`, which uses the native BattleState damage/faint path so trainer replacement, EXP and victory handling remain engine-owned.

## 0.2.2 — Movable battle animation browser

- The in-battle move-animation browser can be dragged by its header.
- Bottom-right grip resizes it down to a compact 300×220 minimum or back up within the active viewport.
- Header button collapses it to a 58px strip and restores it without closing the Dev overlay.
- Default browser footprint is reduced from near-full-height to a compact 420×560-class panel.

## 0.2.1 — Reliable F3 activation

- Physical F3 can open the overlay even while it is closed.
- The configurable Core binding remains supported without double-toggling on the same key edge.
- A closed Dev overlay never claims pointer ownership, preserving Voxel mouse-look.

## Interactive overlay

`F3` opens the developer overlay. On the overworld it provides:

- Wild battle launcher with every Pokémon present in the loaded game data.
- Level selection from 1 to 100 and explicit shiny on/off.
- Trainer battle launcher covering every loaded trainer class/party.
- Session-only Fly override. It bypasses the HM/badge check for map Fly without changing inventory, badges or save data.

While a battle is active, F3 exposes a compact `ONE-SHOT ENEMY` control. The move-animation browser is shown only when `BATTLE MOVE PREVIEW` is enabled; clicking a move plays its live `AnimPlayer` animation without spending PP, dealing move damage or clearing pending battle damage state.

`Insert` writes the current runtime state summary to the log. The actions are registered through Kanto Rework Core and remain rebindable in Controls.

## Options

- `INTERACTIVE DEV OVERLAY`: enables/disables the F3 developer UI.
- `BATTLE MOVE PREVIEW`: enables/disables the in-battle move-animation browser.

## Scope

Battle launchers require the real overworld to be the top state. Battles are real `BattleState` sessions, so normal battle consequences apply if the user completes them. Fly override is volatile and is reset on each `game.ready`.
