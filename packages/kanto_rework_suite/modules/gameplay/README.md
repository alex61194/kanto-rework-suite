# Kanto Rework Gameplay 0.3.11

## 0.3.11 — Battle Bag action boundary

Battle item lists retain item use, pocket switching and back while suppressing sorting and favorites.

## 0.3.10 — Validated Bag header navigation

Bag pockets now follow the validated fullscreen header model: horizontal pocket switching with a vertical item ledger.
## 0.3.9 — Gen1Recomp 0.1.86 sandbox baseline

- Requires Core 0.1.38+ and Gen1Recomp 0.1.86+.
- Gameplay's internal modules load through the sandbox-safe KRS loader; mechanics are unchanged from 0.3.8.

## 0.3.8 — Vertical Bag pocket controller

- The pocket spine now owns UP/DOWN navigation in every Bag context, including battle.
- LEFT/RIGHT no longer cycles pockets; RIGHT/confirm enters the focused pocket and LEFT returns from the item ledger.

## 0.3.7 — Stable package metadata

- Removes the obsolete experimental package tag and requires Core 0.1.36+. Gameplay behavior is otherwise unchanged from 0.3.6.


Gameplay 0.3.0 targets Gen1Recomp 0.1.76 and supplies the functional model required by the rebuilt Kanto Journal menus.

### 0.3.0 additions

- Expanded Pokémon storage target: 20 boxes × 180 Pokémon, preserving existing box arrays and appending new boxes lazily.
- Shop BUY stack limit raised to the KRS 999-item target; SELL consumes the Bag pocket model when pockets are enabled.
- Player PC deposits consume the Bag pocket/sort/favorite model.
- Nine persistent registered-item shortcuts, with `Ctrl+1` … `Ctrl+9` overworld activation. Registrations are written immediately to per-playthrough mod storage and restored after a full game restart.
- Manual Field Actions for Teleport, Dig, Softboiled and Sweet Scent, using native engine semantics where available.
- Run Indoors option added alongside the existing Run On Foot behavior.


### Modern Bag organization

- A new Bag instance opens on the first non-empty canonical pocket, normally
  `Medicine`, rather than following the oldest acquired item into Poké Balls.
- `BAG SORT` opens a chooser for Type/TM Number, Name, Newest First and
  Favorites First. Defaults: `Tab` on keyboard and Back/Select on controller.
- `BAG FAVORITE` toggles the focused item. Defaults: `F` on keyboard and
  Start/Plus on controller.
- Sort mode, favorite markers and acquisition sequence are stored in the mod's
  save namespace. Sorting changes the derived view only; inventory quantities,
  canonical pocket assignment and `save.bagOrder` remain untouched.
- Disabling `BAG POCKETS` restores the native flat list and manual SELECT swap.

## Features

### Run on foot

- Uses the public `movement.speed` hook.
- Default binding: `Left Alt`, registered through Kanto Rework Core.
- Supports `Hold` and `Toggle` modes.
- Changes a normal 16-frame walking step to 12 frames.
- Never accelerates bicycle movement, Surf, an input-locked player, or a step
  without directional input.
- `RUN ON FOOT = OFF` delegates the unmodified duration to the engine.

### Non-lethal field poison

- Applies only to overworld poison on Gen1Recomp 0.1.76.
- A lethal tick floors the Pokémon at exactly 1 HP and clears PSN.
- Keeps the native `Poisoned` sound and removes the overworld dark flash while
  this rule is enabled.
- Non-lethal ticks delegate to the native engine implementation.
- Battle poison is unchanged.
- `NON-LETHAL FIELD POISON = OFF` delegates the complete vanilla behavior,
  including faint, flash, messages and blackout handling.

The poison decision has no public hook in 0.1.75. The module therefore owns one
version-bounded `engine_internals` adapter around
`OverworldState.applyFieldPoison`; it restores the original method when its
architecture is unregistered and does not overwrite a later mod wrapper.

### Repeat item use

- Applies to out-of-battle Bag items that target a party Pokémon, including
  Potion, status cures, Revive, Rare Candy, Ether/Elixer, PP Up, vitamins,
  evolution stones and TM/HM flows.
- After an attempted use, the party target picker stays open while the selected
  item remains in the Bag, allowing immediate reuse on another Pokémon.
- `Cancel` closes the target picker and returns to the Bag.
- Consuming the last unit closes the depleted target context automatically and
  returns to the refreshed Bag.
- Native target screens, HP animation, move selection, teaching/evolution
  sequences, item effects and messages are preserved.
- In-battle item use is unchanged.
- `REPEAT ITEM USE = OFF` restores the complete vanilla close-after-use flow.

Gen1Recomp 0.1.76 has no public hook around the private Bag target-use closure.
The module therefore decorates only `BagMenu.new` and the out-of-battle
`PartyMenu.new` instances created from it. The adapter is version-bounded,
restores both constructors on unregister, and preserves wrappers installed later
by other mods.

### Expanded Bag

- `EXPANDED BAG` is enabled by default.
- The Bag accepts up to 4096 distinct item stacks, which exceeds the complete
  merged Gen 1 catalog and leaves room for mod-added items.
- Every normal item stack is capped at exactly 999.
- Acquisition order, item removal, key-item/HM protections, badges, shops,
  gifts, ground items, rewards and PC withdrawals keep using the engine's
  central `Bag` API.
- Existing saves require no migration; Lua save serialization preserves the
  expanded slot list and three-digit quantities.
- Disabling the option restores the native 20-slot and 99-per-stack checks for
  future acquisitions without destructively truncating an existing save.

This rule does not change the separate Player PC capacity. Exporting a
Gen1Recomp Lua save back to original Game Boy SRAM remains constrained by the
original 20-slot, one-byte inventory format and cannot preserve expanded Bag
data.

### Contextual Field Moves

`CONTEXTUAL FIELD MOVES` defaults to `AUTOMATIC` and supports:

- `CUT`: walk into a valid Cut tree or gym plant; the normal interaction input
  remains a secondary trigger. Tall grass is excluded by default;
- `SURF`: walk into valid water or press the normal interaction input; the same
  contextual path dismounts onto a valid shore while already surfing;
- `STRENGTH`: walk into a real pushable boulder to activate Strength, then
  continue pressing the direction to enter the native boulder-push path;
- `FLASH`: after a dark map has finished loading and the overworld is stable,
  Flash activates automatically.

All four actions:

- require the corresponding HM item in the Bag and the native badge;
- do not require any party Pokémon to learn or equip the move;
- leave party movesets and battle moves unchanged;
- call the native Gen1Recomp checks and world mutations;
- suppress successful HM-use announcements while retaining failure feedback,
  native animation, audio, music and map-state changes;
- remain available through the Pokémon menu;
- expose the same backend through `Core.fieldActions` for the future Prompt and
  manual Field Actions interfaces.

`LAWN MOWER` is an independent option, disabled by default. When enabled, Cut
also removes tall grass automatically. When disabled, tall grass is never
removed by movement or the contextual interaction path, but manual Cut from the
Pokémon menu remains available.

Native interactions have priority. NPCs, signs, hidden objects, scripted
interactions and bookshelves are resolved before contextual Cut or Surf.
Strength only intercepts an actual pushable boulder directly in front of the
player. Flash waits until the overworld is the active state, so it cannot run
inside a warp, map script, battle or menu sequence.

`CONTEXTUAL FIELD MOVES = VANILLA` disables every automatic trigger and restores
the untouched Pokémon-menu flow. Prompt presentation and manual invocation are
reserved for Phases G/H; the registered backend already supports both without a
second implementation.

Gen1Recomp 0.1.76 has no pre-movement Field Move event, and its native Cut/Surf
methods call the learned-move gate internally. The module therefore owns
version-bounded adapters around `OverworldState.handleInput` and
`OverworldState.partyKnows`, plus the existing Strength adapter around
`OverworldState.checkBoulderPush`. Automatic mode changes only contextual
eligibility; Vanilla delegates to the original learned-move behavior. Every
adapter restores the original method on unregister and preserves later
wrappers.

## Dependencies

- Required: `kanto_rework_core >=0.1.12 <0.2.0`
- Optional: `kanto_rework_ui >=0.4.3 <0.5.0`

Fly remains owned by the future Map/Fly phase. Dig and Teleport remain manual
Pokémon-menu actions because they have no unambiguous contextual target.
