## 0.3.18 — Field Action capability recovery

- Prevent optional historical OverworldState adapters from aborting Field Action registration.
- Resolve manual HM/Dig/Teleport/Softboiled/Sweet Scent capability from active moves or permanent KRS Move Memory as applicable.
- Preserve validated automatic HM+badge QoL policy while keeping one shared action backend.

## 0.3.17 — Box healing and Move Memory bridge restore

- Pokémon Center healing now applies the official `Pokemon.heal` routine to stored Pokémon across all KRS boxes, once per native nurse-heal animation.
- Existing recursive current-species + pre-evolution level-up Move Memory migration is preserved; Core 0.1.40 restores the missing persistence bridge it requires.

## 0.3.16 — Release metadata consistency

- Aligns the runtime release constant and manifest at 0.3.16 after the supplied 0.3.15 package still reported 0.3.14 from `main.lua`.
- Makes no gameplay-rule change in this pass.

## 0.3.15
- Move Memory migration now reconstructs level-up moves from the current species and every reachable pre-evolution species up to the Pokémon's current level, matching the requested permanent-memory policy while still excluding TM/HM/tutor/event moves.

## 0.3.14 — Evolved Pokémon Move Memory reconstruction

- Retroactive Move Memory now always reconstructs the current species' own level-1 and level-up moves through the Pokémon's current level, including evolved species.
- Evolution ambiguity is retained as metadata instead of suppressing current-species reconstruction; pre-evolution-only, TM/HM, tutor and event history is never invented.
- Keeps migration idempotent and preserves active moves plus existing remembered PP / PP Ups exactly.

## 0.3.13 — Retroactive Move Memory reconstruction

- Reconstructs provable current-species level-up history for existing Party and PC Pokémon through the active storage provider, including migrated legacy boxes.
- Keeps active moves, existing remembered moves, PP and PP Ups untouched; newly inferred inactive records start at 0 PP and exclude TM/HM/tutor/event sources.
- Treats species with a possible pre-evolution as historically uncertain instead of inventing an evolution timestamp; repeated migrations are idempotent.

## 0.3.12 — Permanent learned moves and PP-preserving swaps

- Full movesets no longer force a move to be forgotten: newly acquired moves are recorded in KRS Move Memory.
- Out-of-battle PP-item targeting can include confirmed inactive moves; battle targeting remains limited to active moves.
- Ether/Max Ether, Elixer/Max Elixer and PP Up preserve the same PP state whether a move is active or remembered.

## 0.3.11 — Battle Bag action boundary

- Detects native battle item-use lists and exposes only item use, pocket switching and back.
- Suppresses sort and favorite actions in battle while preserving the canonical horizontal-pocket/vertical-item navigation contract.

## 0.3.10 — Validated Bag header navigation

- Replaced the legacy vertical pocket-spine input contract with the validated Bag contract: LEFT/RIGHT changes visible pockets; UP/DOWN remains native item navigation.
- Bag opens directly in the item ledger and uses one consistent pocket-navigation policy in overworld and battle.
- Updated status metadata and regression tests for the new contract.

## 0.3.9 — Gen1Recomp 0.1.86 sandbox migration

- Migrates Gameplay's multi-file loader to `mod:read()` + sandbox-bound `load()`.
- Raises the Core dependency to 0.1.37 and the engine baseline to Gen1Recomp 0.1.86.
- Preserves vertical Bag pocket navigation, contextual field actions, 20×180 storage, repeat-item behavior, EXP.ALL summary and low-HP alarm behavior.

## 0.3.8 — Vertical Bag pocket navigation

- Fixed the Gameplay list decorator that intercepted LEFT/RIGHT before the KRS UI controller.
- Pocket focus is now UP/DOWN; RIGHT/confirm opens a pocket; LEFT returns from items to the pocket spine.
- The shared data owner makes the behavior identical in overworld, battle, Shop Sell and PC item flows.

## 0.3.7 — Stable package metadata

- Removes the obsolete experimental package tag after the validated runtime series.
- Raises the internal Core dependency to 0.1.36; gameplay mechanics are unchanged.

## 0.3.6 — Durable registered-item shortcuts

- Persists Ctrl+1..Ctrl+9 registrations immediately through Gen1Recomp per-mod playthrough storage instead of relying only on the next normal game save.
- Reloads the registered slots when a save is adopted/loaded, fixing stale in-memory slots after Continue or a full game restart.
- Migrates existing `registered_items_v1` mod.save assignments into durable storage when available.

## 0.3.4 — Registered-item shortcut execution

- Makes Ctrl+1..Ctrl+9 invoke the registered Bag item's USE action instead of stopping on the native USE/TOSS submenu.
- Accepts both number-row and keypad slot keys.
- Consumes Ctrl+number before Gen1Recomp's bare-number engine hotkeys, while leaving bare 1..9 untouched.
- Keeps the native Bag callback and ItemEffects path as the sole gameplay authority.

## 0.3.3 — Low-HP alarm cap

- Uses Gen1Recomp's public battle.low_health_alarm hook to stop each continuous low-HP warning period after three real seconds.
- Resets the timer when the native alarm turns off, so a later independent danger period can warn again.
- Does not alter HP thresholds, battle logic speed or other audio cues.

## 0.3.2 — Consolidated EXP.ALL battle messaging

- Preserves the exact Gen 1 EXP.ALL split and all engine-owned level-up/move-learning flows.
- Replaces the second pass of per-Pokémon EXP.ALL messages with one `The rest of the team earned XX EXP!` summary.

## 0.3.1

- Makes Run on Foot, Run Indoors, Repeat Item Use, Expanded Bag and Bag Pockets baseline KRS behaviour instead of redundant exposed toggles.
- Keeps Run Mode, Non-Lethal Field Poison, Contextual Field Moves and Lawn Mower configurable.
- Exposes the pocket controller operations required by the Wide KRS Bag without re-enabling the native parallel controller.

## 0.3.0

- Targets Gen1Recomp 0.1.76.
- Adds 20×180 Pokémon storage, Shop 999/pocket integration and Player PC Bag integration.
- Adds registered-item shortcuts and manual Teleport/Dig/Softboiled/Sweet Scent field actions.
- Keeps native callbacks and vanilla fallbacks wherever the KRS Wide UI is not active.

# Changelog

## 0.2.5

- Declares the Kanto Bag and contextual Field Actions as cooperative capability
  providers through Core 0.1.24.
- Unregisters both provider claims with the rest of the gameplay architecture.
- Leaves every existing gameplay option and vanilla fallback unchanged.

## 0.2.4

- Opens every new Bag instance on the first non-empty canonical pocket instead
  of the pocket containing the oldest acquired item.
- Added generation-IX-style sorting by type/TM number, name, newest first and
  favorites first without rewriting the authoritative inventory/order tables.
- Added persistent item favorites and a native four-choice sort menu.
- Added reassignable `BAG SORT` (`Tab` / controller Back) and `BAG FAVORITE`
  (`F` / controller Start) actions.
- Replaced manual SELECT item swapping only while modern pockets are enabled;
  `BAG POCKETS = OFF` retains the exact native flat-list behavior.

## 0.2.3

- Excluded tall grass from automatic Cut by default while preserving automatic
  Cut for trees and Gym plants.
- Added the independent `LAWN MOWER` option, disabled by default, to allow
  automatic tall-grass cutting when explicitly enabled.
- Preserved manual Cut on tall grass from the Pokémon menu regardless of the
  Lawn Mower setting.

## 0.2.2

- Removed every automatic HM-use TextBox from Cut, Surf, Strength and Flash.
- Kept Cut mutation/animation, Surf movement/music, Strength activation and
  Flash lighting/transition while executing them immediately.
- Added eight modern Bag pocket definitions derived from the existing flat
  inventory without changing save serialization.
- Added Left/Right pocket navigation, per-pocket reordering and hidden empty
  pockets in the native Bag.
- Added explicit stock Gen 1 assignments, automatic TM/HM and Berry routing,
  an Other Items fallback for unknown mod items and exported pocket/catalog
  APIs for the future Wide Bag.
- Added `BAG POCKETS` with an exact flat-list fallback.

## 0.2.1

- Fixed contextual HM eligibility: `CUT`, `SURF`, `STRENGTH` and `FLASH` now
  require only the matching HM item in the Bag plus the native badge.
- Removed the incorrect requirement for a party Pokémon to know the move.
- Added automatic Cut/Surf detection on a held movement attempt into the
  target, while retaining A-button interaction as a secondary trigger.
- Added one-shot dark-map observation so Flash also arms when a save boots
  directly into a dark map before `map.entered` is observed.
- Added `EXPANDED BAG`, defaulting to 4096 distinct item stacks and 999 units
  per stack, with an exact option-off fallback to the native 20/99 limits.
- Preserved native Cut/Surf world mutation, text, animation, audio, music and
  transition paths through bounded 0.1.75 adapters.

## 0.2.0

- Added the Phase F backend for contextual `CUT`, `SURF`, `STRENGTH` and
  `FLASH` through the Core Field Action Registry.
- Added `CONTEXTUAL FIELD MOVES` with `AUTOMATIC` and exact `VANILLA` modes.
- Made native NPC, sign, hidden-object, script and bookshelf interactions win
  before automatic Cut/Surf detection.
- Reused the native Cut/Surf eligibility checks, execution paths, messages,
  music, transitions and progression gates.
- Added contextual Surf dismount onto valid shores.
- Added automatic Strength activation only when pushing a real boulder, with a
  0.1.75-bounded `checkBoulderPush` adapter and restoration on unregister.
- Added deferred Flash execution after the dark overworld becomes the active
  stable state.
- Kept Fly for Map/Fly and kept Dig/Teleport as manual Pokémon-menu actions.
- Preserved all Phase E options and behavior.

## 0.1.5

- Added the independently configurable `REPEAT ITEM USE` Phase E flow.
- Kept the party target picker open while a selected Bag item remains.
- Added automatic return to the refreshed Bag after consuming the last unit.
- Preserved Cancel-to-Bag, native item effects, messages, target/move screens,
  HP animation, TM/HM, Rare Candy and evolution sequences.
- Kept all in-battle item behavior unchanged.
- Added a 0.1.75-bounded BagMenu/PartyMenu adapter with an exact option-off
  fallback and constructor restoration on unregister.

## 0.1.4

- Added independent `RUN ON FOOT` and `NON-LETHAL FIELD POISON` toggles.
- Added exact per-feature vanilla fallbacks without requiring the whole mod to
  be disabled.
- Exposed active feature state through `capabilities`, `runStatus` and
  `poisonRuleStatus`.
- Updated the Phase E documentation and retained the 0.1.75-bounded poison
  adapter.

## 0.1.3

- Fixed the real-runtime lethal poison regression: field poison can no longer KO a Pokémon.
- Lethal field poison floors HP at 1 and cures PSN.
- Removed the overworld poison flash/black-square effect while retaining the Poisoned sound.
- Removed the fragile dependency on a cached `game.ready` payload for the poison adapter.

## 0.1.0

- Initial architecture-only module.
- Depends only on Kanto Rework Core.
- Optionally detects Kanto Rework UI.
- Registers the logical `RUN` action with default keyboard binding Left Alt.
- No gameplay mechanics are active yet.
