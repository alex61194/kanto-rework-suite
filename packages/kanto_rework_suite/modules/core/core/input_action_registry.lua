-- Generic logical-input registry for Kanto Rework modules and third-party mods.
--
-- Gen1Recomp 0.1.75 exposes remapping only for its eight Game Boy buttons.
-- Custom Kanto actions therefore live in this presentation-neutral registry.
-- Bindings are stored as an unknown-but-preserved key in options.lua so they
-- follow the engine's normal global-preference/portable-mode persistence.
return function(deps)
  local runtime=assert(deps.runtime,"runtime is required")
  local inputDevice=assert(deps.inputDevice,"inputDevice is required")
  local service={}

  local OPTIONS_KEY="kantoReworkBindings"
  local state=runtime.inputActionState or {
    serial=0,definitions={},sources={},pressQueue={},releaseQueue={},
    pressed={},released={},capture=nil,pendingBindings={},
  }
  runtime.inputActionState=state

  local function validId(id)
    return type(id)=="string" and id:match("^[A-Z][A-Z0-9_%.%-]*$")~=nil
  end
  local function copy(t) local out={} for k,v in pairs(t or {}) do out[k]=v end return out end
  local function normalizeSlot(slot) return slot=="pad" and "pad" or "key" end

  local function store()
    local game=runtime.game
    local opts=game and game.save and game.save.options
    if opts then
      if type(opts[OPTIONS_KEY])~="table" then opts[OPTIONS_KEY]={} end
      return opts[OPTIONS_KEY],true
    end
    return state.pendingBindings,false
  end
  local function persist()
    local game=runtime.game
    if game and type(game.writeOptions)=="function" then
      local ok,err=pcall(game.writeOptions,game)
      if not ok then return false,err end
    end
    return true
  end
  local function migratePending()
    local game=runtime.game;local opts=game and game.save and game.save.options
    if not opts then return false end
    opts[OPTIONS_KEY]=type(opts[OPTIONS_KEY])=="table" and opts[OPTIONS_KEY] or {}
    for id,b in pairs(state.pendingBindings or {}) do
      if opts[OPTIONS_KEY][id]==nil then opts[OPTIONS_KEY][id]=copy(b) end
    end
    state.pendingBindings={}
    return true
  end
  function service.attachGame(game)
    runtime.game=game or runtime.game
    return migratePending()
  end

  local function sortedDefinitions()
    local out={} for _,d in pairs(state.definitions) do out[#out+1]=d end
    table.sort(out,function(a,b)
      local ga,gb=tostring(a.group or ""),tostring(b.group or "")
      if ga~=gb then return ga<gb end
      local pa,pb=tonumber(a.priority) or 0,tonumber(b.priority) or 0
      if pa~=pb then return pa>pb end
      return tostring(a.id)<tostring(b.id)
    end)
    return out
  end

  local function customBinding(id)
    local bindings=store()
    local b=bindings[id]
    return type(b)=="table" and b or nil
  end
  local function effective(id,slot)
    slot=normalizeSlot(slot)
    local custom=customBinding(id)
    if custom and custom[slot]~=nil then return custom[slot] end
    local def=state.definitions[id]
    return def and def.defaults and def.defaults[slot] or nil
  end

  local function sourceKey(event)
    return (event.slot=="pad" and "pad:" or "key:")..tostring(event.code)
  end
  local function matches(def,event)
    local bound=effective(def.id,event.slot)
    return bound~=nil and tostring(bound)==tostring(event.code)
  end
  local function activeSources(id)
    local s=state.sources[id];if not s then s={};state.sources[id]=s end;return s
  end

  local function handleCapture(event)
    local c=state.capture;if not c then return false end
    if event.slot~=c.slot then return true end
    if c.slot=="key" and event.phase=="pressed" and event.code=="escape" then state.capture=nil;return true end
    if event.phase=="pressed" then
      if c.pending then state.capture=nil;return true end
      c.pending={code=event.code,source=sourceKey(event)};return true
    end
    if event.phase=="released" and c.pending and c.pending.source==sourceKey(event) then
      local id,slot,value,callback=c.id,c.slot,c.pending.code,c.callback
      state.capture=nil
      local ok,reason,detail=service.setBinding(id,slot,value,{swap=true})
      if type(callback)=="function" then pcall(callback,ok,reason,detail) end
      return true
    end
    return true
  end

  -- Gen1Recomp owns a few controller buttons as engine-level display/speed
  -- shortcuts before they ever become GB logical input. If a Kanto action is
  -- explicitly bound to one of those non-GB controls, the custom binding must
  -- reserve it or a single press would both trigger the Kanto action and alter
  -- the whole game's speed/display state. Face A/B and D-pad are deliberately
  -- excluded because they are normal GB controls and require future context
  -- routing rather than unconditional suppression.
  local ENGINE_RESERVED_PAD={
    x=true,y=true,leftshoulder=true,rightshoulder=true,
    lefttrigger=true,righttrigger=true,
  }

  local function onPhysical(event)
    if type(event)~="table" or (event.slot~="key" and event.slot~="pad") then return false end
    -- A capture owns the physical event. This prevents the button being
    -- rebound from also activating an engine hotkey while the capture screen
    -- is waiting for its release.
    if handleCapture(event) then return true end
    local src=sourceKey(event);local matched=false
    for _,def in ipairs(sortedDefinitions()) do
      if matches(def,event) then
        matched=true
        local sources=activeSources(def.id)
        if event.phase=="pressed" then
          if not sources[src] then sources[src]=true;state.pressQueue[def.id]=true end
        elseif event.phase=="released" and sources[src] then
          sources[src]=nil;if next(sources)==nil then state.releaseQueue[def.id]=true end
        end
      end
    end
    return matched and event.slot=="pad" and ENGINE_RESERVED_PAD[tostring(event.code)]==true
  end

  function service.install()
    if state.unregisterPhysical then pcall(state.unregisterPhysical) end
    state.unregisterPhysical=inputDevice.onPhysical("kanto_rework_core.input_actions",onPhysical)
    return true
  end
  function service.register(definition)
    assert(type(definition)=="table","input action definition must be a table")
    assert(validId(definition.id),"input action id must be UPPER_SNAKE_CASE")
    assert(type(definition.label)=="string" and definition.label~="","input action label is required")
    state.serial=state.serial+1;local token=state.serial
    local d=copy(definition);d.defaults=copy(definition.defaults)
    d.source=tostring(definition.source or "unknown");d.group=tostring(definition.group or "KANTO REWORK")
    d.priority=tonumber(definition.priority) or 0;d._token=token;state.definitions[d.id]=d
    return function()
      local live=state.definitions[d.id]
      if live and live._token==token then
        state.definitions[d.id]=nil;state.sources[d.id]=nil
        state.pressQueue[d.id]=nil;state.releaseQueue[d.id]=nil
        state.pressed[d.id]=nil;state.released[d.id]=nil
        return true
      end
      return false
    end
  end

  function service.list()
    local out={}
    for _,d in ipairs(sortedDefinitions()) do
      out[#out+1]={id=d.id,label=d.label,description=d.description,source=d.source,group=d.group,priority=d.priority,
        key=effective(d.id,"key"),pad=effective(d.id,"pad"),defaultKey=d.defaults.key,defaultPad=d.defaults.pad}
    end
    return out
  end
  function service.definition(id)
    local d=state.definitions[id];if not d then return nil end
    return {id=d.id,label=d.label,description=d.description,source=d.source,group=d.group,priority=d.priority,
      key=effective(id,"key"),pad=effective(id,"pad"),defaultKey=d.defaults.key,defaultPad=d.defaults.pad}
  end
  function service.binding(id,slot) return effective(id,slot) end

  local function customConflict(id,slot,value)
    for otherId in pairs(state.definitions) do if otherId~=id and effective(otherId,slot)==value then return otherId end end
  end
  local NATIVE_ACTIONS={"up","down","left","right","a","b","start","select"}
  local function nativeConflict(slot,value)
    local kind=slot=="pad" and "controller" or "keyboard"
    for _,native in ipairs(NATIVE_ACTIONS) do
      if inputDevice.binding(runtime.game,native,kind)==value then return native end
    end
  end
  function service.conflict(id,slot,value)
    slot=normalizeSlot(slot)
    local c=customConflict(id,slot,value);if c then return {kind="custom",action=c} end
    local n=nativeConflict(slot,value);if n then return {kind="native",action=n} end
    return nil
  end
  function service.setBinding(id,slot,value,opts)
    slot=normalizeSlot(slot)
    if not state.definitions[id] then return false,"unknown_action" end
    if value==nil or tostring(value)=="" then return false,"invalid_binding" end
    value=tostring(value)

    -- Kanto actions are contextual, so sharing a physical input with one of
    -- Gen1Recomp's eight GB buttons is legal.  Blocking those overlaps made
    -- almost every face/D-pad button impossible to bind on a controller and
    -- left R1 as one of the only apparently-working choices.  We still report
    -- the native overlap so Controls can surface it, but the binding is stored.
    local custom=customConflict(id,slot,value)
    local native=nativeConflict(slot,value)
    local bindings=store();local previous=effective(id,slot)
    if custom then
      if not (opts and opts.swap) then return false,"binding_conflict",{kind="custom",action=custom} end
      bindings[custom]=type(bindings[custom])=="table" and bindings[custom] or {}
      bindings[custom][slot]=previous
    end
    bindings[id]=type(bindings[id])=="table" and bindings[id] or {};bindings[id][slot]=value
    local ok,err=persist();if not ok then return false,"persist_failed",err end
    if native then return true,"native_binding_overlap",{kind="native",action=native} end
    return true
  end
  function service.clearBinding(id,slot)
    slot=normalizeSlot(slot);if not state.definitions[id] then return false,"unknown_action" end
    local bindings=store();local b=bindings[id]
    if type(b)=="table" then b[slot]=nil;if b.key==nil and b.pad==nil then bindings[id]=nil end end
    local ok,err=persist();if not ok then return false,"persist_failed",err end
    return true
  end
  function service.resetAll()
    local game=runtime.game;local opts=game and game.save and game.save.options
    if opts then opts[OPTIONS_KEY]={} else state.pendingBindings={} end
    local ok,err=persist();if not ok then return false,err end;return true
  end

  function service.beginCapture(id,slot,callback)
    slot=normalizeSlot(slot);if not state.definitions[id] then return false,"unknown_action" end
    state.capture={id=id,slot=slot,pending=nil,callback=callback};return true
  end
  function service.cancelCapture() state.capture=nil;return true end
  function service.captureState()
    local c=state.capture;return c and {id=c.id,slot=c.slot,pending=c.pending and c.pending.code or nil} or nil
  end

  function service.step()
    state.pressed={};state.released={}
    for id in pairs(state.pressQueue) do state.pressed[id]=true end
    for id in pairs(state.releaseQueue) do state.released[id]=true end
    state.pressQueue={};state.releaseQueue={}
  end
  function service.wasPressed(id) return state.pressed[id]==true end
  function service.wasReleased(id) return state.released[id]==true end
  function service.isDown(id) local s=state.sources[id];return s~=nil and next(s)~=nil end
  function service.status()
    local n=0 for _ in pairs(state.definitions) do n=n+1 end
    return {version=1,actions=n,capture=service.captureState(),persistence="options."..OPTIONS_KEY}
  end

  service.install()
  return service
end
