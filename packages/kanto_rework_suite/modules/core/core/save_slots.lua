-- Gen1Recomp 0.1.76 native save-slot facade for Kanto Rework.
-- Presentation lives in kanto_rework_ui; Core only exposes safe data/actions.
return function(deps)
  local runtime=assert(deps.runtime)
  local SaveData=require('src.core.SaveData')
  local SaveSerializer=require('src.core.SaveSerializer')
  local GameVersion=require('src.core.GameVersion')
  local Badges=require('src.inventory.Badges')

  local service={}
  local function version() return GameVersion.get() end
  local function slotPaths(id)
    local main=('saves/%s/%s.lua'):format(tostring(version()),id)
    return main,main..'.tmp',main..'.bak'
  end
  local function readRawSlot(id)
    if type(id)~='string' or not id:match('^slot%d+$') then return nil,'invalid slot id' end
    local fs=SaveData.persistenceFs and SaveData.persistenceFs() or (love and love.filesystem)
    if not fs or type(fs.getInfo)~='function' or type(fs.read)~='function' then return nil,'persistence unavailable' end
    local lastError
    for _,path in ipairs({slotPaths(id)}) do
      if fs.getInfo(path) then
        local body,readErr=fs.read(path)
        if body then
          local decoded,decodeErr=SaveSerializer.decode(body)
          if decoded then return decoded end
          lastError=decodeErr
        else lastError=readErr end
      end
    end
    return nil,lastError or 'slot has no readable save data'
  end
  local function countSet(t) local n=0;for _,v in pairs(t or {}) do if v then n=n+1 end end;return n end
  local function locationLabel(save)
    local id=save and save.player and save.player.map;if not id then return nil end
    local game=runtime.game;local def=game and game.data and game.data.maps and game.data.maps[id]
    return tostring(def and (def.name or def.label) or id):gsub('_',' ')
  end
  local function monSummary(game,mon)
    local def=game and game.data and game.data.pokemon and mon and game.data.pokemon[mon.species]
    return {species=mon and mon.species or nil,name=mon and (mon.nickname or (def and def.name)) or nil,level=mon and mon.level or nil}
  end
  local function playSeconds(save)
    local value=save and save.playTime
    if type(value)=='table' then return math.floor((tonumber(value.hours) or 0)*3600+(tonumber(value.minutes) or 0)*60+(tonumber(value.seconds) or 0)) end
    return math.floor(tonumber(value) or 0)
  end
  local function richSummary(record,save)
    local game=runtime.game;local meta=record.meta or {};local party={}
    for i,mon in ipairs((save and save.party) or {}) do party[i]=monSummary(game,mon) end
    local t=playSeconds(save)
    return {
      id=record.id,exists=record.exists==true,label=record.label,
      active=SaveData.activeSlot(version())==record.id,
      name=(save and save.player and save.player.name) or record.name,
      badges=save and Badges.count(game and game.data,save) or (tonumber(meta.badges) or 0),
      seen=save and countSet(save.pokedex and save.pokedex.seen) or 0,
      owned=save and countSet(save.pokedex and save.pokedex.owned) or (tonumber(meta.dexCount) or 0),
      money=tonumber(save and save.money) or 0,
      location=locationLabel(save),playTime=t,
      timeText=save and ('%d:%02d:%02d'):format(math.floor(t/3600),math.floor(t/60)%60,t%60) or meta.timeText,
      savedAt=save and save.meta and tonumber(save.meta.savedAt) or nil,
      party=party,raw=save,
    }
  end

  function service.list(opts)
    opts=opts or {}
    local list=SaveData.listSlots(version()) or {}
    local out={}
    for _,rec in ipairs(list) do
      -- Every card is sourced from its own persisted slot. Never substitute
      -- the currently running playthrough for another slot's metadata.
      local save=rec.exists and select(1,readRawSlot(rec.id)) or nil
      out[#out+1]=richSummary(rec,save)
    end
    local min=math.max(0,tonumber(opts.minimum) or 0)
    while #out<min do out[#out+1]={id=nil,exists=false,virtual=true,index=#out+1,name='EMPTY',badges=0,seen=0,owned=0,money=0,party={}} end
    return out
  end

  function service.read(id)
    if not id then return nil,'missing slot id' end
    return readRawSlot(id)
  end

  function service.active() return SaveData.activeSlot(version()) end

  local function syncSlotRegistryIntoGame(game)
    if not (game and game.save and game.save.options) then return end
    local opts=SaveData.loadOptions()
    if opts and opts.saveSlots then
      -- SaveData.loadOptions returns an independent decoded table, so this
      -- assignment also refreshes the live full-options snapshot that
      -- Game:writeSave() will flush on the next targeted save.
      game.save.options.saveSlots=opts.saveSlots
    end
  end

  function service.save(game,id)
    game=game or runtime.game
    if not (game and game.save and type(game.writeSave)=='function') then return false,'game unavailable' end
    if not id then id=SaveData.createSlot(version()) end
    if not id then return false,'slot allocation failed' end

    -- Game:writeSave() flushes game.save.options after progress capture. That
    -- live full-options snapshot can predate a newly selected save slot. Keep
    -- the persistent registry AND the live snapshot synchronized before the
    -- progress write, then re-assert/synchronize after success. This matters
    -- for consecutive targeted saves (slot2 then slot3): without refreshing
    -- the live snapshot, the second write can silently erase slot2.
    local previous=SaveData.activeSlot(version())
    SaveData.setActiveSlot(version(),id)
    syncSlotRegistryIntoGame(game)
    local ok,err=game:writeSave()
    if ok==false then
      if previous then SaveData.setActiveSlot(version(),previous) end
      syncSlotRegistryIntoGame(game)
      return false,err or 'save failed'
    end
    SaveData.setActiveSlot(version(),id)
    syncSlotRegistryIntoGame(game)
    return true,id
  end

  function service.load(game,id)
    game=game or runtime.game
    if not (game and type(game.restoreSave)=='function') then return false,'game unavailable' end
    if not id then return false,'missing slot id' end
    SaveData.setActiveSlot(version(),id)
    local loaded,recovered=SaveData.load(version())
    if not loaded then return false,'slot has no save data' end
    game:restoreSave(loaded,recovered)
    return true,id
  end

  function service.delete(id)
    if not id then return false,'missing slot id' end
    return SaveData.deleteSlot(version(),id)
  end

  function service.rename(id,name)
    if not id then return false,'missing slot id' end
    return SaveData.renameSlot(version(),id,name)
  end

  function service.status()
    return {available=type(SaveData.listSlots)=='function',version=version(),active=SaveData.activeSlot(version())}
  end
  return service
end
