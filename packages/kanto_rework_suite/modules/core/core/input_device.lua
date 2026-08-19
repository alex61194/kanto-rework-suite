-- Presentation-agnostic active-input and binding service.
-- Core records the physical source; product UIs decide how to draw labels/glyphs.
return function(deps)
  local runtime=assert(deps.runtime,"runtime is required")
  local service={}
  local PATCH_KEY="__KANTO_REWORK_INPUT_DEVICE_V1"

  -- Authoritative active-device state.  runtime.lastInput is kept only as a
  -- compatibility mirror because older Core adapters still read/write it.
  -- Presentation must never derive its device from that legacy field: one
  -- adapter using the historical name "gamepad" must not turn a controller
  -- footer back into KEYBOARD + MOUSE.
  local state=runtime.inputDeviceState or {}
  runtime.inputDeviceState=state
  state.physicalListeners=state.physicalListeners or {}
  state.padDown=state.padDown or {}
  state.physicalPressQueue=state.physicalPressQueue or {key={},pad={}}
  state.physicalPressed=state.physicalPressed or {key={},pad={}}

  local function canonicalKind(kind)
    kind=tostring(kind or "keyboard"):lower()
    if kind=="controller" or kind=="gamepad" or kind=="joystick" or kind=="pad" then return "controller" end
    if kind=="touch" then return "touch" end
    if kind=="mouse" then return "mouse" end
    return "keyboard"
  end

  if not state.activeKind then state.activeKind=canonicalKind(runtime.lastInput) end

  local KEY_DEFAULT={up="up",down="down",left="left",right="right",a="z",b="x",start="escape",select="tab"}
  local PAD_DEFAULT={up="dpup",down="dpdown",left="dpleft",right="dpright",a="a",b="b",start="start",select="back"}

  local function controllerName(joystick)
    if joystick and joystick.getName then
      local ok,name=pcall(joystick.getName,joystick)
      if ok and type(name)=="string" and name~="" then return name end
    end
    return runtime.controllerName
  end

  local function controllerGuid(joystick)
    if joystick and joystick.getGUID then
      local ok,guid=pcall(joystick.getGUID,joystick)
      if ok and type(guid)=="string" and guid~="" then return guid:lower() end
    end
    return runtime.controllerGuid
  end
  local function family(name,guid)
    local n=tostring(name or ""):lower();local g=tostring(guid or ""):lower()
    -- SDL GUID vendor 0x054c (Sony) appears little-endian as 4c05.
    if g:find("4c05",1,true) or n:find("dualsense",1,true) or n:find("dualshock",1,true) or n:find("playstation",1,true) or n:find("ps5",1,true) or n:find("ps4",1,true) or n:find("sony",1,true) or n=="wireless controller" then return "playstation" end
    if n:find("xbox",1,true) or n:find("xinput",1,true) then return "xbox" end
    if n:find("nintendo",1,true) or n:find("switch",1,true) or n:find("joy%-con") then return "nintendo" end
    return "generic"
  end
  local function model(name,guid)
    local n=tostring(name or ""):lower();local g=tostring(guid or ""):lower()
    -- DualSense USB/Bluetooth product 0x0ce6 is e60c in SDL's GUID bytes.
    if n:find("dualsense",1,true) or n:find("ps5",1,true) or (g:find("4c05",1,true) and g:find("e60c",1,true)) then return "dualsense" end
    return nil
  end

  local function set(kind,joystick)
    kind=canonicalKind(kind)
    state.activeKind=kind
    -- Compatibility mirror only.  All new consumers read state.activeKind.
    runtime.lastInput=kind
    if kind=="controller" then
      local name=controllerName(joystick);local guid=controllerGuid(joystick)
      if name then runtime.controllerName=name end;if guid then runtime.controllerGuid=guid end
      runtime.controllerFamily=family(runtime.controllerName,runtime.controllerGuid)
      runtime.controllerModel=model(runtime.controllerName,runtime.controllerGuid)
    end
    if runtime.inputMode and type(runtime.inputMode.observeDevice)=="function" then
      runtime.inputMode.observeDevice(kind,joystick)
    end
  end

  local function emitPhysical(event)
    if type(event)~="table" then return false end
    if event.phase=='pressed' and (event.slot=='key' or event.slot=='pad') and event.code~=nil then
      state.physicalPressQueue[event.slot][tostring(event.code)]=true
    end
    local consumed=false
    for _,callback in pairs(state.physicalListeners) do
      local ok,result=pcall(callback,event)
      if ok and result==true then consumed=true end
    end
    return consumed
  end
  local function emitPadButton(phase,code,joystick,extra)
    code=tostring(code or "")
    if code=="" then return false end
    if phase=="pressed" then
      if state.padDown[code] then return false end
      state.padDown[code]=true
    elseif phase=="released" then
      if not state.padDown[code] then return false end
      state.padDown[code]=nil
    end
    local event={phase=phase,kind="controller",slot="pad",code=code,source="pad:"..code,joystick=joystick}
    for k,v in pairs(extra or {}) do event[k]=v end
    return emitPhysical(event)
  end
  function service.onPhysical(id,callback)
    assert(type(id)=="string" and id~="","physical listener id is required")
    assert(type(callback)=="function","physical listener callback is required")
    state.physicalListeners[id]=callback
    return function()
      if state.physicalListeners[id]==callback then state.physicalListeners[id]=nil;return true end
      return false
    end
  end

  function service.step()
    state.physicalPressed=state.physicalPressQueue
    state.physicalPressQueue={key={},pad={}}
    return true
  end
  function service.wasNativeActionPressed(game,action)
    local kind=canonicalKind(state.activeKind)
    local slot=kind=='controller' and 'pad' or 'key'
    local code=service.binding(game,action,kind)
    return code~=nil and state.physicalPressed[slot][tostring(code)]==true
  end

  function service.observeKeyboard() set("keyboard") end
  function service.observePointer(ev)
    if not ev then return end
    set(ev.source=="touch" and "touch" or "mouse")
  end
  function service.observeGamepad(joystick) set("controller",joystick) end
  function service.observeJoystick(joystick)
    if joystick and joystick.isGamepad then
      local ok,isPad=pcall(joystick.isGamepad,joystick)
      if ok and isPad then return end
    end
    set("controller",joystick)
  end
  function service.observeAxis(joystick,value)
    if math.abs(tonumber(value) or 0)>0.5 then service.observeGamepad(joystick) end
  end
  function service.observeHat(joystick,direction)
    if direction and direction~="c" then service.observeJoystick(joystick) end
  end

  -- LÖVE 11.5 exposes L2/R2 as gamepad axes, not GamepadButton values.
  -- Convert them to button-like physical edges for the logical action
  -- registry. Hysteresis prevents analog noise from repeatedly arming a
  -- capture or toggling an action around the threshold.
  state.triggerActive=state.triggerActive or {}
  local TRIGGER_ON,TRIGGER_OFF=.55,.35
  local function triggerCode(axis)
    if axis=="triggerleft" then return "lefttrigger" end
    if axis=="triggerright" then return "righttrigger" end
  end
  local function triggerKey(joystick,axis) return tostring(joystick or "default")..":"..tostring(axis) end
  function service.observeGamepadAxis(joystick,axis,value)
    service.observeAxis(joystick,value)
    local code=triggerCode(axis);if not code then return false end
    local v=tonumber(value) or 0;local key=triggerKey(joystick,axis);local down=state.triggerActive[key]==true
    if not down and v>=TRIGGER_ON then
      state.triggerActive[key]=true
      service.observeGamepad(joystick)
      return emitPadButton("pressed",code,joystick,{axis=axis,value=v})
    elseif down and v<=TRIGGER_OFF then
      state.triggerActive[key]=nil
      service.observeGamepadRelease(joystick)
      return emitPadButton("released",code,joystick,{axis=axis,value=v})
    end
    return false
  end

  -- LÖVE 11.5's standardized GamepadButton set predates SDL's PS5
  -- touchpad/misc buttons. Recognized gamepads still emit raw joystick button
  -- events as well, but most are duplicates of gamepadpressed. Use the SDL
  -- mapping to discard mapped duplicates and expose only truly extra raw
  -- buttons (notably DualSense Touchpad).
  local STD_PAD_BUTTONS={"a","b","x","y","back","guide","start","leftstick","rightstick","leftshoulder","rightshoulder","dpup","dpdown","dpleft","dpright"}
  local function mappedRawButton(joystick,index)
    if not (joystick and joystick.getGamepadMapping) then return nil end
    for _,name in ipairs(STD_PAD_BUTTONS) do
      local ok,inputType,inputIndex=pcall(joystick.getGamepadMapping,joystick,name)
      if ok and inputType=="button" and tonumber(inputIndex)==tonumber(index) then return name end
    end
    return nil
  end
  local function mappingButtonName(joystick,index)
    if not (joystick and joystick.getGamepadMappingString) then return nil end
    local ok,mapping=pcall(joystick.getGamepadMappingString,joystick)
    if not ok or type(mapping)~="string" then return nil end
    local names={}
    for _,name in ipairs(STD_PAD_BUTTONS) do names[#names+1]=name end
    for _,name in ipairs({"touchpad","misc1","paddle1","paddle2","paddle3","paddle4"}) do names[#names+1]=name end
    for _,name in ipairs(names) do
      local zero=mapping:match("[, ]"..name..":b(%d+)") or mapping:match("^"..name..":b(%d+)")
      if zero and tonumber(zero)+1==tonumber(index) then return name end
    end
    return nil
  end
  function service.rawExtraCode(joystick,index)
    -- Returning a standardized name as well as extra names lets the raw SDL
    -- path backstop a missing gamepadpressed event. emitPadButton deduplicates
    -- the normal case where SDL sends both routes for the same physical press.
    return mappedRawButton(joystick,index) or mappingButtonName(joystick,index) or ("joy"..tostring(index))
  end

  -- Releases are not a new device choice. They only canonicalize controller
  -- continuity so a historical `runtime.lastInput = "gamepad"` write from a
  -- legacy adapter cannot leak into presentation between press and next frame.
  function service.observeGamepadRelease(joystick)
    if state.activeKind=="controller" or canonicalKind(runtime.lastInput)=="controller" then
      state.activeKind="controller"
      runtime.lastInput="controller"
      local name=controllerName(joystick);local guid=controllerGuid(joystick)
      if name then runtime.controllerName=name end;if guid then runtime.controllerGuid=guid end
      runtime.controllerFamily=family(runtime.controllerName,runtime.controllerGuid)
      runtime.controllerModel=model(runtime.controllerName,runtime.controllerGuid)
    end
  end
  function service.observeJoystickRelease(joystick)
    service.observeGamepadRelease(joystick)
  end

  local function bindings(game)
    return game and game.save and game.save.options and game.save.options.bindings or {}
  end
  local function custom(game,action)
    local value=bindings(game)[action]
    return value
  end
  local function defaultPad(action)
    local ok,map=pcall(require,"src.core.GamepadMap")
    if ok and type(map)=="table" and type(map.gamepadBindings)=="function" then
      local ok2,t=pcall(map.gamepadBindings)
      if ok2 and type(t)=="table" then
        for button,a in pairs(t) do if a==action then return button end end
      end
    end
    return PAD_DEFAULT[action] or action
  end

  function service.binding(game,action,kind)
    kind=canonicalKind(kind or state.activeKind)
    local value=custom(game,action)
    if kind=="controller" then
      if type(value)=="table" and value.pad then return tostring(value.pad) end
      return defaultPad(action)
    end
    if type(value)=="table" and value.key then return tostring(value.key) end
    if type(value)=="string" then return value end
    return KEY_DEFAULT[action] or action
  end

  function service.status(game)
    local kind=canonicalKind(state.activeKind)
    return {
      kind=kind,
      controllerName=runtime.controllerName,
      controllerFamily=runtime.controllerFamily or family(runtime.controllerName,runtime.controllerGuid),
      controllerGuid=runtime.controllerGuid,controllerModel=runtime.controllerModel,
      bindings={
        up=service.binding(game,"up",kind),down=service.binding(game,"down",kind),
        left=service.binding(game,"left",kind),right=service.binding(game,"right",kind),
        a=service.binding(game,"a",kind),b=service.binding(game,"b",kind),
        start=service.binding(game,"start",kind),select=service.binding(game,"select",kind),
      },
    }
  end

  -- Gen1Recomp 0.1.86 owns the outer LÖVE callbacks.  Mods observe raw
  -- physical input by wrapping the engine Game service, which is allowed by
  -- our engine_internals permission and avoids assigning love.* from the
  -- sandbox.  A consumed KRS hotkey stops before the vanilla Game handler;
  -- ordinary input forwards unchanged.
  local function installGameBridge(methodName,observer,canConsume)
    local ok,Game=pcall(require,"src.core.Game")
    if not ok or type(Game)~="table" or type(Game[methodName])~="function" then return false end
    runtime.inputDeviceGamePatches=runtime.inputDeviceGamePatches or {}
    local patch=runtime.inputDeviceGamePatches[methodName]
    if type(patch)~="table" or patch.target~=Game then
      patch={target=Game,original=Game[methodName],observer=observer}
      runtime.inputDeviceGamePatches[methodName]=patch
      Game[methodName]=function(self,...)
        local live=runtime.inputDeviceGamePatches and runtime.inputDeviceGamePatches[methodName]
        local consumed=false
        if live and type(live.observer)=="function" then
          local obsOk,result=pcall(live.observer,self,...)
          consumed=obsOk and result==true
        end
        if consumed and canConsume then return true end
        if live and type(live.original)=="function" then return live.original(self,...) end
      end
    else
      patch.observer=observer
    end
    return true
  end

  function service.install()
    if state.installed then return true end
    installGameBridge("keypressed",function(_,key,scancode,isrepeat)
      service.observeKeyboard()
      return emitPhysical({phase="pressed",kind="keyboard",slot="key",code=key,
        scancode=scancode,isrepeat=isrepeat==true,source="key:"..tostring(key)})
    end,true)
    installGameBridge("keyreleased",function(_,key,scancode)
      return emitPhysical({phase="released",kind="keyboard",slot="key",code=key,
        scancode=scancode,source="key:"..tostring(key)})
    end,false)
    installGameBridge("gamepadpressed",function(_,joystick,button)
      service.observeGamepad(joystick);return emitPadButton("pressed",button,joystick)
    end,true)
    installGameBridge("gamepadreleased",function(_,joystick,button)
      service.observeGamepadRelease(joystick);return emitPadButton("released",button,joystick)
    end,false)
    installGameBridge("joystickpressed",function(_,joystick,button)
      local isPad=false
      if joystick and joystick.isGamepad then local ok2,v=pcall(joystick.isGamepad,joystick);isPad=ok2 and v==true end
      if isPad then
        service.observeGamepad(joystick)
        local code=service.rawExtraCode(joystick,button)
        return code and emitPadButton("pressed",code,joystick,{rawButton=button}) or false
      end
      service.observeJoystick(joystick)
      return emitPhysical({phase="pressed",kind="controller",slot="pad",code="joy"..tostring(button),
        source="joy:"..tostring(button),joystick=joystick})
    end,true)
    installGameBridge("joystickreleased",function(_,joystick,button)
      local isPad=false
      if joystick and joystick.isGamepad then local ok2,v=pcall(joystick.isGamepad,joystick);isPad=ok2 and v==true end
      if isPad then
        service.observeGamepadRelease(joystick)
        local code=service.rawExtraCode(joystick,button)
        return code and emitPadButton("released",code,joystick,{rawButton=button}) or false
      end
      service.observeJoystickRelease(joystick)
      return emitPhysical({phase="released",kind="controller",slot="pad",code="joy"..tostring(button),
        source="joy:"..tostring(button),joystick=joystick})
    end,false)
    installGameBridge("gamepadaxis",function(_,joystick,axis,value)
      return service.observeGamepadAxis(joystick,axis,value)
    end,false)
    installGameBridge("joystickaxis",function(_,joystick,_,value)
      service.observeAxis(joystick,value);return false
    end,false)
    installGameBridge("joystickhat",function(_,joystick,_,direction)
      service.observeHat(joystick,direction);return false
    end,false)
    state.installed=true
    return true
  end

  return service
end
