return function(options)
  local Fixture=assert(options.Fixture)
  local Core=options.Core or {}
  local PokemonArt=assert(options.PokemonArt,"PokemonArt service is required")
  local Graphics=options.Graphics
  local PokemonName=options.PokemonName or function(value,species)return tostring(value or species or "POKéMON") end
  local Adapter={};local imageCache={};local internal={}
  local function safeRequire(name)
    if internal[name]~=nil then return internal[name] or nil end
    local ok,value=pcall(require,name);internal[name]=ok and value or false;return ok and value or nil
  end
  local function topState(game) local stack=game and game.stack;return stack and type(stack.top)=="function" and stack:top() or nil end
  local function normalizeType(value)
    value=tostring(value or ""):upper()
    if value=="PSYCH_TYPE" or value=="PSYCHIC_TYPE" or value=="PSYCH" then return "PSYCHIC" end
    value=value:gsub("_TYPE$","")
    if value=="PSYCH" then value="PSYCHIC" end
    return value~="" and value or "UNKNOWN"
  end
  local function partyShape(state)
    return type(state)=="table" and type(state.index)=="number" and state.items==nil and state.rows==nil and
      (type(state.bottomMessage)=="function" or state.subItems~=nil or state.pickOnly~=nil or state.tmhm~=nil or state.onSwitch~=nil or state.swapFrom~=nil)
  end
  function Adapter.topState(game) return topState(game) end
  function Adapter.isNativeParty(state) return partyShape(state) end
  function Adapter.kind(game) local state=topState(game);if type(state)=="table" and state.__kantoPartyUi then return "kanto_party",state end;if partyShape(state) then return "native_party",state end;return nil,state end
  function Adapter.canReplaceParty(state)
    if not partyShape(state) or state.submenu or state.heal or state.tmhm or state.pickOnly or state.softboiledFrom then return false end
    -- Battle Party is safe when the native picker exposes onSwitch; KRS owns
    -- only its Wide controller/presentation and forwards the selected mon to
    -- the engine callback unchanged.
    if state.battle then return type(state.onSwitch)=="function" end
    return not state.forceSwitch
  end
  function Adapter.party(game,state) return (state and state.party) or (game and game.save and game.save.party) or {} end
  function Adapter.speciesDef(game,mon) return game and game.data and game.data.pokemon and mon and game.data.pokemon[mon.species] or nil end
  function Adapter.moveDef(game,id) return game and game.data and game.data.moves and game.data.moves[id] or nil end
  function Adapter.maxPP(def,move) local base=type(def)=="table" and tonumber(def.pp) or nil;if not base then return nil end;return base+math.max(0,tonumber(move and move.ppUps) or 0)*math.floor(base/5) end
  local PHYSICAL={NORMAL=true,FIGHTING=true,FLYING=true,POISON=true,GROUND=true,ROCK=true,BUG=true,GHOST=true}
  local function description(game,move,def)
    for _,key in ipairs({"description","desc","summary","text"}) do local v=def and def[key];if type(v)=="string" and v~="" then return v,"move_def."..key end end
    if type(Core.moveDescription)=="function" then local ok,v,source=pcall(Core.moveDescription,def,move and move.id);if ok and type(v)=="string" and v~="" then return v,source or "kanto_rework_core" end end
    return "Move description unavailable.","fallback"
  end
  function Adapter.moveModel(game,move)
    if type(move)~="table" then return nil end
    local def=Adapter.moveDef(game,move.id) or {};local desc,source=description(game,move,def);local power=tonumber(def.power) or 0
    local moveType=normalizeType(def.type);local explicit=tostring(def.category or def.damageClass or ""):upper();local category
    if explicit~="" then category=explicit elseif power<=0 then category="STATUS" else category=PHYSICAL[moveType] and "PHYSICAL" or "SPECIAL" end
    return {id=move.id,name=tostring(def.name or move.id or "UNKNOWN"),type=moveType,category=category,power=power>0 and power or nil,accuracy=tonumber(def.accuracy or def.acc),pp=tonumber(move.pp),maxPP=Adapter.maxPP(def,move),description=desc,descriptionSource=source,source=move,disabled=move.disabled==true,developmentFixture=move.developmentFixture==true}
  end
  function Adapter.frontSprite(game,mon)
    if not (game and mon) then return nil,"missing pokemon" end
    local art=PokemonArt:image(game,mon.species,"front",{mon=mon,kind="party"})
    if not art then return nil,"front sprite path unavailable" end
    return art.image,nil,art
  end
  function Adapter.drawPartyIcon(game,mon,x,y,size)
    -- Party list icons are presentation assets, not battle sprites. Prefer the
    -- KRS Graphics Gen5 two-frame sheet and fall back to the engine icon only
    -- when the registry has no matching species/form.
    if Graphics and type(Graphics.draw)=="function" then
      local ok,drawn=pcall(Graphics.draw,Graphics,"party.icon",game,mon,x,y,size or 64,size or 64)
      if ok and drawn==true then return true end
    end
    local PartyMenu=safeRequire("src.ui.PartyMenu");if not (PartyMenu and type(PartyMenu.drawIcon)=="function") then return false end
    local scale=(size or 64)/16;love.graphics.push("all");love.graphics.translate(x,y);love.graphics.scale(scale,scale);local ok,result=pcall(PartyMenu.drawIcon,game,mon,0,0,false,0,false);love.graphics.pop();return ok and result~=false
  end
  local function expValues(game,mon,def)
    if not (mon and def and tonumber(mon.exp) and tonumber(mon.level)) then return nil,nil,nil end
    local Growth=safeRequire("src.pokemon.Growth");if not (Growth and type(Growth.expForLevel)=="function") then return nil,nil,nil end
    local level=tonumber(mon.level);if level>=100 then return mon.exp,0,1 end
    local ok0,base=pcall(Growth.expForLevel,def.growthRate,level);local ok1,nextExp=pcall(Growth.expForLevel,def.growthRate,level+1)
    if not (ok0 and ok1 and type(base)=="number" and type(nextExp)=="number") then return nil,nil,nil end
    local current=math.max(0,tonumber(mon.exp)-base);local total=math.max(1,nextExp-base);return current,math.max(0,nextExp-tonumber(mon.exp)),math.min(1,current/total)
  end
  function Adapter.pokemon(game,mon)
    local def=Adapter.speciesDef(game,mon) or {};local moves={};for i=1,4 do moves[i]=Adapter.moveModel(game,mon and mon.moves and mon.moves[i]) end
    local types={};for _,value in ipairs(def.types or {}) do types[#types+1]=normalizeType(value) end
    local trainer=type(Core.trainerModel)=="function" and Core.trainerModel() or {};local expWithin,toNext,expRatio=expValues(game,mon,def)
    local nickname=mon and mon.nickname
    return {source=mon,species=mon and mon.species,dex=def.dex,name=PokemonName(nickname or def.name or (mon and mon.species),mon and mon.species,def,nickname~=nil),level=tonumber(mon and mon.level) or 0,status=mon and mon.status,hp=tonumber(mon and mon.hp) or 0,stats=mon and mon.stats or {},types=types,ot=(mon and mon.ot) or trainer.name,otId=(mon and mon.otId) or trainer.id,exp=tonumber(mon and mon.exp),expWithinLevel=expWithin,toNextLevel=toNext,expRatio=expRatio,moves=moves,dvs=mon and mon.dvs,statExp=mon and mon.statExp,heldItem=nil,ability=nil,modernIVAvailable=false,modernEVAvailable=false}
  end
  local function actualLearned(game,pokemon)
    if type(Core.knownMoves)~="function" or not (pokemon and pokemon.source) then return {},{available=false,source="none"} end
    local ok,rows,meta=pcall(Core.knownMoves,pokemon.source,true);if not ok or type(rows)~="table" then return {},{available=false,source="core-error"} end
    local out={};for _,raw in ipairs(rows) do local model=Adapter.moveModel(game,raw);if model then model.disabled=raw.disabled==true;out[#out+1]=model end end
    local extras=0;for _,m in ipairs(out) do if not m.disabled then extras=extras+1 end end
    return out,{available=extras>0,source="core-known-library",completeBeforeInstall=meta and meta.completeBeforeInstall==true,tracked=true}
  end
  function Adapter.learnedMoves(game,pokemon,fixtureEnabled)
    local out,meta=actualLearned(game,pokemon);if #out>0 then return out,meta end
    if fixtureEnabled then
      for _,raw in ipairs(Fixture.learnedMoves(game,pokemon and pokemon.source and pokemon.source.moves or {})) do local model=Adapter.moveModel(game,raw);if model then model.developmentFixture=true;out[#out+1]=model end end
      return out,{available=#out>0,source="development-fixture",development=true}
    end
    return {},meta
  end
  function Adapter.replaceLearnedMove(game,mon,activeIndex,moveId)
    if type(Core.replaceKnownMove)~="function" then return false,"known-move provider unavailable" end
    return Core.replaceKnownMove(mon,activeIndex,moveId)
  end
  function Adapter.reorderParty(game,partyState,fromIndex,toIndex)
    local party=Adapter.party(game,partyState);if not Adapter.canReplaceParty(partyState) or partyState.battle then return false,"unsafe party context" end
    if not party[fromIndex] or not party[toIndex] or fromIndex==toIndex then return false,"invalid target" end
    party[fromIndex],party[toIndex]=party[toIndex],party[fromIndex];partyState.index=toIndex;if game then game.partyMenuSavedIndex=toIndex end;pcall(function() require("src.core.Sound").play(game.data,"Swap") end);return true
  end
  function Adapter.reorderMoves(game,mon,fromIndex,toIndex)
    local moves=mon and mon.moves;if type(moves)~="table" or not moves[fromIndex] or not moves[toIndex] or fromIndex==toIndex then return false,"invalid move target" end
    local moving=table.remove(moves,fromIndex);table.insert(moves,toIndex,moving);pcall(function() require("src.core.Sound").play(game.data,"Swap") end);return true
  end
  function Adapter.popNativeParty(game,partyState,notifyCancel)
    local stack=game and game.stack;if not (stack and type(stack.top)=="function") then return false end
    if stack:top()==partyState then stack:pop() end
    if notifyCancel and type(partyState and partyState.onCancel)=="function" then
      local ok,err=pcall(partyState.onCancel);if not ok then return false,tostring(err) end
    end
    return true
  end
  function Adapter.closeNativeParty(game,partyState) return Adapter.popNativeParty(game,partyState,true) end
  return Adapter
end
