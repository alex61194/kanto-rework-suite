-- Cooperative capability and compatibility registry.
--
-- The registry never monkey-patches another mod and never claims that two
-- opaque implementations have been made compatible.  Cooperative consumers
-- resolve providers through this service; compatibility packages may add
-- policies and diagnostics without coupling those rules to Core releases.
return function(deps)
  local runtime=assert(deps.runtime,"runtime is required")
  local release=tostring(deps.release or "")
  local state=runtime.capabilityRegistryState or {
    serial=0,definitions={},providers={},policies={},diagnostics={}
  }
  state.definitions=state.definitions or {}
  state.providers=state.providers or {}
  state.policies=state.policies or {}
  state.diagnostics=state.diagnostics or {}
  runtime.capabilityRegistryState=state

  local api={}
  local MODES={exclusive=true,middleware=true,additive=true,advisory=true}

  local function validId(id)
    return type(id)=="string" and id:match("^[%w_%.%-]+$")~=nil
  end
  local function copy(value)
    local out={};for k,v in pairs(value or {}) do out[k]=v end;return out
  end
  local function nextToken()
    state.serial=state.serial+1;return state.serial
  end
  local function unregister(bucket,id,token)
    return function()
      local live=bucket[id]
      if live and live._token==token then bucket[id]=nil;return true end
      return false
    end
  end
  local function enabled(provider)
    if type(provider.enabled)=="function" then
      local ok,value=pcall(provider.enabled)
      return ok and value~=false
    end
    return provider.enabled~=false
  end
  local function orderedProviders(capabilityId,onlyEnabled)
    local out={}
    for _,provider in pairs(state.providers) do
      if provider.capability==capabilityId and (not onlyEnabled or enabled(provider)) then
        local item=copy(provider);item.enabled=enabled(provider);out[#out+1]=item
      end
    end
    table.sort(out,function(a,b)
      local pa,pb=tonumber(a.priority) or 0,tonumber(b.priority) or 0
      if pa~=pb then return pa>pb end
      return tostring(a.id)<tostring(b.id)
    end)
    return out
  end
  local function preferences()
    local game=runtime.game
    local options=game and game.save and game.save.options
    if not options then return {} end
    options.kantoReworkCapabilityPreferences=options.kantoReworkCapabilityPreferences or {}
    return options.kantoReworkCapabilityPreferences
  end

  function api.define(definition)
    assert(type(definition)=="table" and validId(definition.id),"capability id is required")
    local mode=definition.mode or "additive"
    assert(MODES[mode],"unsupported capability mode")
    local value=copy(definition);value.mode=mode;value._token=nextToken()
    state.definitions[value.id]=value
    return unregister(state.definitions,value.id,value._token)
  end

  function api.registerProvider(definition)
    assert(type(definition)=="table" and validId(definition.id),"provider id is required")
    assert(validId(definition.capability),"provider capability is required")
    assert(state.definitions[definition.capability],"unknown capability: "..definition.capability)
    local value=copy(definition);value.source=value.source or value.modId or value.id
    value.modId=value.modId or value.source;value._token=nextToken()
    state.providers[value.id]=value
    return unregister(state.providers,value.id,value._token)
  end

  function api.registerPolicy(definition)
    assert(type(definition)=="table" and validId(definition.id),"policy id is required")
    assert(type(definition.match)=="function","policy match function is required")
    local value=copy(definition);value._token=nextToken();state.policies[value.id]=value
    return unregister(state.policies,value.id,value._token)
  end

  function api.registerDiagnostic(definition)
    assert(type(definition)=="table" and validId(definition.id),"diagnostic id is required")
    assert(type(definition.scan)=="function","diagnostic scan function is required")
    local value=copy(definition);value._token=nextToken();state.diagnostics[value.id]=value
    return unregister(state.diagnostics,value.id,value._token)
  end

  function api.definition(id)
    local value=state.definitions[id];return value and copy(value) or nil
  end
  function api.providers(id) return orderedProviders(id,false) end
  function api.providersForMod(modId)
    local out={}
    for _,provider in pairs(state.providers) do
      if provider.modId==modId or provider.source==modId then
        local item=copy(provider);item.enabled=enabled(provider);out[#out+1]=item
      end
    end
    table.sort(out,function(a,b)
      if a.capability~=b.capability then return a.capability<b.capability end
      return a.id<b.id
    end)
    return out
  end

  function api.resolve(id)
    local definition=state.definitions[id]
    if not definition then return nil,"unknown capability" end
    local providers=orderedProviders(id,true)
    local preferred=preferences()[id]
    if definition.mode=="exclusive" and preferred then
      for i,provider in ipairs(providers) do
        if provider.id==preferred then table.remove(providers,i);table.insert(providers,1,provider);break end
      end
    end
    local active={}
    if definition.mode=="exclusive" then
      if providers[1] then active[1]=providers[1] end
    else
      for _,provider in ipairs(providers) do active[#active+1]=provider end
    end
    return {
      id=id,label=definition.label or id,mode=definition.mode,
      preferred=preferred,providers=providers,active=active,
      requiresChoice=definition.mode=="exclusive" and #providers>1,
      selected=active[1] and active[1].id or nil,
    }
  end

  function api.setPreference(id,providerId)
    local definition=state.definitions[id]
    if not definition or definition.mode~="exclusive" then return false,"not an exclusive capability" end
    local found=false
    for _,provider in ipairs(orderedProviders(id,false)) do if provider.id==providerId then found=true;break end end
    if not found then return false,"unknown provider" end
    preferences()[id]=providerId
    local game=runtime.game
    if game and type(game.writeOptions)=="function" then
      local ok,err=pcall(game.writeOptions,game);if not ok then return false,tostring(err) end
    end
    return true
  end

  function api.evaluateMod(mod,wantEnabled)
    local out={}
    for _,policy in pairs(state.policies) do
      local ok,matched=pcall(policy.match,mod,wantEnabled)
      if ok and matched then
        out[#out+1]={
          id=policy.id,source=policy.source,severity=policy.severity or "warning",
          message=type(policy.message)=="function" and policy.message(mod,wantEnabled) or policy.message,
          blocksEnable=wantEnabled==true and policy.blocksEnable==true,
          remediation=policy.remediation,
        }
      end
    end
    table.sort(out,function(a,b) return tostring(a.id)<tostring(b.id) end)
    return out
  end

  function api.canEnable(mod)
    for _,issue in ipairs(api.evaluateMod(mod,true)) do
      if issue.blocksEnable then return false,issue.message,issue end
    end
    return true
  end

  function api.issues()
    local out={}
    for id,definition in pairs(state.definitions) do
      local resolution=api.resolve(id)
      if resolution and resolution.requiresChoice then
        out[#out+1]={
          id="capability."..id,severity="warning",capability=id,
          message=(definition.label or id).." has multiple active providers; choose one provider.",
          providers=resolution.providers,
        }
      end
    end
    table.sort(out,function(a,b) return a.id<b.id end)
    return out
  end

  function api.scan(mods,loaderErrors)
    local out=api.issues()
    for _,mod in ipairs(mods or {}) do
      for _,issue in ipairs(api.evaluateMod(mod,mod.enabled~=false)) do
        issue.modId=mod.id;issue.modName=mod.name;out[#out+1]=issue
      end
    end
    for _,diagnostic in pairs(state.diagnostics) do
      local ok,items=pcall(diagnostic.scan,mods or {},loaderErrors or {})
      if ok and type(items)=="table" then
        for _,issue in ipairs(items) do
          if type(issue)=="table" then
            local item=copy(issue);item.source=item.source or diagnostic.source or diagnostic.id
            item.id=item.id or diagnostic.id;item.severity=item.severity or diagnostic.severity or "warning"
            out[#out+1]=item
          end
        end
      end
    end
    table.sort(out,function(a,b)
      if tostring(a.severity)~=tostring(b.severity) then return tostring(a.severity)<tostring(b.severity) end
      return tostring(a.id)<tostring(b.id)
    end)
    return out
  end

  function api.status()
    local definitions,providers,policies,diagnostics=0,0,0,0
    for _ in pairs(state.definitions) do definitions=definitions+1 end
    for _ in pairs(state.providers) do providers=providers+1 end
    for _ in pairs(state.policies) do policies=policies+1 end
    for _ in pairs(state.diagnostics) do diagnostics=diagnostics+1 end
    return {release=release,definitions=definitions,providers=providers,policies=policies,diagnostics=diagnostics}
  end

  return api
end
