-- Theoretical relearn set. This service is intentionally separate from the
-- confirmed move history: it answers what the data/rules imply could be
-- relearnable, never what the Pokemon was actually observed learning.
return function(deps)
  local runtime=assert(deps.runtime,"runtime is required")
  local service={}
  local function clampLevel(v) v=math.floor(tonumber(v) or 1);return math.max(1,math.min(100,v)) end
  local function reverseEvolutions(game)
    local reverse={}
    for speciesId,def in pairs(game and game.data and game.data.pokemon or {}) do
      for _,evo in ipairs(def.evolutions or {}) do
        if evo.species then
          reverse[evo.species]=reverse[evo.species] or {}
          reverse[evo.species][#reverse[evo.species]+1]=speciesId
        end
      end
    end
    return reverse
  end
  local function lineage(game,speciesId)
    local reverse=reverseEvolutions(game);local out,seen={},{}
    local function visit(id)
      if not id or seen[id] then return end;seen[id]=true
      for _,parent in ipairs(reverse[id] or {}) do visit(parent) end
      out[#out+1]=id
    end
    visit(speciesId);return out
  end
  function service.moves(game,mon)
    game=game or runtime.game
    if type(mon)~="table" then return {},{inferred=true,reason="invalid_pokemon"} end
    local level=clampLevel(mon.level);local known,order={},{}
    local function add(id,source)
      id=tostring(id or "");if id=="" or known[id] then return end
      known[id]=source or true;order[#order+1]={id=id,source=source}
    end
    for _,speciesId in ipairs(lineage(game,mon.species)) do
      local def=game and game.data and game.data.pokemon and game.data.pokemon[speciesId]
      if def then
        for _,id in ipairs(def.level1Moves or {}) do add(id,"level1") end
        for _,row in ipairs(def.learnset or {}) do if (tonumber(row.level) or 1)<=level then add(row.move,"level_up") end end
      end
    end
    for _,m in ipairs(mon.moves or {}) do add(m.id,"active") end
    return order,{inferred=true,claim="theoretical_relearn_set",complete=false,
      note="This set is inferred from species data and must not be presented as confirmed learning history."}
  end
  return service
end
