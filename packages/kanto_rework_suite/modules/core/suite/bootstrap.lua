return function(host)
  local SUITE={id="kanto_rework_suite",version="0.1.0-candidate.6",game=nil,moduleOrder={}}
  local LEGACY={"kanto_rework_core","kanto_rework_graphics","kanto_rework_gameplay","kanto_rework_compat","kanto_rework_battle_anims","kanto_rework_ui","kanto_rework_dev"}
  local function loadFile(path) local src,e=host:read(path);assert(type(src)=="string",e or ("Unable to read "..path));local chunk,ce=load(src,"@kanto_rework_suite/"..path);assert(chunk,ce);return chunk() end
  do local ok,Version=pcall(require,"src.core.Version");SUITE.engineVersion=ok and Version and Version.engine or nil end
  local legacy={};for _,id in ipairs(LEGACY) do local ok,h=pcall(host.find,id);if ok and h then legacy[#legacy+1]=id end end
  if #legacy>0 then local message="Kanto Rework Suite Candidate blocked: legacy KRS packages are still active: "..table.concat(legacy,", ")..". Disable/remove the legacy ZIPs and restart; no files were deleted.";if host.log and host.log.error then pcall(host.log.error,host.log,"%s",message) end;error(message,0) end
  local defs=loadFile("config/modules.lua");for _,d in ipairs(defs) do SUITE.moduleOrder[#SUITE.moduleOrder+1]=d.id end
  local Options=loadFile("modules/core/suite/options.lua")(host,SUITE);local Diagnostics=loadFile("modules/core/suite/diagnostics.lua")(SUITE);Diagnostics:setLegacy(legacy)
  Options:setRoot({{key="dev_tools.enabled",label="DEVELOPER TOOLS",type="toggle",default=false,group="DEVELOPER",description="Include the internal KRS Developer Tools module on the next boot. Restart required."}})
  local Facade=loadFile("modules/core/suite/facade.lua");local Registry=loadFile("modules/core/suite/registry.lua")(host,SUITE,defs,Facade,Options,Diagnostics)
  local desired=host.options and host.options.get and host.options:get("dev_tools.enabled")==true;local dev=Registry.modules.dev_tools;if dev then dev.enabled=desired;dev.state=desired and "registered" or "disabled" end;SUITE.devEnabledAtBoot=desired
  local Migrations=loadFile("migrations/legacy_v1.lua")(host,SUITE,defs,Options,Diagnostics)
  host.events:on("game.ready",function(payload) local game=payload and payload.game;if not game then return end;SUITE.game=game;Options:attachGame(game);local ok,result=Migrations:run(game);if not ok and host.log and host.log.warn then pcall(host.log.warn,host.log,"Suite legacy migration incomplete: %s",tostring(result)) end end)
  host.events:on("mod.options_changed",function(payload) if payload and payload.mod==SUITE.id and payload.key=="dev_tools.enabled" then Diagnostics.restartPending=(payload.value==true)~=(SUITE.devEnabledAtBoot==true) end end)
  local graphOk,graphErr=Registry:validateGraph();assert(graphOk,graphErr);local initOk,initErr=Registry:initializeAll();assert(initOk,"Required KRS internal module failed: "..tostring(initErr))
  host.events:on("mod.unload",function(payload) Registry:shutdownAll(payload and payload.reason or "mod.unload") end)
  host.exports.version=SUITE.version;host.exports.suiteVersion=SUITE.version;host.exports.moduleStates=function() return Registry:moduleStates() end;host.exports.findInternal=function(id) return Registry:find(id) end;host.exports.has=function(mid,cap) return Registry:has(mid,cap) end;host.exports.diagnostics=function() return Diagnostics:snapshot(Registry) end;host.exports.migrationSchema=Migrations.schema;host.exports.restartRequired=function() return Diagnostics.restartPending==true end;host.exports.shutdown=function(reason) return Registry:shutdownAll(reason or "external") end
  if host.log and host.log.info then local active={};for _,s in ipairs(Registry:moduleStates()) do if s.state=="active" then active[#active+1]=s.id end end;pcall(host.log.info,host.log,"Kanto Rework Suite %s loaded; internal modules: %s",SUITE.version,table.concat(active,", ")) end
end
