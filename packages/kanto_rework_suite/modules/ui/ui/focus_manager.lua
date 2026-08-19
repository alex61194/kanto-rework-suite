-- Kanto UI facade over Core's single InputModeResolver.
-- Screens own domain navigation values; Core owns POINTER/NAVIGATION mode,
-- active device and the active item id used by focus + contextual prompts.
return function(deps)
  local Core=assert(deps.Core,"Core is required")
  local Manager={}

  function Manager.new(owner)
    return {owner=owner or "kanto_rework_ui",pointerTarget=nil}
  end

  local function snapshot(state)
    if type(Core.inputMode)=="function" then
      local ok,v=pcall(Core.inputMode,state.owner)
      if ok and type(v)=="table" then return v end
    end
    return {activeMode="navigation"}
  end

  function Manager.pointerMove(state,target,commit)
    state.pointerTarget=target
    if target~=nil then
      if type(Core.setInputPointer)=="function" then Core.setInputPointer(state.owner,target)
      elseif type(Core.setActiveInputItem)=="function" then Core.setActiveInputItem(state.owner,target) end
      if type(commit)=="function" then commit(target) end
    end
    return target
  end

  function Manager.pointerPress(state,target,commit)
    return Manager.pointerMove(state,target,commit)
  end

  function Manager.navigation(state,target)
    state.pointerTarget=nil
    if target==nil and type(Core.getFocus)=="function" then target=Core.getFocus(state.owner) end
    if type(Core.setInputNavigation)=="function" then Core.setInputNavigation(state.owner,target)
    elseif type(Core.setActiveInputItem)=="function" and target~=nil then Core.setActiveInputItem(state.owner,target) end
    return target
  end

  function Manager.syncDevice(state,logicalTarget)
    local snap=snapshot(state)
    if snap.activeMode~="pointer" then
      state.pointerTarget=nil
      local target=logicalTarget
      if target==nil and type(Core.getFocus)=="function" then target=Core.getFocus(state.owner) end
      if target~=nil and type(Core.setActiveInputItem)=="function" then Core.setActiveInputItem(state.owner,target) end
    end
    return snap.activeMode,snap.activeDevice and snap.activeDevice.kind or nil
  end

  function Manager.active(state,fallback)
    if type(Core.activeInputItem)=="function" then
      local ok,v=pcall(Core.activeInputItem,state.owner)
      if ok and v~=nil then return v end
    end
    return fallback
  end

  function Manager.visual(state,id,logicalTarget,hoverTarget)
    local snap=snapshot(state)
    local active=Manager.active(state,logicalTarget)
    if snap.activeMode=="pointer" then
      local hover=hoverTarget or state.pointerTarget
      if hover~=nil and tostring(hover)==tostring(id) then return "hover" end
      return "default"
    end
    if active~=nil and tostring(active)==tostring(id) then return "focus" end
    return "default"
  end

  function Manager.isPointer(state) return snapshot(state).activeMode=="pointer" end
  function Manager.isNavigation(state) return not Manager.isPointer(state) end
  function Manager.snapshot(state) return snapshot(state) end
  return Manager
end
