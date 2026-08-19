# Kanto Rework Core — Inter-mod API 29

Resolve the Core through the official Gen1Recomp Mod API:

```lua
local handle = mod.find("kanto_rework_core")
local Core = handle and handle.exports
assert(Core and Core.version >= 29)
```

No global `_G.KantoRework` contract is required.

## Capabilities and compatibility

Register a provider only for a capability already defined by Core:

```lua
local unregister = Core.compatibility.registerProvider({
  id = "my_mod.bag",
  capability = "bag.organization",
  source = mod.id,
  modId = mod.id,
  label = "My Bag",
  priority = 100,
})
```

`Core.compatibility.resolve(id)` returns the ordered providers and the selected
provider for exclusive capabilities. `setPreference` persists an explicit
choice. Compatibility packages can register versioned policies and diagnostics
through `registerPolicy` and `registerDiagnostic`; Core itself does not patch
third-party implementations.

Defined capability ids in API 29 are `compatibility.registry`, `ui.shell`,
`ui.party`, `bag.organization`, `field.actions`, `move.relearn`, `battle.exp`,
`battle.camera`, `pokemon.menu_icon` and `audio.music`.

## Versioned mod presentation adapters

Compatibility packages can register an adapter through
`Core.modIntegrations.register(adapter)`. An adapter may decorate the generic
installed-mod model, group native option rows, expose utility roots and claim a
parallel Start-menu action once the same action is reachable under Mods.
Product UIs consume the normalized model; third-party callbacks and persistence
remain owned by the source mod.

## Color accessibility

- `Core.activeAccessibilityProfile()` returns `standard`, `protanopia`, `deuteranopia` or `tritanopia`.
- `Core.setAccessibilityProfile(value)` changes and persists one profile.
- `Core.cycleAccessibilityProfile(dir)` cycles the four profiles live.
- `Core.fullFrameColorAccessibility()` reports whether the final-pixel shader is available.

Core registers `COLOR_ACCESSIBILITY_CYCLE` through the logical input registry. Its default bindings are `F7` and controller `rightstick` (`R3`), and both can be rebound through the same Controls UI as any third-party action.

## Logical input actions

```lua
local unregister = Core.inputActions.register({
  id = "MY_ACTION",
  label = "MY ACTION",
  source = mod.id,
  group = "MY MOD",
  defaults = { key = "k", pad = nil },
})
```

Consumers query only the logical action:

```lua
Core.inputActions.wasPressed("MY_ACTION")
Core.inputActions.isDown("MY_ACTION")
Core.inputActions.wasReleased("MY_ACTION")
```

Bindings are global preferences stored under `options.kantoReworkBindings`, an
unknown options key that Gen1Recomp 0.1.75 preserves when rewriting options.lua.
The registry supports keyboard and controller slots, conflict detection, capture,
clear/reset and custom-action swapping. Native GB bindings are never overwritten.

## Captured physical pointers

Versioned compatibility adapters that must coexist with a third-party camera
owning LOVE mouse callbacks can re-enter the canonical KRS pointer pipeline:

```lua
Core.dispatchPointerEvent(game, {
  source = "mouse", id = "mouse", phase = "moved", x = x, y = y,
  dx = dx, dy = dy,
})
```

Use this only for a real physical event that the third-party owner would
otherwise swallow. Do not replay an event that already reached
`input.pointer`.

## Field actions

```lua
local unregister = Core.fieldActions.register({
  id = "my_mod.action",
  label = "MY FIELD ACTION",
  source = mod.id,
  trigger = "manual", -- manual | automatic | both
  priority = 0,
  requirements = function(context)
    return true
  end,
  availability = function(context)
    return false, "Cannot be used here."
  end,
  execute = function(context)
    return true
  end,
  feedback = { message = "ACTION USED" },
})
```

`requirements` represents whether the action is known/owned. `availability`
represents whether the current context permits execution. A known action can
therefore remain visible as `disabled` with a reason.

Core never automatically executes registered field actions. Gameplay/context
modules decide when to evaluate or execute them.

## Modular overlays

- `Core.overlayState()` returns global visibility, `contextMode`, focused widget and positions for `player`, `party`, `encounters`, `type_chart`, `capture` and `session`. `editMode` remains a deprecated compatibility mirror of `contextMode`.
- `Core.setOverlayRegion(id, rect)` publishes the current screen-space hit region for pointer dragging.
- `Core.setOverlayFocus(id)` selects the widget moved by keyboard/controller.
- `Core.visibleOverlayIds()` returns the current pointer-visible overlay ids in draw order for direct layout controllers.
- `Core.setOverlayPosition(id, x, y, save)` writes a normalized position.
- `Core.moveOverlay(id, dx, dy)` moves and persists the expanded widget, or its independent tab placement while collapsed.
- `Core.setOverlayTabPlacement(id, edge, position, save)` persists a collapsed tab on `left`, `right`, `top` or `bottom`, with a normalized along-edge position.
- `Core.setOverlaySize(id, width, height, save)` persists independent width and height factors.
- `Core.setOverlayMode(id, mode, save)` persists `overworld`, `battle`, `both` or `none`.
- `Core.setOverlayCollapsed(id, collapsed, save)` toggles a widget's persisted edge-collapsed state without changing its expanded geometry.
- `Core.toggleFocusedOverlayCollapsed(save)` collapses or restores the last focused currently visible widget, falling back to the topmost visible widget; it returns `false` when the overlay layer is hidden or no widget is available.

Core owns placement and interaction state only. Consumer modules own overlay content, theme rendering and individual availability options.

## Move capability services

- `Core.confirmedMoves(mon, includeActive)` — observed facts only.
- `Core.recordConfirmedMove(mon, moveId, source)` — explicit observation.
- `Core.inferredRelearnMoves(mon)` — theoretical learnset inference only.

The inferred set must never be presented as proof that a Pokémon actually learned
a move in the past.

## Notifications

```lua
Core.notifications.emit({
  source = mod.id,
  kind = "info",
  message = "...",
})
```

Listeners can use `Core.notifications.subscribe(id, callback)` or the engine event
`mod.kanto_rework_core.notification`. Core does not draw notifications.
