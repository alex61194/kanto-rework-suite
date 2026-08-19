return function(suite)
  local d={errors={},migrations={},legacyDetected={},restartPending=false}
  function d:error(moduleId,phase,err,context) local r={module=moduleId or "suite",phase=phase or "unknown",error=tostring(err or "unknown"),context=context};self.errors[#self.errors+1]=r;return r end
  function d:migration(id,result,detail) self.migrations[#self.migrations+1]={id=id,result=result,detail=detail} end
  function d:setLegacy(ids) self.legacyDetected={};for _,id in ipairs(ids or {}) do self.legacyDetected[#self.legacyDetected+1]=id end end
  function d:snapshot(registry)
    local modules={};for _,id in ipairs(suite.moduleOrder or {}) do local m=registry and registry.modules and registry.modules[id];if m then modules[#modules+1]={id=id,name=m.name,version=m.version,schema=m.schema,enabled=m.enabled==true,required=m.required==true,state=m.state,restartRequired=m.restartRequired==true,error=m.error} end end
    local function status(id) local h=registry and registry:find(id);local ex=h and h.exports;if ex and type(ex.status)=="function" then local ok,v=pcall(ex.status);if ok then return v end end;return ex and "loaded" or nil end
    return {suiteId=suite.id,suiteVersion=suite.version,gen1recompVersion=suite.engineVersion,modules=modules,migrations=self.migrations,legacyPackagesDetected=self.legacyDetected,restartRequired=self.restartPending==true,graphicsProvider=status("graphics"),battleAnimationProvider=status("battle_animations"),compatibility=status("compatibility"),errors=self.errors}
  end
  return d
end
