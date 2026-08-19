-- Data-only models for the two retained product overlays. Drawing and
-- interaction stay in components/modular_overlays.lua.
return function(PokemonName)
  PokemonName=PokemonName or function(value,species)return tostring(value or species or "POKéMON") end
  local M={}
  local BALL_ORDER={"MASTER_BALL","ULTRA_BALL","GREAT_BALL","POKE_BALL","SAFARI_BALL"}
  local FALLBACK_BUCKETS={51,102,141,166,191,216,229,242,253,256}

  local function context(game)
    local stack=game and game.stack;local top=stack and type(stack.top)=="function" and stack:top() or nil
    if top and (top.kind=="overlay_context" or top.kind=="overlay_layout" or top.kind=="overlay_editor")
        and type(stack.states)=="table" then top=stack.states[#stack.states-1] end
    return top
  end
  M.context=context

  local function encounterGroup(game,id,group)
    if type(group)~="table" or (tonumber(group.rate) or 0)<=0
        or type(group.slots)~="table" or #group.slots==0 then return nil end
    local buckets=group.buckets or (game.data.constants and game.data.constants.encounterBuckets) or FALLBACK_BUCKETS
    local bySpecies={};local previous=0
    for i,slot in ipairs(group.slots) do
      local threshold=math.max(previous,math.min(256,tonumber(buckets[i]) or 256))
      local weight=threshold-previous;previous=threshold
      if slot and slot.species and weight>0 then
        local row=bySpecies[slot.species]
        if not row then
          local def=game.data.pokemon and game.data.pokemon[slot.species] or {}
          row={species=slot.species,name=PokemonName(def.name or slot.species,slot.species,def,false),
            weight=0,minLevel=tonumber(slot.level) or 1,maxLevel=tonumber(slot.level) or 1}
          bySpecies[slot.species]=row
        end
        row.weight=row.weight+weight
        row.minLevel=math.min(row.minLevel,tonumber(slot.level) or row.minLevel)
        row.maxLevel=math.max(row.maxLevel,tonumber(slot.level) or row.maxLevel)
      end
    end
    local owned=game.save and game.save.pokedex and game.save.pokedex.owned or {};local rows={}
    for _,row in pairs(bySpecies) do
      row.percent=row.weight/256*100;row.caught=owned[row.species]==true;rows[#rows+1]=row
    end
    table.sort(rows,function(a,b)
      if a.caught~=b.caught then return a.caught==false end
      if a.percent~=b.percent then return a.percent>b.percent end
      return a.name<b.name
    end)
    if #rows==0 then return nil end
    return {id=id,label=id=="water" and "SURF" or "HIERBA",
      stepPercent=(tonumber(group.rate) or 0)/256*100,rows=rows}
  end

  local BALL_SPANISH={
    MASTER_BALL="MASTER BALL",
    ULTRA_BALL="ULTRA BALL",
    GREAT_BALL="SUPER BALL",
    POKE_BALL="POKÉ BALL",
    SAFARI_BALL="SAFARI BALL",
  }

  function M.encounters(game)
    local ow=game and game.overworld;local mapId=ow and ow.map and ow.map.id
    local def=mapId and game.data and game.data.encounters and game.data.encounters[mapId]
    if type(def)~="table" then return nil end
    local groups={};local grass=encounterGroup(game,"grass",def.grass);local water=encounterGroup(game,"water",def.water)
    if grass then groups[#groups+1]=grass end;if water then groups[#groups+1]=water end
    if #groups==0 then return nil end
    local caught,total=0,0;local speciesSeen={}
    for _,group in ipairs(groups) do for _,row in ipairs(group.rows) do
      if not speciesSeen[row.species] then
        speciesSeen[row.species]=true;total=total+1;if row.caught then caught=caught+1 end
      end
    end end
    return {mapId=mapId,groups=groups,caught=caught,total=total}
  end

  local function stockChance(ballDef,mon,speciesDef,statuses,rateOverride)
    if not (ballDef and mon and speciesDef and mon.stats) then return nil end
    if ballDef.autoCatch then return 100 end
    if type(ballDef.attempt)=="function" then return nil end
    local randMax=tonumber(ballDef.randMax);if not randMax then return nil end
    local statusRecord=mon.status and statuses and statuses[mon.status] or nil
    local statusBonus=tonumber(statusRecord and statusRecord.catchBonus) or 0
    local maxhp=math.max(1,tonumber(mon.stats.hp) or 1);local hpQuarter=math.max(1,math.floor((tonumber(mon.hp) or 0)/4))
    local factor=tonumber(ballDef.hpFactor) or 12
    local f=math.min(255,math.floor(math.floor(maxhp*255/factor)/hpQuarter))
    local rate=math.max(0,math.min(255,tonumber(rateOverride or speciesDef.catchRate) or 0))
    local rolls=randMax+1;local automatic=math.min(rolls,math.max(0,statusBonus))
    local lastPassing=math.min(randMax,rate+statusBonus);local secondStage=math.max(0,lastPassing-statusBonus+1)
    return (automatic/rolls+secondStage/rolls*((f+1)/256))*100
  end

  function M.capture(game)
    local battle=context(game)
    if not (battle and battle.kind=="wild" and battle.enemy and battle.enemy.mon and battle.enemy.def) then return nil end
    if battle.demo or battle.oakDemo or battle.ghostReal then return nil end
    local inventory=game.save and game.save.inventory or {};local rows={};local safari=battle.safari~=nil
    for _,id in ipairs(BALL_ORDER) do
      local quantity=safari and id=="SAFARI_BALL" and tonumber(battle.safari and battle.safari.balls) or tonumber(inventory[id])
      if quantity and quantity>0 and (not safari or id=="SAFARI_BALL") then
        local def=type(battle.ballDef)=="function" and battle:ballDef(id) or nil
        local chance=stockChance(def,battle.enemy.mon,battle.enemy.def,battle.data and battle.data.statuses,
          safari and battle.safariCatchRate or nil)
        rows[#rows+1]={id=id,label=BALL_SPANISH[id] or id:gsub("_"," "),quantity=quantity,chance=chance}
      end
    end
    table.sort(rows,function(a,b)
      local ac,bc=tonumber(a.chance),tonumber(b.chance)
      if ac and bc and ac~=bc then return ac>bc end
      if ac and not bc then return true end;if bc and not ac then return false end
      return a.label<b.label
    end)
    return {battle=battle,species=battle.enemy.mon.species,mon=battle.enemy.mon,
      name=PokemonName(battle.enemy.name or battle.enemy.def.name or battle.enemy.mon.species,
        battle.enemy.mon.species,battle.enemy.def,battle.enemy.mon.nickname~=nil),
      hp=tonumber(battle.enemy.mon.hp) or 0,maxHp=tonumber(battle.enemy.mon.stats and battle.enemy.mon.stats.hp) or 1,
      status=battle.enemy.mon.status,rows=rows,safari=safari}
  end

  return M
end
