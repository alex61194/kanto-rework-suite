-- Shared physical-input mode resolver.
--
-- One source of truth for active device, interaction mode and active UI item.
-- It deliberately does not infer pointer intent from the current cursor position.
-- A mouse click/wheel is explicit intent; mouse motion after a window-focus regain
-- must produce a second non-zero move before POINTER mode is restored, filtering
-- the one synthetic refresh event emitted by some SDL/Windows focus paths.
return function(deps)
  local runtime=assert(deps.runtime,"runtime is required")
  local inputDevice=assert(deps.inputDevice,"input device service is required")
  local service={}
  local state=runtime.inputModeState or {
    activeMode="navigation", activeScope=nil, activeItems={}, lastPhysicalInput=nil,
    windowFocused=true, ignoreNextMouseMove=false, cursorHidden=false, mouseMoveDistance=0,
  }
  runtime.inputModeState=state

  local function setCursor(visible)
    if not (love and love.mouse and type(love.mouse.setVisible)=="function") then return end
    pcall(love.mouse.setVisible,visible==true)
    state.cursorHidden=not visible
  end

  local function deviceStatus()
    local ok,v=pcall(inputDevice.status,runtime.game)
    if ok and type(v)=="table" then return v end
    return {kind=runtime.lastInput or "keyboard"}
  end

  local function record(kind,source,extra)
    local t={kind=kind,source=source,time=love and love.timer and love.timer.getTime and love.timer.getTime() or 0}
    if type(extra)=="table" then for k,v in pairs(extra) do t[k]=v end end
    state.lastPhysicalInput=t
  end

  function service.observeDevice(kind,joystick)
    if kind~='mouse' then state.mouseMoveDistance=0 end
    if kind=="controller" then
      state.activeMode="navigation"
      record("controller","controller",{name=runtime.controllerName})
      setCursor(false)
    elseif kind=="keyboard" then
      state.activeMode="navigation"
      record("keyboard","keyboard")
      -- A keyboard action changes navigation/footer device, but the OS cursor
      -- remains hidden if a controller hid it. Only real mouse intent restores it.
    elseif kind=="touch" then
      state.activeMode="pointer"
      record("touch","touch")
    elseif kind=="mouse" then
      -- Mouse is promoted only by pointerEvent()/wheel(); input_device may call
      -- this after that promotion, so do not manufacture intent here.
    end
    return service.snapshot()
  end

  local function promotePointer(ev,reason)
    state.activeMode="pointer"
    state.ignoreNextMouseMove=false
    state.mouseMoveDistance=0
    record("mouse",reason or "pointer",{x=ev and ev.x,y=ev and ev.y,dx=ev and ev.dx,dy=ev and ev.dy,button=ev and ev.button})
    inputDevice.observePointer(ev or {source="mouse"})
    setCursor(true)
    return true
  end

  function service.pointerEvent(ev)
    if type(ev)~="table" then return false end
    if ev.source=="touch" then
      state.activeMode="pointer";record("touch",ev.phase or "pointer",{x=ev.x,y=ev.y});inputDevice.observePointer(ev);return true
    end
    if ev.source~="mouse" then return false end
    if state.windowFocused==false then return false end
    if ev.phase=="pressed" then return promotePointer(ev,"pressed") end
    if ev.phase=="moved" then
      local dx,dy=tonumber(ev.dx) or 0,tonumber(ev.dy) or 0
      if dx==0 and dy==0 then return false end
      if state.ignoreNextMouseMove then
        state.ignoreNextMouseMove=false
        state.mouseMoveDistance=0
        return false
      end
      local current=deviceStatus().kind
      if current=='mouse' and state.activeMode=='pointer' then return promotePointer(ev,'moved') end
      -- Small synthetic cursor noise (including stick-induced OS cursor drift)
      -- must not steal the footer/focus mode from a controller. A real mouse
      -- move accumulates quickly and promotes after a deliberate 6 px travel.
      state.mouseMoveDistance=(tonumber(state.mouseMoveDistance) or 0)+math.abs(dx)+math.abs(dy)
      if state.mouseMoveDistance<6 then return false end
      return promotePointer(ev,"moved")
    end
    return false
  end

  function service.wheel(dx,dy)
    if state.windowFocused==false or ((tonumber(dx) or 0)==0 and (tonumber(dy) or 0)==0) then return false end
    return promotePointer({source="mouse",dx=dx,dy=dy},"wheel")
  end

  function service.focus(focused)
    state.windowFocused=focused~=false
    if state.windowFocused then
      -- Preserve controller/keyboard mode and active item. Ignore the first
      -- post-focus mousemoved as a possible SDL/Windows cursor resync.
      state.ignoreNextMouseMove=true
      if state.activeMode=="navigation" and deviceStatus().kind=="controller" then setCursor(false) end
    end
    return service.snapshot()
  end

  function service.setScope(scope)
    if scope~=nil then state.activeScope=tostring(scope) end
    return state.activeScope
  end
  function service.setActiveItem(scope,id)
    scope=tostring(scope or state.activeScope or "global")
    state.activeScope=scope
    if id~=nil then state.activeItems[scope]=tostring(id) end
    return state.activeItems[scope]
  end
  function service.activeItem(scope)
    scope=tostring(scope or state.activeScope or "global")
    return state.activeItems[scope]
  end
  function service.navigation(scope,id)
    state.activeMode="navigation"
    if scope then service.setActiveItem(scope,id or service.activeItem(scope)) end
    local st=deviceStatus(); if st.kind=="controller" then setCursor(false) end
    return service.snapshot(scope)
  end
  function service.pointer(scope,id)
    state.activeMode="pointer"
    if scope then service.setActiveItem(scope,id) end
    setCursor(true)
    return service.snapshot(scope)
  end
  function service.snapshot(scope)
    local d=deviceStatus();scope=scope or state.activeScope
    return {
      activeDevice=d,
      activeMode=state.activeMode,
      activeScope=state.activeScope,
      activeItem=scope and state.activeItems[tostring(scope)] or nil,
      lastPhysicalInput=state.lastPhysicalInput,
      windowFocused=state.windowFocused,
      cursorVisible=not state.cursorHidden,
    }
  end
  function service.isPointer() return state.activeMode=="pointer" end
  function service.isNavigation() return state.activeMode~="pointer" end
  function service.install()
    local st=deviceStatus()
    if st.kind=="controller" then setCursor(false) else setCursor(true) end
    return true
  end
  return service
end
