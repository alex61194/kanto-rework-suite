-- Native in-game SAVE flow. This intentionally calls game:writeSave() and is
-- completely separate from Gen1Recomp's F1/F2 save-state system.
return function(deps)
  local runtime = assert(deps.runtime, "runtime is required")
  local presenter = deps.presenter
  local service = { active = false, lastError = nil }

  local function topState(game)
    local stack = game and game.stack
    return stack and type(stack.top) == "function" and stack:top() or nil
  end

  local function battleShape(state)
    return type(state) == "table" and type(state.phase) == "string"
      and state.player ~= nil and state.enemy ~= nil
  end

  function service.canRequest(game, opts)
    game = game or runtime.game
    if not game or type(game.writeSave) ~= "function" then return false, "save unavailable" end
    if service.active then return false, "save already open" end
    local state = topState(game)
    if battleShape(state) then return false, "cannot save during battle" end
    if opts and opts.trustedUi then return true end
    if state == game.overworld then return true end
    if presenter and type(presenter.isSupportedStartMenu) == "function" then
      local ok = presenter.isSupportedStartMenu(game)
      if ok then return true end
    end
    if type(state) == "table" and state.krsAllowsGameSave == true then return true end
    return false, "open the game menu before saving"
  end

  function service.request(game, opts)
    game = game or runtime.game
    local allowed, reason = service.canRequest(game, opts)
    if not allowed then service.lastError = reason return false, reason end

    local ok, TextBox = pcall(require, "src.render.TextBox")
    local stringsOk, Strings = pcall(require, "src.core.Strings")
    local badgesOk, Badges = pcall(require, "src.inventory.Badges")
    if not (ok and stringsOk and badgesOk) then
      service.lastError = "native save UI unavailable"
      return false, service.lastError
    end

    local save = game.save or {}
    local owned = 0
    for _ in pairs(save.pokedex and save.pokedex.owned or {}) do owned = owned + 1 end
    local badgeCount = Badges.count(game.data, save)
    local t = math.floor(save.playTime or 0)
    local player = save.player and save.player.name or "RED"
    local panel = Strings("PLAYER %s\nBADGES    %d\nPOKéDEX %3d\nTIME %6d:%02d",
      player, badgeCount, owned, math.floor(t / 3600), math.floor(t / 60) % 60)

    service.active = true
    game.stack:push(TextBox.new(game,
      panel .. Strings("\fWould you like to\nSAVE the game?"), nil, {
      choice = function(yes)
        if not yes then service.active = false return end
        game.stack:push(TextBox.new(game, Strings("Now saving..."), function()
          local writeOk, writeErr = pcall(game.writeSave, game)
          service.active = false
          if not writeOk then service.lastError = tostring(writeErr) return end
          game.stack:push(TextBox.new(game,
            Strings("%s saved\nthe game!", player), nil, { auto = {
              sound = function()
                local soundOk, Sound = pcall(require, "src.core.Sound")
                return soundOk and Sound.play(game.data, "Save") or nil
              end,
              delay = 30,
            } }))
        end, { auto = { delay = 120 } }))
      end,
    }))
    service.lastError = nil
    return true
  end

  function service.status()
    return { active = service.active, error = service.lastError, kind = "native_game_save" }
  end

  return service
end
