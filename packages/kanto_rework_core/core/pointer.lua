local function createPointer(deps)
  local mod = assert(deps.mod)
  local runtime = assert(deps.runtime)
  local presenter = assert(deps.presenter)
  local Layout = assert(deps.Layout)
  local persist = assert(deps.persist)

  local createNNative = deps.createNative
  local native = createNNative and createNNative(deps) or (deps.native)

  local Pointer = {}
  runtime.pointer = Pointer
  runtime.pointerSessions = runtime.pointerSessions or {}
  runtime.pointerHookSequence = runtime.pointerHookSequence or 0

  local function game()
    return runtime.game
  end

  local function supportedMenu()
    return presenter.isSupportedStartMenu(game())
  end

  local function hasTopState()
    local state = presenter.topState(game())
    return state ~= nil
  end

  local function updateHover(x, y)
    local region = presenter.hitTest(x, y)
    if region and region.kind == "menu_row" then
      runtime.hoveredItem = region.itemIndex
    else
      runtime.hoveredItem = nil
    end
    return region
  end

  local function selectRow(region, activate)
    local ok, state = supportedMenu()
    if not (ok and state and region and region.kind == "menu_row") then return false end
    state.index = region.itemIndex
    if state.clampScroll then state:clampScroll() end
    if activate then mod.input:tap(game(), "a") end
    return true
  end

  local function beginDrag(region, x, y)
    if not (region and region.kind == "overlay" and runtime.editMode) then return false end
    if runtime.profile.widgetLocked then return false end
    runtime.drag = {
      offsetX = x - region.x,
      offsetY = y - region.y,
      w = region.w,
      h = region.h,
    }
    return true
  end

  local function dragTo(x, y)
    local drag = runtime.drag
    if not drag or not runtime.viewport then return end
    local vpW = tonumber(runtime.viewport.width) or 1920
    local vpH = tonumber(runtime.viewport.height) or 1080

    local targetX = math.max(8, math.min(vpW - drag.w - 8, x - drag.offsetX))
    local targetY = math.max(8, math.min(vpH - drag.h - 8, y - drag.offsetY))

    runtime.profile.widgetX = targetX / vpW
    runtime.profile.widgetY = targetY / vpH
  end

  local function endDrag()
    if runtime.drag then
      runtime.drag = nil
      persist()
    end
  end

  local function pointerId(ev)
    return ev and ev.id or "mouse"
  end

  local function isPrimary(ev)
    return not ev or ev.button == 1 or ev.button == nil
  end

  local function movedTooFar(session, ev)
    local dx = (ev.x or session.x) - session.x
    local dy = (ev.y or session.y) - session.y
    return (dx * dx + dy * dy) > 64 -- 8px tolerance
  end

  local function activatePrimary(x, y)
    local region = presenter.hitTest(x, y)
    if region and region.kind == "menu_row" then
      return selectRow(region, true)
    end
    if region and region.kind == "overlay" then
      return true
    end
    if native and native.activate then
      if native.isOverworld and native.isOverworld() and native.inGameViewport(x, y) then
        mod.input:tap(game(), "a")
        return true
      end
      return native.activate(x, y)
    end
    return false
  end

  function Pointer.handle(currentGame, ev)
    if type(ev) ~= "table" then return false end
    runtime.game = currentGame or runtime.game
    local id = pointerId(ev)
    local phase = ev.phase
    local source = ev.source or "mouse"
    runtime.lastInput = source == "touch" and "touch" or "mouse"

    if phase == "moved" then
      local region = updateHover(ev.x or 0, ev.y or 0)
      local session = runtime.pointerSessions[id]
      if session then
        session.moved = session.moved or movedTooFar(session, ev)
        if session.mode == "overlay" then dragTo(ev.x or 0, ev.y or 0) end
        if session.mode == "primary" and not region and native and native.hover then
          native.hover(ev.x or 0, ev.y or 0)
        end
        return true
      end
      if not region and native and native.hover then native.hover(ev.x or 0, ev.y or 0) end
      return false
    end

    if phase == "cancelled" then
      local session = runtime.pointerSessions[id]
      runtime.pointerSessions[id] = nil
      if session and session.mode == "overlay" then endDrag() end
      return session ~= nil
    end

    if phase == "pressed" then
      local x, y = ev.x or 0, ev.y or 0
      local region = updateHover(x, y)

      if region and region.kind == "overlay" then
        local dragging = isPrimary(ev) and beginDrag(region, x, y)
        runtime.pointerSessions[id] = {
          mode = "overlay", source = source, x = x, y = y,
          dragging = dragging == true,
        }
        return true
      end

      if ev.button == 2 and hasTopState() then
        runtime.pointerSessions[id] = {
          mode = "back", source = source, x = x, y = y,
        }
        return true
      end

      if isPrimary(ev) and (region ~= nil or (native and native.inGameViewport and native.inGameViewport(x, y))) then
        runtime.pointerSessions[id] = {
          mode = "primary", source = source, x = x, y = y,
        }
        if region then
          selectRow(region, false)
        elseif native and native.hover then
          native.hover(x, y)
        end
        return true
      end
      return false
    end

    if phase == "released" then
      local session = runtime.pointerSessions[id]
      runtime.pointerSessions[id] = nil
      if not session then return false end

      if session.mode == "overlay" then
        if session.dragging then endDrag() end
        return true
      end

      if session.mode == "back" then
        mod.input:tap(game(), "b")
        return true
      end

      if session.mode == "primary" then
        if not session.moved and not movedTooFar(session, ev) then
          activatePrimary(ev.x or session.x, ev.y or session.y)
        end
        return true
      end
      return false
    end

    return false
  end

  mod.hooks:wrap("input.pointer", function(next, currentGame, ev)
    runtime.pointerHookSequence = runtime.pointerHookSequence + 1
    if Pointer.handle(currentGame, ev) then return true end
    return next(currentGame, ev)
  end, 120)

  local function installGlobalBridges()
    local global = runtime.global or runtime
    if global.pointerInstalled then return end
    global.pointerInstalled = true
    global.original = global.original or {}

    global.original.mousepressed = love.mousepressed
    love.mousepressed = function(x, y, button, istouch, presses)
      local r = _G.__KANTO_REWORK_CORE_P0 or runtime
      local before = r and r.pointerHookSequence or 0
      local original = r and r.global and r.global.original and r.global.original.mousepressed
      local result
      if original then result = original(x, y, button, istouch, presses) end
      if r and r.pointerHookSequence == before and not istouch
          and r.pointer and r.pointer.handle then
        r.pointer.handle(r.game, {
          phase = "pressed", source = "mouse", id = "mouse",
          x = x, y = y, dx = 0, dy = 0, button = button,
        })
      end
      return result
    end

    global.original.mousereleased = love.mousereleased
    love.mousereleased = function(x, y, button, istouch, presses)
      local r = _G.__KANTO_REWORK_CORE_P0 or runtime
      local before = r and r.pointerHookSequence or 0
      local original = r and r.global and r.global.original and r.global.original.mousereleased
      local result
      if original then result = original(x, y, button, istouch, presses) end
      if r and r.pointerHookSequence == before and not istouch
          and r.pointer and r.pointer.handle then
        r.pointer.handle(r.game, {
          phase = "released", source = "mouse", id = "mouse",
          x = x, y = y, dx = 0, dy = 0, button = button,
        })
      end
      return result
    end

    global.original.mousemoved = love.mousemoved
    love.mousemoved = function(x, y, dx, dy, istouch)
      local r = _G.__KANTO_REWORK_CORE_P0 or runtime
      local before = r and r.pointerHookSequence or 0
      local original = r and r.global and r.global.original and r.global.original.mousemoved
      local result
      if original then result = original(x, y, dx, dy, istouch) end
      if r and r.pointerHookSequence == before and not istouch
          and r.pointer and r.pointer.handle then
        r.pointer.handle(r.game, {
          phase = "moved", source = "mouse", id = "mouse",
          x = x, y = y, dx = dx or 0, dy = dy or 0,
        })
      end
      return result
    end

    global.original.wheelmoved = love.wheelmoved
    love.wheelmoved = function(dx, dy)
      local r = _G.__KANTO_REWORK_CORE_P0 or runtime
      if r and r.handlers and r.handlers.wheelmoved
          and r.handlers.wheelmoved(dx, dy) then
        return
      end
      local original = r and r.global and r.global.original and r.global.original.wheelmoved
      if original then return original(dx, dy) end
    end

    global.original.keypressed = love.keypressed
    love.keypressed = function(key, scancode, isrepeat)
      local r = _G.__KANTO_REWORK_CORE_P0 or runtime
      if r and r.handlers and r.handlers.keypressed
          and r.handlers.keypressed(key, scancode, isrepeat) then
        return
      end
      local original = r and r.global and r.global.original and r.global.original.keypressed
      if original then return original(key, scancode, isrepeat) end
    end

    global.original.gamepadpressed = love.gamepadpressed
    love.gamepadpressed = function(joystick, button)
      local r = _G.__KANTO_REWORK_CORE_P0 or runtime
      if r and r.handlers and r.handlers.gamepadpressed then
        r.handlers.gamepadpressed(joystick, button)
      end
      local original = r and r.global and r.global.original and r.global.original.gamepadpressed
      if original then return original(joystick, button) end
    end
  end

  runtime.handlers = runtime.handlers or {}
  runtime.handlers.wheelmoved = function(_, dy)
    runtime.lastInput = "mouse"
    local x, y = love.mouse.getPosition()
    local region = updateHover(x, y)
    local ok, state = supportedMenu()
    if ok and region and region.kind == "menu_row" and dy ~= 0 then
      local delta = dy > 0 and -1 or 1
      state.index = math.max(1, math.min(#state.items, state.index + delta))
      if state.clampScroll then state:clampScroll() end
      return true
    end
    if region and region.kind == "overlay" then return true end
    if native and native.wheel then return native.wheel(dy) end
    return false
  end

  runtime.handlers.keypressed = function(key)
    runtime.lastInput = "keyboard"
    if key == "f8" then
      runtime.profile.overlayVisible = not runtime.profile.overlayVisible
      persist()
      return true
    end
    if key == "f9" then
      runtime.editMode = not runtime.editMode
      return true
    end
    if key == "escape" and runtime.editMode then
      runtime.editMode = false
      runtime.drag = nil
      return true
    end
    return false
  end

  runtime.handlers.gamepadpressed = function()
    runtime.lastInput = "controller"
  end

  installGlobalBridges()
  return Pointer
end

return createPointer
