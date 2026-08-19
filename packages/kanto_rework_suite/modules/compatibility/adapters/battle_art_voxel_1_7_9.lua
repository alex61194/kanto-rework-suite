-- BATTLE ART VOXEL FORK 1.7.9 integration adapter.
--
-- The third-party mod remains the sole owner of its settings, callbacks and
-- persistence. KRS only removes its duplicate rows from the global Options
-- screen, exposes its two engine-owned render pipelines from the Mods tree,
-- releases relative mouse capture while a KRS screen covers the world, and
-- reconnects Gameplay's registered contextual actions to Voxel FreeMove.
return function(deps)
  local voxel=assert(deps.voxel,"BATTLE ART VOXEL FORK handle is required")
  local findMod=assert(deps.findMod,"mod lookup is required")
  local Core=assert(deps.Core,"Kanto Rework Core exports are required")
  local hooks=assert(deps.hooks,"Kanto Rework Compatibility hooks are required")

  local MOD_ID="BATTLE_ART_VOXEL_FORK"
  local PIPELINES={
    {id="voxel",label="VOXEL",description="Cycle the active voxel camera and presentation mode."},
    {id="tiltshift",label="T-SHIFT",description="Cycle the voxel world's tilt-shift post-processing level."},
  }

  local adapter={
    id="battle_art_voxel_fork.1.7.9",
    modId=MOD_ID,
    label="Battle Art Voxel Fork",
    version="1.7.9",
    priority=110,
  }

  function adapter.match(manifest)
    return tostring(manifest.id)==MOD_ID
      and tostring(manifest.name)=="BATTLE ART VOXEL FORK"
      and tostring(manifest.version)=="1.7.9"
  end

  local function optionSchema(game)
    local loader=game and game.mods
    local schemas=loader and loader.optionSchemas
    local rows=schemas and schemas[MOD_ID]
    return type(rows)=="table" and rows or {}
  end

  -- Runs outside the third-party ui.options.rows hook. Its post-processed
  -- result is filtered by stable ownership: the two pipeline ids registered
  -- by this release plus every key in the mod's own live option schema.
  function adapter.filterGlobalOptions(game,rows)
    if type(rows)~="table" then return rows end
    local hidden={
      ["pipeline:voxel"]=true,
      ["pipeline:tiltshift"]=true,
    }
    for _,definition in ipairs(optionSchema(game)) do
      if type(definition)=="table" and type(definition.key)=="string" then
        hidden[definition.key]=true
      end
    end
    local out={}
    for _,row in ipairs(rows) do
      local id=type(row)=="table" and row.id or nil
      if not hidden[id] then out[#out+1]=row end
    end
    return out
  end

  local function renderModeMenu(game)
    local Pipelines=require("src.render.Pipelines")
    local Tilt=require("src.render.Tilt")
    local state={title="BATTLE ART · RENDER MODES",items={}}

    local function labelFor(definition)
      local value=type(Pipelines.levelLabel)=="function"
        and Pipelines.levelLabel(definition.id) or nil
      return definition.label.." · "..tostring(value or "UNAVAILABLE"):upper()
    end

    local function syncLabels()
      for i,definition in ipairs(PIPELINES) do
        state.items[i].label=labelFor(definition)
      end
    end

    local function cycle(definition)
      if type(Pipelines.cycle)~="function" then return false end
      Pipelines.cycle(definition.id,1)
      local options=game and game.save and game.save.options
      if options and type(Pipelines.syncOptions)=="function" then
        Pipelines.syncOptions(options)
        if type(Tilt.setLevel)=="function" then Tilt.setLevel(options.tilt or 0) end
      end
      if game and type(game.writeOptions)=="function" then
        pcall(game.writeOptions,game)
      end
      syncLabels()
      return true
    end

    for i,definition in ipairs(PIPELINES) do
      local owned=definition
      state.items[i]={
        label=labelFor(owned),
        description=owned.description,
        onSelect=function() return cycle(owned) end,
      }
    end
    return state
  end

  function adapter.utilities(game)
    return {{
      id="render_modes",
      label="RENDER MODES",
      group="DISPLAY",
      description="Configure VOXEL and T-SHIFT here. Every other Battle Art setting is listed below from the mod's native schema.",
      open=function() return renderModeMenu(game) end,
    }}
  end

  local function krsCoversWorld(game)
    local dev=findMod("dev_tools")
    local dex=dev and dev.exports
    if dex and type(dex.pointerSurfaceActive)=="function" then
      local ok,value=pcall(dex.pointerSurfaceActive);if ok and value==true then return true end
    end
    local ui=findMod("ui")
    local exports=ui and ui.exports
    local stack=game and game.stack
    local top=stack and type(stack.top)=="function" and stack:top() or nil
    if top==nil then return false end
    if exports and type(exports.krsOwnsPointerSurface)=="function" then
      local ok,owned=pcall(exports.krsOwnsPointerSurface,game,top)
      if ok then return owned==true end
    end
    if not ui or top==game.overworld then return false end
    return true
  end

  local function pointerVisibleForActiveDevice(physicalPointerIntent)
    if physicalPointerIntent==true then return true end
    if type(Core.inputMode)~="function" then return true end
    local ok,snapshot=pcall(Core.inputMode)
    if not ok or type(snapshot)~="table" then return true end
    local device=type(snapshot.activeDevice)=="table" and snapshot.activeDevice.kind or nil
    return snapshot.activeMode=="pointer" or device=="mouse" or device=="keyboard" or device==nil
  end

  local function pointerOwnsCursor(physicalPointerIntent)
    if physicalPointerIntent==true then return true end
    if type(Core.inputMode)~="function" then return false end
    local ok,snapshot=pcall(Core.inputMode)
    if not ok or type(snapshot)~="table" then return false end
    local device=type(snapshot.activeDevice)=="table" and snapshot.activeDevice.kind or nil
    return snapshot.activeMode=="pointer" or device=="mouse"
  end

  local function gameplayFieldMoveStatus()
    local gameplay=findMod("gameplay")
    local exports=gameplay and gameplay.exports
    if not (exports and type(exports.fieldMoveStatus)=="function") then return nil end
    local ok,status=pcall(exports.fieldMoveStatus)
    return ok and type(status)=="table" and status or nil
  end

  local function voxelFreeMoveModules()
    local live=findMod(MOD_ID) or voxel
    local exports=live and live.exports
    local lib=exports and exports.lib
    if not (lib and type(lib.require)=="function") then return nil end
    local okFirst,FirstPerson=pcall(lib.require,"FirstPerson")
    local okMove,FreeMove=pcall(lib.require,"FreeMove")
    if not (okFirst and okMove and type(FirstPerson)=="table" and type(FreeMove)=="table") then
      return nil
    end
    return FirstPerson,FreeMove
  end

  local DIRECTIONS={
    left={-1,0},right={1,0},up={0,-1},down={0,1},
  }

  local function movementDirection(FirstPerson)
    if not (type(FirstPerson.moveVector)=="function"
        and type(FirstPerson.moveWorld)=="function") then return nil end
    local okVector,mx,mz=pcall(FirstPerson.moveVector)
    if not okVector or (mx==0 and mz==0) then return nil end
    local okWorld,wx,wz=pcall(FirstPerson.moveWorld,mx,mz)
    if not okWorld or (wx==0 and wz==0) then return nil end
    if math.abs(wx)>=math.abs(wz) then return wx>=0 and "right" or "left" end
    return wz>=0 and "down" or "up"
  end

  -- FreeMove deliberately replaces the grid-walk branch while 1ST/3RD is
  -- driving. KRS automatic Cut/Surf normally runs immediately before that
  -- grid branch, so it never sees the push. This adapter asks Voxel for its
  -- public camera-relative world vector, confirms through FreeMove's public
  -- collision query that the dominant target cell is actually blocked, then
  -- delegates the action and every progression check to Gameplay's registered
  -- Core field actions. Strength continues through the shared native
  -- checkBoulderPush seam and Flash remains map-entry driven.
  local function tryVoxelContextualFieldMove(game,overworld,FirstPerson,FreeMove)
    local status=gameplayFieldMoveStatus()
    if not (status and status.automatic==true) then return false end
    if not (type(FirstPerson.driving)=="function" and FirstPerson.driving()) then return false end
    local player=overworld and overworld.player
    if not (player and not player.moving and not player.inputLocked
        and type(FreeMove._blockedCell)=="function") then return false end
    local dir=movementDirection(FirstPerson)
    local delta=dir and DIRECTIONS[dir]
    if not delta then return false end
    local tx,ty=player.cellX+delta[1],player.cellY+delta[2]
    local okBlocked,why=pcall(FreeMove._blockedCell,overworld,player,tx,ty)
    if not okBlocked or not why or why=="entity" then return false end

    local previousFacing=player.facing
    player.facing=dir
    local context={game=game,overworld=overworld,automatic=true,
      source="battle_art_voxel_free_move",direction=dir,x=tx,y=ty,
      mapId=overworld.map and overworld.map.id}
    local ok=Core.fieldActions and type(Core.fieldActions.execute)=="function"
      and Core.fieldActions.execute("kanto.cut",context)==true
    if not ok and Core.fieldActions and type(Core.fieldActions.execute)=="function" then
      ok=Core.fieldActions.execute("kanto.surf",context)==true
    end
    if not ok then player.facing=previousFacing end
    return ok==true
  end

  -- DramaticShape 1.7.9 asks for relative mode while the first/third-person
  -- rung is engaged, even when its own driving() gate is false because a menu
  -- covers the overworld. It also keeps a private `captured` flag true after an
  -- external caller releases LOVE relative mode. Its LOVE callbacks therefore
  -- continue swallowing mouse motion and map clicks to GB A/B. The bridge below
  -- leaves the third-party closure untouched: while a KRS pointer surface owns
  -- the screen, it prevents recapture and routes the physical mouse sequence to
  -- Gen1Recomp's public Game pointer seam. Returning to the world restores the
  -- original callback chain on the next event/tick.
  function adapter.installPointerGuard()
    local Pipelines=require("src.render.Pipelines")
    local mouse=love and love.mouse or nil
    local activeGame
    local fieldOriginal,fieldWrapper,fieldOwner

    local function freeCamSelected()
      if type(Pipelines.level)~="function" then return false end
      local ok,level=pcall(Pipelines.level,"voxel")
      return ok and (tonumber(level)==6 or tonumber(level)==7)
    end
    local function releaseCapture(game)
      if not (mouse and freeCamSelected() and krsCoversWorld(game)) then return false end
      if type(mouse.getRelativeMode)=="function" and type(mouse.setRelativeMode)=="function" then
        local ok,relative=pcall(mouse.getRelativeMode)
        if ok and relative==true then pcall(mouse.setRelativeMode,false) end
      end
      if type(mouse.setVisible)=="function" and pointerVisibleForActiveDevice(false) then
        pcall(mouse.setVisible,true)
      end
      return true
    end
    local function ensureFieldMoveBridge()
      if fieldWrapper then return true end
      local FirstPerson,FreeMove=voxelFreeMoveModules()
      if not (FirstPerson and FreeMove) then return false end
      local OverworldState=require("src.world.OverworldController")
      if not (OverworldState and OverworldState.dramaticShapeFreeMoveHook==true
          and type(OverworldState.handleInput)=="function") then return false end
      fieldOwner=OverworldState;fieldOriginal=OverworldState.handleInput
      fieldWrapper=function(self,...)
        if tryVoxelContextualFieldMove(activeGame,self,FirstPerson,FreeMove) then return "field_move" end
        return fieldOriginal(self,...)
      end
      OverworldState.handleInput=fieldWrapper
      return true
    end
    local stepUnregister=hooks:wrap("input.step",function(next,game,dt)
      activeGame=game or activeGame
      releaseCapture(activeGame);ensureFieldMoveBridge()
      
      local result={next(game,dt)}
      activeGame=game or activeGame
      ensureFieldMoveBridge();releaseCapture(activeGame)
      return (table.unpack or unpack)(result)
    end,5000)
    local stopped=false
    return function()
      if stopped then return false end;stopped=true
      if stepUnregister then pcall(stepUnregister);stepUnregister=nil end
      if fieldOwner and fieldOwner.handleInput==fieldWrapper then fieldOwner.handleInput=fieldOriginal end
      
      return true
    end
  end

  adapter.voxel=voxel
  return adapter
end
