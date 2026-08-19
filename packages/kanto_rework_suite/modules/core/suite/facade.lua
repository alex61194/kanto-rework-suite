-- Internal-module facade over the single native kanto_rework_suite API.
return function(host,suite,registry,optionsService,diagnostics,meta)
  local unpackArgs=table.unpack or unpack;local moduleId=assert(meta.id);local root="modules/"..assert(meta.dir).."/"
  local facade={id=moduleId,legacyId=meta.legacyId,name=meta.name,version=meta.version,enabled=meta.enabled~=false,dependencies=meta.dependencies or {},exports={},content=host.content,input=host.input,checkpoints=host.checkpoints,suite={id=suite.id,version=suite.version},_cleanup={}}
  local function report(phase,err,context) diagnostics:error(moduleId,phase,err,context);if host.log and host.log.error then pcall(host.log.error,host.log,"[%s] %s: %s",moduleId,tostring(phase),tostring(err)) end end
  local function trackCleanup(value) if type(value)=="function" then facade._cleanup[#facade._cleanup+1]=value end;return value end
  function facade:_rollback(reason)
    local list=self._cleanup or {};self._cleanup={}
    for i=#list,1,-1 do local ok,e=pcall(list[i]);if not ok then report("cleanup",e,reason) end end
    return true
  end
  function facade:read(relative) return host:read(root..tostring(relative or "")) end
  facade.path=type(host.path)=="string" and (host.path.."/"..root:sub(1,-2)) or root:sub(1,-2)
  facade.find=function(first,second) local id=second==nil and first or second;return registry:find(id) end
  facade.assets={}
  function facade.assets:path(relative) return host.assets:path(root..tostring(relative or "")) end
  function facade.assets:image(relative) return host.assets:image(root..tostring(relative or "")) end
  facade.options={}
  function facade.options:define(rows) return optionsService:define(moduleId,rows) end
  function facade.options:get(k) return optionsService:get(moduleId,k) end
  function facade.options:set(k,v,opts) return optionsService:set(moduleId,k,v,opts) end
  local function saveKey(k) return moduleId.."."..tostring(k or "") end
  facade.save={}
  function facade.save:get(k,default) return host.save and host.save.get and host.save:get(saveKey(k),default) or default end
  function facade.save:set(k,v) return host.save and host.save.set and host.save:set(saveKey(k),v) or false end
  local function storageKey(k) k=tostring(k or "");return moduleId..(k~="" and ("/"..k) or "") end
  facade.storage={}
  function facade.storage:context(game) return host.storage:context(game) end
  function facade.storage:read(game,k) return host.storage:read(game,storageKey(k)) end
  function facade.storage:write(game,k,v) return host.storage:write(game,storageKey(k),v) end
  function facade.storage:readBytes(game,k) return host.storage:readBytes(game,storageKey(k)) end
  function facade.storage:writeBytes(game,k,v) return host.storage:writeBytes(game,storageKey(k),v) end
  function facade.storage:delete(game,k) return host.storage:delete(game,storageKey(k)) end
  function facade.storage:list(game,prefix)
    local raw,code,msg=host.storage:list(game,storageKey(prefix or ""));if type(raw)~="table" then return raw,code,msg end
    local out,lead={},moduleId.."/";for _,k in ipairs(raw) do if k==moduleId then out[#out+1]="" elseif k:sub(1,#lead)==lead then out[#out+1]=k:sub(#lead+1) end end;return out
  end
  function facade.storage:selected(game)
    local selected,code,msg=host.storage:selected(game);if not selected then return nil,code,msg end
    local p={};function p:context() return selected:context() end;function p:read(k) return selected:read(storageKey(k)) end;function p:write(k,v) return selected:write(storageKey(k),v) end;function p:readBytes(k) return selected:readBytes(storageKey(k)) end;function p:writeBytes(k,v) return selected:writeBytes(storageKey(k),v) end;function p:delete(k) return selected:delete(storageKey(k)) end
    function p:list(prefix) local raw,c,m=selected:list(storageKey(prefix or ""));if type(raw)~="table" then return raw,c,m end;local out,lead={},moduleId.."/";for _,k in ipairs(raw) do if k:sub(1,#lead)==lead then out[#out+1]=k:sub(#lead+1) end end;return out end
    return p
  end
  facade.log={};for _,level in ipairs({"info","warn","error"}) do facade.log[level]=function(_,fmt,...) local fn=host.log and host.log[level];if fn then return fn(host.log,"["..moduleId.."] "..tostring(fmt),...) end end end
  facade.events={}
  function facade.events:on(name,callback)
    return trackCleanup(host.events:on(name,function(payload,...)
      local n=select("#",...);local extra={...};if name=="game.ready" and payload and payload.game then suite.game=payload.game;optionsService:attachGame(payload.game) end
      local forwarded=payload;if name=="mod.options_changed" and type(payload)=="table" and payload.mod==suite.id and type(payload.key)=="string" then local prefix=moduleId..".";if payload.key:sub(1,#prefix)==prefix then forwarded={};for k,v in pairs(payload) do forwarded[k]=v end;forwarded.mod=moduleId;forwarded.key=payload.key:sub(#prefix+1) end end
      local ok,a,b,c=xpcall(function() return callback(forwarded,unpackArgs(extra,1,n)) end,function(err) return debug and debug.traceback and debug.traceback(tostring(err),2) or tostring(err) end)
      if not ok then report("event:"..tostring(name),a);return nil end;return a,b,c
    end))
  end
  local function suiteEventName(name)
    name=tostring(name or "")
    local suitePrefix="mod."..suite.id.."."
    if name:sub(1,#suitePrefix)==suitePrefix then return name end
    local legacyPrefix=meta.legacyId and ("mod."..meta.legacyId..".") or nil
    if legacyPrefix and name:sub(1,#legacyPrefix)==legacyPrefix then
      return suitePrefix..moduleId.."."..name:sub(#legacyPrefix+1)
    end
    local internalPrefix="mod."..moduleId.."."
    if name:sub(1,#internalPrefix)==internalPrefix then
      return suitePrefix..moduleId.."."..name:sub(#internalPrefix+1)
    end
    return name
  end
  function facade.events:emit(name,payload) return host.events:emit(suiteEventName(name),payload) end
  facade.hooks={}
  function facade.hooks:wrap(name,callback,priority)
    return trackCleanup(host.hooks:wrap(name,function(...) local n=select("#",...);local args={...};local ok,a,b,c=xpcall(function() return callback(unpackArgs(args,1,n)) end,function(err) return debug and debug.traceback and debug.traceback(tostring(err),2) or tostring(err) end);if not ok then report("hook:"..tostring(name),a);error("[KRS "..moduleId.."] "..tostring(a),0) end;return a,b,c end,priority))
  end
  function facade.suite:restartRequired() return diagnostics.restartPending==true end
  function facade.suite:diagnostics() return diagnostics:snapshot(registry) end
  function facade.suite:module(id) return registry:find(id) end
  return setmetatable(facade,{__index=function(_,k) if k=="game" then return suite.game end end})
end
