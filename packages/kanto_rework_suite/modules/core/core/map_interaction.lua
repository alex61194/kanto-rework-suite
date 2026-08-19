-- Pointer interaction and Fly confirmation for the native TownMap. The same
-- model is exported for the future square overlay and 16:9 full-screen map.
return function(deps)
  local runtime = assert(deps.runtime, "runtime is required")
  local foundation = deps.foundation
  local resolveDevFly = deps.devFlyUnlocked
  local service = { lastError = nil }

  local function isTownMap(state)
    return type(state) == "table" and type(state.locs) == "table"
      and type(state.sel) == "number" and type(state.mode) == "string"
      and type(state.byMap) == "table" and state.blink ~= nil
  end

  local function firstVisible(state, rows)
    return math.max(1, math.min(state.sel - 2, #state.locs - rows + 1))
  end

  function service.locationAt(state, ux, uy)
    if not isTownMap(state) or state.nestSpecies then return nil end
    if state.mode == "grid" then
      local best, bestD
      for i, loc in ipairs(state.locs) do
        if loc.x and loc.y then
          local cx, cy = loc.x * 8 + 20, loc.y * 8 + 12
          local dx, dy = ux - cx, uy - cy
          local d = dx * dx + dy * dy
          if d <= 12 * 12 and (not bestD or d < bestD) then best, bestD = i, d end
        end
      end
      return best
    end
    local rows = 6
    if ux < 0 or ux > 160 or uy < 32 or uy >= 32 + rows * 16 then return nil end
    local row = math.floor((uy - 32) / 16) + 1
    local index = firstVisible(state, rows) + row - 1
    return state.locs[index] and index or nil
  end

  local function owns(game, itemId)
    local value = game and game.save and game.save.inventory
      and game.save.inventory[itemId]
    if type(value) == "number" then return value > 0 end
    return value == true
  end

  local function devFlyUnlocked()
    if type(resolveDevFly)~="function" then return false end
    local ok,value=pcall(resolveDevFly)
    return ok and value==true
  end

  function service.canUseFly(game)
    local ow = game and game.overworld
    local save = game and game.save
    if not (ow and ow.map and ow.map.def and save and save.inventory) then
      return false, "no_overworld"
    end
    -- Kanto Rework automatic Field Moves use the owned HM item plus the
    -- vanilla badge as their progression gate.  The map shortcut must never
    -- bypass that contract by calling OverworldController:flyTo directly.
    if not devFlyUnlocked() then
      if not owns(game, "HM_FLY") then return false, "hm_required" end
      if not owns(game, "THUNDERBADGE") then return false, "badge_required" end
    end
    local okMap, Map = pcall(require, "src.world.Map")
    local okDefaults, FieldDefaults = pcall(require, "src.world.FieldDefaults")
    if not (okMap and okDefaults) then return false, "engine_unavailable" end
    if Map.isOutside(ow.map.def,
        FieldDefaults.field(game.data, "outsideTilesets")) ~= true then
      return false, "outside_required"
    end
    return true, nil
  end

  function service.flyStatus(game)
    local available, reason = service.canUseFly(game)
    return {
      available = available == true,
      reason = reason,
      hm = "HM_FLY",
      badge = "THUNDERBADGE",
    }
  end

  function service.destinationFor(game, state, index)
    if not (game and isTownMap(state) and state.locs[index]) then return nil end
    if state.flyMapIds and state.flyMapIds[index] then return state.flyMapIds[index] end
    local target = state.locs[index]
    local field = game.data and game.data.field or {}
    local visited = game.save and game.save.visited or {}
    local flyWarps = field.flyWarps or {}
    local okMap, Map = pcall(require, "src.world.Map")
    if not okMap then return nil end
    for _, mapId in ipairs(field.flyOrder or {}) do
      local def = game.data.maps and game.data.maps[mapId]
      if state.byMap[mapId] == target and visited[mapId] and flyWarps[mapId]
          and def and Map.isFlyTown(def) then
        return mapId
      end
    end
    return nil
  end

  function service.model(game, state)
    if not isTownMap(state) then return nil end
    local locations = {}
    for i, loc in ipairs(state.locs) do
      local mapId = service.destinationFor(game, state, i)
      locations[#locations + 1] = {
        index = i, name = loc.name, x = loc.x, y = loc.y,
        selected = i == state.sel, mapId = mapId,
        flyAvailable = mapId ~= nil and service.canUseFly(game),
      }
    end
    return { mode = state.mode, fly = state.fly == true,
      flyStatus = service.flyStatus(game), locations = locations }
  end

  function service.select(game, state, index)
    if not (isTownMap(state) and state.locs[index]) then return false end
    local changed = state.sel ~= index
    state.sel = index
    if changed then
      pcall(function() require("src.core.Sound").play(game.data, "Tink") end)
    end
    return true
  end

  function service.activate(game, state, index, ownerState)
    if not service.select(game, state, index) then return false end
    local mapId = service.destinationFor(game, state, index)
    local permitted, reason = service.canUseFly(game)
    if not mapId then return true, "destination_unavailable" end
    if not permitted then return true, reason end
    local ow = game.overworld
    local ok, TextBox = pcall(require, "src.render.TextBox")
    local stringsOk, Strings = pcall(require, "src.core.Strings")
    if not (ok and stringsOk and ow and type(ow.flyTo) == "function") then
      service.lastError = "fly confirmation unavailable"
      return true
    end
    local name = state.locs[index].name or mapId:gsub("_", " ")
    game.stack:push(TextBox.new(game, Strings("Fly to %s?", name), nil, {
      defaultNo = true,
      choice = function(yes)
        if not yes then return end
        if game.stack and type(game.stack.top) == "function" then
          local top = game.stack:top()
          if top == (ownerState or state) or top == state then game.stack:pop() end
        end
        ow:flyTo(mapId)
      end,
    }))
    return true
  end

  function service.registerModelHotspots(game, state)
    if not foundation or not isTownMap(state) then return end
    local key = tostring(state) .. ":" .. tostring(service.canUseFly(game))
      .. ":" .. tostring(#state.locs)
    if runtime.mapHotspotKey == key then return end
    runtime.mapHotspotKey = key
    runtime.mapHotspotUnregister = runtime.mapHotspotUnregister or {}
    for _, off in ipairs(runtime.mapHotspotUnregister) do pcall(off) end
    runtime.mapHotspotUnregister = {}
    for i, loc in ipairs(state.locs) do
      local mapId = service.destinationFor(game, state, i)
      local off = foundation.registerMapHotspot({
        id = "town_map." .. tostring(i),
        priority = 10,
        name = loc.name,
        mapId = mapId,
        x = loc.x, y = loc.y,
        flyAvailable = mapId ~= nil and service.canUseFly(game),
      })
      runtime.mapHotspotUnregister[#runtime.mapHotspotUnregister + 1] = off
    end
  end

  function service.isTownMap(state) return isTownMap(state) end
  function service.status() return { error = service.lastError, interactive = true } end
  return service
end
