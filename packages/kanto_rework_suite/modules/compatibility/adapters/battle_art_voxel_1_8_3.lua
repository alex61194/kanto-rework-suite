-- BATTLE ART VOXEL FORK 1.8.3 integration adapter.
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
    id="battle_art_voxel_fork.1.8.3",
    modId=MOD_ID,
    label="Battle Art Voxel Fork",
    version="1.8.3",
    priority=110,
  }

  function adapter.match(manifest)
    return tostring(manifest.id)==MOD_ID
      and tostring(manifest.name)=="BATTLE ART VOXEL FORK"
      and tostring(manifest.version)=="1.8.3"
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
        -- Voxel ModSetting:row() prefixes global Options row ids with the
        -- owning mod id. 0.3.6 only hid the bare schema key, which is why
        -- 1.8.3 rows leaked back into OPTIONS / OTHER.
        hidden[MOD_ID..":"..definition.key]=true
      end
    end
    local out={}
    for _,row in ipairs(rows) do
      local id=type(row)=="table" and row.id or nil
      if not hidden[id] then out[#out+1]=row end
    end
    return out
  end

  local function pipelineValue(id)
    local Pipelines=require("src.render.Pipelines")
    return type(Pipelines.levelLabel)=="function" and tostring(Pipelines.levelLabel(id)):upper() or "UNAVAILABLE"
  end

  local function adjustPipeline(game,id,dir)
    local Pipelines=require("src.render.Pipelines")
    local Tilt=require("src.render.Tilt")
    if type(Pipelines.cycle)~="function" then return false,"pipeline cycle unavailable" end
    Pipelines.cycle(id,dir or 1)
    local options=game and game.save and game.save.options
    if options and type(Pipelines.syncOptions)=="function" then
      Pipelines.syncOptions(options)
      if type(Tilt.setLevel)=="function" then Tilt.setLevel(options.tilt or 0) end
    end
    if game and type(game.writeOptions)=="function" then
      local ok,err=pcall(game.writeOptions,game)
      if not ok then return false,tostring(err) end
    end
    return true,pipelineValue(id)
  end

  local GROUPS={
    voxelGrid="WORLD RENDERING",worldCurve="WORLD RENDERING",water="WORLD RENDERING",shadows="WORLD RENDERING",
    battles="BATTLE PRESENTATION",hudScale="BATTLE PRESENTATION",spriteLight="BATTLE PRESENTATION",hudColor="BATTLE PRESENTATION",arenaFill="BATTLE PRESENTATION",bossBg="BATTLE PRESENTATION",textboxFill="BATTLE PRESENTATION",
    battleArt="BATTLE ART",trainerArtSet="BATTLE ART",playerArtSet="BATTLE ART",playerAnimatedSet="BATTLE ART",frontAnimatedSet="BATTLE ART",backAnimatedSet="BATTLE ART",duplicateFix="BATTLE ART",playerView="BATTLE ART",frontFlip="BATTLE ART",backPlacement="BATTLE ART",
    daytime="ATMOSPHERE",aa="PERFORMANCE",
  }

  -- The source mod remains the owner of every native option and its
  -- persistence. KRS only groups the normalized rows and adds the two engine
  -- render-pipeline controls inline so Voxel behaves like every other mod in
  -- MODS instead of opening a separate submenu.
  function adapter.decorateOptions(_,rows)
    local out={}
    for _,definition in ipairs(PIPELINES) do
      local id=definition.id
      out[#out+1]={
        id="__pipeline_"..id,key="__pipeline_"..id,label=definition.label,
        description=definition.description,type="choice",group="WORLD RENDERING",
        displayValue=pipelineValue(id),value=pipelineValue(id),
        adjust=function(game,dir) return adjustPipeline(game,id,dir) end,
      }
    end
    for _,row in ipairs(rows or {}) do
      local copy={}
      for k,v in pairs(row) do copy[k]=v end
      if row.id~="__reset" then copy.group=GROUPS[row.id] or row.group or "GENERAL" end
      out[#out+1]=copy
    end
    return out
  end

  function adapter.utilities() return {} end

  -- Public compatibility seam used by KRS Battle. Applying Battle Art is
  -- deliberately independent from who owns the background: WHITE/BLACK KRS
  -- backgrounds must never force Voxel-selected Pokémon or trainer art back
  -- to ROM. No third-party field or setting is changed here.
  --
  -- Voxel normally advances AnimatedBattleArt from OverworldBattle.update.
  -- That update deliberately has no battle session when 3D-BTL is OFF, which
  -- used to leave KRS repeatedly asking for frame 1 with dt=0. Compatibility
  -- becomes the clock owner only while Voxel itself is NOT staging this exact
  -- battle. This preserves the user's ANIMATED/front/back/player selections
  -- without double-stepping a genuine staged battle.
  local animationOwner,animationOriginal,animationWrapper
  local animationClock=setmetatable({},{__mode="k"})

  local function battleArtModules()
    local live=findMod(MOD_ID) or voxel
    local exports=live and live.exports
    local lib=exports and exports.lib
    if not (lib and type(lib.require)=="function") then return nil end
    local okArt,BattleArt=pcall(lib.require,"BattleArt")
    if not (okArt and type(BattleArt)=="table") then return nil end
    local okAnim,Animated=pcall(lib.require,"AnimatedBattleArt")
    local okWorld,OverworldBattle=pcall(lib.require,"OverworldBattle")
    return BattleArt,okAnim and Animated or nil,okWorld and OverworldBattle or nil
  end


  -- Version-locked KRS presentation resolver for Voxel 1.8.3. The public
  -- `mod.exports.lib` namespace intentionally exposes V.require/V.data and
  -- BattleArt.prepareData; Compatibility uses those shipped contracts to
  -- decode the SAME atlas cells selected by Voxel without modifying the mod.
  -- This makes one selected provider usable in Battle, Party, Pokédex and PC.
  local menuFrameCache=setmetatable({},{__mode='k'})
  local dataCache={}
  local function voxelLib()
    local live=findMod(MOD_ID) or voxel
    return live and live.exports and live.exports.lib or nil
  end
  local function dataSet(name)
    if dataCache[name]~=nil then return dataCache[name] or nil end
    local lib=voxelLib();if not (lib and type(lib.data)=='function') then dataCache[name]=false;return nil end
    local ok,value=pcall(lib.data,name);dataCache[name]=ok and type(value)=='table' and value or false
    return dataCache[name] or nil
  end
  local function atlasDef(species,side,generation)
    local source
    if side=='back' then
      if generation=='gen3' then source=dataSet('animated_battle_backs_gen3')
      elseif generation=='gen5' then source=dataSet('animated_battle_sprites_gen5') end
    else
      source=dataSet('animated_battle_sprites_'..tostring(generation))
    end
    local bySpecies=source and source[tostring(species or ''):upper()]
    return bySpecies and bySpecies[side] or nil
  end
  local shinyDefCache=setmetatable({},{__mode='k'})
  local function shinyAtlasDef(def)
    if not (type(def)=='table' and type(def.image)=='string') then return nil end
    local cached=shinyDefCache[def];if cached~=nil then return cached or nil end
    local image=tostring(def.image):gsub('\\','/')
    -- The Voxel fork ships animated Gen5 opponent shinies under
    -- assets/battle/front-animated/gen5/shiny. Reuse the provider's own atlas
    -- geometry/durations and change only the asset leaf, so KRS does not need
    -- to duplicate species aliases, frame cells or timing metadata.
    local prefix=image:match('^(.-front%-animated/gen5/)')
    local base=image:match('([^/]+)$')
    if not (prefix and base) then shinyDefCache[def]=false;return nil end
    local shinyPath=prefix..'shiny/'..base
    if shinyPath==image then shinyDefCache[def]=false;return nil end
    local out={};for k,v in pairs(def) do out[k]=v end;out.image=shinyPath
    shinyDefCache[def]=out;return out
  end

  local function atlasFrames(BattleArt,def)
    if not (def and BattleArt and type(BattleArt.prepareData)=='function') then return nil end
    local mode=type(BattleArt.displayMode)=='function' and BattleArt.displayMode() or 'gbc'
    local perDef=menuFrameCache[def];if not perDef then perDef={};menuFrameCache[def]=perDef end
    if perDef[mode]~=nil then return perDef[mode] or nil end
    local lib=voxelLib();local path=lib and lib.mod and lib.mod.assets and lib.mod.assets:path(def.image)
    local fs=nil -- sandbox: no direct filesystem
    if not (path and fs and type(fs.getInfo)=='function' and fs.getInfo(path)) then perDef[mode]=false;return nil end
    local frames
    local ok=pcall(function()
      local sheet=love.image.newImageData(path);local sw,sh=sheet:getDimensions();local out={}
      local cells=def.cells;local auto=tonumber(def.autoColumns);local count=cells and #cells or auto or tonumber(def.frames)
      if not count or count<1 then return end
      local aw=auto and sw/auto or nil
      if auto and (auto%1~=0 or sw%auto~=0) then return end
      for index=0,count-1 do
        local x,y,w,h
        if cells then local c=cells[index+1];x,y=tonumber(c.x) or 0,tonumber(c.y) or 0;w,h=tonumber(c.width),tonumber(c.height)
        elseif auto then x,y=index*aw,0;w,h=aw,sh
        else w,h=tonumber(def.width),tonumber(def.height);local cols=tonumber(def.columns);if not(w and h and cols) then return end;x=(index%cols)*w;y=math.floor(index/cols)*h end
        if not(w and h) or w<1 or h<1 or x<0 or y<0 or x+w>sw or y+h>sh then return end
        local cell=love.image.newImageData(w,h);cell:paste(sheet,0,0,x,y,w,h)
        local image=BattleArt.prepareData(cell,mode);if not image then return end
        out[#out+1]=image
      end
      if #out==count then
        if def.stableAnchor and type(BattleArt.shareFrameAnchor)=='function' then pcall(BattleArt.shareFrameAnchor,out,#out) end
        frames=out
      end
    end)
    perDef[mode]=(ok and frames) or false
    return perDef[mode] or nil
  end
  local function forcedShinyAtlas(BattleArt,species,side,opts)
    local mon=opts and opts.mon
    if not (side=='front' and type(mon)=='table' and mon.shiny==true) then return nil end
    local setting=BattleArt and BattleArt.frontAnimationSetting
    local generation=type(setting)=='table' and type(setting.get)=='function' and setting:get() or nil
    if generation~='gen5' then return nil end
    local normal=atlasDef(species,'front','gen5');local shiny=shinyAtlasDef(normal)
    local frames=shiny and atlasFrames(BattleArt,shiny) or nil
    if not (frames and frames[1]) then return nil end
    local metric=type(BattleArt.metrics)=='function' and BattleArt.metrics(frames[1]) or nil
    return {image=frames[1],frames=frames,durations=shiny.durations or (normal and normal.durations),
      trueColor=true,source='battle_art_voxel.pokemon_sprites',metrics=metric,loop=true,forcedShiny=true}
  end

  local function isAnimatedGeneration(side,generation)
    if side=='back' then return generation=='gen3' or generation=='gen5' end
    return generation~='gen1'
  end
  function adapter.resolvePokemonArtImage(game,species,side,opts)
    if not species then return nil end
    side=side=='back' and 'back' or 'front';opts=type(opts)=='table' and opts or {}
    local BattleArt=battleArtModules();if not BattleArt then return nil end
    local forcedShiny=forcedShinyAtlas(BattleArt,species,side,opts)
    if forcedShiny then return forcedShiny end
    -- Voxel's PLAYER option is independent from its generation selectors.
    -- KRS mirrors that choice on every surface when Voxel is the selected
    -- pokemon.sprite_art provider. Menus normally request front art; battle
    -- requests the player side with opts.player=true.
    if opts.player==true and side=='back' and type(BattleArt.playerSide)=='function' then
      local ok,value=pcall(BattleArt.playerSide)
      if ok and value=='front' then side='front' end
    end
    local mode=type(BattleArt.setting)=='table' and type(BattleArt.setting.get)=='function' and BattleArt.setting:get() or 'rom'
    if mode=='rom' then return nil end
    local image,frames,durations
    if mode=='static' then
      if type(BattleArt.image)=='function' then local ok,v=pcall(BattleArt.image,species,side);if ok then image=v end end
    else
      local generation=side=='back' and BattleArt.backAnimationSetting:get() or BattleArt.frontAnimationSetting:get()
      if type(BattleArt.prefersModded)=='function' and BattleArt.prefersModded() then
        local fn=side=='back' and BattleArt.generationBackImage or BattleArt.generationFrontImage
        if type(fn)=='function' then local ok,v=pcall(fn,species,generation);if ok then image=v end end
      elseif isAnimatedGeneration(side,generation) then
        local def=atlasDef(species,side,generation);frames=atlasFrames(BattleArt,def);durations=def and def.durations or nil;image=frames and frames[1] or nil
      else
        local fn=side=='back' and BattleArt.generationBackImage or BattleArt.generationFrontImage
        if type(fn)=='function' then local ok,v=pcall(fn,species,generation);if ok then image=v end end
      end
    end
    if not image then return nil end
    local metric=type(BattleArt.metrics)=='function' and BattleArt.metrics(image) or nil
    return {image=image,frames=frames,durations=durations,trueColor=true,source='battle_art_voxel.pokemon_sprites',metrics=metric,loop=true}
  end

  -- Animated sprite atlases are presentational. Gen1Recomp intentionally
  -- multiplies BattleState logic by the selected battle-speed option, so the
  -- dt Voxel receives from OverworldBattle.update may be 2x/5x/10x even though
  -- an authored Gen2-5 atlas should keep its normal playback tempo. Wrap only
  -- Voxel 1.8.3's public AnimatedBattleArt.update entry point and feed the
  -- original implementation real elapsed seconds. KRS never edits Voxel files
  -- or settings, and the wrapper is restored when Compatibility unloads.
  local function ensureRealtimeAnimationClock()
    local _,Animated=battleArtModules()
    if not (type(Animated)=='table' and type(Animated.update)=='function') then return false end
    if animationOwner==Animated and Animated.update==animationWrapper then return true end
    if animationOwner and animationWrapper and animationOriginal
        and animationOwner.update==animationWrapper then
      animationOwner.update=animationOriginal
    end
    animationOwner=Animated
    animationOriginal=Animated.update
    animationClock=setmetatable({},{__mode='k'})
    animationWrapper=function(battle,_logicDt,...)
      local timer=love and love.timer
      local now=timer and type(timer.getTime)=='function' and timer.getTime() or nil
      local previous=battle and animationClock[battle] or nil
      local dt
      if now then
        if battle then animationClock[battle]=now end
        dt=previous and math.max(0,math.min(.1,now-previous)) or 1/60
      elseif timer and type(timer.getDelta)=='function' then
        local ok,value=pcall(timer.getDelta)
        dt=ok and tonumber(value) or nil
        dt=dt and dt>0 and math.min(.1,dt) or 1/60
      else
        dt=1/60
      end
      return animationOriginal(battle,dt,...)
    end
    Animated.update=animationWrapper
    return true
  end

  function adapter.prepareBattleArt(battle,dt,policy)
    if not battle then return false end
    local BattleArt,Animated,OverworldBattle=battleArtModules()
    if not BattleArt then return false end
    local ownPokemon=not(type(policy)=="table" and policy.pokemonSprites==false)
    if ownPokemon then
      if type(BattleArt.apply)=="function" then pcall(BattleArt.apply,battle) end
    else
      -- Explicit KRS provider ownership wins only on KRS presentation surfaces.
      -- Restore Voxel species overrides without touching any Voxel option.
      if type(Animated)=="table" and type(Animated.finish)=="function" then pcall(Animated.finish,battle) end
      if type(BattleArt.releaseSpeciesOverrides)=="function" then pcall(BattleArt.releaseSpeciesOverrides,battle) end
    end

    local voxelOwnsClock=false
    if type(OverworldBattle)=="table" and type(OverworldBattle.battle)=="function" then
      local ok,active=pcall(OverworldBattle.battle)
      voxelOwnsClock=ok and active==battle
    end
    if ownPokemon then
      ensureRealtimeAnimationClock()
      if not voxelOwnsClock and type(Animated)=="table" and type(Animated.update)=="function" then
        pcall(Animated.update,battle,0)
      end
    end
    if type(BattleArt.applyTrainers)=="function" then pcall(BattleArt.applyTrainers,battle) end
    return true
  end

  -- BattleArt exposes authored-cell and opaque-bound metrics for every decoded
  -- external sprite. KRS reads the stable authored w/h for scale and the shared
  -- center/y1 anchors for placement, so animation frames cannot visually pump
  -- as their opaque silhouette changes. Nothing is written to Voxel.
  function adapter.battleArtMetrics(image)
    if not image then return nil end
    local BattleArt=battleArtModules()
    if not (BattleArt and type(BattleArt.metrics)=="function") then return nil end
    local ok,value=pcall(BattleArt.metrics,image)
    if not (ok and type(value)=="table") then return nil end
    return {x0=value.x0,x1=value.x1,y0=value.y0,y1=value.y1,w=value.w,h=value.h,
      center=value.center,padBottom=value.padBottom,staticFront=value.staticFront}
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

  -- DramaticShape 1.8.3 asks for relative mode while the first/third-person
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
      ensureRealtimeAnimationClock()
      local result={next(game,dt)}
      activeGame=game or activeGame
      ensureFieldMoveBridge();ensureRealtimeAnimationClock();releaseCapture(activeGame)
      return (table.unpack or unpack)(result)
    end,5000)
    local stopped=false
    return function()
      if stopped then return false end;stopped=true
      if stepUnregister then pcall(stepUnregister);stepUnregister=nil end
      if fieldOwner and fieldOwner.handleInput==fieldWrapper then fieldOwner.handleInput=fieldOriginal end
      if animationOwner and animationWrapper and animationOriginal and animationOwner.update==animationWrapper then animationOwner.update=animationOriginal end
      animationOwner,animationOriginal,animationWrapper=nil,nil,nil
      animationClock=setmetatable({},{__mode='k'})
      return true
    end
  end

  adapter.voxel=voxel
  return adapter
end
