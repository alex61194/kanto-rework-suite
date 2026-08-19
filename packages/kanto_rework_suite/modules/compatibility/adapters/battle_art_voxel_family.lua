-- BATTLE ART VOXEL FORK contract-family integration adapter.
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
  local LIVE_VERSION=tostring(voxel.version or "unknown")
  local PIPELINES={
    {id="voxel",label="VOXEL",description="Cycle the active voxel camera and presentation mode."},
    {id="tiltshift",label="T-SHIFT",description="Cycle the voxel world's tilt-shift post-processing level."},
  }
  -- KRS Compatibility owns these presentation choices. They are intentionally
  -- separate from Battle Art Voxel's own option schema: no third-party option
  -- or source file is changed. DEFAULT is literal authored-frame x1; only AUTO
  -- derives a per-Pokémon multiplier.
  local UPSCALE_VALUES={"default","x0.5","x2","x3","auto"}
  local UPSCALE_LABELS={default="DEFAULT",["x0.5"]="X0.5",x2="X2",x3="X3",auto="AUTO"}
  local REAL_SIZE_VALUES={"no","yes","auto"}
  local REAL_SIZE_LABELS={no="NO",yes="YES",auto="AUTO"}
  local function presentationBucket(game)
    local options=game and game.save and game.save.options
    if type(options)~="table" then return nil end
    -- Migrate the short-lived 0.4.12 keys without making Voxel itself own them.
    if options.kantoReworkCompatSpriteUpscale==nil then
      options.kantoReworkCompatSpriteUpscale=options.kantoReworkVoxelUpscale or "default"
    end
    if options.kantoReworkCompatPokemonRealSize==nil then
      if options.kantoReworkVoxelPokedexSized==true then
        -- 0.4.12 used a deliberately tempered Pokédex correction, which maps
        -- semantically to the new AUTO policy rather than the stronger YES.
        options.kantoReworkCompatPokemonRealSize="auto"
      elseif options.kantoReworkVoxelPokedexSized==false then
        options.kantoReworkCompatPokemonRealSize="no"
      else
        options.kantoReworkCompatPokemonRealSize="auto"
      end
    end
    local upscale=tostring(options.kantoReworkCompatSpriteUpscale or "default"):lower()
    -- 0.25× was removed from the KRS scale policy. Preserve intent by moving
    -- the short-lived stored value to the nearest still-supported literal rung.
    if upscale=="x0.25" then upscale="x0.5" end
    local valid=false;for _,v in ipairs(UPSCALE_VALUES) do if v==upscale then valid=true break end end
    if not valid then upscale="default" end
    options.kantoReworkCompatSpriteUpscale=upscale
    local real=tostring(options.kantoReworkCompatPokemonRealSize or "auto"):lower()
    valid=false;for _,v in ipairs(REAL_SIZE_VALUES) do if v==real then valid=true break end end
    if not valid then real="auto" end
    options.kantoReworkCompatPokemonRealSize=real
    return options
  end
  local function persistOptions(game)
    if game and type(game.writeOptions)=="function" then
      local ok,err=pcall(game.writeOptions,game);if not ok then return false,tostring(err) end
    end
    return true
  end
  local function upscaleValue(game)
    local options=presentationBucket(game);return options and options.kantoReworkCompatSpriteUpscale or "default"
  end
  local function realSizeValue(game)
    local options=presentationBucket(game);return options and options.kantoReworkCompatPokemonRealSize or "auto"
  end
  local function cycle(values,current,dir)
    local index=1;for i,v in ipairs(values) do if v==current then index=i break end end
    index=((index-1+((tonumber(dir) or 1)<0 and -1 or 1))%#values)+1
    return values[index]
  end
  local function adjustUpscale(game,dir)
    local options=presentationBucket(game);if not options then return false,"options unavailable" end
    options.kantoReworkCompatSpriteUpscale=cycle(UPSCALE_VALUES,upscaleValue(game),dir)
    local ok,err=persistOptions(game);if not ok then return false,err end
    return true,UPSCALE_LABELS[options.kantoReworkCompatSpriteUpscale]
  end
  local function adjustRealSize(game,dir)
    local options=presentationBucket(game);if not options then return false,"options unavailable" end
    options.kantoReworkCompatPokemonRealSize=cycle(REAL_SIZE_VALUES,realSizeValue(game),dir)
    local ok,err=persistOptions(game);if not ok then return false,err end
    return true,REAL_SIZE_LABELS[options.kantoReworkCompatPokemonRealSize]
  end


  local adapter={
    id="battle_art_voxel_fork.family."..LIVE_VERSION:gsub("[^%w]+","_"),
    modId=MOD_ID,
    label="Battle Art Voxel Fork",
    version=LIVE_VERSION,
    priority=110,
  }

  function adapter.match(manifest)
    return manifest~=nil and tostring(manifest.id)==MOD_ID
      and tostring(manifest.version)==LIVE_VERSION
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
    voxelGrid="WORLD RENDERING",worldCurve="WORLD RENDERING",worldFill="WORLD RENDERING",water="WORLD RENDERING",shadows="WORLD RENDERING",
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
        displayValue=function() return pipelineValue(id) end,value=pipelineValue(id),
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

  -- Capabilities are validated independently. A future Voxel release may add
  -- assets/options without invalidating the stable public seams KRS uses. If
  -- one seam disappears, only that domain degrades instead of disabling all
  -- standard option ownership and conflict discovery.
  function adapter.contractStatus()
    local live=findMod(MOD_ID) or voxel
    local exports=live and live.exports
    local lib=exports and exports.lib
    local status={version=LIVE_VERSION,lib=false,battleArt=false,input=false}
    if not (lib and type(lib.require)=="function") then return status end
    status.lib=true
    local BattleArt,Animated,OverworldBattle=battleArtModules()
    status.battleArt=type(BattleArt)=="table"
      and type(BattleArt.apply)=="function"
      and type(BattleArt.applyTrainers)=="function"
      and type(BattleArt.metrics)=="function"
      and type(Animated)=="table" and type(Animated.update)=="function"
      and type(OverworldBattle)=="table" and type(OverworldBattle.battle)=="function"
    local okFirst,FirstPerson=pcall(lib.require,"FirstPerson")
    local okFree,FreeMove=pcall(lib.require,"FreeMove")
    status.input=okFirst and type(FirstPerson)=="table"
      and type(FirstPerson.driving)=="function"
      and type(FirstPerson.moveVector)=="function"
      and type(FirstPerson.moveWorld)=="function"
      and okFree and type(FreeMove)=="table"
      and type(FreeMove._blockedCell)=="function"
    return status
  end

  function adapter.presentationSettings(game)
    local mode=upscaleValue(game)
    local fixed={default=1,["x0.5"]=0.5,x2=2,x3=3}
    return {
      upscale=mode,
      pixelScale=fixed[mode], -- nil only for AUTO
      realSize=realSizeValue(game),
      nativePixels=true,
    }
  end

  -- These rows are consumed by Kanto Rework Compatibility's own MOD card.
  -- They must not appear under Battle Art Voxel Fork itself.
  function adapter.presentationOptionRows()
    return {
      {
        id="__krs_compat_sprite_upscale",key="__krs_compat_sprite_upscale",label="UPSCALE",
        description="Battle Art Voxel sprite scale owned by Kanto Rework Compatibility. DEFAULT is exact authored-frame x1. X0.5/X2/X3 are literal pixel multipliers. AUTO computes a per-Pokémon multiplier. This compatibility API is legacy; Kanto Rework Graphics owns the user-facing scale controls.",
        type="choice",group="VOXEL SPRITE PRESENTATION",
        displayValue=function(game) return UPSCALE_LABELS[upscaleValue(game)] end,
        adjust=function(game,dir) return adjustUpscale(game,dir) end,
      },
      {
        id="__krs_compat_pokemon_real_size",key="__krs_compat_pokemon_real_size",label="POKÉMON REAL SIZE",
        description="Used by UPSCALE=AUTO. NO targets a consistent readable size from each native frame; YES weights canonical Pokédex height more strongly; AUTO uses a gentler Pokédex-aware balance. Player/back sprites receive a small perspective boost because they are closer to the camera.",
        type="choice",group="VOXEL SPRITE PRESENTATION",
        displayValue=function(game) return REAL_SIZE_LABELS[realSizeValue(game)] end,
        adjust=function(game,dir) return adjustRealSize(game,dir) end,
      },
    }
  end

  function adapter.supportsBattleArt()
    return adapter.contractStatus().battleArt==true
  end

  function adapter.supportsInputBridge()
    return adapter.contractStatus().input==true
  end

  -- Exact battle-environment ownership seam. DramaticShape exposes the
  -- BattleState currently staged by its OverworldBattle session; nil means
  -- 3D-BTL is off, arena setup failed, or the session already ended. KRS must
  -- never infer ownership merely from installation, an option value, or the
  -- free-roam voxel pipeline level because staged battles can run independently
  -- from that overworld presentation mode.
  local function battleRendererHealth(OverworldBattle)
    local live=findMod(MOD_ID) or voxel
    local exports=live and live.exports
    local lib=exports and exports.lib
    local status={rendererKnown=false,rendererAvailable=true,shotKnown=false,shotActive=true}
    if lib and type(lib.require)=='function' then
      local ok3d,Voxel3D=pcall(lib.require,'Voxel3D')
      if ok3d and type(Voxel3D)=='table' and type(Voxel3D.available)=='function' then
        status.rendererKnown=true
        local okAvailable,available=pcall(Voxel3D.available)
        status.rendererAvailable=okAvailable and available==true
      end
    end
    -- Newer Voxel families expose the staged shot. A BattleState can remain
    -- attached while arena/renderer setup failed, so battle()==battle is not
    -- sufficient proof that a 3D environment is actually drawable.
    if type(OverworldBattle)=='table' and type(OverworldBattle.shot)=='function' then
      status.shotKnown=true
      local okShot,shot=pcall(OverworldBattle.shot)
      status.shotActive=okShot and shot~=nil and shot~=false
    end
    return status
  end

  function adapter.battleEnvironmentStatus(battle)
    local result={owns=false,reason='no_battle',activeBattle=false,rendererKnown=false,rendererAvailable=true,shotKnown=false,shotActive=true}
    if battle==nil then return result end
    local _,_,OverworldBattle=battleArtModules()
    if not (type(OverworldBattle)=='table' and type(OverworldBattle.battle)=='function') then
      result.reason='battle_seam_unavailable';return result
    end
    local ok,active=pcall(OverworldBattle.battle)
    result.activeBattle=ok and active~=nil and active==battle
    if not result.activeBattle then result.reason='no_staged_battle';return result end
    local health=battleRendererHealth(OverworldBattle)
    for k,v in pairs(health) do result[k]=v end
    if result.rendererKnown and not result.rendererAvailable then
      result.reason='renderer_unavailable';return result
    end
    if result.shotKnown and not result.shotActive then
      result.reason='battle_shot_unavailable';return result
    end
    result.owns=true;result.reason='live_3d_battle'
    return result
  end

  function adapter.ownsBattleEnvironment(battle)
    return adapter.battleEnvironmentStatus(battle).owns==true
  end


  -- Contract-gated KRS presentation resolver for the live Voxel release. The public
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
  local function shinyAtlasDef(species,side,generation,normalDef)
    -- 1.8.6+ ships a first-class generated shiny dataset. Prefer it verbatim
    -- instead of manufacturing a path from the normal atlas: the dataset is
    -- the fork's source of truth for image path, cell geometry and timings.
    local source=dataSet('animated_battle_sprites_'..tostring(generation)..'_shiny')
    local bySpecies=source and source[tostring(species or ''):upper()]
    local direct=bySpecies and bySpecies[side] or nil
    if direct then return direct end
    -- Older compatible family members may have shiny assets but no generated
    -- dataset. Keep a narrow Gen5 path fallback without modifying the fork.
    local def=normalDef
    if not (generation=='gen5' and type(def)=='table' and type(def.image)=='string') then return nil end
    local cached=shinyDefCache[def];if cached~=nil then return cached or nil end
    local image=tostring(def.image):gsub('\\','/')
    local prefix=image:match('^(.-front%-animated/gen5/)')
    local base=image:match('([^/]+)$')
    if not (prefix and base) then shinyDefCache[def]=false;return nil end
    local out={};for k,v in pairs(def) do out[k]=v end;out.image=prefix..'shiny/'..base
    shinyDefCache[def]=out;return out
  end

  local function atlasFrames(BattleArt,def)
    if not (def and BattleArt and type(BattleArt.prepareData)=='function') then return nil end
    local mode=type(BattleArt.displayMode)=='function' and BattleArt.displayMode() or 'gbc'
    local perDef=menuFrameCache[def];if not perDef then perDef={};menuFrameCache[def]=perDef end
    if perDef[mode]~=nil then return perDef[mode] or nil end
    local lib=voxelLib();local path=lib and lib.mod and lib.mod.assets and lib.mod.assets:path(def.image)
    if not path then perDef[mode]=false;return nil end
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
  local function shinyRequested(opts)
    local mon=opts and opts.mon
    local battler=opts and opts.battler
    if type(mon)=='table' and (mon.shiny==true or mon.isShiny==true or mon.__krsForceShiny==true) then return true end
    if type(battler)=='table' and (battler.shiny==true or battler.__krsForceShiny==true
        or type(battler.mon)=='table' and battler.mon.shiny==true) then return true end
    return false
  end
  local function forcedShinyAtlas(BattleArt,species,side,opts)
    if not shinyRequested(opts) then return nil end
    local setting=side=='back' and BattleArt and BattleArt.backAnimationSetting
      or BattleArt and BattleArt.frontAnimationSetting
    local generation=type(setting)=='table' and type(setting.get)=='function' and setting:get() or nil
    if not tostring(generation or ''):match('^gen[2-5]$') then return nil end
    local normal=atlasDef(species,side,generation)
    local shiny=shinyAtlasDef(species,side,generation,normal)
    local frames=shiny and atlasFrames(BattleArt,shiny) or nil
    if not (frames and frames[1]) then return nil end
    local metric=type(BattleArt.metrics)=='function' and BattleArt.metrics(frames[1]) or nil
    return {image=frames[1],frames=frames,durations=shiny.durations or (normal and normal.durations),
      trueColor=true,source='battle_art_voxel.pokemon_sprites',metrics=metric,loop=true,forcedShiny=true,
      shinyDataset='animated_battle_sprites_'..tostring(generation)..'_shiny'}
  end

  local function isAnimatedGeneration(side,generation)
    if side=='back' then return generation=='gen3' or generation=='gen5' end
    return generation~='gen1'
  end
  -- Prefer Voxel's own live BattleArt / AnimatedBattleArt resolver instead of
  -- duplicating its collection rules. 1.8.4 expanded species aliases, shiny
  -- datasets and static-vs-atlas generation routing; the old KRS decoder could
  -- therefore disagree with the mod even though the public Battle Art contract
  -- itself was still intact. A tiny cached preview battle lets Voxel resolve the
  -- exact same selected art it would attach in battle, without editing any
  -- option or touching the real BattleState. This same result feeds every KRS
  -- menu surface and the KRS battle renderer.
  local previewBattles={}
  -- BattleArt.apply builds/attaches the provider sprite state. Calling it from
  -- every KRS render pass restarts animated atlases at frame one. Keep one
  -- application record per live battle and invalidate it only when the active
  -- provider settings or either Pokémon record changes.
  local liveBattleArtState=setmetatable({},{__mode='k'})
  local function shallowCopy(value)
    if type(value)~='table' then return value end
    local out={};for k,v in pairs(value) do out[k]=v end;return out
  end
  local function previewMon(species,mon)
    local out=type(mon)=='table' and shallowCopy(mon) or {}
    out.species=species
    -- Voxel's shiny resolver reads the real party record (not merely species).
    -- Clone the mutable value bags so a presentational preview cannot become a
    -- write path into Gen1Recomp's save state.
    out.dvs=shallowCopy(out.dvs)
    out.ivs=shallowCopy(out.ivs)
    out.stats=shallowCopy(out.stats)
    out.statExp=shallowCopy(out.statExp)
    return out
  end
  local function monFingerprint(mon)
    if type(mon)~='table' then return 'species' end
    local dvs=type(mon.dvs)=='table' and mon.dvs or {}
    return table.concat({tostring(mon),tostring(mon.shiny==true),
      tostring(dvs.attack),tostring(dvs.defense),tostring(dvs.speed),tostring(dvs.special)},':')
  end
  local function settingValue(setting)
    if type(setting)=='table' and type(setting.get)=='function' then
      local ok,value=pcall(setting.get,setting);if ok then return tostring(value) end
    end
    return ''
  end
  local function artFingerprint(BattleArt,side,opts)
    local mode=settingValue(BattleArt and BattleArt.setting)
    local generation=side=='back' and settingValue(BattleArt and BattleArt.backAnimationSetting)
      or settingValue(BattleArt and BattleArt.frontAnimationSetting)
    local playerSide=''
    if opts and opts.player==true and type(BattleArt and BattleArt.playerSide)=='function' then
      local ok,value=pcall(BattleArt.playerSide);if ok then playerSide=tostring(value or '') end
    end
    local display=type(BattleArt and BattleArt.displayMode)=='function' and select(2,pcall(BattleArt.displayMode)) or ''
    local modded=type(BattleArt and BattleArt.prefersModded)=='function' and select(2,pcall(BattleArt.prefersModded)) or false
    return table.concat({mode,generation,playerSide,tostring(display or ''),tostring(modded==true)},':')
  end
  local function previewKey(BattleArt,species,side,opts)
    return table.concat({tostring(species),side,opts and opts.player==true and 'player' or 'species',
      monFingerprint(opts and opts.mon),artFingerprint(BattleArt,side,opts)},'|')
  end
  local function liveResolvedImage(BattleArt,Animated,species,side,opts)
    if not (type(BattleArt)=='table' and type(BattleArt.apply)=='function') then return nil end
    local key=previewKey(BattleArt,species,side,opts)
    local rec=previewBattles[key]
    if not rec then
      local placeholder={__krsVoxelPreview=true}
      local battler={mon=previewMon(species,opts and opts.mon),sprite=placeholder}
      local battle={showEnemyTrainer=false,showPlayerBack=false,demo=false}
      if side=='front' and not(opts and opts.player==true) then battle.enemy=battler
      else battle.player=battler end
      rec={battle=battle,battler=battler,placeholder=placeholder,last=nil}
      previewBattles[key]=rec
      -- Apply exactly once for this visual fingerprint. Re-applying every HUD
      -- draw restarts Voxel's atlas state at frame one, which makes an animated
      -- provider look static in KRS menus/overlays. Animated.update owns the
      -- frame progression after the provider has attached its sprite state.
      local okApply=pcall(BattleArt.apply,rec.battle)
      if not okApply then previewBattles[key]=nil;return nil end
    else
      rec.battler.mon=previewMon(species,opts and opts.mon)
    end
    local timer=love and love.timer
    local now=timer and type(timer.getTime)=='function' and timer.getTime() or nil
    local dt=1/60
    if now then
      if rec.last then dt=math.max(0,math.min(.1,now-rec.last)) end
      rec.last=now
    end
    if type(Animated)=='table' and type(Animated.update)=='function' then
      pcall(Animated.update,rec.battle,dt)
    end
    local image=rec.battler.sprite
    if image==rec.placeholder then return nil end
    return image
  end

  function adapter.resolvePokemonArtImage(game,species,side,opts)
    if not species then return nil end
    side=side=='back' and 'back' or 'front';opts=type(opts)=='table' and opts or {}
    local BattleArt,Animated=battleArtModules();if not BattleArt then return nil end
    -- Voxel's live resolver can key shiny selection from its own DV rules while
    -- Gen1Recomp/KRS can explicitly mark a debug or mod-authored Pokémon shiny.
    -- When those semantics disagree, prefer the fork's shipped shiny Gen5 atlas
    -- for presentation only; battle stats/DVs and the third-party mod stay untouched.
    local forcedShiny=forcedShinyAtlas(BattleArt,species,side,opts)
    if forcedShiny then return forcedShiny end

    -- In an actual KRS battle, Voxel has already attached and advanced the
    -- authoritative live sprite on the real battler through prepareBattleArt.
    -- Re-resolving a separate preview battle here severs that animation state
    -- and can freeze the visible Pokémon on a single atlas frame. Use the live
    -- battler image directly; menus/overlays still use the isolated preview.
    if opts.kind=='battle' and type(opts.battler)=='table' then
      local live=opts.battler.sprite
      if live and not(type(live)=='table' and live.__krsVoxelPreview==true) then
        local metric=nil
        if type(BattleArt.metrics)=='function' then local ok,value=pcall(BattleArt.metrics,live);if ok then metric=value end end
        return {image=live,trueColor=true,source='battle_art_voxel.pokemon_sprites',metrics=metric,loop=true,liveBattle=true}
      end
    end

    local liveImage=(side=='front' or opts.player==true) and liveResolvedImage(BattleArt,Animated,species,side,opts) or nil
    if liveImage then
      local metric=nil
      if type(BattleArt.metrics)=='function' then local ok,value=pcall(BattleArt.metrics,liveImage);if ok then metric=value end end
      return {image=liveImage,trueColor=true,source='battle_art_voxel.pokemon_sprites',metrics=metric,loop=true}
    end
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
  -- the live Voxel public AnimatedBattleArt.update entry point and feed the
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

  local function liveBattleFingerprint(BattleArt,battle)
    local player=battle and battle.player and battle.player.mon
    local enemy=battle and battle.enemy and battle.enemy.mon
    return table.concat({
      artFingerprint(BattleArt,'front',{player=false}),
      artFingerprint(BattleArt,'back',{player=true}),
      monFingerprint(player),monFingerprint(enemy),
      tostring(player and player.species or ''),tostring(enemy and enemy.species or ''),
    },'|')
  end

  function adapter.prepareBattleArt(battle,dt,policy)
    if not battle then return false end
    local BattleArt,Animated,OverworldBattle=battleArtModules()
    if not BattleArt then return false end
    local ownPokemon=not(type(policy)=="table" and policy.pokemonSprites==false)
    local state=liveBattleArtState[battle] or {}
    local fingerprint=liveBattleFingerprint(BattleArt,battle)
    if ownPokemon then
      -- Applying on every render frame resets Voxel's animated atlas. Apply on
      -- entry/provider change/party switch only, then let Animated.update own
      -- the frame clock.
      if state.owner~=true or state.fingerprint~=fingerprint then
        if type(BattleArt.apply)=="function" then pcall(BattleArt.apply,battle) end
        state.owner=true;state.fingerprint=fingerprint;state.trainersApplied=false
      end
    elseif state.owner~=false then
      -- Explicit KRS provider ownership wins only on KRS presentation surfaces.
      -- Restore Voxel species overrides once without touching any Voxel option.
      if type(Animated)=="table" and type(Animated.finish)=="function" then pcall(Animated.finish,battle) end
      if type(BattleArt.releaseSpeciesOverrides)=="function" then pcall(BattleArt.releaseSpeciesOverrides,battle) end
      state.owner=false;state.fingerprint=fingerprint
    end
    liveBattleArtState[battle]=state

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
    if not state.trainersApplied and type(BattleArt.applyTrainers)=="function" then
      pcall(BattleArt.applyTrainers,battle);state.trainersApplied=true
    end
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
    local relativeOriginal,relativeWrapper

    local function freeCamSelected()
      if type(Pipelines.level)~="function" then return false end
      local ok,level=pcall(Pipelines.level,"voxel")
      if not (ok and (tonumber(level)==6 or tonumber(level)==7)) then return false end
      -- Gen1Recomp can keep a selected pipeline level even when the third-
      -- party hardware/driver gate rejects the renderer. Do not let KRS' own
      -- pointer/field-move bridge pretend that a 1ST/3RD 3D surface exists in
      -- that state. Voxel remains the owner of the actual render pipeline.
      if type(Pipelines.eligible)=="function" then
        local okEligible,eligible=pcall(Pipelines.eligible,"voxel")
        if okEligible and eligible~=true then return false end
      end
      return true
    end
    local function krsOwnsFreeCamPointer(game)
      return mouse and freeCamSelected() and krsCoversWorld(game) or false
    end
    -- Voxel 1.9.0 moved relative-mode ownership into FirstPerson's update
    -- lifecycle. Releasing capture once per input.step is therefore racy: a
    -- later Voxel update can immediately call setRelativeMode(true) again.
    -- Guard the LOVE seam itself only while a KRS pointer surface covers the
    -- world. Requests to release capture always pass through; world gameplay
    -- is otherwise untouched, so 1ST/3RD recapture naturally on close.
    if mouse and type(mouse.setRelativeMode)=="function" then
      relativeOriginal=mouse.setRelativeMode
      relativeWrapper=function(value,...)
        if value==true and krsOwnsFreeCamPointer(activeGame) then
          local result={relativeOriginal(false,...)}
          if type(mouse.setVisible)=="function" and pointerVisibleForActiveDevice(false) then pcall(mouse.setVisible,true) end
          return (table.unpack or unpack)(result)
        end
        return relativeOriginal(value,...)
      end
      mouse.setRelativeMode=relativeWrapper
    end
    local function releaseCapture(game)
      if not krsOwnsFreeCamPointer(game) then return false end
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
      if mouse and relativeWrapper and relativeOriginal and mouse.setRelativeMode==relativeWrapper then mouse.setRelativeMode=relativeOriginal end
      relativeOriginal,relativeWrapper=nil,nil
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
