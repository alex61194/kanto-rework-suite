-- Kanto Ascendant family presentation adapter.
-- Release numbers are diagnostic only. Native schemas, exports, callbacks and
-- persistence remain authoritative; each optional seam is gated by its live
-- runtime contract.
return function(deps)
  local ascendant=assert(deps.ascendant,"Ascendant handle is required")
  local Core=deps.Core
  local identityMatch=deps.identityMatch
  local modId=tostring(ascendant.id or "trainer_rematch")
  local liveVersion=tostring(ascendant.version or "unknown")
  local gateways=setmetatable({},{__mode="k"})
  local groups={
    GENERAL={language=true},
    REMATCHES={rest_min=true,rest_max=true,level_gain=true,team_growth=true,loot_mode=true},
    ["KANTO COMPLETION"]={kanto_151=true},
    ["ART & ANIMATION"]={legend_art=true,kanto_crystal_art=true,dex_sprite_style=true,crystal_animation=true},
    SHINY={shiny_hunts=true,shiny_effects=true,shiny_protection=true,shiny_event=true},
    ["MEGA EVOLUTION"]={mega_evolution=true,mega_opponents=true},
    ["JOHTO SIGNALS"]={johto_time=true,johto_signals_enable=true,johto_wilds_integration=true,johto_signals_start=true,mythic_signals=true},
    LEGENDARIES={legend_articuno=true,legend_zapdos=true,legend_moltres=true,legend_mewtwo=true,legend_raikou=true,legend_entei=true,legend_suicune=true,legend_lugia=true,legend_ho_oh=true,legend_celebi=true,legend_mew=true,mew_profile=true},
    ["HERITAGE EVENTS"]={event_mode=true,event_university_magikarp=true,event_stamp_fearow=true,event_flying_pikachu=true,event_stamp_rapidash=true,event_surfing_pikachu=true,event_flee=true,event_rosette=true},
    POSTGAME={rocket_story=true,grand_tournament=true,ascendant_rules=true},
  }
  local groupByKey={}
  local animationCache={}
  for group,keys in pairs(groups) do for key in pairs(keys) do groupByKey[key]=group end end

  local function gatewayKey(item)
    if type(item)~="table" or type(item.onSelect)~="function" then return nil end
    local label=tostring(item.label or ""):upper()
    if item.ascendantMenu==true or label=="ASCENDANT" then return label~="" and label or "ASCENDANT" end
  end

  local function gatewayMap(game)
    local found=gateways[game] or {};gateways[game]=found
    local ok,StartMenu=pcall(require,"src.ui.StartMenu")
    if not(ok and StartMenu and type(StartMenu.new)=="function") then return found end
    local madeOk,native=pcall(StartMenu.new,game)
    if not madeOk or type(native)~="table" then return found end
    for _,item in ipairs(native.items or {}) do
      local key=gatewayKey(item);if key then found[key]=item end
    end
    return found
  end

  local function captureState(game,callback)
    local stack=game and game.stack
    if not(stack and type(stack.push)=="function" and type(callback)=="function") then return nil,"stack unavailable" end
    local original=stack.push
    local captured={}
    stack.push=function(_,state) captured[#captured+1]=state;return state end
    local ok,err=xpcall(callback,tostring)
    stack.push=original
    if not ok then return nil,err end
    return captured[#captured],#captured>0 and nil or "Ascendant did not open a state"
  end

  local adapter={id="kanto_ascendant.family",modId=modId,label="Kanto Ascendant",version=liveVersion,priority=100}
  function adapter.match(manifest)
    if tostring(manifest and manifest.id or "")~=modId then return false end
    if type(identityMatch)=="function" then
      local ok,value=pcall(identityMatch,ascendant,manifest);return ok and value==true
    end
    local name=tostring(manifest and manifest.name or ""):lower()
    return modId=="trainer_rematch" and (name=="" or name=="kanto ascendant")
  end
  function adapter.supportsMenu()
    return type(ascendant.exports)=="table" and type(ascendant.exports.ascendantMenu)=="table"
  end
  function adapter.supportsCrystalSprites()
    local crystal=type(ascendant.exports)=="table" and ascendant.exports.crystalAnimation or nil
    return type(crystal)=="table" and type(crystal.staticFrameOne)=="function"
  end
  function adapter.claimStartMenuItem(game,item)
    if not adapter.supportsMenu() then return false end
    local key=gatewayKey(item);if not key then return false end
    local found=gateways[game] or {};gateways[game]=found;found[key]=item;return true
  end
  function adapter.decorateOptions(_,rows)
    for _,row in ipairs(rows or {}) do row.group=row.id=="__reset" and "MAINTENANCE" or groupByKey[row.id] or row.group or "OTHER" end
    return rows
  end
  local function storedOption(game,key,default)
    local loader=game and game.mods
    local bucket=loader and type(loader.modOptions)=="table"
      and loader.modOptions[modId] or nil
    if type(bucket)=="table" and bucket[key]~=nil then return bucket[key] end
    return default
  end
  local function animationModel(crystal,ctx,which,dex,side)
    side=side=="back" and "back" or "front"
    local cacheKey=tostring(dex)..":"..which..":"..side
    if animationCache[cacheKey]~=nil then return animationCache[cacheKey] or nil end
    if not(type(crystal.select)=="function" and type(crystal.selected)=="table") then animationCache[cacheKey]=false;return nil end
    local probe={species=ctx.species}
    if type(ctx.mon)=="table" then for key,value in pairs(ctx.mon) do probe[key]=value end end
    local probeCtx={species=ctx.species,data=ctx.data,mon=probe,kind="battle",side=side,trueColor=true}
    local ok,path=pcall(crystal.select,probeCtx,side,false)
    local selected=crystal.selected[probe]
    crystal.selected[probe]=nil
    if not(ok and type(path)=="string" and type(selected)=="table"
        and type(selected.durations)=="table" and #selected.durations>1) then animationCache[cacheKey]=false;return nil end
    local frames,durations={},{}
    for i,duration in ipairs(selected.durations) do
      frames[i]=path:gsub("%d%d%d%.png$",("%03d.png"):format(i))
      durations[i]=math.max(1,tonumber(duration) or 100)
    end
    local model={frames=frames,durations=durations,loop=true}
    animationCache[cacheKey]=model;return model
  end
  local function providerSelected()
    if not (Core and Core.compatibility and type(Core.compatibility.resolve)=="function") then return true end
    local ok,r=pcall(Core.compatibility.resolve,"pokemon.sprite_art")
    return not ok or not r or r.selected=="kanto_ascendant.crystal_sprites"
  end

  function adapter.resolvePokemonArt(game,request,current)
    request=type(request)=="table" and request or {}
    if not adapter.supportsCrystalSprites() or not providerSelected() or not request.species then return current end
    local side=request.side=="back" and "back" or "front"
    local data=request.data or (game and game.data)
    local def=data and data.pokemon and data.pokemon[request.species]
    local dex=def and tonumber(def.dex)
    if not dex then return current end
    local crystal=ascendant.exports and ascendant.exports.crystalAnimation
    if not (type(crystal)=="table" and type(crystal.staticFrameOne)=="function") then return current end

    -- Provider ownership is now explicit in Compatibility. Ascendant's own
    -- KANTO CRYSTAL ART / LEGEND ART / CRYSTAL ANIMATION options still decide
    -- which Crystal material exists; Compatibility only decides whether that
    -- material is the one KRS presents everywhere.
    if dex>=1 and dex<=151 then
      if storedOption(game,"kanto_crystal_art",true)==false then return current end
      if type(crystal.externalKantoActive)=="function" then
        local ok,external=pcall(crystal.externalKantoActive,dex)
        if ok and external then return current end
      end
    elseif dex>=152 and dex<=251 then
      if storedOption(game,"legend_art","crystal")~="crystal" then return current end
    end

    local which="normal"
    local shiny=ascendant.exports and ascendant.exports.shinySystem
    if request.mon and type(shiny)=="table" and type(shiny.isShiny)=="function" then
      local ok,value=pcall(shiny.isShiny,request.mon)
      if ok and value==true then which="shiny" end
    end
    local ctx={species=request.species,data=data,mon=request.mon,kind="kanto_rework_menu",side=side,trueColor=true}
    local ok,path=pcall(crystal.staticFrameOne,ctx,side,which)
    if not (ok and type(path)=="string" and path~="") then return current end
    local animation
    if side=="front" and storedOption(game,"crystal_animation",true)~=false then
      animation=animationModel(crystal,ctx,which,dex,side)
    end
    return {path=path,trueColor=true,source="kanto_ascendant.crystal_sprites",animation=animation}
  end

  function adapter.resolvePokemonArtImage(game,species,side,opts)
    local request={species=species,side=side,data=game and game.data,mon=type(opts)=="table" and opts.mon or nil}
    local value=adapter.resolvePokemonArt(game,request,{})
    return type(value)=="table" and type(value.path)=="string" and value or nil
  end

  function adapter.utilities(game)
    if not adapter.supportsMenu() then return {} end
    local policy={reader={mode="adaptive_document",mergeSourcePages=true,preserveLines=false}}
    local out={{id="ascendant_hub",label="KANTO ASCENDANT HUB",group="FEATURES",
      description="Open Ascendant progress, research and world utilities inside the Kanto Rework navigation shell.",
      presentation=policy,
      open=function()
        local gateway=gatewayMap(game).ASCENDANT;if not gateway then error("Kanto Ascendant gateway is unavailable") end
        local state,err=captureState(game,gateway.onSelect);if not state then error(err or "Kanto Ascendant menu is unavailable") end
        return state
      end}}
    for key,item in pairs(gatewayMap(game)) do
      if key~="ASCENDANT" then
        local utilityKey,utilityItem=key,item
        out[#out+1]={id="ascendant_"..utilityKey:lower():gsub("[^%w]+","_"),label=utilityKey,group="FEATURES",
          description="Open this Ascendant utility inside the Kanto Rework navigation shell.",presentation=policy,
          open=function()
            local state,err=captureState(game,utilityItem.onSelect);if not state then error(err or (utilityKey.." is unavailable")) end
            return state
          end}
      end
    end
    table.sort(out,function(a,b) if a.id=="ascendant_hub" then return true elseif b.id=="ascendant_hub" then return false end return a.label<b.label end)
    return out
  end
  adapter.ascendant=ascendant.exports
  return adapter
end
