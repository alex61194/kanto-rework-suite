-- Durable live Graphics editor configuration.
-- All design/presentation settings live in global KRS options.lua so they
-- survive Pokemon save/slot changes. Legacy mod.storage is read only for a
-- one-way migration and is retained untouched for rollback. Local entries
-- mean background-specific composition, not Pokemon-save-local storage.
return function(deps)
  local mod=assert(deps.mod)
  local service={}
  local K_GLOBAL='graphics_editor_global_v1'
  local K_LOCAL='graphics_editor_backgrounds_v1'
  local K_PROFILES='graphics_editor_profiles_v1'
  local K_ACTIVE='graphics_editor_active_profile_v1'
  local TIME_PHASE={sunrise=true,day=true,sunset=true,night=true}
  local SHARED_TIME_KEY='__time__'
  local function localSlot(phase)
    phase=tostring(phase or '')
    return TIME_PHASE[phase] and SHARED_TIME_KEY or phase
  end
  local function copy(v)
    if type(v)~='table' then return v end
    local o={};for k,x in pairs(v) do o[k]=copy(x) end;return o
  end
  local function merge(base,over)
    local out=copy(base)
    for k,v in pairs(type(over)=='table' and over or {}) do
      if type(v)=='table' and type(out[k])=='table' then out[k]=merge(out[k],v) else out[k]=copy(v) end
    end
    return out
  end
  local function eq(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not eq(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
  end
  local function diff(value,base)
    if type(value)~='table' or type(base)~='table' then return eq(value,base) and nil or copy(value) end
    local out={}
    for k,v in pairs(value) do
      local d=diff(v,base[k]);if d~=nil then out[k]=d end
    end
    return next(out) and out or nil
  end
  local function readGlobalOption(key)
    if mod.options and type(mod.options.get)=='function' then
      local ok,v=pcall(mod.options.get,mod.options,key)
      if ok and v~=nil then return copy(v) end
    end
    return nil
  end
  local function writeGlobalOption(game,key,value)
    if not(mod.options and type(mod.options.set)=='function') then
      return false,'global_options_unavailable'
    end
    local ok,result=pcall(mod.options.set,mod.options,key,copy(value),{game=game,persist=true,emit=false})
    if not ok then return false,result end
    return result~=false,result==false and 'global_options_write_failed' or nil
  end
  local function legacyRead(game,key)
    if mod.storage and type(mod.storage.read)=='function' then
      local ok,v=pcall(mod.storage.read,mod.storage,game,key)
      if ok and v~=nil then return copy(v) end
    end
    return nil
  end
  local function read(game,key,default)
    local v=readGlobalOption(key)
    if v~=nil then return v end
    local legacy=legacyRead(game,key)
    if legacy~=nil then
      -- Preserve old per-playthrough storage as rollback evidence. New writes
      -- go only to options.lua and therefore apply to every Pokemon save.
      writeGlobalOption(game,key,legacy)
      return legacy
    end
    return copy(default)
  end
  local function write(game,key,value)
    return writeGlobalOption(game,key,value)
  end
  local function option(key,default) local v=mod.options:get(key);return v==nil and default or v end
  -- Live Editor percentage is independent from the coarse global animation
  -- speed choice. New editor configurations start deliberately slow at 15%;
  -- merge() below preserves any percentage already present in durable config.
  local DEFAULT_EDITOR_ANIMATION_SPEED=15
  function service.defaults()
    local mode=(tostring(option('battle_sprite_mode','animated')):lower()=='animated' and option('sprite_animation',true)~=false) and 'animated' or 'static'
    return {
      schema=2,
      background={scale=100,offsetX=0,offsetY=0},
      player={orientation='back',mode=mode,generation=tostring(option('back_generation','gen5')),size=0,animationSpeed=DEFAULT_EDITOR_ANIMATION_SPEED},
      opponent={orientation='front',mode=mode,generation=tostring(option('front_generation','gen5')),size=0,animationSpeed=DEFAULT_EDITOR_ANIMATION_SPEED},
    }
  end
  function service.global(game)
    return merge(service.defaults(),read(game,K_GLOBAL,{}))
  end
  function service.rawGlobal(game) return read(game,K_GLOBAL,{}) end
  function service.locals(game) return read(game,K_LOCAL,{}) end
  function service.localOverride(game,background,phase)
    local all=service.locals(game);local b=all[tostring(background or '')]
    if type(b)~='table' then return nil end
    local slot=localSlot(phase)
    local value=b[slot]
    -- Migration fallback: old builds stored Sunrise/Day/Sunset/Night as four
    -- independent calibrations. A shared entry wins; otherwise the current
    -- legacy phase remains readable until the family is next committed.
    if value==nil and slot==SHARED_TIME_KEY then value=b[tostring(phase or '')] end
    return type(value)=='table' and copy(value) or nil
  end
  function service.hasLocal(game,background,phase)
    local v=service.localOverride(game,background,phase);return type(v)=='table' and v.__created==true
  end
  function service.resolve(game,background,phase)
    local raw=service.rawGlobal(game);local global=merge(service.defaults(),raw);local localv=service.localOverride(game,background,phase)
    if type(localv)=='table' then
      local clean=copy(localv);clean.__created=nil
      return merge(global,clean),{source='local',background=background,phase=phase,configured=true}
    end
    return global,{source='global',background=background,phase=phase,configured=next(raw)~=nil}
  end
  function service.commitGlobal(game,value)
    local d=diff(value,service.defaults()) or {}
    d.schema=2
    return write(game,K_GLOBAL,d)
  end
  function service.commitLocal(game,background,phase,value)
    background=tostring(background or '');phase=tostring(phase or '')
    if background=='' or phase=='' then return false,'invalid_background' end
    local all=service.locals(game);all[background]=type(all[background])=='table' and all[background] or {}
    local d=diff(value,service.global(game)) or {};d.__created=true
    local slot=localSlot(phase);all[background][slot]=d
    if slot==SHARED_TIME_KEY then
      -- Once a family is saved under the shared key, stale time-specific
      -- calibrations must no longer shadow the family contract.
      for p in pairs(TIME_PHASE) do all[background][p]=nil end
    end
    return write(game,K_LOCAL,all)
  end
  function service.seedLocal(game,background,phase,current)
    if service.hasLocal(game,background,phase) then return false,'exists' end
    return service.commitLocal(game,background,phase,current or service.global(game))
  end
  function service.deleteLocal(game,background,phase)
    local all=service.locals(game);local b=all[background];if type(b)~='table' then return true end
    local slot=localSlot(phase);b[slot]=nil
    if slot==SHARED_TIME_KEY then for p in pairs(TIME_PHASE) do b[p]=nil end end
    if next(b)==nil then all[background]=nil end
    return write(game,K_LOCAL,all)
  end
  function service.variantType(phase) return TIME_PHASE[tostring(phase or '')] and 'time' or 'structural' end
  function service.localStorageKey(phase) return localSlot(phase) end
  function service.profiles(game) return read(game,K_PROFILES,{}) end
  function service.activeProfile(game) return tostring(read(game,K_ACTIVE,'') or '') end
  local function cleanName(name)
    name=tostring(name or ''):gsub('^%s+',''):gsub('%s+$',''):gsub('[\r\n\t]',' ')
    if #name>32 then name=name:sub(1,32) end
    return name
  end
  function service.saveProfile(game,name,value)
    name=cleanName(name);if name=='' then return false,'invalid_name' end
    local p=service.profiles(game);p[name]=copy(value or service.global(game))
    local ok,err=write(game,K_PROFILES,p);if not ok then return false,err end
    write(game,K_ACTIVE,name);return true
  end
  function service.loadProfile(game,name)
    local p=service.profiles(game);local value=p[name];if type(value)~='table' then return false,'not_found' end
    local ok,err=service.commitGlobal(game,value);if not ok then return false,err end
    write(game,K_ACTIVE,name);return true,copy(value)
  end
  function service.renameProfile(game,oldName,newName)
    newName=cleanName(newName);local p=service.profiles(game)
    if type(p[oldName])~='table' then return false,'not_found' end
    if newName=='' or (newName~=oldName and p[newName]~=nil) then return false,'invalid_name' end
    p[newName]=p[oldName];p[oldName]=nil
    local ok,err=write(game,K_PROFILES,p);if not ok then return false,err end
    if service.activeProfile(game)==oldName then write(game,K_ACTIVE,newName) end
    return true
  end
  function service.deleteProfile(game,name)
    local p=service.profiles(game);if p[name]==nil then return false,'not_found' end
    p[name]=nil;local ok,err=write(game,K_PROFILES,p);if not ok then return false,err end
    if service.activeProfile(game)==name then write(game,K_ACTIVE,'') end
    return true
  end
  function service.snapshot(game)
    local locals=service.locals(game);local count=0
    for _,phases in pairs(locals) do for _,v in pairs(phases) do if type(v)=='table' and v.__created then count=count+1 end end end
    local profiles=service.profiles(game);local pc=0 for _ in pairs(profiles) do pc=pc+1 end
    return {schema=2,global=service.global(game),localOverrides=count,profiles=pc,activeProfile=service.activeProfile(game),storage={K_GLOBAL,K_LOCAL,K_PROFILES,K_ACTIVE}}
  end
  return service
end
