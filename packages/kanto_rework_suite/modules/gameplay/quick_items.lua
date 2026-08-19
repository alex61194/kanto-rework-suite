-- Nine registered Bag item shortcuts (Ctrl+1 .. Ctrl+9 on keyboard).
-- Registration is per playthrough and persisted immediately through mod.storage,
-- with mod.save retained as a migration/fallback mirror. Invocation deliberately
-- enters the native Bag item path instead of duplicating ItemEffects.
return function(deps)
  local mod=assert(deps.mod)
  local Core=assert(deps.Core)
  local Game=assert(deps.Game)
  local BagMenu=require('src.ui.BagMenu')
  local state={slots={}}
  local LEGACY_KEY='registered_items_v1'
  local STORAGE_KEY='registered_items_v2'

  local function normalizedSlots(value)
    if type(value)=='table' and type(value.slots)=='table' then value=value.slots end
    if type(value)~='table' then value={} end
    local slots={}
    for i=1,9 do if type(value[i])=='string' then slots[i]=value[i] end end
    return slots
  end

  local function storageRead(game)
    if not (mod.storage and mod.storage.read) then return nil end
    local ok,value=pcall(mod.storage.read,mod.storage,game,STORAGE_KEY)
    return ok and type(value)=='table' and value or nil
  end

  local function storageWrite(game)
    if not (mod.storage and mod.storage.write) then return false end
    local payload={version=2,slots={}}
    for i=1,9 do if type(state.slots[i])=='string' then payload.slots[i]=state.slots[i] end end
    local ok,written=pcall(mod.storage.write,mod.storage,game,STORAGE_KEY,payload)
    return ok and written==true
  end

  local function load(game)
    game=game or Game
    local durable=storageRead(game)
    if durable then
      state.slots=normalizedSlots(durable)
      if mod.save and mod.save.set then mod.save:set(LEGACY_KEY,state.slots) end
      return state.slots,'storage'
    end
    local legacy=mod.save and mod.save.get and mod.save:get(LEGACY_KEY,nil) or nil
    state.slots=normalizedSlots(legacy)
    if next(state.slots)~=nil then storageWrite(game) end
    return state.slots,'mod.save'
  end

  local function persist(game)
    game=game or Game
    if mod.save and mod.save.set then mod.save:set(LEGACY_KEY,state.slots) end
    storageWrite(game)
  end

  load(Game)

  function state.assign(slot,itemId)
    slot=tonumber(slot)
    if not slot or slot<1 or slot>9 or type(itemId)~='string' then return false,'invalid slot or item' end
    state.slots[slot]=itemId;persist(Game);return true
  end
  function state.clear(slot)
    slot=tonumber(slot);if not slot or slot<1 or slot>9 then return false end
    state.slots[slot]=nil;persist(Game);return true
  end
  function state.item(slot) return state.slots[tonumber(slot)] end
  function state.list() local o={};for i=1,9 do o[i]=state.slots[i] end;return o end

  local function top(game) return game and game.stack and game.stack.top and game.stack:top() end
  local function overworldOnly(game)
    local s=top(game);return game and s and s==game.overworld
  end
  local function cleanupTo(game,wanted)
    if not (game and game.stack and game.stack.top and game.stack.pop) then return end
    local guard=0
    while game.stack:top() and game.stack:top()~=wanted and guard<8 do
      game.stack:pop();guard=guard+1
    end
  end

  function state.use(slot,game)
    game=game or Game
    local id=state.item(slot)
    if not id then return false,'empty slot' end
    if not (game and game.save and game.save.inventory and game.save.inventory[id]) then return false,'item unavailable' end
    if not overworldOnly(game) then return false,'shortcut unavailable here' end
    local origin=game.stack:top()
    local list=BagMenu.new(game)
    local found
    for i,row in ipairs(list.items or {}) do if row.value==id then found=i break end end
    if not found and list.__kantoPocketState then
      local pocketState=list.__kantoPocketState
      for pocketIndex,pocket in ipairs(pocketState.pockets or {}) do
        for i,row in ipairs(pocket.items or {}) do
          if row.value==id then
            pocketState.pocketIndex=pocketIndex
            list.items=pocket.items
            list.index=i
            list.scroll=math.max(0,i-(list.rows or 7))
            found=i
            break
          end
        end
        if found then break end
      end
    end
    if not found then return false,'item not in bag' end
    list.index=found;list.scroll=math.max(0,found-(list.rows or 7))
    game.stack:push(list)
    local row=list.items[found]
    local ok,err=pcall(function()
      assert(type(list.onChoose)=='function','bag choice handler unavailable')
      list.onChoose(row,list)
      local useMenu=game.stack:top()
      -- Out-of-battle BagMenu deliberately inserts a USE/TOSS Menu. A
      -- registered shortcut means "USE this item", not "open its submenu".
      -- Reproduce Menu:update(A): beep, pop the submenu, call its USE callback.
      if useMenu and useMenu~=list and type(useMenu.items)=='table' then
        local first=useMenu.items[1]
        local label=first and tostring(first.label or ''):upper() or ''
        if first and type(first.onSelect)=='function' and label:find('USE',1,true) then
          if not useMenu.noSound then
            local Sound=require('src.core.Sound');Sound.play(game.data,'Press_AB')
          end
          game.stack:pop()
          first.onSelect()
        end
      end
    end)
    if not ok then cleanupTo(game,origin);return false,tostring(err) end
    return true,id
  end

  local function shortcutNumber(key,scancode)
    for _,v in ipairs({key,scancode}) do
      if type(v)=='string' then
        local n=tonumber(v) or tonumber(v:match('^kp([1-9])$'))
        if n and n>=1 and n<=9 then return n end
      end
    end
  end

  local unregisterInput=Core.registerInputLayer({
    id='kanto_rework_gameplay.registered_items',priority=170,
    active=function(game) return overworldOnly(game) end,
    keypressed=function(game,key,scancode,isrepeat)
      if isrepeat then return false end
      local n=shortcutNumber(key,scancode)
      if not n then return false end
      local ctrl=love.keyboard and love.keyboard.isDown and
        (love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl'))
      if not ctrl then return false end
      state.use(n,game)
      -- Consume the chord even when the registered item is unavailable, so
      -- Ctrl+1 can never leak into Gen1Recomp's bare "1 = speed" hotkey.
      return true
    end,
  })

  local unsubs={}
  if mod.events and mod.events.on then
    unsubs[#unsubs+1]=mod.events:on('save.loaded',function() load(Game) end)
    unsubs[#unsubs+1]=mod.events:on('save.created',function() load(Game) end)
    unsubs[#unsubs+1]=mod.events:on('game.ready',function() load(Game) end)
  end
  state.reload=function(game) return load(game or Game) end
  state.unregister=function()
    if unregisterInput then pcall(unregisterInput);unregisterInput=nil end
    for i=#unsubs,1,-1 do if type(unsubs[i])=='function' then pcall(unsubs[i]) end end
    unsubs={}
    return true
  end
  state.status=function() return {installed=true,slots=state.list(),keyboard='CTRL+1..CTRL+9',scope='overworld',persistence='playthrough_storage'} end
  return state
end
