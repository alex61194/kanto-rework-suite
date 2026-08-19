-- Releases camera-owned relative mouse capture while an interactive KRS
-- surface covers the world. The active input resolver remains authoritative:
-- controller navigation keeps the cursor hidden until genuine mouse intent.
return function(deps)
  local Core=assert(deps.Core,"Core is required")
  local Layout=assert(deps.Layout,"Layout is required")
  local runtime=assert(deps.runtime,"runtime is required")
  local okDex,DexEntryMenu=pcall(require,'src.ui.DexEntryMenu')
  local Guard={}
  local POINTER_SURFACES={
    krs_title=true,main=true,options=true,mods=true,controls=true,mod_extension=true,
    save_slots=true,krs_pokedex=true,bag_register=true,pc_storage=true,
    field_actions_popup=true,krs_map=true,overlay_context=true,overlay_layout=true,
  }

  local function interactiveOverworldOverlay(game,state)
    if not (game and state==game.overworld and type(Core.overlayState)=="function") then return false end
    local ok,overlay=pcall(Core.overlayState)
    if not (ok and type(overlay)=="table" and overlay.visible==true) then return false end
    -- Passive F8 widgets must not steal Voxel's relative mouse capture. Pointer
    -- ownership begins only when the user explicitly enters context/layout
    -- interaction, so first/third-person camera look keeps working underneath.
    return overlay.contextMode==true or overlay.editMode==true
      or runtime.overlayLayoutMode==true
  end

  local function devPointerSurface()
    local mod=runtime.mod
    local handle=mod and mod.find and mod.find("dev_tools")
    local exports=handle and handle.exports
    if exports and type(exports.pointerSurfaceActive)=="function" then
      local ok,value=pcall(exports.pointerSurfaceActive)
      return ok and value==true
    end
    if exports and type(exports.status)=="function" then
      local ok,value=pcall(exports.status)
      return ok and type(value)=="table" and value.pointerSurfaceActive==true
    end
    return false
  end

  function Guard.owns(game,state)
    if not state or not Layout.isWide(runtime.viewport) then return false end
    if interactiveOverworldOverlay(game,state) or devPointerSurface() then return true end
    -- Wide battle commands are mouse-driven KRS surfaces too. Without this
    -- explicit ownership Voxel can leave relative capture active after the
    -- battle transition, making the battle cursor unavailable.
    if runtime.BattlePresenter and type(runtime.BattlePresenter.handles)=="function" then
      local ok,owned=pcall(runtime.BattlePresenter.handles,game)
      if ok and owned==true then return true end
    end
    if POINTER_SURFACES[state.kind] or state==runtime.state then return true end
    -- Oak's starter preview is a native DexEntryMenu. Voxel's overworld
    -- camera must release relative mouse capture here or mouse/touch-only
    -- players can become trapped after Oak's lab script pushes the entry.
    if okDex and DexEntryMenu and getmetatable(state)==DexEntryMenu then return true end
    if runtime.NativePresenter and type(runtime.NativePresenter.handles)=="function" then
      local ok,handled=pcall(runtime.NativePresenter.handles,game,state)
      if ok and handled==true then return true end
    end
    if runtime.LinkPresenter and type(runtime.LinkPresenter.handles)=="function" then
      local ok,handled=pcall(runtime.LinkPresenter.handles,game,state)
      if ok and handled==true then return true end
    end
    return false
  end

  function Guard.restore(game,state)
    if not Guard.owns(game,state) then return false end
    local mouse=love and love.mouse;if not mouse then return false end
    local releasedRelative=false
    if type(mouse.getRelativeMode)=="function" and type(mouse.setRelativeMode)=="function" then
      local ok,relative=pcall(mouse.getRelativeMode)
      if ok and relative==true then
        local released=pcall(mouse.setRelativeMode,false)
        releasedRelative=released==true
      end
    end
    local snapshot
    if type(Core.inputMode)=="function" then
      local ok,value=pcall(Core.inputMode)
      if ok and type(value)=="table" then snapshot=value end
    end
    local device=snapshot and snapshot.activeDevice
    if type(mouse.setVisible)=="function" and snapshot
        and (snapshot.activeMode=="pointer" or (device and device.kind=="mouse")
          or (releasedRelative and (not device or device.kind~="controller"))) then
      pcall(mouse.setVisible,true)
    end
    return true
  end

  return Guard
end
