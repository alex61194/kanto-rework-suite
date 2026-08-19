-- Presentation-neutral font-family registry shared by Kanto Rework modules.
-- Owning UI mods provide the font files; Core resolves weight fallbacks and
-- caches LÖVE Font objects without taking responsibility for visual styling.
return function(deps)
  local runtime=assert(deps.runtime,"runtime is required")
  local service={}
  local state=runtime.typographyState or {serial=0,families={},fonts={}}
  runtime.typographyState=state

  local WEIGHTS={regular=true,medium=true,semibold=true,bold=true,black=true}
  local FALLBACK={black={"black","bold","semibold","regular"},bold={"bold","semibold","medium","regular"},semibold={"semibold","bold","medium","regular"},medium={"medium","regular","semibold"},regular={"regular","medium"}}

  local function cleanPaths(paths)
    local out={}
    for weight,path in pairs(type(paths)=="table" and paths or {}) do
      weight=tostring(weight):lower()
      if WEIGHTS[weight] and type(path)=="string" and path~="" then out[weight]=path end
    end
    return out
  end

  function service.registerFamily(def)
    assert(type(def)=="table","font family definition must be a table")
    local id=tostring(def.id or "")
    assert(id:match("^[a-z][a-z0-9_.%-]*$"),"font family id is required")
    local paths=cleanPaths(def.paths)
    assert(paths.regular,"font family requires a regular face")
    state.serial=state.serial+1
    local token=state.serial
    state.families[id]={id=id,label=tostring(def.label or id),source=tostring(def.source or "unknown"),paths=paths,_token=token}
    state.fonts[id]={}
    return function()
      local live=state.families[id]
      if live and live._token==token then state.families[id]=nil;state.fonts[id]=nil;return true end
      return false
    end
  end

  function service.paths(id)
    local family=state.families[tostring(id or "")]
    if not family then return nil end
    local out={} for k,v in pairs(family.paths) do out[k]=v end return out
  end

  function service.resolve(id,weight)
    local family=state.families[tostring(id or "")]
    if not family then return nil end
    weight=WEIGHTS[tostring(weight or "regular"):lower()] and tostring(weight or "regular"):lower() or "regular"
    for _,candidate in ipairs(FALLBACK[weight]) do if family.paths[candidate] then return family.paths[candidate],candidate end end
    return family.paths.regular,"regular"
  end

  function service.font(id,weight,px)
    px=math.max(1,math.floor((tonumber(px) or 12)+.5))
    local path,resolved=service.resolve(id,weight)
    if not path then return nil,"unknown_family" end
    local cache=state.fonts[tostring(id)] or {};state.fonts[tostring(id)]=cache
    local key=tostring(resolved)..":"..tostring(px)
    if cache[key] then return cache[key] end
    local ok,font=pcall(love.graphics.newFont,path,px)
    if not ok or not font then return nil,font or "font_load_failed" end
    cache[key]=font
    return font
  end

  function service.list()
    local out={}
    for _,family in pairs(state.families) do out[#out+1]={id=family.id,label=family.label,source=family.source,paths=service.paths(family.id)} end
    table.sort(out,function(a,b)return a.id<b.id end)
    return out
  end

  function service.status()
    local families,fonts=0,0
    for _ in pairs(state.families) do families=families+1 end
    for _,cache in pairs(state.fonts) do for _ in pairs(cache) do fonts=fonts+1 end end
    return {version=1,families=families,cachedFonts=fonts}
  end

  return service
end
