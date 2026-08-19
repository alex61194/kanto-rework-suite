-- Presentation-neutral notification bus. Product UI decides placement,
-- animation and styling; Core only normalizes and dispatches payloads.
return function(deps)
  local mod=assert(deps.mod,"mod is required")
  local runtime=assert(deps.runtime,"runtime is required")
  local service={}
  local state=runtime.notificationState or {serial=0,listeners={}}
  runtime.notificationState=state
  local EVENT=(mod.suite and mod.suite.id)
    and ("mod."..mod.suite.id..".core.notification")
    or "mod.kanto_rework_core.notification"

  local function copy(t) local o={} for k,v in pairs(t or {}) do o[k]=v end return o end
  function service.subscribe(id,callback)
    assert(type(id)=="string" and id~="","listener id is required")
    assert(type(callback)=="function","listener callback is required")
    state.serial=state.serial+1;local token=state.serial
    state.listeners[id]={token=token,callback=callback}
    return function()
      local live=state.listeners[id]
      if live and live.token==token then state.listeners[id]=nil;return true end
      return false
    end
  end
  function service.emit(payload)
    assert(type(payload)=="table","notification payload must be a table")
    local out={
      id=payload.id and tostring(payload.id) or nil,
      source=tostring(payload.source or "unknown"),
      message=tostring(payload.message or ""),
      kind=tostring(payload.kind or "info"),
      priority=tonumber(payload.priority) or 0,
      duration=tonumber(payload.duration),replaceKey=payload.replaceKey and tostring(payload.replaceKey) or nil,
      data=copy(payload.data),
    }
    for _,entry in pairs(state.listeners) do pcall(entry.callback,out) end
    pcall(function() mod.events:emit(EVENT,out) end)
    return out
  end
  function service.eventName() return EVENT end
  function service.status()
    local n=0 for _ in pairs(state.listeners) do n=n+1 end
    return {version=1,listeners=n,event=EVENT}
  end
  return service
end
