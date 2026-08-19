-- UI-owned live battle composition. These are global KRS presentation
-- settings: options.lua, not a Pokemon save/playthrough. The legacy storage
-- key is read once for migration and deliberately left intact for rollback.
return function(deps)
  local mod=assert(deps.mod)
  local K_LAYOUT='battle_live_layout_v1' -- legacy mod.storage key
  local K_GLOBAL='__battle_live_layout_global_v1' -- hidden KRS option key
  local service={}
  local DEFAULTS={schema=4,
    opponent_frame={x=0,y=0,scale=92},
    player_frame={x=0,y=0,scale=92},
    command_list={x=0,y=0,scale=95},
    command_fight={x=0,y=0},
    command_pokemon={x=0,y=0},
    command_bag={x=0,y=0},
    command_run={x=0,y=0},
    move_menu={x=0,y=0,scale=95},
    trainer_intro={x=1248,y=280},
    trainer_battle={x=1580,y=350},
    trainer_post={x=1248,y=280},
    trainer_style={scale=100,animationSpeed=100},
  }
  local function copy(v) if type(v)~='table' then return v end;local o={};for k,x in pairs(v) do o[k]=copy(x) end;return o end
  local function merge(base,over) local out=copy(base);for k,v in pairs(type(over)=='table' and over or {}) do if type(v)=='table' and type(out[k])=='table' then out[k]=merge(out[k],v) else out[k]=copy(v) end end;return out end
  local function globalRead()
    if mod.options and type(mod.options.get)=='function' then
      local ok,v=pcall(mod.options.get,mod.options,K_GLOBAL)
      if ok and type(v)=='table' then return copy(v) end
    end
    return nil
  end
  local function globalWrite(game,value)
    if not(mod.options and type(mod.options.set)=='function') then return false,'global_options_unavailable' end
    local ok,result=pcall(mod.options.set,mod.options,K_GLOBAL,copy(value),{game=game,persist=true,emit=false})
    if not ok then return false,result end
    return result~=false,result==false and 'global_options_write_failed' or nil
  end
  local function legacyRead(game)
    if mod.storage and type(mod.storage.read)=='function' then
      local ok,v=pcall(mod.storage.read,mod.storage,game,K_LAYOUT)
      if ok and type(v)=='table' then return copy(v) end
    end
    return nil
  end
  local function read(game)
    local v=globalRead()
    if v then return v end
    local legacy=legacyRead(game)
    if legacy then
      -- Best-effort one-way migration into global options. Never delete the
      -- legacy playthrough bucket: it is the rollback witness.
      globalWrite(game,legacy)
      return legacy
    end
    return {}
  end
  function service.defaults() return copy(DEFAULTS) end
  function service.resolve(game) return merge(DEFAULTS,read(game)) end
  function service.commit(game,value)
    local payload=merge(DEFAULTS,value or {});payload.schema=4
    return globalWrite(game,payload)
  end
  function service.resetTarget(value,id)
    value=merge(DEFAULTS,value or {});if DEFAULTS[id] then value[id]=copy(DEFAULTS[id]) end;return value
  end
  function service.storageKey() return K_LAYOUT end -- legacy compatibility/diagnostics
  function service.globalOptionKey() return K_GLOBAL end
  return service
end
