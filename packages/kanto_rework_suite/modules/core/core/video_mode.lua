-- Kanto Rework Core display-mode compatibility extension.
--
-- Extends Gen1Recomp's native VIDEO MODE contract to three desktop modes:
--   windowed   -> normal resizable/decorated window
--   fullscreen -> exclusive fullscreen
--   borderless -> borderless WINDOWED mode sized to the active desktop
--
-- Important: LÖVE's setFullscreen(true, "desktop") is still a fullscreen
-- mode. Kanto's BORDERLESS deliberately does not use it: on desktop we use
-- fullscreen=false + borderless=true so Windows overlays and other windows
-- can layer above the game like a normal borderless window.
--
-- The native OptionsMenu and Game:applyOptions both resolve src.core.VideoMode,
-- so patching that shared service keeps one persisted source of truth:
-- save.options.videoMode. No second mod-specific display setting is created.
--
-- This is a compatibility/foundation patch, not visual-theme ownership.
return function(deps)
  local mod = assert(deps and deps.mod, "mod is required")
  local runtime = assert(deps and deps.runtime, "runtime is required")

  local MODES = { "windowed", "fullscreen", "borderless" }
  local LABELS = {
    windowed = "WINDOWED",
    fullscreen = "FULLSCREEN",
    borderless = "BORDERLESS",
  }

  local service = {}
  local installed = false
  local installError = nil
  local engineVideoMode = nil

  local function isMobile()
    local ok,Platform=pcall(require,"src.core.Platform")
    local detected=ok and Platform and Platform.detect and Platform.detect() or nil
    return detected and detected.mobile==true or false
  end

  local function normalize(mode)
    if mode == "fullscreen" or mode == "exclusive" or mode == "normal" then
      return "fullscreen"
    end
    if mode == "borderless" or mode == "desktop" then
      return "borderless"
    end
    return "windowed"
  end

  local function modeLabel(mode)
    return LABELS[normalize(mode)]
  end

  local function indexOf(mode)
    mode = normalize(mode)
    for i, candidate in ipairs(MODES) do
      if candidate == mode then return i end
    end
    return 1
  end

  local function cycle(mode, dir)
    dir = tonumber(dir) or 1
    dir = dir < 0 and -1 or 1
    local i = indexOf(mode)
    i = ((i - 1 + dir) % #MODES) + 1
    return MODES[i]
  end

  local function getMode()
    if not (love and love.window and love.window.getMode) then return nil end
    local ok, w, h, flags = pcall(love.window.getMode)
    if not ok or type(w) ~= "number" or type(h) ~= "number" then return nil end
    flags = type(flags) == "table" and flags or {}
    return w, h, flags
  end

  local function getPosition()
    if not (love and love.window and love.window.getPosition) then return nil, nil, nil end
    local ok, x, y, display = pcall(love.window.getPosition)
    if not ok then return nil, nil, nil end
    return x, y, display
  end

  local function rememberWindowedMode()
    local w, h, flags = getMode()
    if not w then return end
    -- Never replace the user's remembered normal window with the desktop-sized
    -- Kanto borderless window (or with any fullscreen state).
    if flags.fullscreen or flags.borderless then return end
    local x, y, positionDisplay = getPosition()
    runtime.lastWindowedMode = {
      width = w,
      height = h,
      display = tonumber(positionDisplay) or tonumber(flags.display) or 1,
      x = tonumber(x),
      y = tonumber(y),
      resizable = flags.resizable ~= false,
    }
  end

  local function windowFlags()
    local _, _, flags = getMode()
    return flags or {}
  end

  local function exitFullscreenIfNeeded()
    local flags = windowFlags()
    if not flags.fullscreen then return true end
    if not (love and love.window and love.window.setFullscreen) then
      return false, "love.window.setFullscreen unavailable"
    end
    local ok, result = pcall(love.window.setFullscreen, false)
    if not ok then return false, result end
    if result == false then return false, "window backend rejected fullscreen exit" end
    return true
  end

  local function restoreNormalWindow()
    local ok, err = exitFullscreenIfNeeded()
    if not ok then return false, err end

    local saved = runtime.lastWindowedMode
    local w, h, flags = getMode()
    if not w then return false, "love.window.getMode unavailable" end

    -- If we just left fullscreen and never had a Kanto snapshot, LÖVE has
    -- restored its own pre-fullscreen window here; preserve that before any
    -- borderless transition can replace it.
    if not saved and not flags.borderless then
      rememberWindowedMode()
      saved = runtime.lastWindowedMode
    end

    saved = saved or {
      width = w,
      height = h,
      display = tonumber(flags.display) or 1,
      resizable = flags.resizable ~= false,
    }

    local update = love and love.window and love.window.updateMode
    local setMode = love and love.window and love.window.setMode
    local fn = update or setMode
    if not fn then return false, "love.window.updateMode/setMode unavailable" end

    local modeFlags = {
      fullscreen = false,
      borderless = false,
      resizable = saved.resizable ~= false,
      display = tonumber(saved.display) or 1,
      centered = saved.x == nil or saved.y == nil,
    }
    if saved.x ~= nil and saved.y ~= nil then
      modeFlags.x = saved.x
      modeFlags.y = saved.y
    end

    local ok2, result = pcall(fn, saved.width, saved.height, modeFlags)
    if not ok2 then return false, result end
    if result == false then return false, "window backend rejected windowed mode" end
    return true
  end

  local function desktopDimensions(display)
    if not (love and love.window and love.window.getDesktopDimensions) then
      return nil, nil
    end
    local ok, w, h = pcall(love.window.getDesktopDimensions, display)
    if not ok or type(w) ~= "number" or type(h) ~= "number" then return nil, nil end
    return w, h
  end

  local function applyBorderless()
    -- A persisted Gen1Recomp BORDERLESS may already have put us in LÖVE
    -- desktop-fullscreen before this mod patches VideoMode. Exit that state
    -- first so we can recover/remember the normal window and then create the
    -- real windowed-borderless presentation.
    local flags = windowFlags()
    if flags.fullscreen then
      local ok, err = exitFullscreenIfNeeded()
      if not ok then return false, err end
      rememberWindowedMode()
    else
      rememberWindowedMode()
    end

    local _, _, currentFlags = getMode()
    currentFlags = currentFlags or {}
    local display = tonumber(currentFlags.display)
      or (runtime.lastWindowedMode and tonumber(runtime.lastWindowedMode.display))
      or 1
    local desktopW, desktopH = desktopDimensions(display)
    if not desktopW or not desktopH then
      return false, "love.window.getDesktopDimensions unavailable"
    end

    local update = love and love.window and love.window.updateMode
    local setMode = love and love.window and love.window.setMode
    local fn = update or setMode
    if not fn then return false, "love.window.updateMode/setMode unavailable" end

    local ok, result = pcall(fn, desktopW, desktopH, {
      fullscreen = false,
      borderless = true,
      resizable = false,
      centered = false,
      display = display,
      x = 0,
      y = 0,
    })
    if not ok then return false, result end
    if result == false then return false, "window backend rejected borderless mode" end

    -- updateMode's x/y flags are supported by the project's LÖVE 11.5 target;
    -- setPosition is an extra backend-safe nudge for SDL/Windows variants.
    if love.window.setPosition then
      pcall(love.window.setPosition, 0, 0, display)
    end
    return true
  end

  local function applyFullscreen()
    local flags = windowFlags()
    if flags.borderless and not flags.fullscreen then
      -- Restore the user's real normal window first. This ensures LÖVE's own
      -- pre-fullscreen restore target is not the desktop-sized borderless one.
      local ok, err = restoreNormalWindow()
      if not ok then return false, err end
    else
      rememberWindowedMode()
      if flags.fullscreen then
        local ok, err = exitFullscreenIfNeeded()
        if not ok then return false, err end
      end
    end

    if not (love and love.window and love.window.setFullscreen) then
      return false, "love.window.setFullscreen unavailable"
    end
    local ok, result = pcall(love.window.setFullscreen, true, "exclusive")
    if not ok then return false, result end
    if result == false then return false, "window backend rejected fullscreen mode" end
    return true
  end

  local function apply(mode)
    mode = normalize(mode)
    runtime.videoMode = mode
    if isMobile() then return true end

    if mode == "fullscreen" then
      return applyFullscreen()
    elseif mode == "borderless" then
      return applyBorderless()
    end
    return restoreNormalWindow()
  end

  local function applyOptions(opts)
    return apply(opts and opts.videoMode)
  end

  local function liveService()
    local state=runtime.videoModePatch
    return type(state)=="table" and state.service or nil
  end

  function service.install()
    local ok, VideoMode = pcall(require, "src.core.VideoMode")
    if not ok or type(VideoMode) ~= "table" then
      installed = false
      installError = tostring(VideoMode)
      return false, installError
    end

    local state=runtime.videoModePatch
    if type(state)~="table" or state.module~=VideoMode then
      state={original={}}
      runtime.videoModePatch=state
    end
    state.service = service
    state.module = VideoMode

    if not state.installed then
      state.original.MODES = VideoMode.MODES
      state.original.DEFAULT = VideoMode.DEFAULT
      state.original.normalize = VideoMode.normalize
      state.original.modeLabel = VideoMode.modeLabel
      state.original.cycle = VideoMode.cycle
      state.original.apply = VideoMode.apply
      state.original.applyOptions = VideoMode.applyOptions
      state.original.isMobile = VideoMode.isMobile

      VideoMode.normalize = function(mode)
        local live = liveService()
        return live and live.normalize(mode) or normalize(mode)
      end
      VideoMode.modeLabel = function(mode)
        local live = liveService()
        return live and live.modeLabel(mode) or modeLabel(mode)
      end
      VideoMode.cycle = function(mode, dir)
        local live = liveService()
        return live and live.cycle(mode, dir) or cycle(mode, dir)
      end
      VideoMode.apply = function(mode)
        local live = liveService()
        return live and live.apply(mode) or apply(mode)
      end
      VideoMode.applyOptions = function(opts)
        local live = liveService()
        return live and live.applyOptions(opts) or applyOptions(opts)
      end
      VideoMode.isMobile = function()
        local live = liveService()
        return live and live.isMobile() or isMobile()
      end
      state.installed = true
    end

    VideoMode.MODES = { "windowed", "fullscreen", "borderless" }
    VideoMode.DEFAULT = "windowed"
    engineVideoMode = VideoMode
    installed = true
    installError = nil
    return true
  end

  local function physicalMode()
    if isMobile() then return runtime.videoMode or "windowed", "mobile" end

    local _, _, flags = getMode()
    if flags then
      if flags.fullscreen then
        local kind = tostring(flags.fullscreentype or ""):lower()
        if kind == "exclusive" or kind == "normal" then
          return "fullscreen", "exclusive_fullscreen"
        end
        -- Legacy/native Gen1Recomp BORDERLESS uses desktop fullscreen.
        return "borderless", "desktop_fullscreen"
      end
      if flags.borderless then return "borderless", "windowed_borderless" end
      return "windowed", "windowed"
    end

    if love and love.window and love.window.getFullscreen then
      local ok, full, kind = pcall(love.window.getFullscreen)
      if ok and type(full) == "boolean" then
        if not full then return "windowed", "windowed" end
        return tostring(kind or ""):lower() == "exclusive"
          and "fullscreen" or "borderless",
          tostring(kind or ""):lower() == "exclusive"
          and "exclusive_fullscreen" or "desktop_fullscreen"
      end
    end
    return runtime.videoMode or "windowed", "unknown"
  end

  local function faithfulActive(game)
    local opts = game and game.save and game.save.options
    if tonumber(opts and opts.faithfulRes or 0) ~= 0 then return true end
    local ok, F = pcall(require, "src.core.FaithfulRes")
    return ok and type(F) == "table" and F.locked == true
  end

  function service.reconcile(game)
    if faithfulActive(game) then return false, runtime.videoMode end

    local opts = game and game.save and game.save.options
    local desired = normalize((opts and opts.videoMode) or runtime.videoMode)
    local actual, physicalKind = physicalMode()

    -- Migrate the engine's old desktop-fullscreen interpretation of BORDERLESS
    -- into Kanto's true borderless window as soon as the patched service owns
    -- the session. This is required on startup when the persisted setting was
    -- already BORDERLESS before mods loaded.
    if desired == "borderless" and physicalKind == "desktop_fullscreen" then
      local ok = apply("borderless")
      if ok then
        actual, physicalKind = physicalMode()
      end
    end

    runtime.videoMode = normalize(actual)
    runtime.videoPhysicalKind = physicalKind
    if opts and normalize(opts.videoMode) ~= runtime.videoMode then
      opts.videoMode = runtime.videoMode
      if game.writeOptions then game:writeOptions() end
      return true, runtime.videoMode
    end
    return false, runtime.videoMode
  end

  function service.current(game)
    if game then service.reconcile(game) end
    local opts = game and game.save and game.save.options
    return normalize((opts and opts.videoMode) or runtime.videoMode)
  end

  function service.set(game, mode)
    mode = normalize(mode)
    local ok, err = apply(mode)
    if ok then
      local opts = game and game.save and game.save.options
      if opts then opts.videoMode = mode end
      runtime.videoMode = mode
      local _, physicalKind = physicalMode()
      runtime.videoPhysicalKind = physicalKind
      if game and game.writeOptions then game:writeOptions() end
    end
    return ok, err, mode
  end

  function service.step(game, dir)
    service.reconcile(game)
    return service.set(game, cycle(service.current(game), dir))
  end

  function service.status()
    local physical, physicalKind = physicalMode()
    return {
      installed = installed,
      error = installError,
      modes = { "windowed", "fullscreen", "borderless" },
      current = runtime.videoMode,
      physical = physical,
      physicalKind = physicalKind,
      engineModule = engineVideoMode ~= nil,
      lastWindowedMode = runtime.lastWindowedMode,
    }
  end

  service.normalize = normalize
  service.modeLabel = modeLabel
  service.cycle = cycle
  service.apply = apply
  service.applyOptions = applyOptions
  service.isMobile = isMobile

  return service
end
