-- Neutral KRS graphics-provider registry.
-- Core owns only provider contracts and arbitration; concrete art remains in
-- dedicated graphics/UI modules. Contexts are explicit (e.g. party.icon,
-- intro.pokemon) so battle rendering policy can never leak into menu sizing.
return function()
  local M={providers={},serial=0}

  local function normalizeContexts(value)
    if type(value)=='string' then return {[value]=true} end
    local out={}
    for _,v in ipairs(type(value)=='table' and value or {}) do
      if type(v)=='string' and v~='' then out[v]=true end
    end
    return out
  end

  local function accepts(provider,context)
    local contexts=provider.contexts or {}
    if contexts['*'] or contexts[context] then return true end
    -- A provider may opt into a whole namespace with "party.*".
    local prefix=tostring(context or ''):match('^([^%.]+)%.')
    return prefix and contexts[prefix..'.*']==true or false
  end

  function M.registerProvider(spec)
    assert(type(spec)=='table','graphics provider spec is required')
    assert(type(spec.id)=='string' and spec.id~='','graphics provider id is required')
    assert(type(spec.resolve)=='function','graphics provider resolve is required')
    M.serial=M.serial+1
    local entry={
      id=spec.id,
      source=spec.source or spec.id,
      priority=tonumber(spec.priority) or 0,
      contexts=normalizeContexts(spec.contexts or '*'),
      resolve=spec.resolve,
      enabled=spec.enabled,
      order=M.serial,
    }
    M.providers[entry.id]=entry
    return function() if M.providers[entry.id]==entry then M.providers[entry.id]=nil end end
  end

  function M.resolve(context,request,fallback)
    context=tostring(context or '')
    request=type(request)=='table' and request or {}
    local list={}
    for _,provider in pairs(M.providers) do
      if accepts(provider,context) then
        local enabled=true
        if type(provider.enabled)=='function' then
          local ok,value=pcall(provider.enabled,context,request)
          enabled=ok and value~=false
        end
        if enabled then list[#list+1]=provider end
      end
    end
    table.sort(list,function(a,b)
      if a.priority~=b.priority then return a.priority>b.priority end
      return a.order<b.order
    end)
    for _,provider in ipairs(list) do
      local ok,value=pcall(provider.resolve,context,request)
      if ok and type(value)=='table' then
        value.provider=value.provider or provider.id
        value.source=value.source or provider.source
        return value
      end
    end
    return fallback
  end

  function M.status()
    local out={}
    for _,p in pairs(M.providers) do
      out[#out+1]={id=p.id,source=p.source,priority=p.priority,contexts=p.contexts}
    end
    table.sort(out,function(a,b) return a.id<b.id end)
    return {providers=out,count=#out}
  end
  return M
end
