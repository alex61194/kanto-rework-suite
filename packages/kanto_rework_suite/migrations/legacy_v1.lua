-- One-shot legacy native KRS namespace migration. Old data is preserved for rollback.
return function(host,suite,definitions,optionsService,diagnostics)
  local service={schema=1}
  local function clone(v) if type(v)~="table" then return v end;local o={};for k,x in pairs(v) do o[k]=clone(x) end;return o end
  local function ensure(t,k) if type(t[k])~="table" then t[k]={} end;return t[k] end
  local function migrateOptions(game)
    local options=game and game.save and game.save.options;if type(options)~="table" then return false,"options unavailable" end
    options.modOptions=type(options.modOptions)=="table" and options.modOptions or {};local target=ensure(options.modOptions,suite.id);local copied=0
    for _,def in ipairs(definitions) do local src=options.modOptions[def.legacyId];if type(src)=="table" then for k,v in pairs(src) do local nk=def.id.."."..tostring(k);if target[nk]==nil then target[nk]=clone(v);copied=copied+1 end end end end
    for _,profile in ipairs(options.modProfiles or {}) do if type(profile)=="table" then
      profile.options=type(profile.options)=="table" and profile.options or {};local pt=ensure(profile.options,suite.id)
      for _,def in ipairs(definitions) do local src=profile.options[def.legacyId];if type(src)=="table" then for k,v in pairs(src) do local nk=def.id.."."..tostring(k);if pt[nk]==nil then pt[nk]=clone(v) end end end end
      profile.enabled=type(profile.enabled)=="table" and profile.enabled or {};if profile.enabled[suite.id]==nil then local any=false;for _,def in ipairs(definitions) do if profile.enabled[def.legacyId]~=false then any=true;break end end;profile.enabled[suite.id]=any end
    end end
    target.__suite_schema_version=math.max(tonumber(target.__suite_schema_version) or 0,service.schema)
    local loader=game.mods;if loader then loader.modOptions=type(loader.modOptions)=="table" and loader.modOptions or {};loader.modOptions[suite.id]=target end
    if type(game.writeOptions)=="function" then pcall(game.writeOptions,game) end
    if loader and loader.events and type(loader.events.emit)=="function" then for k,v in pairs(target) do if type(k)=="string" and k:sub(1,2)~="__" then pcall(loader.events.emit,loader.events,"mod.options_changed",{mod=suite.id,key=k,value=v,migrated=true}) end end end
    return true,{copied=copied,schema=service.schema}
  end
  local function migrateSave(game)
    local save=game and game.save;if type(save)~="table" then return false,"save unavailable" end;save.modData=type(save.modData)=="table" and save.modData or {};local target=ensure(save.modData,suite.id);local copied=0
    for _,def in ipairs(definitions) do local src=save.modData[def.legacyId];if type(src)=="table" then for k,v in pairs(src) do local nk=def.id.."."..tostring(k);if target[nk]==nil then target[nk]=clone(v);copied=copied+1 end end end end
    target.__legacy_migration_schema=math.max(tonumber(target.__legacy_migration_schema) or 0,service.schema);local loader=game.mods;if loader then loader.modSave=type(loader.modSave)=="table" and loader.modSave or {};loader.modSave[suite.id]=target end
    return true,{copied=copied,schema=service.schema}
  end
  local function targetExists(game,key) if host.storage:read(game,key)~=nil then return true end;if host.storage:readBytes(game,key)~=nil then return true end;return false end
  local function migrateStorage(game)
    local ok,Storage=pcall(require,"src.mods.Storage");if not ok or not Storage or type(Storage.new)~="function" then return false,"src.mods.Storage unavailable" end
    local marker="migration/legacy_v1";local current=host.storage:read(game,marker);if type(current)=="table" and tonumber(current.schema) and tonumber(current.schema)>=service.schema then return true,{copied=0,already=true,schema=service.schema} end
    local copied,skipped,failures=0,0,{}
    for _,def in ipairs(definitions) do local legacy=Storage.new(def.legacyId);local keys,code,msg=legacy:list(game,"");if type(keys)=="table" then for _,k in ipairs(keys) do local tk=def.id.."/"..k;if targetExists(game,tk) then skipped=skipped+1 else local v=legacy:read(game,k);if v~=nil then local w,c,m=host.storage:write(game,tk,v);if w then copied=copied+1 else failures[#failures+1]=tk..": "..tostring(m or c) end else local bytes,bc,bm=legacy:readBytes(game,k);if bytes~=nil then local w,c,m=host.storage:writeBytes(game,tk,bytes);if w then copied=copied+1 else failures[#failures+1]=tk..": "..tostring(m or c) end elseif bc~="not_found" then failures[#failures+1]=def.legacyId.."/"..k..": "..tostring(bm or bc) end end end end elseif code and code~="not_found" and code~="storage_unavailable" then failures[#failures+1]=def.legacyId..": "..tostring(msg or code) end end
    if #failures==0 then host.storage:write(game,marker,{schema=service.schema,copied=copied,skipped=skipped});return true,{copied=copied,skipped=skipped,schema=service.schema} end
    return false,{copied=copied,skipped=skipped,failures=failures,schema=service.schema}
  end
  function service:run(game) optionsService:attachGame(game);local a,b=migrateOptions(game);diagnostics:migration("legacy_options_v1",a and "PASS" or "FAIL",b);local c,d=migrateSave(game);diagnostics:migration("legacy_mod_save_v1",c and "PASS" or "FAIL",d);local e,f=migrateStorage(game);diagnostics:migration("legacy_storage_v1",e and "PASS" or "PARTIAL",f);return a and c and e,{options=b,modSave=d,storage=f} end
  return service
end
