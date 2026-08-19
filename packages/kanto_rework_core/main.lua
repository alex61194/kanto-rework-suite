return function(mod)
  local function loadModule(relative)
    local path = mod.path .. "/" .. relative
    local chunk, err = love.filesystem.load(path)
    assert(chunk, err or ("Unable to load " .. path))
    return chunk()
  end

  local Layout = loadModule("core/layout.lua")
  local Theme = loadModule("core/theme.lua")
  local I18nClass = loadModule("core/i18n.lua")
  local SafeSave = loadModule("core/safe_save.lua")
  local createProfileStore = loadModule("core/profile.lua")
  local createPresenter = loadModule("core/presenter.lua")
  local createNativePointer = loadModule("core/native_pointer.lua")
  local createPointer = loadModule("core/pointer.lua")

  local locale_en = loadModule("locales/en.lua")
  local locale_es = loadModule("locales/es.lua")

  local i18n = I18nClass.new({
    defaultLocale = "es",
    locales = {
      en = locale_en,
      es = locale_es,
    },
  })

  mod.options:define({
    { key = "language", label = "IDIOMA / LANGUAGE", type = "choice",
      default = "es",
      choices = {
        { "ESPAÑOL", "es" },
        { "ENGLISH", "en" },
      },
      description = "Selecciona el idioma de la interfaz / Select UI language." },
    { key = "replace_start_menu", label = "REPLACE START MENU", type = "toggle",
      default = true,
      description = "Replace the classic Start menu with the modern Field Journal presenter." },
    { key = "overlay", label = "COMPANION OVERLAY", type = "toggle",
      default = true,
      description = "Show the movable trainer companion overlay card outside the Start menu." },
    { key = "theme", label = "UI THEME", type = "choice",
      default = "field_journal",
      choices = {
        { "FIELD JOURNAL", "field_journal" },
        { "GRAPHITE", "graphite" },
        { "PURPLE NIGHT", "purple_night" },
        { "RETRO DMG", "retro" },
      },
      description = "Switch the live vector design tokens used by the interface." },
    { key = "diagnostics", label = "DIAGNOSTIC BADGE", type = "toggle",
      default = true,
      description = "Show the render-hook and screen detection state for this build." },
  })

  local global = _G.__KANTO_REWORK_CORE_P0 or { original = {} }
  _G.__KANTO_REWORK_CORE_P0 = global
  global.global = global
  global.mod = mod
  global.lastInput = global.lastInput or "keyboard"
  global.editMode = global.editMode or false
  global.hoveredItem = nil
  global.startMenu = nil
  global.overlayRegion = nil
  global.viewport = global.viewport or { width = 1920, height = 1080 }
  global.presenterReady = false
  global.presenterError = nil
  global.loggedPresenterError = nil
  global.lastErrorTime = 0
  global.i18n = i18n

  local profileStore = createProfileStore({
    path = "kanto_rework/profiles/default.lua",
    defaults = {
      language = mod.options:get("language") or "es",
      theme = mod.options:get("theme") or "field_journal",
      overlayVisible = true,
      widgetLocked = false,
      widgetX = 0.04,
      widgetY = 0.08,
    },
  })

  local profile, profileError = profileStore.load()
  global.profile = profile
  if profileError then mod.log:warn("profile fallback: %s", tostring(profileError)) end

  -- Initialize locale from profile
  i18n:setLocale(global.profile.language or "es")

  local function persist()
    local ok, err = profileStore.save(global.profile)
    if not ok then mod.log:warn("profile save failed: %s", tostring(err)) end
    return ok
  end

  local presenter = createPresenter({
    Layout = Layout,
    Theme = Theme,
    I18n = i18n,
    runtime = global,
    MenuClass = mod.ui and mod.ui.Menu,
  })
  global.presenter = presenter

  local nativePointer = createNativePointer({
    mod = mod,
    runtime = global,
    presenter = presenter,
  })
  global.nativePointer = nativePointer

  createPointer({
    mod = mod,
    runtime = global,
    presenter = presenter,
    Layout = Layout,
    persist = persist,
    native = nativePointer,
  })

  local function logPresenterError(err)
    local value = tostring(err)
    global.presenterError = value
    local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
    if global.loggedPresenterError ~= value or (now - global.lastErrorTime > 5.0) then
      global.loggedPresenterError = value
      global.lastErrorTime = now
      mod.log:error("presenter failed; native UI retained: %s", value)
    end
  end

  local function drawEmergencyNotice(viewport, message)
    if not (love and love.graphics and viewport) then return end
    local width = tonumber(viewport.width) or 640
    local height = tonumber(viewport.height) or 360
    local boxW = math.min(760, math.max(320, width - 48))
    local boxH = 118
    local x = (width - boxW) / 2
    local y = math.max(24, height - boxH - 52)
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setColor(0.10, 0.025, 0.035, 0.97)
    love.graphics.rectangle("fill", x, y, boxW, boxH, 12)
    love.graphics.setColor(0.96, 0.28, 0.25, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, boxW, boxH, 12)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(i18n:t("emergency_notice_title"), x + 18, y + 16)
    love.graphics.setColor(0.90, 0.84, 0.84, 1)
    love.graphics.printf(tostring(message), x + 18, y + 48, boxW - 36, "left")
    love.graphics.pop()
  end

  mod.events:on("game.ready", function(payload)
    global.game = payload and payload.game or global.game
  end)

  mod.events:on("mod.options_changed", function(payload)
    if not payload or payload.mod ~= mod.id then return end
    if payload.key == "theme" and type(payload.value) == "string" then
      global.profile.theme = payload.value
      persist()
    elseif payload.key == "language" and type(payload.value) == "string" then
      global.profile.language = payload.value
      i18n:setLocale(payload.value)
      persist()
    end
  end)

  mod.hooks:wrap("input.step", function(next, game, dt)
    global.game = game
    return next(game, dt)
  end, 120)

  mod.hooks:wrap("render.zones", function(next, game, zones)
    global.game = game
    return next(game, zones)
  end, 120)

  mod.hooks:wrap("render.compose", function(next, renderer, ctx)
    local handled = next(renderer, ctx)
    if handled == true or mod.options:get("replace_start_menu") == false then
      return handled
    end
    local supported = presenter.isSupportedStartMenu(global.game)
    if supported and global.presenterReady
        and love and love.graphics and ctx and ctx.uiCanvas then
      love.graphics.push("all")
      love.graphics.setCanvas(ctx.uiCanvas)
      love.graphics.clear(0, 0, 0, 0)
      love.graphics.pop()
    end
    return handled
  end, 120)

  mod.hooks:wrap("render.hud", function(next, game, viewport)
    global.game = game
    next(game, viewport)
    if not (love and love.graphics and viewport) then
      global.presenterReady = false
      return
    end

    global.viewport = viewport
    global.startMenu = nil
    global.overlayRegion = nil
    global.presenterReady = false
    global.presenterError = nil
    global.profile.theme = mod.options:get("theme") or global.profile.theme
    global.profile.language = mod.options:get("language") or global.profile.language
    i18n:setLocale(global.profile.language)

    if mod.options:get("replace_start_menu") ~= false then
      local ok, drawn = pcall(presenter.drawStartMenu,
        game, viewport, global.profile, i18n)
      if ok then
        global.presenterReady = drawn == true
      else
        logPresenterError(drawn)
        drawEmergencyNotice(viewport, drawn)
      end
    end

    if mod.options:get("overlay") ~= false then
      local ok, err = pcall(presenter.drawOverlay,
        game, viewport, global.profile, i18n)
      if not ok then
        logPresenterError(err)
        drawEmergencyNotice(viewport, err)
      end
    end

    local ok, err = pcall(presenter.drawDiagnostics,
      game, viewport, global.profile, i18n,
      mod.options:get("diagnostics") ~= false)
    if not ok then logPresenterError(err) end
  end, 120)

  mod.exports.version = 5
  mod.exports.layoutClass = function(width, height)
    return Layout.classify(width, height)
  end
  mod.exports.profile = function()
    return {
      language = global.profile.language,
      theme = global.profile.theme,
      overlayVisible = global.profile.overlayVisible,
      widgetLocked = global.profile.widgetLocked,
      widgetX = global.profile.widgetX,
      widgetY = global.profile.widgetY,
    }
  end
  mod.exports.diagnostics = function()
    local supported, state, reason = presenter.isSupportedStartMenu(global.game)
    return {
      hudActive = global.viewport ~= nil,
      presenterReady = global.presenterReady,
      presenterError = global.presenterError,
      startMenuSupported = supported,
      topScreenId = state and state.screenId or nil,
      supportReason = reason,
      viewport = global.viewport,
      language = i18n:getLocale(),
    }
  end
  mod.exports.i18n = i18n
  mod.exports.safeSave = SafeSave
  mod.exports.isPointerExperimental = false

  mod.log:info("Kanto Rework Core 0.1.0 loaded with Spanish & English i18n, safe save, and multi-ratio support.")
end
