-- Persistent known-move library. Existing Gen 1 saves do not contain a full
-- historical move list, so exact pre-install history cannot be reconstructed.
-- This service records every active move it observes from installation onward;
-- when a move leaves the active set it remains available with its own PP.
return function(deps)
  local mod=assert(deps.mod);local runtime=assert(deps.runtime);local Library={}
  local KEY="known_move_library_v1";local ledger=mod.save:get(KEY,{version=1,mons={}})
  if type(ledger)~="table" then ledger={version=1,mons={}} end;ledger.mons=type(ledger.mons)=="table" and ledger.mons or {}
  local dirty=false
  local function normalizeId(id) return tostring(id or "") end
  local function fingerprint(mon,player)
    local d=mon and mon.dvs or {};local parts={
      tostring(mon and mon.otId or player and player.id or 0),tostring(mon and mon.catchRate or 0),
      tostring(d.attack or d.atk or 0),tostring(d.defense or d.def or 0),tostring(d.speed or 0),tostring(d.special or d.sp or 0),
    }
    return table.concat(parts,":")
  end
  local function copyMove(m)
    return {id=normalizeId(m and m.id),pp=tonumber(m and m.pp) or 0,ppUps=tonumber(m and m.ppUps) or 0}
  end
  local function entryFor(game,mon)
    local key=fingerprint(mon,game and game.save and game.save.player);local e=ledger.mons[key]
    if type(e)~="table" then e={known={},active={},completeBeforeInstall=false};ledger.mons[key]=e;dirty=true end
    e.known=type(e.known)=="table" and e.known or {};e.active=type(e.active)=="table" and e.active or {}
    return e,key
  end
  local function sameSet(a,b)
    local c={};for _,m in ipairs(a or {}) do c[m.id]=(c[m.id] or 0)+1 end
    for _,m in ipairs(b or {}) do c[m.id]=(c[m.id] or 0)-1 end
    for _,n in pairs(c) do if n~=0 then return false end end;return true
  end
  function Library.observe(game,mon)
    if type(mon)~="table" then return false end
    local e=entryFor(game,mon);local now={}
    for i,m in ipairs(mon.moves or {}) do
      local rec=copyMove(m);now[i]=rec
      if rec.id~="" then local old=e.known[rec.id] or {};old.id=rec.id;old.pp=rec.pp;old.ppUps=rec.ppUps;old.lastSource="active";e.known[rec.id]=old end
    end
    if not sameSet(e.active,now) then
      for _,old in ipairs(e.active) do
        if old.id~="" then local rec=e.known[old.id] or {};rec.id=old.id;rec.pp=old.pp;rec.ppUps=old.ppUps;rec.lastSource="observed_history";e.known[old.id]=rec end
      end
      dirty=true
    else
      for i,m in ipairs(now) do local old=e.active[i];if not old or old.id~=m.id or old.pp~=m.pp or old.ppUps~=m.ppUps then dirty=true break end end
    end
    e.active=now
    if dirty then mod.save:set(KEY,ledger);dirty=false end
    return true
  end
  function Library.observeParty(game)
    for _,mon in ipairs(game and game.save and game.save.party or {}) do Library.observe(game,mon) end
  end
  local function activeSet(mon) local s={};for _,m in ipairs(mon and mon.moves or {}) do s[normalizeId(m.id)]=true end;return s end
  function Library.moves(game,mon,includeActive)
    Library.observe(game,mon);local e,key=entryFor(game,mon);local active=activeSet(mon);local out={}
    for id,rec in pairs(e.known) do if includeActive or not active[id] then out[#out+1]={id=id,pp=tonumber(rec.pp) or 0,ppUps=tonumber(rec.ppUps) or 0,disabled=active[id]==true,historySource=rec.lastSource or "observed"} end end
    table.sort(out,function(a,b) return a.id<b.id end)
    return out,{key=key,completeBeforeInstall=e.completeBeforeInstall==true,tracked=true}
  end
  function Library.remember(game,mon,moveId,pp,ppUps,source)
    if type(mon)~="table" then return false,"invalid pokemon" end
    moveId=normalizeId(moveId);if moveId=="" then return false,"invalid move" end
    Library.observe(game,mon)
    local e=entryFor(game,mon);local active
    for _,m in ipairs(mon.moves or {}) do if normalizeId(m.id)==moveId then active=copyMove(m);break end end
    ppUps=math.max(0,tonumber(ppUps) or (active and active.ppUps) or 0)
    local currentPP=tonumber(pp)
    if active then currentPP=active.pp;ppUps=active.ppUps
    elseif currentPP==nil then
      -- nil means the caller has no PP value. An explicit 0 is meaningful for
      -- retroactive learnset reconstruction: historical PP cannot be inferred
      -- from a Gen 1 save and must remain depleted until the player restores it.
      local mdef=game and game.data and game.data.moves and game.data.moves[moveId]
      local base=mdef and tonumber(mdef.pp) or 0
      currentPP=base+ppUps*math.floor(base/5)
    end
    local rec=e.known[moveId] or {id=moveId}
    rec.id=moveId;rec.pp=math.max(0,currentPP or 0);rec.ppUps=ppUps
    rec.lastSource=tostring(source or "learnset_inference");rec.inferred=true
    e.known[moveId]=rec;mod.save:set(KEY,ledger)
    return true
  end

  function Library.recordConfirmed(game,mon,moveId,source)
    if type(mon)~="table" then return false,"invalid pokemon" end
    moveId=normalizeId(moveId);if moveId=="" then return false,"invalid move" end
    Library.observe(game,mon)
    local e=entryFor(game,mon);local current
    for _,m in ipairs(mon.moves or {}) do if normalizeId(m.id)==moveId then current=copyMove(m);break end end
    local rec=e.known[moveId] or {id=moveId,pp=0,ppUps=0}
    if current then rec.pp=current.pp;rec.ppUps=current.ppUps end
    rec.id=moveId;rec.lastSource=tostring(source or "confirmed_event");rec.confirmed=true
    rec.confirmedAt=tonumber(game and game.save and game.save.playTime) or rec.confirmedAt
    e.known[moveId]=rec;mod.save:set(KEY,ledger)
    return true
  end

  function Library.confirmed(game,mon,includeActive)
    local out,meta=Library.moves(game,mon,includeActive)
    for _,row in ipairs(out) do row.confirmed=true end
    meta.claim="confirmed_observation_history"
    return out,meta
  end

  function Library.replace(game,mon,activeIndex,learnedId)
    if type(mon)~="table" or type(mon.moves)~="table" or not mon.moves[activeIndex] then return false,"invalid active slot" end
    Library.observe(game,mon);local e=entryFor(game,mon);local incoming=e.known[normalizeId(learnedId)]
    if not incoming then return false,"move is not in the observed library" end
    for _,m in ipairs(mon.moves) do if m.id==incoming.id then return false,"move is already active" end end
    local outgoing=copyMove(mon.moves[activeIndex]);e.known[outgoing.id]={id=outgoing.id,pp=outgoing.pp,ppUps=outgoing.ppUps,lastSource="replaced"}
    mon.moves[activeIndex]={id=incoming.id,pp=tonumber(incoming.pp) or 0,ppUps=tonumber(incoming.ppUps) or 0}
    incoming.lastSource="active";e.known[incoming.id]=incoming;e.active={};dirty=true;Library.observe(game,mon);mod.save:set(KEY,ledger)
    return true,outgoing
  end
  function Library.status(game,mon)
    local _,meta=Library.moves(game,mon,false);local count=0;local e=ledger.mons[meta.key];for _ in pairs(e and e.known or {}) do count=count+1 end
    return {tracked=true,known=count,completeBeforeInstall=false,note="Confirmed history starts from moves observed active after KRS installation; exact pre-install history is not recoverable from a Gen 1 save."}
  end
  return Library
end
