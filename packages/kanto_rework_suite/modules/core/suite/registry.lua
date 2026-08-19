return function(host,suite,definitions,FacadeFactory,optionsService,diagnostics)
  local r={modules={},aliases={},order={},definitions=definitions}
  local function trace(e) return debug and debug.traceback and debug.traceback(tostring(e),2) or tostring(e) end
  -- Preserve the isolation the modules had as independent native mods without
  -- creating a second native-mod security identity.  Every internal module gets
  -- a private globals table that inherits the already-sandboxed Suite env
  -- (including the Suite's LegacyCompat/love/require facades).  Only compilation
  -- is delegated to the engine Sandbox so secondary load()/loadstring() calls
  -- stay inside that same private environment.
  local Sandbox=nil
  do
    local ok,value=pcall(require,"src.mods.Sandbox")
    if ok and type(value)=="table" and type(value.compile)=="function" then Sandbox=value end
  end
  local parentEnv=_G
  local function copyNamespace(value)
    if type(value)~="table" then return value end
    local out={};for k,v in pairs(value) do out[k]=v end;return out
  end
  local function privateEnvironment()
    local env={}
    for _,name in ipairs({"coroutine","math","string","table","bit","os"}) do
      if parentEnv[name]~=nil then env[name]=copyNamespace(parentEnv[name]) end
    end
    env._G=env
    setmetatable(env,{__index=parentEnv})
    if Sandbox then
      local function privateLoad(source,chunkname)
        if type(source)=="function" then
          local parts={};while true do local piece=source();if piece==nil or piece=="" then break end;parts[#parts+1]=piece end;source=table.concat(parts)
        end
        if type(source)~="string" then return nil,"load expects a string or reader" end
        return Sandbox.compile(source,chunkname or "=(load)",env)
      end
      env.load=privateLoad;env.loadstring=privateLoad
    end
    return env
  end
  for _,def in ipairs(definitions or {}) do assert(type(def.id)=="string" and def.id~="");assert(not r.modules[def.id],"duplicate internal module id: "..def.id);local m={};for k,v in pairs(def) do m[k]=v end;m.enabled=def.enabled~=false;m.state=m.enabled and "registered" or "disabled";r.modules[m.id]=m;r.aliases[m.id]=m.id;if m.legacyId then r.aliases[m.legacyId]=m.id end;r.order[#r.order+1]=m.id end
  suite.moduleOrder=r.order
  function r:validateGraph()
    local visiting,done,sorted={},{},{};local function visit(id,path) if done[id] then return true end;if visiting[id] then return false,"dependency cycle: "..table.concat(path," -> ").." -> "..id end;local m=self.modules[id];if not m then return false,"unknown module "..tostring(id) end;visiting[id]=true;path[#path+1]=id;for _,dep in ipairs(m.dependencies or {}) do if not self.modules[dep] then return false,id.." depends on missing "..tostring(dep) end;local ok,e=visit(dep,path);if not ok then return false,e end end;path[#path]=nil;visiting[id]=nil;done[id]=true;sorted[#sorted+1]=id;return true end
    for _,id in ipairs(self.order) do local ok,e=visit(id,{});if not ok then return false,e end end;self.topological=sorted;return true,sorted
  end
  function r:find(id)
    if id==suite.id then return {id=suite.id,version=suite.version,exports=host.exports,native=true} end
    local iid=self.aliases[id];if iid then local m=self.modules[iid];if m and (m.state=="active" or m.state=="initializing") and m.facade then return {id=m.id,legacyId=m.legacyId,version=m.version,exports=m.facade.exports,state=m.state,internal=true} end;return nil end
    if host.find then local ok,v=pcall(host.find,id);if ok then return v end end;return nil
  end
  function r:prepareFacades()
    for _,id in ipairs(self.order) do
      local m=self.modules[id]
      m.facade=FacadeFactory(host,suite,self,optionsService,diagnostics,m)
      m.settingsProvider=function() return optionsService:schemaFor(id) end
      m.diagnostics=function() return {id=id,state=m.state,error=m.error,enabled=m.enabled==true,required=m.required==true} end
    end
  end
  function r:initializeOne(id)
    local m=self.modules[id];if not m then return false,"unknown module" end;if not m.enabled then m.state="disabled";return true end
    for _,conflictId in ipairs(m.conflicts or {}) do
      local active=nil;if host.find then local ok,value=pcall(host.find,conflictId);if ok then active=value end end
      if active then m.state="conflict";m.error="conflicts with "..tostring(conflictId);diagnostics:error(id,"conflict",m.error);return false,m.error end
    end
    for _,depId in ipairs(m.dependencies or {}) do local dep=self.modules[depId];if not dep or dep.state~="active" then m.state="blocked_dependency";m.error="dependency "..tostring(depId).." is not active";diagnostics:error(id,"dependency",m.error);return false,m.error end end
    m.state="initializing";local path="modules/"..m.dir.."/"..m.entry;local src,readErr=host:read(path);if type(src)~="string" then m.state="error";m.error=tostring(readErr or "read failed");diagnostics:error(id,"read",m.error,path);return false,m.error end
    local chunk,compileErr
    if Sandbox then
      m.environment=m.environment or privateEnvironment()
      chunk,compileErr=Sandbox.compile(src,"@kanto_rework_suite/"..path,m.environment)
    else
      -- Headless/unit-test seam only.  A real Gen1Recomp boot exposes Sandbox.
      chunk,compileErr=load(src,"@kanto_rework_suite/"..path)
    end
    if not chunk then m.state="error";m.error=tostring(compileErr);diagnostics:error(id,"compile",m.error,path);return false,m.error end
    local ok,init=xpcall(chunk,trace);if not ok or type(init)~="function" then m.state="error";m.error=ok and "entry did not return initializer" or tostring(init);diagnostics:error(id,"entry",m.error,path);if m.facade and m.facade._rollback then m.facade:_rollback("entry failure") end;return false,m.error end
    m.init=init
    local ran,result=xpcall(function() return init(m.facade) end,trace)
    if not ran then m.state="error";m.error=tostring(result);diagnostics:error(id,"init",m.error,path);if m.facade and m.facade._rollback then m.facade:_rollback("init failure") end;return false,m.error end
    if type(result)=="function" then m.shutdown=result
    elseif type(result)=="table" and type(result.shutdown)=="function" then m.shutdown=result.shutdown end
    m.state="active";return true
  end
  function r:initializeAll() local ok,e=self:validateGraph();if not ok then return false,e end;self:prepareFacades();for _,id in ipairs(self.topological or self.order) do local success,err=self:initializeOne(id);if not success and self.modules[id].required then return false,err end end;return true end
  function r:shutdownAll(reason)
    local order=self.topological or self.order
    for i=#order,1,-1 do
      local id=order[i];local m=self.modules[id]
      if m and m.state=="active" and type(m.shutdown)=="function" then
        local ok,e=xpcall(function() return m.shutdown(reason) end,trace)
        if not ok then diagnostics:error(id,"shutdown",e,reason) end
      end
      if m and m.facade and m.facade._rollback then m.facade:_rollback(reason or "shutdown") end
      if m and m.state=="active" then m.state="stopped" end
    end
    return true
  end
  function r:moduleStates() local out={};for _,id in ipairs(self.order) do local m=self.modules[id];out[#out+1]={id=id,legacyId=m.legacyId,name=m.name,version=m.version,schema=m.schema,enabled=m.enabled==true,required=m.required==true,restartRequired=m.restartRequired==true,dependencies=m.dependencies,state=m.state,error=m.error,hasInit=type(m.init)=="function",hasShutdown=type(m.shutdown)=="function",settingsProvider=type(m.settingsProvider)=="function",diagnostics=type(m.diagnostics)=="function",isolatedEnvironment=Sandbox~=nil and type(m.environment)=="table"} end;return out end
  function r:has(mid,cap) local h=self:find(mid);local ex=h and h.exports;if not ex then return false end;if cap==nil or ex[cap]~=nil then return true end;if mid=="graphics" and cap=="animatedPokemon" then return type(ex.resolve)=="function" elseif mid=="graphics" and cap=="battleBackgrounds" then return type(ex.battleBackgroundsEnabled)=="function" elseif mid=="gameplay" and cap=="fieldActions" then return ex.fieldMoveStatus~=nil elseif mid=="battle_animations" and cap=="enabled" then return type(ex.enabled)=="function" and ex.enabled()==true end;return false end
  return r
end
