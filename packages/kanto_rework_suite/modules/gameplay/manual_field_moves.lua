-- Manual TM/field actions added to the KRS Field Actions popup.
-- Native Gen1 semantics are reused for Dig/Teleport/Softboiled. Sweet Scent
-- is additive and only becomes available when a loaded dataset actually
-- provides that move and a local encounter table.
return function(deps)
  local mod=assert(deps.mod);local Core=assert(deps.Core);local Game=assert(deps.Game)
  local Map=require('src.world.Map')
  local FieldDefaults=require('src.world.FieldDefaults')
  local PartyMenu=require('src.ui.PartyMenu')
  local Encounter=require('src.world.Encounter')
  local BattleState=require('src.battle.BattleState')
  local registrations={}
  local DIG_TILESETS={FOREST=true,CEMETERY=true,CAVERN=true,FACILITY=true,INTERIOR=true}

  local function game(context) return (context and context.game) or Game end
  local function ow(context) local g=game(context);return (context and context.overworld) or (g and g.overworld) end
  local function topIsWorld(g,o) return g and o and g.stack and g.stack:top()==o end
  local function findMoveUser(g,id)
    id=tostring(id or '')
    for i,mon in ipairs(g.save and g.save.party or {}) do
      for _,mv in ipairs(mon.moves or {}) do if tostring(type(mv)=='table' and mv.id or mv)==id then return mon,i,'active' end end
      if type(Core.knownMoves)=='function' then
        local ok,known=pcall(Core.knownMoves,mon,true)
        if ok and type(known)=='table' then
          for _,mv in ipairs(known) do if tostring(mv and mv.id or '')==id then return mon,i,'memory' end end
        end
      end
    end
  end
  local function moveRequirement(id)
    return function(context)
      local g=game(context);local mon,index,source=findMoveUser(g,id)
      if not mon then return {ok=false,reason='move_not_known',move=id} end
      return {ok=true,move=id,pokemon=index,capabilitySource=source}
    end
  end
  local function moveExists(g,id) return g and g.data and g.data.moves and g.data.moves[id]~=nil end
  local function baseReady(context,id)
    local g,o=game(context),ow(context)
    if not topIsWorld(g,o) and not (context and context.fieldPopup==true) then return nil,nil,'not_overworld' end
    local mon,index=findMoveUser(g,id)
    if not mon then return nil,nil,'move_not_known' end
    return mon,index,nil
  end

  local function escapeAvailability(id,kind)
    return function(context)
      local g,o=game(context),ow(context);local mon,index,reason=baseReady(context,id)
      if not mon then return {available=false,reason=reason} end
      if kind=='teleport' then
        local outside=Map.isOutside(o.map.def,FieldDefaults.field(g.data,'outsideTilesets'))
        return {available=outside,reason=outside and nil or 'outdoors_only',pokemon=index}
      end
      local ok=DIG_TILESETS[o.map.def.tileset] and o.map.id~='AGATHAS_ROOM'
      return {available=ok,reason=ok and nil or 'escape_unavailable',pokemon=index}
    end
  end
  local function escapeExecute(context)
    local o=ow(context);if not o then return false,'no_overworld' end
    o:beginTeleportOut();return true,'teleporting'
  end

  local function softAvailability(context)
    local g=game(context);local mon,index,reason=baseReady(context,'SOFTBOILED')
    if not mon then return {available=false,reason=reason} end
    local stats=mon.stats;local heal=stats and math.floor((stats.hp or 0)/5) or 0
    local hasTarget=false
    for i,target in ipairs(g.save.party or {}) do if i~=index and (target.hp or 0)>0 and target.stats and target.hp<target.stats.hp then hasTarget=true break end end
    local ok=heal>0 and (mon.hp or 0)>heal and hasTarget
    return {available=ok,reason=ok and nil or 'no_valid_transfer',pokemon=index,amount=heal}
  end
  local function softExecute(context)
    local g=game(context);local _,index=baseReady(context,'SOFTBOILED')
    if not index then return false,'move_not_known' end
    local menu=PartyMenu.new(g);menu.softboiledFrom=index;g.stack:push(menu);return true,'choose_target'
  end

  local function sweetContext(g,o)
    local encDef=g and g.data and g.data.encounters and o and g.data.encounters[o.map.id]
    if not encDef then return nil,nil end
    local p=o.player
    if p and p.surfing and encDef.water and o.map:isWaterCell(p.cellX,p.cellY) then return encDef.water,'water' end
    if p and o.map:isGrassCell(p.cellX,p.cellY) then return encDef.grass,'grass' end
    local indoor=g.data.field.indoorEncounters
    if indoor and o.map.def.index and o.map.def.index>=indoor.firstIndoorMap and o.map.def.tileset~=indoor.excludedTileset then return encDef.grass,'indoor' end
    return nil,nil
  end
  local function sweetAvailability(context)
    local g,o=game(context),ow(context)
    if not moveExists(g,'SWEET_SCENT') then return {available=false,reason='move_not_defined'} end
    local mon,index,reason=baseReady(context,'SWEET_SCENT');if not mon then return {available=false,reason=reason} end
    local grass,terrain=sweetContext(g,o);return {available=grass~=nil,reason=grass and nil or 'no_encounters_here',pokemon=index,terrain=terrain}
  end
  local function sweetExecute(context)
    local g,o=game(context),ow(context);local grass,terrain=sweetContext(g,o);if not grass then return false,'no_encounters_here' end
    local forced={};for k,v in pairs(grass) do forced[k]=v end;forced.rate=256
    local enc=o:rollEncounter({grass=forced},terrain)
    if not enc then return false,'no_encounter' end
    local battle=BattleState.newWild(g,enc.species,enc.level)
    battle.checkpointOrigin={kind='wild_encounter',map=o.map.id}
    battle.onFinish=function(result) o:afterBattle(result,battle) end
    o:pushBattle(battle);return true,'encounter'
  end

  local defs={
    {id='kanto.teleport',label='TELEPORT',desc='Return to last Pokémon Center',priority=260,availability=escapeAvailability('TELEPORT','teleport'),execute=escapeExecute},
    {id='kanto.dig',label='DIG',desc='Escape from caves instantly',priority=250,availability=escapeAvailability('DIG','dig'),execute=escapeExecute},
    {id='kanto.softboiled',label='SOFTBOILED',desc='Transfer HP to another Pokémon',priority=240,availability=softAvailability,execute=softExecute},
    {id='kanto.sweet_scent',label='SWEET SCENT',desc='Attract wild Pokémon nearby',priority=230,availability=sweetAvailability,execute=sweetExecute},
  }
  for _,d in ipairs(defs) do
    registrations[#registrations+1]=Core.fieldActions.register({id=d.id,label=d.label,description=d.desc,source=mod.id,trigger='manual',priority=d.priority,
      requirements=moveRequirement(d.label=='SWEET SCENT' and 'SWEET_SCENT' or d.label),availability=d.availability,execute=d.execute})
  end
  return {unregister=function() for i=#registrations,1,-1 do pcall(registrations[i]) end end,status=function() return {installed=true,actions=defs} end}
end
