-- Presentation-neutral registry for versioned third-party mod adapters.
-- Compat owns knowledge of external mods; Core only resolves normalized
-- models and invokes their public/native callbacks on behalf of a presenter.
return function()
  local service={}
  local adapters={}
  local discoveryProviders={}
  local autoUtilities=setmetatable({},{__mode="k"})

  local function slug(value)
    value=tostring(value or "feature"):lower():gsub("[^%w]+","_"):gsub("^_+",""):gsub("_+$","")
    return value~="" and value or "feature"
  end

  local function captureState(game,callback)
    local stack=game and game.stack
    if not(stack and type(stack.push)=="function" and type(callback)=="function") then return nil,"stack unavailable" end
    local original=stack.push;local captured={}
    stack.push=function(_,state) captured[#captured+1]=state;return state end
    local ok,err=pcall(callback)
    stack.push=original
    if not ok then return nil,err end
    return captured[#captured],#captured>0 and nil or "the mod did not open a supported state"
  end

  local function autoBucket(game,modId)
    if not(game and modId) then return nil end
    local byMod=autoUtilities[game];if not byMod then byMod={};autoUtilities[game]=byMod end
    local bucket=byMod[modId];if not bucket then bucket={order={},byId={}};byMod[modId]=bucket end
    return bucket
  end

  local function rememberAutomatic(game,item,owner)
    if type(item)~="table" or type(item.onSelect)~="function" or type(owner)~="string" or owner=="" then return false end
    local bucket=autoBucket(game,owner);if not bucket then return false end
    local base="auto_"..slug(item.label);local id=base;local suffix=2
    while bucket.byId[id] and bucket.byId[id].item~=item do id=base.."_"..suffix;suffix=suffix+1 end
    local row=bucket.byId[id]
    if not row then
      row={id=id,label=tostring(item.label or "MOD FEATURE"),group="FEATURES",item=item,
        description="Open this feature inside the Kanto Rework navigation shell.",
        presentation={reader={mode="adaptive_document",mergeSourcePages=true,preserveLines=false}}}
      bucket.byId[id]=row;bucket.order[#bucket.order+1]=id
    else row.item=item end
    return true,id
  end

  local function matches(adapter,manifest)
    if type(adapter)~="table" or type(manifest)~="table" then return false end
    if adapter.modId and tostring(adapter.modId)~=tostring(manifest.id) then return false end
    if type(adapter.match)=="function" then
      local ok,value=pcall(adapter.match,manifest)
      return ok and value==true
    end
    return adapter.modId~=nil
  end

  local function resolve(manifest)
    for _,adapter in ipairs(adapters) do
      if matches(adapter,manifest) then return adapter end
    end
  end

  function service.register(adapter)
    assert(type(adapter)=="table","mod integration adapter is required")
    assert(type(adapter.id)=="string" and adapter.id~="","mod integration id is required")
    assert(adapter.modId or type(adapter.match)=="function","mod integration match is required")
    for i,existing in ipairs(adapters) do
      if existing.id==adapter.id then adapters[i]=adapter;return function() if adapters[i]==adapter then table.remove(adapters,i);return true end return false end end
    end
    adapters[#adapters+1]=adapter
    table.sort(adapters,function(a,b)
      local ap,bp=tonumber(a.priority) or 0,tonumber(b.priority) or 0
      if ap==bp then return a.id<b.id end
      return ap>bp
    end)
    return function()
      for i,candidate in ipairs(adapters) do if candidate==adapter then table.remove(adapters,i);return true end end
      return false
    end
  end

  function service.registerDiscovery(provider)
    assert(type(provider)=="table","mod discovery provider is required")
    assert(type(provider.id)=="string" and provider.id~="","mod discovery id is required")
    assert(type(provider.capture)=="function" and type(provider.ownerOf)=="function","mod discovery provider must implement capture and ownerOf")
    for i,existing in ipairs(discoveryProviders) do
      if existing.id==provider.id then discoveryProviders[i]=provider;return function() if discoveryProviders[i]==provider then table.remove(discoveryProviders,i);return true end return false end end
    end
    discoveryProviders[#discoveryProviders+1]=provider
    return function() for i,candidate in ipairs(discoveryProviders) do if candidate==provider then table.remove(discoveryProviders,i);return true end end return false end
  end

  function service.traceStartMenu(game,factory)
    assert(type(factory)=="function","Start Menu factory is required")
    autoUtilities[game]={}
    local provider=discoveryProviders[1]
    if not provider then return factory() end
    local ok,value=pcall(function() return provider.capture(game,factory) end)
    if ok then return value end
    return factory()
  end

  function service.refreshAutomatic(game)
    local ok,StartMenu=pcall(require,"src.ui.StartMenu")
    if not(ok and StartMenu and type(StartMenu.new)=="function") then return false end
    local made,native=pcall(service.traceStartMenu,game,function() return StartMenu.new(game) end)
    if not made then return false end
    for _,item in ipairs(type(native)=="table" and native.items or {}) do service.claimStartMenuItem(game,item) end
    return true
  end

  function service.hasAutomatic(game,modId)
    local bucket=game and autoUtilities[game] and autoUtilities[game][modId]
    return bucket~=nil and #bucket.order>0
  end

  function service.adapterFor(manifest) return resolve(manifest) end

  function service.decorateModel(manifest,model)
    local adapter=resolve(manifest)
    if not adapter then return model end
    model.integration={id=adapter.id,label=adapter.label or model.name,version=adapter.version,status="adapted"}
    if type(adapter.decorateModel)=="function" then
      local ok,value=pcall(adapter.decorateModel,manifest,model)
      if ok and type(value)=="table" then model=value end
    end
    return model
  end

  function service.decorateOptions(manifest,rows)
    local adapter=resolve(manifest)
    if not adapter or type(adapter.decorateOptions)~="function" then return rows end
    local ok,value=pcall(adapter.decorateOptions,manifest,rows)
    return ok and type(value)=="table" and value or rows
  end

  function service.utilities(game,manifest)
    -- Utilities are additive surfaces. A manifest may legitimately have one
    -- high-priority adapter decorating options/models and another adapter
    -- contributing a first-party utility. Do not let resolve() shadow the
    -- latter: collect utilities from every matching adapter in priority order.
    local out,seen={},{}
    for _,adapter in ipairs(adapters) do
      if matches(adapter,manifest) and type(adapter.utilities)=="function" then
        local ok,value=pcall(adapter.utilities,game,manifest)
        if ok and type(value)=="table" then
          for _,row in ipairs(value) do
            if type(row)=="table" and type(row.id)=="string" and type(row.open)=="function" and not seen[row.id] then
              seen[row.id]=true
              out[#out+1]={id=row.id,label=row.label or row.id,description=row.description or "",group=row.group or "FEATURES",open=row.open,presentation=type(row.presentation)=="table" and row.presentation or nil}
            end
          end
        end
      end
    end
    local bucket=game and autoUtilities[game] and manifest and autoUtilities[game][manifest.id]
    for _,id in ipairs(bucket and bucket.order or {}) do
      local row=bucket.byId[id]
      if not seen[row.id] then
        seen[row.id]=true
        out[#out+1]={id=row.id,label=row.label,description=row.description,group=row.group,presentation=row.presentation,
          open=function()
            local state,err=captureState(game,row.item.onSelect)
            if not state then error(err or "mod feature is unavailable") end
            return state
          end}
      end
    end
    return out
  end

  function service.openUtility(game,manifest,id)
    for _,row in ipairs(service.utilities(game,manifest)) do
      if row.id==id then
        local ok,value=pcall(row.open,game,manifest)
        return ok and value~=nil,ok and value or nil,ok and nil or tostring(value)
      end
    end
    return false,nil,"unknown mod utility"
  end

  function service.claimStartMenuItem(game,item)
    for _,adapter in ipairs(adapters) do
      if type(adapter.claimStartMenuItem)=="function" then
        local ok,value=pcall(adapter.claimStartMenuItem,game,item)
        if ok and value==true then return true,adapter.id end
      end
    end
    for _,provider in ipairs(discoveryProviders) do
      local ok,owner=pcall(provider.ownerOf,provider,game,item)
      if ok and type(owner)=="string" and owner~="" then
        local claimed=rememberAutomatic(game,item,owner)
        if claimed then return true,"auto:"..owner end
      end
    end
    return false
  end

  -- Resolve presentation art through versioned compatibility adapters after
  -- the engine's own live sprite hooks have produced a safe fallback.  Core
  -- knows only the neutral request/result contract; third-party option names,
  -- exports and asset layouts remain owned by Compatibility adapters.
  function service.resolvePokemonArt(game,request,fallback)
    request=type(request)=="table" and request or {}
    local current=type(fallback)=="table" and fallback or {}
    for _,adapter in ipairs(adapters) do
      if type(adapter.resolvePokemonArt)=="function" then
        local ok,value=pcall(adapter.resolvePokemonArt,game,request,current)
        if ok and type(value)=="table"
            and type(value.path)=="string" and value.path~="" then
          -- Returning the exact fallback means "not handled" and lets the
          -- next compatible adapter try. A distinct result is an explicit
          -- claim by the highest-priority provider.
          if value~=current then current=value;break end
        end
      end
    end
    return current
  end

  function service.status()
    local out={}
    for _,adapter in ipairs(adapters) do out[#out+1]={id=adapter.id,modId=adapter.modId,label=adapter.label,version=adapter.version} end
    return {count=#out,adapters=out,discoveryProviders=#discoveryProviders,
      pokemonArtResolver=true}
  end

  return service
end
