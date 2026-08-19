-- Presentation-agnostic services shared by Kanto Rework modules.
-- The core owns contracts and dispatch only; it never draws a product UI.
return function(deps)
  local runtime = assert(deps.runtime, "runtime is required")
  local release = tostring(deps.release or "")

  local state = runtime.foundationState or {
    serial = 0,
    screens = {}, overlays = {}, actions = {}, hotspots = {}, inputLayers = {},
    focus = nil, drag = nil, pointerCaptures = {},
  }
  state.screens = state.screens or {}
  state.overlays = state.overlays or {}
  state.actions = state.actions or {}
  state.hotspots = state.hotspots or {}
  state.inputLayers = state.inputLayers or {}
  state.pointerCaptures = state.pointerCaptures or {}
  runtime.foundationState = state

  local api = {}

  local function validId(id)
    return type(id) == "string" and id:match("^[%w_%.%-]+$") ~= nil
  end

  local function register(bucket, definition)
    assert(type(definition) == "table", "definition must be a table")
    assert(validId(definition.id), "definition.id is required")
    state.serial = state.serial + 1
    local token = state.serial
    local copy = {}
    for k, v in pairs(definition) do copy[k] = v end
    copy._token = token
    bucket[copy.id] = copy
    return function()
      local live = bucket[copy.id]
      if live and live._token == token then
        bucket[copy.id] = nil
        return true
      end
      return false
    end
  end

  local function list(bucket)
    local out = {}
    for _, value in pairs(bucket) do out[#out + 1] = value end
    table.sort(out, function(a, b)
      local pa, pb = tonumber(a.priority) or 0, tonumber(b.priority) or 0
      if pa ~= pb then return pa > pb end
      return tostring(a.id) < tostring(b.id)
    end)
    return out
  end

  function api.registerScreen(definition) return register(state.screens, definition) end
  function api.registerOverlay(definition) return register(state.overlays, definition) end
  function api.registerMapHotspot(definition) return register(state.hotspots, definition) end

  -- One ordered input-layer registry is shared by pointer, wheel and future
  -- semantic-input dispatch. A layer must return true to consume an event.
  function api.registerInputLayer(definition)
    assert(type(definition) == "table", "input layer must be a table")
    assert(type(definition.pointer) == "function"
      or type(definition.wheel) == "function"
      or type(definition.keypressed) == "function",
      "input layer requires pointer, wheel or keypressed")
    return register(state.inputLayers, definition)
  end

  local function layerActive(layer, game)
    if type(layer.active) ~= "function" then return true end
    local ok, result = pcall(layer.active, game)
    return ok and result == true
  end

  local function dispatch(method, game, ...)
    for _, layer in ipairs(list(state.inputLayers)) do
      if layerActive(layer, game) and type(layer[method]) == "function" then
        local ok, consumed = pcall(layer[method], game, ...)
        if ok and consumed == true then return true, layer.id end
        if not ok then runtime.lastInputLayerError = tostring(consumed) end
      end
    end
    return false
  end

  local function pointerKey(event)
    if type(event) ~= "table" then return nil end
    return tostring(event.source or "pointer") .. ":" .. tostring(event.id or "default")
  end

  -- Pointer ownership is captured on the physical press. If that press changes
  -- the screen stack, move/release phases stay owned by the original layer and
  -- are swallowed when that layer is no longer active. A single physical click
  -- can therefore never be replayed into the newly pushed screen.
  function api.dispatchPointer(game, event)
    local key = pointerKey(event)
    local captured = key and state.pointerCaptures[key] or nil
    if captured then
      local layer = state.inputLayers[captured]
      if layer and layerActive(layer, game) and type(layer.pointer) == "function" then
        local ok, consumed = pcall(layer.pointer, game, event)
        if not ok then runtime.lastInputLayerError = tostring(consumed) end
      end
      if event.phase == "released" or event.phase == "cancelled" then
        state.pointerCaptures[key] = nil
      end
      return true, captured
    end
    for _, layer in ipairs(list(state.inputLayers)) do
      if layerActive(layer, game) and type(layer.pointer) == "function" then
        local ok, consumed = pcall(layer.pointer, game, event)
        if ok and consumed == true then
          if key and event.phase == "pressed" then state.pointerCaptures[key] = layer.id end
          return true, layer.id
        end
        if not ok then runtime.lastInputLayerError = tostring(consumed) end
      end
    end
    return false
  end
  function api.dispatchWheel(game, dx, dy, x, y)
    return dispatch("wheel", game, dx, dy, x, y)
  end
  function api.dispatchKeypressed(game, key, scancode, isrepeat)
    return dispatch("keypressed", game, key, scancode, isrepeat)
  end

  function api.registerAction(definition, handler)
    if type(definition) == "string" then
      definition = { id = definition, run = handler }
    end
    assert(type(definition) == "table" and type(definition.run) == "function",
      "action requires id and run")
    return register(state.actions, definition)
  end

  function api.runAction(id, ...)
    local action = state.actions[id]
    if not action then return false, "unknown action" end
    local ok, a, b = pcall(action.run, ...)
    if not ok then return false, a end
    if a == nil then a = true end
    return a, b
  end

  function api.setFocus(owner, target)
    state.focus = owner and { owner = owner, target = target } or nil
    return state.focus
  end
  function api.getFocus(owner)
    if not state.focus then return nil end
    if owner ~= nil and state.focus.owner ~= owner then return nil end
    return state.focus.target
  end
  function api.clearFocus(owner)
    if not state.focus or owner == nil or state.focus.owner == owner then
      state.focus = nil
      return true
    end
    return false
  end

  function api.beginDrag(definition)
    assert(type(definition) == "table" and definition.owner,
      "drag requires an owner")
    state.drag = definition
    return definition
  end
  function api.dragState(owner)
    if state.drag and (owner == nil or state.drag.owner == owner) then return state.drag end
    return nil
  end
  function api.endDrag(owner)
    if state.drag and (owner == nil or state.drag.owner == owner) then
      local value = state.drag
      state.drag = nil
      return value
    end
    return nil
  end

  function api.screen(id) return state.screens[id] end
  function api.overlay(id) return state.overlays[id] end
  function api.action(id) return state.actions[id] end
  function api.hotspot(id) return state.hotspots[id] end
  function api.inputLayer(id) return state.inputLayers[id] end
  function api.screens() return list(state.screens) end
  function api.overlays() return list(state.overlays) end
  function api.actions() return list(state.actions) end
  function api.hotspots() return list(state.hotspots) end
  function api.inputLayers() return list(state.inputLayers) end

  function api.capabilities()
    return {
      release = release,
      api = 2,
      visualPresentation = false,
      screens = true,
      overlays = true,
      actions = true,
      focus = true,
      dragDrop = true,
      inputLayers = true,
      pointerDispatch = true,
      pointerSequenceOwnership = true,
      externalPointerIngress = true,
      mapHotspots = true,
      textInput = true,
      nativeGameSave = true,
      elevationProfiles = true,
      logicalInputActions = true,
      fieldActionRegistry = true,
      notifications = true,
      confirmedMoveHistory = true,
      inferredRelearnSet = true,
      interModExports = true,
    }
  end

  function api.snapshot()
    return {
      capabilities = api.capabilities(),
      screens = api.screens(), overlays = api.overlays(),
      actions = api.actions(), hotspots = api.hotspots(),
      inputLayers = api.inputLayers(), focus = state.focus, drag = state.drag,
      lastInputLayerError = runtime.lastInputLayerError,
    }
  end

  return api
end
