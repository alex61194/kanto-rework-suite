-- Generic field-action registry. Core owns the contract and evaluation only;
-- Kanto-specific rules (HM ownership, badges, Cut/Surf/etc.) belong to the
-- gameplay module.
return function(deps)
  local runtime=assert(deps.runtime,"runtime is required")
  local service={}
  local state=runtime.fieldActionState or {serial=0,definitions={}}
  runtime.fieldActionState=state

  local function validId(id)
    return type(id)=="string" and id:match("^[%w_%.%-]+$")~=nil
  end
  local function copy(t)
    local out={} for k,v in pairs(t or {}) do out[k]=v end return out
  end
  local function sorted()
    local out={} for _,d in pairs(state.definitions) do out[#out+1]=d end
    table.sort(out,function(a,b)
      local pa,pb=tonumber(a.priority) or 0,tonumber(b.priority) or 0
      if pa~=pb then return pa>pb end
      return tostring(a.id)<tostring(b.id)
    end)
    return out
  end
  local function invoke(fn,context,defaultOk)
    if type(fn)~="function" then return defaultOk,nil,nil end
    local ok,a,b=pcall(fn,context)
    if not ok then return false,"provider_error",tostring(a) end
    if type(a)=="table" then
      local value=a.ok
      if value==nil then value=a.available end
      if value==nil then value=a.known end
      if value==nil then value=defaultOk end
      return value==true,a.reason,a
    end
    if a==nil then return defaultOk,b,nil end
    return a==true,b,nil
  end

  function service.register(definition)
    assert(type(definition)=="table","field action definition must be a table")
    assert(validId(definition.id),"field action id is required")
    assert(type(definition.label)=="string" and definition.label~="","field action label is required")
    assert(type(definition.execute)=="function","field action execute callback is required")
    local trigger=definition.trigger or "manual"
    assert(trigger=="manual" or trigger=="automatic" or trigger=="both","invalid field action trigger")
    state.serial=state.serial+1
    local token=state.serial
    local d=copy(definition);d.feedback=copy(definition.feedback)
    d.source=tostring(definition.source or "unknown");d.trigger=trigger
    d.priority=tonumber(definition.priority) or 0;d._token=token
    state.definitions[d.id]=d
    return function()
      local live=state.definitions[d.id]
      if live and live._token==token then state.definitions[d.id]=nil;return true end
      return false
    end
  end

  function service.evaluate(id,context)
    local d=state.definitions[id]
    if not d then return nil,"unknown_action" end
    local known,reason,reqMeta=invoke(d.requirements,context,true)
    local available=false;local availabilityMeta
    if known then available,reason,availabilityMeta=invoke(d.availability,context,true) end
    local status=known and (available and "available" or "disabled") or "unknown"
    return {
      id=d.id,label=d.label,source=d.source,trigger=d.trigger,priority=d.priority,
      known=known,available=known and available or false,status=status,
      reason=reason,feedback=copy(d.feedback),
      requirementMeta=reqMeta,availabilityMeta=availabilityMeta,
    }
  end

  function service.list(context,opts)
    opts=opts or {};local out={}
    for _,d in ipairs(sorted()) do
      if not opts.trigger or d.trigger==opts.trigger or d.trigger=="both" then
        local row=service.evaluate(d.id,context)
        if row and (opts.includeUnknown==true or row.known) then out[#out+1]=row end
      end
    end
    return out
  end

  function service.execute(id,context)
    local d=state.definitions[id]
    if not d then return false,"unknown_action" end
    local row=service.evaluate(id,context)
    if not row.known then return false,row.reason or "requirements_not_met",row end
    if not row.available then return false,row.reason or "unavailable",row end
    local ok,a,b=pcall(d.execute,context)
    if not ok then return false,"execute_error",tostring(a) end
    if a==nil then a=true end
    return a,b,row
  end

  function service.definition(id)
    local d=state.definitions[id]
    if not d then return nil end
    return {id=d.id,label=d.label,source=d.source,trigger=d.trigger,priority=d.priority,feedback=copy(d.feedback)}
  end
  function service.status()
    local n=0 for _ in pairs(state.definitions) do n=n+1 end
    return {version=1,registered=n}
  end
  return service
end
