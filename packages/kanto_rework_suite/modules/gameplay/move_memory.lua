-- Kanto Move Memory gameplay adapter for Gen1Recomp 0.1.90.
-- The engine remains authoritative for acquisition timing/items. KRS changes
-- only the full-moveset policy and extends PP item targeting to confirmed
-- remembered moves outside battle.
return function(deps)
  local mod=deps.mod;local Core=assert(deps.Core);local Game=assert(deps.Game)
  local MoveLearnMenu=require('src.ui.MoveLearnMenu')
  local PartyMenu=require('src.ui.PartyMenu')
  local ListMenu=require('src.ui.ListMenu')
  local ItemEffects=require('src.inventory.ItemEffects')
  local TextBox=require('src.render.TextBox')
  local Sound=require('src.core.Sound')
  local originals={enter=MoveLearnMenu.enter,partyNew=PartyMenu.new,listNew=ListMenu.new,itemUse=ItemEffects.use}
  local installed=true;local pendingMon,pendingAllowKnown
  local subscriptions={}
  local migrationStats={runs=0,mons=0,added=0,uncertainEvolution=0,lastReason=nil}
  local function remembered(mon)
    if type(Core.knownMoves)~='function' then return {} end
    local ok,rows=pcall(Core.knownMoves,mon,false);return ok and type(rows)=='table' and rows or {}
  end

  -- Retroactive reconstruction now follows the user's requested policy:
  -- remember every move learned by level-up up to the Pokémon's current level,
  -- including the current species and every reachable pre-evolution species.
  -- TM/HM/tutor/event moves are still excluded because they are not part of the
  -- level-up learnset. A newly inferred inactive move starts at 0 PP because no
  -- historical PP value is recoverable; active/already remembered rows keep
  -- their exact PP/PP Ups.
  local function possiblePreEvolutionSpecies(game,species)
    local pokemon=game and game.data and game.data.pokemon
    if type(pokemon)~='table' then return {} end
    local out={}
    for candidateId,candidate in pairs(pokemon) do
      for _,evo in ipairs(type(candidate)=='table' and candidate.evolutions or {}) do
        if type(evo)=='table' and tostring(evo.species or '')==tostring(species or '') then
          out[#out+1]=tostring(candidateId)
          break
        end
      end
    end
    table.sort(out)
    return out
  end
  local function inferLevelMoves(game,mon)
    local out,seen={},{}
    if type(game)~='table' or type(mon)~='table' then return out,{reliable=false,reason='invalid_mon'} end
    local defs=game.data and game.data.pokemon
    local def=defs and defs[mon.species]
    if type(def)~='table' then return out,{reliable=false,reason='missing_species'} end
    local function add(id)
      id=tostring(id or '')
      if id~='' and not seen[id] and game.data and game.data.moves and game.data.moves[id] then
        seen[id]=true;out[#out+1]=id
      end
    end
    local function addSpeciesMoves(species,level)
      local speciesDef=defs and defs[species]
      if type(speciesDef)~='table' then return false end
      for _,id in ipairs(speciesDef.level1Moves or {}) do add(id) end
      for _,entry in ipairs(speciesDef.learnset or {}) do
        if type(entry)=='table' and (tonumber(entry.level) or math.huge)<=level then
          add(entry.move or entry.id or entry[2])
        end
      end
      return true
    end
    local function walkAncestors(species,visit)
      species=tostring(species or '')
      if species=='' or visit[species] then return end
      visit[species]=true
      local parents=possiblePreEvolutionSpecies(game,species)
      for _,parent in ipairs(parents) do
        walkAncestors(parent,visit)
        addSpeciesMoves(parent,math.max(1,tonumber(mon.level) or 1))
      end
    end
    local level=math.max(1,tonumber(mon.level) or 1)
    walkAncestors(mon.species,{})
    addSpeciesMoves(mon.species,level)
    local parents=possiblePreEvolutionSpecies(game,mon.species)
    return out,{reliable=true,reason='current_species_plus_pre_evolutions_levelup',preEvolutionHistoryUnknown=#parents>0,preEvolutionCount=#parents}
  end
  local function migrateMon(game,mon)
    if type(mon)~='table' or type(Core.knownMoves)~='function' or type(Core.rememberKnownMove)~='function' then return 0 end
    local known={}
    local ok,rows=pcall(Core.knownMoves,mon,true)
    if ok and type(rows)=='table' then for _,mv in ipairs(rows) do if type(mv)=='table' and mv.id then known[tostring(mv.id)]=true end end end
    for _,mv in ipairs(mon.moves or {}) do if type(mv)=='table' and mv.id then known[tostring(mv.id)]=true end end
    local inferred,meta=inferLevelMoves(game,mon)
    local added=0
    for _,moveId in ipairs(inferred) do
      if not known[moveId] then
        local rememberedOk=Core.rememberKnownMove(mon,moveId,0,0,'retroactive_current_species_levelup')
        if rememberedOk then known[moveId]=true;added=added+1 end
      end
    end
    return added,meta
  end
  local function migrateAll(game,reason)
    game=game or Game
    local save=game and game.save
    if type(save)~='table' then return {mons=0,added=0,reason=reason} end
    local mons,added,uncertainEvolution=0,0,0
    local function one(mon)
      if type(mon)=='table' then
        mons=mons+1;local n,meta=migrateMon(game,mon);added=added+(tonumber(n) or 0)
        if meta and meta.preEvolutionHistoryUnknown then uncertainEvolution=uncertainEvolution+1 end
      end
    end
    for _,mon in ipairs(save.party or {}) do one(mon) end
    -- Use the engine's current storage access point when available. KRS patches
    -- Boxes.ensure earlier in the gameplay bootstrap (20 x 180), so this also
    -- migrates legacy `save.box` data and every box exposed by the active storage
    -- system without duplicating storage rules in Move Memory.
    local boxes=save.boxes or {}
    local okBoxes,Boxes=pcall(require,'src.pokemon.Boxes')
    if okBoxes and type(Boxes)=='table' and type(Boxes.ensure)=='function' then
      local okEnsured,ensured=pcall(Boxes.ensure,save)
      if okEnsured and type(ensured)=='table' then boxes=ensured end
    end
    for _,box in ipairs(boxes) do if type(box)=='table' then for _,mon in ipairs(box) do one(mon) end end end
    migrationStats.runs=migrationStats.runs+1;migrationStats.mons=mons;migrationStats.added=added;migrationStats.uncertainEvolution=uncertainEvolution;migrationStats.lastReason=reason
    return {mons=mons,added=added,uncertainEvolution=uncertainEvolution,reason=reason}
  end
  if mod and mod.events and type(mod.events.on)=='function' then
    subscriptions[#subscriptions+1]=mod.events:on('game.ready',function(payload) migrateAll(payload and payload.game or Game,'game.ready') end)
    subscriptions[#subscriptions+1]=mod.events:on('save.loaded',function(payload) migrateAll((payload and payload.game) or Game,'save.loaded') end)
  end
  if Game and Game.save then migrateAll(Game,'install') end
  MoveLearnMenu.enter=function(self,...)
    if type(self.mon)=='table' and #(self.mon.moves or {})>=4 and self.newMoveId then
      for _,mv in ipairs(self.mon.moves or {}) do if mv.id==self.newMoveId then return originals.enter(self,...) end end
      local def=self.game.data.moves[self.newMoveId];local pp=def and def.pp or 0
      if type(Core.rememberKnownMove)=='function' then Core.rememberKnownMove(self.mon,self.newMoveId,pp,0,'learned_full_moveset') end
      local name=self.mon.nickname or (self.game.data.pokemon[self.mon.species] or {}).name or 'POKéMON';local moveName=def and def.name or self.newMoveId
      self.selecting=false
      self.game.stack:push(TextBox.new(self.game,name..' learned\n'..moveName..'!\fIt was added to\nMOVE MEMORY.',function()
        if self.game.stack:top()==self then self.game.stack:pop() end
        if self.onDone then self.onDone(true) end
      end,TextBox.soundOpts(self.game,self.learnedSound or 'Get_Item1')))
      return
    end
    return originals.enter(self,...)
  end
  PartyMenu.new=function(game,opts,...)
    if type(opts)=='table' and opts.pickOnly and type(opts.onSwitch)=='function' then
      local copy={};for k,v in pairs(opts) do copy[k]=v end;local cb=opts.onSwitch
      copy.onSwitch=function(mon,...)
        pendingMon=mon;pendingAllowKnown=not copy.battle
        local result={cb(mon,...)};pendingMon,pendingAllowKnown=nil,nil
        return (table.unpack or unpack)(result)
      end
      return originals.partyNew(game,copy,...)
    end
    return originals.partyNew(game,opts,...)
  end
  ListMenu.new=function(game,title,rows,opts,...)
    if pendingMon and pendingAllowKnown and tostring(title)=='Which move?' and type(rows)=='table' then
      local seen={};for _,row in ipairs(rows) do local mv=pendingMon.moves and pendingMon.moves[row.value];if mv then seen[mv.id]=true end end
      for _,mv in ipairs(remembered(pendingMon)) do if not seen[mv.id] then local def=game.data.moves[mv.id];rows[#rows+1]={value={krsKnownMove=mv.id},label=def and def.name or mv.id,right=tostring(mv.pp or 0),krsRemembered=true} end end
    end
    return originals.listNew(game,title,rows,opts,...)
  end
  ItemEffects.use=function(data,save,itemId,target,battle,moveIndex,ow,...)
    local rememberedId=type(moveIndex)=='table' and moveIndex.krsKnownMove or nil
    if rememberedId and target and not battle then
      if itemId=='ETHER' or itemId=='MAX_ETHER' then
        local ok=Core.restoreKnownMovePP and Core.restoreKnownMovePP(target,rememberedId,10,itemId=='MAX_ETHER')
        return ok and 'consumed' or 'failed',{ok and 'PP was restored.' or "It won't have any effect."}
      elseif itemId=='PP_UP' then
        local ok=Core.ppUpKnownMove and Core.ppUpKnownMove(target,rememberedId)
        return ok and 'consumed' or 'failed',{ok and 'PP increased.' or "It won't have any effect."}
      end
    end
    local result={originals.itemUse(data,save,itemId,target,battle,moveIndex,ow,...)}
    if target and not battle and (itemId=='ELIXER' or itemId=='MAX_ELIXER') and type(Core.knownMoves)=='function' then
      local any=result[1]~='failed';for _,mv in ipairs(remembered(target)) do local ok=Core.restoreKnownMovePP and Core.restoreKnownMovePP(target,mv.id,10,itemId=='MAX_ELIXER');any=ok or any end
      if any and result[1]=='failed' then result={'consumed',{'PP was restored.'}} end
    end
    return (table.unpack or unpack)(result)
  end
  return {
    status=function() return {installed=installed,policy='confirmed_permanent_memory',battleSwap=false,ppPersistent=true,migration=migrationStats} end,
    migrate=function(game,reason) return migrateAll(game or Game,reason or 'manual') end,
    inferLevelMoves=inferLevelMoves,
    uninstall=function()
      if not installed then return false end;installed=false
      for _,unsub in ipairs(subscriptions) do if type(unsub)=='function' then pcall(unsub) end end
      subscriptions={}
      if MoveLearnMenu.enter~=originals.enter then MoveLearnMenu.enter=originals.enter end
      if PartyMenu.new~=originals.partyNew then PartyMenu.new=originals.partyNew end
      if ListMenu.new~=originals.listNew then ListMenu.new=originals.listNew end
      if ItemEffects.use~=originals.itemUse then ItemEffects.use=originals.itemUse end
      return true
    end,
  }
end
