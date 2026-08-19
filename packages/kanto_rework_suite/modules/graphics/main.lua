local RELEASE='0.3.6'
return function(mod)
  local coreHandle=assert(mod.find('core'),'Kanto Rework Core is required')
  local Core=assert(coreHandle.exports,'Kanto Rework Core exports are required')
  assert(Core.version and Core.version>=40,'kanto_rework_core 0.1.40+ graphics contracts are required')
  assert(Core.graphics and type(Core.graphics.registerProvider)=='function','Core graphics registry is required')

  mod.options:define({
    {key='pokemon_provider',label='ART PROVIDER',type='choice',default='krs',group='POKÉMON / TRAINER ART',
      choices={{'KRS GRAPHICS','krs'},{'GEN1RECOMP','gen1'}},
      description='KRS Graphics is autonomous. Gen1Recomp keeps the ROM art as an explicit fallback choice.'},
    {key='battle_sprite_mode',label='POKÉMON SPRITE MODE',type='choice',default='animated',group='POKÉMON / TRAINER ART',
      choices={{'ANIMATED','animated'},{'STATIC','static'}},
      description='Animated uses KRS atlases in every supported KRS front-art context and in battle backs when available. Static freezes the selected generation to one authored frame.'},
    {key='front_generation',label='FRONT SPRITE GENERATION',type='choice',default='gen5',group='POKÉMON / TRAINER ART',
      choices={{'GEN 1 (STATIC)','gen1'},{'GEN 2','gen2'},{'GEN 3','gen3'},{'GEN 4','gen4'},{'GEN 5','gen5'}},
      description='Generation used for Pokémon front art in battle, previews, Pokédex and the Oak intro Pokémon. The supplied Gen 1 compatibility set is single-frame.'},
    {key='back_generation',label='BACK SPRITE GENERATION',type='choice',default='gen5',group='POKÉMON / TRAINER ART',
      choices={{'GEN 1 (STATIC)','gen1'},{'GEN 2 (STATIC)','gen2'},{'GEN 3','gen3'},{'GEN 4 (STATIC)','gen4'},{'GEN 5','gen5'}},
      description='Generation used for player Pokémon back art. The supplied Gen 3 and Gen 5 sets animate; Gen 1, Gen 2 and Gen 4 stay single-frame.'},
    {key='player_art',label='PLAYER ART',type='choice',default='red',group='POKÉMON / TRAINER ART',
      choices={
        {'ROM','rom'},{'GENERIC PLAYER','player'},{'GEN 1','gen1'},{'GEN 2','gen2'},{'GEN 3','gen3'},{'GEN 4','gen4'},{'GEN 5','gen5'},
        {'RED','red'},{'ASH','ash'},{'GARY','gary'},{'BOY','boy'},{'HILBERT','hilbert'},{'LASS','lass'},
        {'ASH FRONT','ashfront'},{'MISTY FRONT','mistyfront'},{'BROCK FRONT','brockfront'},{'BULMA FRONT','bulmafront'},{'GARY FRONT','garyfront'},
      },
      description='Player battle art. Five-pose strips animate during the KRS battle-introduction slide; choices that only have static art remain static, with ROM as final fallback.'},
    {key='trainer_art',label='TRAINER ART',type='choice',default='rom',group='POKÉMON / TRAINER ART',
      choices={{'ROM / ORIGINAL','rom'},{'GEN I','gen1'},{'GEN II','gen2'},{'GEN III','gen3'},{'GEN V','gen5'}},
      description='Battle art for opposing trainers. Only installed trainer packs are exposed; missing selected art falls back deterministically through older KRS packs and finally the ROM.'},
    {key='keep_opponent_trainer_visible',label='KEEP OPPONENT TRAINER VISIBLE',type='toggle',default=false,group='POKÉMON / TRAINER ART',
      description='Keep the opposing trainer in the KRS battle scene after the opening send-out. Intro and post-battle trainer phases remain engine-owned.'},
    {key='sprite_animation',label='SPRITE ANIMATION',type='toggle',default=true,group='POKÉMON / TRAINER ART',
      description='Animate KRS Pokémon atlases. Turning this off keeps the selected generation but freezes it on frame one.'},
    {key='animation_speed',label='POKÉMON ANIMATION SPEED',type='choice',default='normal',group='POKÉMON / TRAINER ART',
      choices={{'SLOW','slow'},{'NORMAL','normal'},{'FAST','fast'}},
      description='Controls KRS Pokémon atlas cadence only. Slow / Normal / Fast are deliberately distinct; battle logic, HUD transactions and fixed-duration engine transitions are not time-scaled by this option.'},
    {key='battle_scale',label='BATTLE SPRITE SCALE',type='choice',default='default',group='SCALING',
      choices={{'DEFAULT / NATIVE','default'},{'0.5×','x0.5'},{'2×','x2'},{'3×','x3'},{'AUTO','auto'}},
      description='Battle-only sprite scale. Party, Summary, Moves, PC, Save, Pokédex and Intro keep their own component sizing.'},
    {key='real_size',label='REAL SIZE',type='choice',default='auto',group='SCALING',
      choices={{'NO','no'},{'YES','yes'},{'AUTO','auto'}},
      description='Species-size policy shared by KRS visual presentation. Battle uses its own perspective/scaling model; Party, Summary, Moves and PC use independent bounded component fits.'},
    {key='battle_backgrounds',label='KRS BATTLE BACKGROUNDS',type='toggle',default=true,group='BATTLE VISUALS',
      description='Use KRS battle environments whenever no actually rendered KRS 3D battle scene owns the background.'},
    {key='time_mode',label='TIME OF DAY',type='choice',default='sync',group='WORLD LIGHTING',
      choices={{'SYNC WITH LOCAL TIME','sync'},{'CYCLE','cycle'},{'SUNRISE','sunrise'},{'DAY','day'},{'SUNSET','sunset'},{'NIGHT','night'}},
      description='One KRS clock drives Sunrise / Day / Sunset / Night. SYNC follows the computer clock; CYCLE runs independently per save.'},
    {key='time_cycle_length',label='CYCLE LENGTH',type='choice',default='20',group='WORLD LIGHTING',
      choices={{'10 MINUTES','10'},{'20 MINUTES','20'},{'40 MINUTES','40'}},
      description='Duration of a complete 24-hour Kanto cycle when TIME OF DAY is CYCLE.'},
    {key='world_lighting',label='2D WORLD LIGHTING',type='toggle',default=true,group='WORLD LIGHTING',
      description='Apply the KRS time tint to the overworld only. UI remains untinted; indoor maps remain neutral.'},
  })

  local function loadModule(relative)
    local source,err=mod:read(relative);assert(type(source)=='string',err or ('Unable to read '..relative))
    local chunk,loadErr=load(source,'@'..mod.id..'/'..relative);assert(chunk,loadErr)
    return chunk()
  end
  local legacyIndex=loadModule('generated/pokemon_asset_index.lua')
  local battleIndex=loadModule('generated/battle_art_index.lua')
  local battleGenderVariants=loadModule('generated/battle_gender_variant_index.lua')
  local trainerGen5=loadModule('generated/trainer_art_gen5_index.lua')
  local trainerArt=loadModule('trainer_art.lua')({battleIndex=battleIndex,gen5Index=trainerGen5,assetPath=function(path) return mod.assets:path(path) end,warn=function(msg) mod.log:warn('%s',msg) end})
  local editor=loadModule('editor_config.lua')({mod=mod})
  local backgroundSpatial=loadModule('background_spatial.lua')
  local placementAssistant=loadModule('placement_assistant.lua')
  local speedStage=loadModule('speed_stage.lua')

  local function dexOf(request)
    local raw=request and (request.dex or request.speciesId or request.species)
    local n=tonumber(raw)
    if n and n>0 then return math.floor(n) end
    local species=tostring(request and request.species or ''):upper()
    local data=request and request.data
    local def=data and data.pokemon and data.pokemon[species]
    n=def and tonumber(def.dex or def.dexNo or def.pokedex or def.number)
    return n and math.floor(n) or nil
  end
  local function female(request)
    local g=tostring(request and request.gender or (request and request.mon and request.mon.gender) or ''):lower()
    return g=='female' or g=='f'
  end
  local function shiny(request)
    return request and (request.shiny==true or (request.mon and request.mon.shiny==true)) or false
  end
  local function formSuffixes(request)
    local f=request and (request.form or (request.mon and request.mon.form))
    if f==nil or f=='' or tonumber(f)==0 then return {} end
    local out={};local n=tonumber(f)
    if n then
      n=math.max(0,math.floor(n));out[#out+1]=('_%02d'):format(n)
      local raw='_'..tostring(n);if raw~=out[1] then out[#out+1]=raw end
      return out
    end
    local value=tostring(f):gsub('[^%w]+','_'):gsub('^_+',''):gsub('_+$','')
    if value~='' then out[#out+1]='_'..value end
    return out
  end
  local function appendForms(names,base,shinyPrefix,isFemale,forms)
    if isFemale then for _,form in ipairs(forms) do names[#names+1]=base..shinyPrefix..'f'..form..'.png' end end
    for _,form in ipairs(forms) do names[#names+1]=base..shinyPrefix..form..'.png' end
  end
  local function candidateNames(request,forceShinyPrefix)
    local dex=dexOf(request);if not dex then return {} end
    local base=('%04d'):format(dex);local forms=formSuffixes(request);local isFemale=female(request)
    local isShiny=forceShinyPrefix or shiny(request);local names={};local shinyPrefix=isShiny and 's' or ''
    appendForms(names,base,shinyPrefix,isFemale,forms)
    if isFemale then names[#names+1]=base..shinyPrefix..'f.png' end
    names[#names+1]=base..shinyPrefix..'.png'
    if isShiny and not forceShinyPrefix then
      appendForms(names,base,'',isFemale,forms);if isFemale then names[#names+1]=base..'f.png' end;names[#names+1]=base..'.png'
    end
    return names
  end
  local function legacyPokemonAsset(family,request)
    local actualFamily=family;local separateShiny=false
    if family=='front' and shiny(request) then actualFamily='front_shiny';separateShiny=true end
    if family=='back' and shiny(request) then actualFamily='back_shiny';separateShiny=true end
    local available=legacyIndex[actualFamily] or {}
    for _,name in ipairs(candidateNames(request,separateShiny)) do
      if available[name] then
        local relative='assets/pokemon/'..actualFamily..'/'..name
        local result={path=mod.assets:path(relative),assetId=relative,trueColor=true,family=actualFamily,filter='nearest'}
        if family=='icon' then
          -- Generation III-V menu sprites are authored as a two-frame 64x32
          -- strip. KRS keeps this cadence presentation-local: 150 ms/frame
          -- (300 ms loop), never Battle/Live Graphics animation speed.
          result.frameCount=2;result.frameWidth=32;result.frameHeight=32;result.frameDuration=0.15;result.loop=true
          result.atlas={path=result.path,frameWidth=32,frameHeight=32,columns=2,rows=1,frameCount=2,frameDurationMs=150,loop=true}
        end
        return result
      end
    end
  end

  local function slugOf(request)
    local raw=tostring(request and request.species or ''):lower()
    if raw=='' then return nil end
    raw=raw:gsub('_','-'):gsub('%s+','-'):gsub("[^%w%-]",'')
    if raw=='nidoran-f' or raw=='nidoranf' then return 'nidoran-f' end
    if raw=='nidoran-m' or raw=='nidoranm' then return 'nidoran-m' end
    if raw=='mr-mime' or raw=='mrmime' then return 'mr-mime' end
    if raw=='farfetchd' or raw=='farfetch-d' then return 'farfetchd' end
    return raw
  end
  local function optionGeneration(key,default)
    local v=tostring(mod.options:get(key) or default):lower()
    local n=v:match('gen([1-5])$') or v:match('^([1-5])$')
    return n or default:match('[1-5]') or '5'
  end
  local function animationMode() return tostring(mod.options:get('battle_sprite_mode') or 'animated'):lower()=='animated' end
  local function animationOn() return animationMode() and mod.options:get('sprite_animation')~=false end
  local function speedFactor(percent)
    if percent~=nil then
      local p=math.max(0,math.min(100,tonumber(percent) or 50))/100
      -- 0 = very deliberate; 50 = KRS normal; 100 = visibly fast. Piecewise
      -- interpolation keeps the exact normal cadence at the centre.
      if p<=.5 then return 2.4-(2.4-1)*(p/.5) end
      return 1-(1-.35)*((p-.5)/.5)
    end
    local speed=tostring(mod.options:get('animation_speed') or 'normal'):lower()
    return ({slow=2.4,normal=1,fast=.40})[speed] or 1
  end
  local function frameMs(count,percent)
    local base=2400/math.max(1,tonumber(count) or 1)
    base=math.max(20,math.min(180,base))*speedFactor(percent)
    return math.max(12,math.floor(base+0.5))
  end
  local function tableClone(t)
    local out={};for k,v in pairs(type(t)=='table' and t or {}) do out[k]=v end;return out
  end
  local function resolvedEditor(request)
    if type(request.editorConfig)=='table' then return request.editorConfig,{configured=true,source='live'} end
    if request.game and editor and type(editor.resolve)=='function' then
      local ok,value,meta=pcall(editor.resolve,request.game,request.backgroundKey,request.backgroundPhase)
      if ok and type(value)=='table' then return value,type(meta)=='table' and meta or {} end
    end
    return nil,{}
  end
  local function roleSettings(request,role)
    local cfg,meta=resolvedEditor(request);if not meta.configured then return nil end
    local value=cfg and cfg[role]
    return type(value)=='table' and value or nil
  end
  local function battlePokemonAsset(side,request)
    local slug=slugOf(request);if not slug then return nil end
    request=request or {}
    local role=tostring(request.editorRole or (side=='back' and 'player' or 'opponent'))
    local settings=roleSettings(request,role)
    local assetSide=side;local mirror=false
    if role=='player' and settings and tostring(settings.orientation)=='front_mirrored' then assetSide='front';mirror=true end
    if role=='opponent' then assetSide='front' end
    local configured=settings and tostring(settings.generation or '') or ''
    local gen=(configured:match('gen([1-5])$') or configured:match('^([1-5])$'))
      or optionGeneration(assetSide=='back' and 'back_generation' or 'front_generation',assetSide=='back' and 'gen5' or 'gen5')
    local palette=shiny(request) and 'shiny' or 'normal'
    local byGen=battleIndex[assetSide] and battleIndex[assetSide][gen]
    local entry=byGen and byGen[palette] and byGen[palette][slug]
    if not entry and palette=='shiny' then entry=byGen and byGen.normal and byGen.normal[slug] end
    if not entry then return legacyPokemonAsset(assetSide,request) end
    local requestedMode=settings and tostring(settings.mode or ''):lower() or nil
    local wantsAnimation=requestedMode and requestedMode=='animated' or animationOn()
    if requestedMode=='static' then wantsAnimation=false end
    local useAnim=wantsAnimation and entry.animated and entry.path
    local relative
    if assetSide=='back' then
      if useAnim then relative=entry.path else relative=entry.staticPath or entry.fallbackPath end
    else
      relative=useAnim and entry.path or entry.fallbackPath or entry.path
    end
    if not relative then return legacyPokemonAsset(assetSide,request) end
    local result={path=mod.assets:path(relative),assetId=relative,trueColor=true,filter='nearest',
      family='battle_'..assetSide..'_gen'..gen,generation=tonumber(gen),palette=palette,animated=useAnim and true or false,
      nativePath=mod.assets:path(entry.fallbackPath or entry.staticPath or relative),mirrorX=mirror,
      editorRole=role,editorSizePercent=settings and tonumber(settings.size) or nil,
      editorAnimationSpeed=settings and tonumber(settings.animationSpeed) or nil,
      editorPosition=settings and type(settings.position)=='table' and tableClone(settings.position) or nil}
    if useAnim then
      local split=battleGenderVariants[assetSide] and battleGenderVariants[assetSide][gen]
        and battleGenderVariants[assetSide][gen][palette] and battleGenderVariants[assetSide][gen][palette][slug]
      local baseFrameMs=frameMs(entry.frameCount,settings and settings.animationSpeed)
      local stage=0
      -- Only a real battle battler carries `stages.speed`. Menu/front previews
      -- and the Live Mockup synthetic battlers stay at stage 0 by construction.
      if request.kind=='battle' and request.battler and type(request.battler.stages)=='table' then stage=request.battler.stages.speed or 0 end
      result.speedStage=speedStage.clamp(stage);result.speedStageRate=speedStage.rate(stage)
      result.atlas={path=result.path,frameWidth=entry.frameWidth,frameHeight=entry.frameHeight,
        columns=entry.columns,rows=entry.rows,frameCount=entry.frameCount,frameDurationMs=speedStage.duration(baseFrameMs,stage),baseFrameDurationMs=baseFrameMs,loop=true}
      if split then
        -- Some supplied animated cells encode the two gender tracks vertically
        -- inside ONE atlas cell. The renderer must choose one track, never draw
        -- both. Track 1 is the common/male track; female selects track 2.
        result.atlas.variantRows=2
        result.atlas.variantIndex=female(request) and 2 or 1
        result.genderVariant=result.atlas.variantIndex==2 and 'female' or 'common'
      else
        result.genderVariant='common'
      end
      result.nativePath=mod.assets:path(entry.fallbackPath or entry.staticPath or relative)
    end
    return result
  end


  local trainerPaths={
    oak='assets/trainers/intro/oak.png',professor_oak='assets/trainers/intro/oak.png',
    blue='assets/trainers/intro/blue.png',gary='assets/trainers/intro/blue.png',rival='assets/trainers/intro/blue.png',
    red='assets/trainers/intro/red.png',player='assets/trainers/intro/red.png',old_man='assets/trainers/intro/old_man.png',
  }
  local function resolve(context,request)
    request=request or {}
    if context=='party.icon' or context=='pc.icon' or context=='save.icon' or context=='moves.icon'
        or context=='main_menu.icon' or context=='menu.icon' then return legacyPokemonAsset('icon',request) end
    if context=='intro.pokemon' then
      local asset=battlePokemonAsset('front',request);if asset then asset.integerScale=true;asset.battleScale=false end;return asset
    end
    if context=='party.preview' or context=='summary.preview' or context=='pokedex.preview' then
      local asset=battlePokemonAsset('front',request);if asset then asset.battleScale=false end;return asset
    end
    if context=='battle.player' then local a=battlePokemonAsset('back',request);if a then a.battleScale=true end;return a end
    if context=='battle.opponent' then local a=battlePokemonAsset('front',request);if a then a.battleScale=true end;return a end
    if context=='battle.trainer' then
      return trainerArt.resolve(mod.options:get('trainer_art') or 'rom',request)
    end
    if context=='player.presentation.front' then
      -- Canonical Figma Trainer Card / Save presentation asset. This family is
      -- independent from player_art battle backsprites and from overworld art.
      local relative='assets/trainers/presentation/red_front.png'
      return {path=mod.assets:path(relative),assetId=relative,trueColor=true,
        filter='linear',presentation=true,nativeWidth=112,nativeHeight=276,
        battleScale=false,noUpscale=true}
    end
    if context=='intro.trainer' then
      local id=tostring(request.id or request.character or ''):lower():gsub('[^%w]+','_');local relative=trainerPaths[id]
      if relative then
        local nativeTrainer=(id=='red' or id=='player' or id=='blue' or id=='gary' or id=='rival')
        return {path=mod.assets:path(relative),assetId=relative,trueColor=true,filter='nearest',presentationScale=nativeTrainer and 0.5 or nil,noUpscale=true}
      end
    end
    if context=='intro.scene' and tostring(request.id or '')=='oak_lab' then
      local relative='assets/scenes/intro/oak_lab.png';return {path=mod.assets:path(relative),assetId=relative,trueColor=true,filter='linear'}
    end
  end

  local function providerMode()
    local value=tostring(mod.options:get('pokemon_provider') or 'krs'):lower();return value=='gen1' and 'gen1' or 'krs'
  end
  local function firstPartyEnabled(context)
    if context~='battle.player' and context~='battle.opponent' then return true end
    return providerMode()=='krs'
  end
  local unregister=Core.graphics.registerProvider({
    id='kanto_rework_graphics.assets',source=mod.id,priority=240,
    contexts={'party.icon','pc.icon','save.icon','moves.icon','main_menu.icon','menu.icon',
      'party.preview','summary.preview','pokedex.preview','player.presentation.front','intro.pokemon','intro.trainer','intro.scene','battle.player','battle.opponent','battle.trainer'},
    enabled=firstPartyEnabled,resolve=resolve,
  })

  -- Native Gen1Recomp sites accept one image path, not an atlas. They receive
  -- the first authored KRS frame while KRS presenters use the live atlas.
  local unhookPokemon=mod.hooks:wrap('pokemon.sprite',function(next,path,ctx)
    ctx=type(ctx)=='table' and ctx or {};if providerMode()=='gen1' then return path end
    local context=ctx.side=='back' and 'battle.player' or 'battle.opponent';local mon=ctx.mon
    local asset=resolve(context,{species=ctx.species,side=ctx.side,kind=ctx.kind,mon=mon,data=ctx.data,
      shiny=mon and mon.shiny,gender=mon and mon.gender,form=mon and mon.form})
    local native=asset and (asset.nativePath or asset.path)
    if native then ctx.trueColor=asset.trueColor==true;return native end
    return next(path,ctx)
  end,9000)

  local function selectedPlayer()
    return tostring(mod.options:get('player_art') or 'red'):lower():gsub('[^%w]+','')
  end
  local function playerAssetPath()
    local choice=selectedPlayer();if choice=='rom' then return nil end
    local aliases={gen1='gen1player',gen2='gen2player',gen3='gen3player',gen4='gen4player',gen5='gen5player',
      red='redplayer',ash='ashplayer',gary='garyplayer',player='player',boy='boyplayer',hilbert='hilbertplayer',lass='lassplayer',
      ashfront='ashfrontplayer',mistyfront='mistyfrontplayer',brockfront='brockfrontplayer',bulmafront='bulmafrontplayer',garyfront='garyfrontplayer'}
    local key=aliases[choice] or choice
    if animationOn() then
      local a=battleIndex.players and battleIndex.players.animated and battleIndex.players.animated[key]
      if a then return mod.assets:path(a.fallbackPath or a.path),a end
    end
    local s=battleIndex.players and battleIndex.players.static and battleIndex.players.static[key]
    if s then return mod.assets:path(s),{animated=false} end
    local a=battleIndex.players and battleIndex.players.animated and battleIndex.players.animated[key]
    if a then return mod.assets:path(a.fallbackPath or a.path),a end
    return nil
  end
  local unhookPlayer=mod.hooks:wrap('player.sprite',function(next,path,ctx)
    ctx=type(ctx)=='table' and ctx or {}
    -- player_art is a BATTLE backsprite choice. Never substitute it into the
    -- Trainer Card, Save, Hall of Fame, intro-front or any overworld surface.
    -- Those use player.presentation.front / their native dedicated families.
    if ctx.kind~='battle' or ctx.side~='back' or ctx.demo or ctx.oakDemo then return next(path,ctx) end
    if providerMode()=='gen1' or selectedPlayer()=='rom' then return next(path,ctx) end
    local chosen=playerAssetPath();if chosen then ctx.trueColor=true;return chosen end
    return next(path,ctx)
  end,9000)

  local function scaleSettings()
    local scale=tostring(mod.options:get('battle_scale') or 'default'):lower()
    local pixel=({['default']=1,['x0.5']=0.5,['x2']=2,['x3']=3})[scale]
    local real=tostring(mod.options:get('real_size') or 'auto'):lower()
    return {upscale=scale,pixelScale=pixel,realSize=real,nativePixels=true,fullAuto=scale=='auto' and real=='auto'}
  end

  -- KRS time-of-day -------------------------------------------------------
  -- Clean-room implementation using Gen1Recomp's public world.tod and
  -- render.compose seams. No Voxel code or renderer dependency is loaded.
  local timeState={mode=nil,baseHours=12,anchor=nil,lastHours=12,outdoor=false,mapId=nil,restored=false}
  local function monotonic() return love and love.timer and love.timer.getTime and love.timer.getTime() or os.clock() end
  local function wrap24(h) h=tonumber(h) or 0;h=h%24;if h<0 then h=h+24 end;return h end
  local PIN={sunrise=6.5,day=12,sunset=18.5,night=0}
  local syncCache={second=-1,hours=12}
  local function syncHours(now)
    -- Host clock reads are much more expensive than the arithmetic below and
    -- callers may ask from world.tod, compose, headers and battle routing in
    -- the same frame. Sample once per real second; visual interpolation at a
    -- finer host-clock resolution is imperceptible.
    now=now or monotonic();local second=math.floor(now)
    if syncCache.second~=second then
      local d=os.date('*t');syncCache.hours=(tonumber(d.hour) or 12)+(tonumber(d.min) or 0)/60+(tonumber(d.sec) or 0)/3600
      syncCache.second=second
    end
    return syncCache.hours
  end
  local function modeValue()
    local v=tostring(mod.options:get('time_mode') or 'sync'):lower()
    if v=='cycle' or v=='sunrise' or v=='day' or v=='sunset' or v=='night' then return v end
    return 'sync'
  end
  local function cycleMinutes()
    local n=tonumber(mod.options:get('time_cycle_length')) or 20
    if n~=10 and n~=40 then n=20 end
    return n
  end
  local function currentHours()
    local mode=modeValue();local now=monotonic()
    if timeState.mode~=mode then
      local inherited=timeState.lastHours or 12
      if mode=='cycle' then timeState.baseHours=wrap24(inherited);timeState.anchor=now end
      timeState.mode=mode
    end
    local h
    if mode=='sync' then h=syncHours(now)
    elseif mode=='cycle' then
      timeState.anchor=timeState.anchor or now
      h=wrap24((timeState.baseHours or 12)+(now-timeState.anchor)*24/(cycleMinutes()*60))
    else h=PIN[mode] or 12 end
    timeState.lastHours=h;return h
  end
  local function phaseAt(h)
    h=wrap24(h)
    if h>=5 and h<8 then return 'sunrise' end
    if h>=8 and h<17 then return 'day' end
    if h>=17 and h<20 then return 'sunset' end
    return 'night'
  end
  local function engineTod(h)
    local p=phaseAt(h);if p=='sunrise' then return 'MORNING' end;if p=='sunset' then return 'EVENING' end
    return p=='night' and 'NIGHT' or 'DAY'
  end
  local TINT={night={0.50,0.58,0.78},sunrise={1.00,0.86,0.76},day={1,1,1},sunset={1.00,0.76,0.66}}
  local KEYS={{0,'night'},{5,'night'},{6.5,'sunrise'},{8,'day'},{16.5,'day'},{18.5,'sunset'},{20,'night'},{24,'night'}}
  local function lerp(a,b,t) return a+(b-a)*t end
  local tintCache={minute=-1,r=1,g=1,b=1}
  local function tintAt(h)
    h=wrap24(h);local minute=math.floor(h*60+0.5)%1440
    if tintCache.minute==minute then return tintCache.r,tintCache.g,tintCache.b end
    local r,g,b=TINT.night[1],TINT.night[2],TINT.night[3]
    for i=1,#KEYS-1 do
      local a,z=KEYS[i],KEYS[i+1]
      if h>=a[1] and h<=z[1] then
        if a[2]==z[2] then local c=TINT[a[2]];r,g,b=c[1],c[2],c[3]
        else local u=(h-a[1])/math.max(0.0001,z[1]-a[1]);local ca,cb=TINT[a[2]],TINT[z[2]];r,g,b=lerp(ca[1],cb[1],u),lerp(ca[2],cb[2],u),lerp(ca[3],cb[3],u) end
        break
      end
    end
    tintCache.minute,tintCache.r,tintCache.g,tintCache.b=minute,r,g,b
    return r,g,b
  end
  local CANOPY={VIRIDIAN_FOREST=true}
  local function mapIsTimeLit(map)
    if not (map and map.def) then return false end
    local def=map.def;local id=tostring(map.id or def.id or ''):upper()
    if CANOPY[id] then return true end
    -- Gen1Recomp's public world.tod payload already supplies the live map.
    -- Use authored map properties directly instead of requiring engine modules:
    -- vanilla outdoor maps use OVERWORLD; Route 23 / Indigo use PLATEAU.
    if def.outdoor~=nil then return def.outdoor and true or false end
    return def.tileset=='OVERWORLD' or def.tileset=='PLATEAU'
  end
  local function outdoorFrom(ctx)
    local map=ctx and ctx.map;timeState.mapId=ctx and ctx.mapId or (map and map.id) or timeState.mapId
    if map then timeState.outdoor=mapIsTimeLit(map) end
    return timeState.outdoor
  end
  local function outdoorNow()
    -- `world.tod` refreshes this from its public ctx before composition. Keeping
    -- the cached boolean avoids a second engine/internal lookup every frame.
    return timeState.outdoor
  end
  local unhookTod=mod.hooks:wrap('world.tod',function(next,tod,ctx)
    outdoorFrom(ctx);return engineTod(currentHours())
  end,7000)

  local function tintColor(c,r,g,b)
    if type(c)~='table' then return c end
    if c.r~=nil then return {r=math.floor(c.r*r+0.5),g=math.floor(c.g*g+0.5),b=math.floor(c.b*b+0.5)} end
    return {math.floor((c[1] or 0)*r+0.5),math.floor((c[2] or 0)*g+0.5),math.floor((c[3] or 0)*b+0.5)}
  end
  local function tintZones(zones,r,g,b)
    if type(zones)~='table' then return false end
    local changed=false
    for _,z in ipairs(zones) do
      if type(z)=='table' and type(z.colors)=='table' then
        local copy={};for i,c in ipairs(z.colors) do copy[i]=tintColor(c,r,g,b) end;z.colors=copy;changed=true
      end
    end
    return changed
  end
  local function multiplyWorldCanvas(canvas,r,g,b)
    if not (canvas and love and love.graphics) then return false end
    local gfx=love.graphics;local oldCanvas=gfx.getCanvas and gfx.getCanvas() or nil
    local oldR,oldG,oldB,oldA=gfx.getColor();local oldBlend,oldAlpha=gfx.getBlendMode();local oldShader=gfx.getShader and gfx.getShader() or nil
    local sx,sy,sw,sh=gfx.getScissor and gfx.getScissor() or nil
    local ok=pcall(function()
      gfx.setCanvas(canvas);if gfx.setShader then gfx.setShader() end;if gfx.setScissor then gfx.setScissor() end
      gfx.setBlendMode('multiply','premultiplied');gfx.setColor(r,g,b,1);gfx.rectangle('fill',0,0,canvas:getWidth(),canvas:getHeight())
    end)
    if oldCanvas then gfx.setCanvas(oldCanvas) else gfx.setCanvas() end
    if oldAlpha~=nil then gfx.setBlendMode(oldBlend or 'alpha',oldAlpha) else gfx.setBlendMode(oldBlend or 'alpha') end
    gfx.setColor(oldR or 1,oldG or 1,oldB or 1,oldA or 1)
    if gfx.setScissor then if sx then gfx.setScissor(sx,sy,sw,sh) else gfx.setScissor() end end
    if gfx.setShader then gfx.setShader(oldShader) end
    return ok
  end
  local unhookCompose=mod.hooks:wrap('render.compose',function(next,renderer,ctx)
    if mod.options:get('world_lighting')~=false and outdoorNow() and type(ctx)=='table' and ctx.worldActive and not ctx.worldOverride then
      local r,g,b=tintAt(currentHours())
      if math.abs(r-1)>0.002 or math.abs(g-1)>0.002 or math.abs(b-1)>0.002 then
        -- Shade-remapped modes: modify this frame's world palette zones only.
        -- ADVANCED true-colour mode intentionally supplies an empty world-zone
        -- list, so multiply its already-RGB world canvas instead. UI is never
        -- touched in either path.
        local zones=ctx.worldZones
        if not (type(zones)=='table' and #zones>0 and tintZones(zones,r,g,b))
            and type(zones)=='table' and #zones==0 then
          multiplyWorldCanvas(ctx.worldCanvas,r,g,b)
        end
      end
    end
    return next(renderer,ctx)
  end,7000)

  local function saveClock()
    if modeValue()~='cycle' then return end
    local api=mod.save;if not (api and api.set) then return end
    pcall(api.set,api,'krs_time_hours',currentHours())
  end
  local function restoreClock()
    local api=mod.save;local stored=nil
    if api and api.get then local ok,v=pcall(api.get,api,'krs_time_hours');if ok then stored=tonumber(v) end end
    if stored then timeState.baseHours=wrap24(stored);timeState.lastHours=timeState.baseHours else timeState.baseHours=12;timeState.lastHours=12 end
    timeState.anchor=monotonic();timeState.restored=true
  end
  mod.events:on('save.writing',saveClock)
  mod.events:on('save.loaded',restoreClock)
  mod.events:on('save.created',restoreClock)

  mod.events:on('mod.unload',function()
    for _,u in ipairs({unregister,unhookPokemon,unhookPlayer,unhookTod,unhookCompose}) do if u then pcall(u) end end
  end)
  local battleVisualState={bounds=nil,viewport=nil,updatedAt=0}
  local function copyBounds(bounds)
    if type(bounds)~='table' then return nil end
    local out={}
    for side,b in pairs(bounds) do if type(b)=='table' then local c={};for k,v in pairs(b) do if type(v)=='table' then local t={};for x,y in pairs(v) do t[x]=y end;c[k]=t else c[k]=v end end;out[side]=c end end
    return out
  end
  mod.exports.release=RELEASE
  mod.exports.battleVisuals={
    update=function(bounds,viewport) battleVisualState.bounds=copyBounds(bounds);battleVisualState.viewport=viewport;battleVisualState.updatedAt=(love and love.timer and love.timer.getTime and love.timer.getTime()) or os.clock();return true end,
    snapshot=function() return {bounds=copyBounds(battleVisualState.bounds),viewport=battleVisualState.viewport,updatedAt=battleVisualState.updatedAt} end,
    anchors=function(side) local b=battleVisualState.bounds and battleVisualState.bounds[side];return b and {top=b.top,center=b.center,feet=b.feet} or nil end,
    clear=function() battleVisualState.bounds=nil;battleVisualState.viewport=nil;return true end,
  }
  mod.exports.resolve=function(context,request,fallback) return resolve(context,request) or fallback end
  mod.exports.battlePresentation=scaleSettings
  mod.exports.menuPresentation=function() return {realSize=tostring(mod.options:get('real_size') or 'auto'):lower(),battleScaleIgnored=true,source='kanto_rework_graphics'} end
  mod.exports.battleBackgroundsEnabled=function() return mod.options:get('battle_backgrounds')~=false end
  mod.exports.providerMode=providerMode
  mod.exports.playerArt=function()
    local p,m=playerAssetPath();local value={choice=selectedPlayer(),path=p,meta=m,animated=false}
    if type(m)=='table' and m.animated and animationOn() and m.path then
      value.animated=true
      value.atlas={path=mod.assets:path(m.path),frameWidth=m.frameWidth,frameHeight=m.frameHeight,
        columns=m.columns or m.frameCount or 5,rows=m.rows or 1,frameCount=m.frameCount or 5,
        frameDurationMs=frameMs(m.frameCount or 5),loop=false}
    end
    return value
  end
  mod.exports.timeOfDay=function()
    local h=currentHours();return {mode=modeValue(),hours=h,phase=phaseAt(h),tod=engineTod(h),outdoor=timeState.outdoor,cycleMinutes=cycleMinutes(),lighting=mod.options:get('world_lighting')~=false}
  end
  mod.exports.timeOfDayPeriod=function() return phaseAt(currentHours()) end
  mod.exports.backgroundSpatialMetadata=function(key) return backgroundSpatial.metadata(key) end
  mod.exports.backgroundSpatialProfiles=function() return backgroundSpatial.profileIds() end
  mod.exports.placementAssistantSuggest=function(request) return placementAssistant.suggest(request) end
  mod.exports.trainerArt={
    sources=function() local out={};for i,v in ipairs(trainerArt.sources) do out[i]=v end;return out end,
    resolve=function(request) return trainerArt.resolve(mod.options:get('trainer_art') or 'rom',request) end,
    selected=function() return tostring(mod.options:get('trainer_art') or 'rom'):lower() end,
    keepVisible=function() return mod.options:get('keep_opponent_trainer_visible')==true end,
  }
  mod.exports.graphicsEditor={
    defaults=function() return editor.defaults() end,
    global=function(game) return editor.global(game) end,
    resolve=function(game,background,phase) return editor.resolve(game,background,phase) end,
    commitGlobal=function(game,value) return editor.commitGlobal(game,value) end,
    commitLocal=function(game,background,phase,value) return editor.commitLocal(game,background,phase,value) end,
    seedLocal=function(game,background,phase,value) return editor.seedLocal(game,background,phase,value) end,
    hasLocal=function(game,background,phase) return editor.hasLocal(game,background,phase) end,
    deleteLocal=function(game,background,phase) return editor.deleteLocal(game,background,phase) end,
    profiles=function(game) return editor.profiles(game) end,
    saveProfile=function(game,name,value) return editor.saveProfile(game,name,value) end,
    loadProfile=function(game,name) return editor.loadProfile(game,name) end,
    renameProfile=function(game,a,b) return editor.renameProfile(game,a,b) end,
    deleteProfile=function(game,name) return editor.deleteProfile(game,name) end,
    snapshot=function(game) return editor.snapshot(game) end,
    variantType=function(phase) return editor.variantType(phase) end,
    localStorageKey=function(phase) return editor.localStorageKey(phase) end,
    speedStageRate=function(stage) return speedStage.rate(stage) end,
  }
  local function availableGenerations(side,species,mode)
    side=side=='back' and 'back' or 'front';local slug=slugOf({species=species});local out={}
    if not slug then return out end
    for n=1,5 do
      local gen=tostring(n);local byGen=battleIndex[side] and battleIndex[side][gen]
      local entry=byGen and byGen.normal and byGen.normal[slug]
      if entry and (mode~='animated' or entry.animated==true) then out[#out+1]='gen'..gen end
    end
    return out
  end
  mod.exports.availablePokemonGenerations=availableGenerations
  mod.exports.status=function()
    return {release=RELEASE,name='Kanto Rework Graphics',provider='kanto_rework_graphics.assets',mode=providerMode(),battle=scaleSettings(),time=mod.exports.timeOfDay(),editor=editor.snapshot and editor.snapshot(nil) or nil,source=battleIndex.source}
  end
  mod.log:info('Kanto Rework Graphics %s loaded',RELEASE)
end
