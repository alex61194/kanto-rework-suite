local function createPresenter(opts)
  opts = opts or {}
  local Layout = opts.Layout
  local Theme = opts.Theme
  local I18n = opts.I18n
  local runtime = opts.runtime or {}
  local MenuClass = opts.MenuClass

  local fontCache = {}
  local function font(size)
    size = math.floor(math.max(9, size or 14))
    if not fontCache[size] and love and love.graphics and love.graphics.newFont then
      fontCache[size] = love.graphics.newFont(size)
    end
    return fontCache[size] or (love and love.graphics and love.graphics.getFont and love.graphics.getFont())
  end

  local function text(val)
    if type(val) == "string" then return val end
    if type(val) == "table" and val.label then return tostring(val.label) end
    if val == nil then return "" end
    return tostring(val)
  end

  local function topState(game)
    if not game then return nil end
    if game.stack and type(game.stack.top) == "function" then
      return game.stack:top()
    end
    if game.stack and type(game.stack.states) == "table" then
      return game.stack.states[#game.stack.states]
    end
    return nil
  end

  local function isMenuInstance(state)
    if type(state) ~= "table" then return false end
    if MenuClass and (getmetatable(state) == MenuClass or state.__index == MenuClass) then
      return true
    end
    return type(state.items) == "table"
      and type(state.index) == "number"
      and (type(state.clampScroll) == "function" or type(state.scroll) == "number")
  end

  local function isSupportedStartMenu(game)
    local state = topState(game)
    if not state then return false, nil, "no active state" end
    if state.screenId == "StartMenu" then return true, state, "screenId" end

    -- Structure heuristic for Gen1Recomp vanilla Start Menu
    if isMenuInstance(state) and state.startCloses == true then
      local labels = {}
      for i, item in ipairs(state.items or {}) do
        labels[i] = text(item.label or item):upper()
      end
      local joined = table.concat(labels, " ")
      if joined:find("POK") or joined:find("ITEM") or joined:find("SAVE") or joined:find("OBJ") or joined:find("GUARDAR") then
        return true, state, "structural"
      end
    end

    return false, state, "unsupported state"
  end

  local function trainerSummary(game)
    local save = game and game.save or {}
    local player = save.player or {}
    local party = save.party or {}
    local mapName = "PALLET TOWN"

    if player.map and game and game.data and game.data.maps and game.data.maps[player.map] then
      mapName = game.data.maps[player.map].name or player.map
    elseif player.map then
      mapName = tostring(player.map)
    end

    local seconds = tonumber(save.playTime) or 0
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local timeStr = string.format("%02d:%02d", hours, mins)

    return {
      name = text(player.name or "RED"):upper(),
      map = text(mapName):upper(),
      money = tonumber(save.money) or 0,
      party = #party,
      time = timeStr,
      owned = (save.pokedex and save.pokedex.owned and type(save.pokedex.owned) == "table" and 0) or 0,
      seen = (save.pokedex and save.pokedex.seen and type(save.pokedex.seen) == "table" and 0) or 0,
    }
  end

  local function roundedShadow(x, y, w, h, r, color, blur)
    if not (love and love.graphics) then return end
    blur = blur or 6
    Theme.setColor(color)
    for i = 1, blur do
      local a = (color[4] or 0.3) / blur * (blur - i + 1) / blur
      love.graphics.setColor(color[1] or 0, color[2] or 0, color[3] or 0, a)
      love.graphics.rectangle("fill", x - i, y - i + 2, w + i * 2, h + i * 2, r + i)
    end
  end

  local function line(theme, x, y, w)
    if not (love and love.graphics) then return end
    Theme.setColor(theme.border)
    love.graphics.setLineWidth(1)
    love.graphics.line(x, y, x + w, y)
  end

  local function getLocalizedLabel(rawLabel, i18n)
    if not rawLabel or not i18n then return text(rawLabel) end
    local s = text(rawLabel):upper()
    if s:find("POK.*DEX") then return i18n:t("pokedex") end
    if s:find("POK.*MON") then return i18n:t("pokemon") end
    if s:find("ITEM") or s:find("OBJETO") then return i18n:t("item") end
    if s:find("SAVE") or s:find("GUARDAR") then return i18n:t("save") end
    if s:find("OPTION") or s:find("OPCION") then return i18n:t("option") end
    return s
  end

  local function drawStartMenu(game, viewport, profile, i18n)
    local ok, state = isSupportedStartMenu(game)
    if not ok or not state then return false end

    local theme = Theme.get(profile and profile.theme)
    local rows = state.items or {}
    local layout = Layout.computeStartMenu(viewport, #rows)
    local selected = state.index or 1
    local scroll = state.scroll or 0
    local maxScroll = math.max(0, #rows - layout.visibleRows)

    runtime.startMenu = {
      state = state,
      layout = layout,
      scroll = scroll,
      regions = {},
    }

    love.graphics.push("all")
    love.graphics.origin()

    -- Backdrop
    Theme.setColor(theme.backdrop)
    love.graphics.rectangle("fill", 0, 0, viewport.width, viewport.height)

    -- Container box
    roundedShadow(layout.x, layout.y, layout.w, layout.h, 18, theme.shadow, 8)
    Theme.setColor(theme.paper)
    love.graphics.rectangle("fill", layout.x, layout.y, layout.w, layout.h, 18)
    Theme.setColor(theme.border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", layout.x + 1, layout.y + 1, layout.w - 2, layout.h - 2, 18)

    -- Accent bar
    Theme.setColor(theme.accent)
    love.graphics.rectangle("fill", layout.x, layout.y, 8, layout.h, 18, 0, 18, 0)

    -- Header
    love.graphics.setFont(font(12))
    Theme.setColor(theme.accentDark)
    love.graphics.print(i18n and i18n:t("app_name") or "DIARIO DE CAMPO", layout.x + 28, layout.y + 24)
    love.graphics.setFont(font(28))
    Theme.setColor(theme.ink)
    love.graphics.print(i18n and i18n:t("region_name") or "KANTO", layout.x + 28, layout.y + 40)
    love.graphics.setFont(font(11))
    Theme.setColor(theme.subtle)
    local countStr = (i18n and i18n:t("entries_count", #rows)) or string.format("%02d ENTRADAS", #rows)
    love.graphics.print(countStr, layout.x + layout.w - 110, layout.y + 50)

    local contentY = layout.y + layout.headerHeight
    line(theme, layout.x + 24, contentY - 1, layout.w - 48)

    -- Render Menu Rows
    for visibleIndex = 1, layout.visibleRows do
      local itemIndex = scroll + visibleIndex
      local item = rows[itemIndex]
      if not item then break end

      local rowY = contentY + (visibleIndex - 1) * layout.rowHeight
      local hovered = runtime.hoveredItem == itemIndex
      local active = itemIndex == selected
      local rx = layout.x + 18
      local rw = layout.w - 36

      if active then
        Theme.setColor(theme.accent)
        love.graphics.rectangle("fill", rx, rowY + 4, rw, layout.rowHeight - 8, 10)
      elseif hovered then
        Theme.setColor(theme.accentSoft)
        love.graphics.rectangle("fill", rx, rowY + 4, rw, layout.rowHeight - 8, 10)
      end

      -- Index badge
      love.graphics.setFont(font(11))
      Theme.setColor(active and theme.onAccent or theme.subtle)
      love.graphics.print(string.format("%02d", itemIndex), rx + 14, rowY + (layout.rowHeight - 11) * 0.5)

      -- Label
      love.graphics.setFont(font(math.max(16, math.floor(layout.rowHeight * 0.34))))
      Theme.setColor(active and theme.onAccent or theme.ink)
      local labelStr = getLocalizedLabel(item.label or item, i18n)
      love.graphics.print(labelStr, rx + 56, rowY + (layout.rowHeight - love.graphics.getFont():getHeight()) * 0.5)

      -- Active arrow
      if active then
        Theme.setColor(theme.onAccent)
        local arrowX = rx + rw - 26
        local cy = rowY + layout.rowHeight * 0.5
        love.graphics.polygon("fill", arrowX, cy - 6, arrowX + 8, cy, arrowX, cy + 6)
      end

      runtime.startMenu.regions[#runtime.startMenu.regions + 1] = {
        kind = "menu_row",
        itemIndex = itemIndex,
        x = rx,
        y = rowY,
        w = rw,
        h = layout.rowHeight,
      }
    end

    -- Footer
    local footerY = layout.y + layout.h - layout.footerHeight
    line(theme, layout.x + 24, footerY, layout.w - 48)
    love.graphics.setFont(font(11))
    Theme.setColor(theme.muted)
    local hintKey = runtime.lastInput == "controller" and "action_hint_controller"
      or (runtime.lastInput == "mouse" and "action_hint_mouse" or "action_hint_keyboard")
    local hintText = i18n and i18n:t(hintKey) or "A CONFIRMAR - B VOLVER"
    love.graphics.print(hintText, layout.x + 28, footerY + (layout.footerHeight - love.graphics.getFont():getHeight()) * 0.5)

    -- Scroll indicators
    if scroll > 0 then
      Theme.setColor(theme.accent)
      love.graphics.polygon("fill", layout.x + layout.w - 28, contentY + 10,
        layout.x + layout.w - 20, contentY + 22,
        layout.x + layout.w - 36, contentY + 22)
    end
    if scroll < maxScroll then
      local bottomY = footerY - 10
      Theme.setColor(theme.accent)
      love.graphics.polygon("fill", layout.x + layout.w - 28, bottomY,
        layout.x + layout.w - 20, bottomY - 12,
        layout.x + layout.w - 36, bottomY - 12)
    end

    love.graphics.pop()
    return true
  end

  local function drawOverlay(game, viewport, profile, i18n)
    runtime.overlayRegion = nil
    if not (profile and profile.overlayVisible) then return false end
    if isSupportedStartMenu(game) then return false end

    local theme = Theme.get(profile.theme)
    local class = Layout.classify(viewport.width, viewport.height)
    local scale = math.max(0.82, math.min(1.20, math.min(viewport.width / 1920, viewport.height / 1080) + 0.22))
    local width = math.floor((class == "portrait" and 300 or 350) * scale)
    local height = math.floor(164 * scale)
    local x, y = Layout.normalizedToWindow(profile, viewport, width, height)
    local summary = trainerSummary(game)

    runtime.overlayRegion = {
      kind = "overlay", x = x, y = y, w = width, h = height,
      headerH = math.floor(38 * scale),
    }

    love.graphics.push("all")
    love.graphics.origin()

    roundedShadow(x, y, width, height, 16, theme.shadow, 6)
    Theme.setColor(theme.night)
    love.graphics.rectangle("fill", x, y, width, height, 16)
    Theme.setColor(runtime.editMode and theme.accent or theme.border)
    love.graphics.setLineWidth(runtime.editMode and 3 or 1.5)
    love.graphics.rectangle("line", x, y, width, height, 16)

    -- Header bar
    Theme.setColor(theme.accent)
    love.graphics.rectangle("fill", x, y, width, runtime.overlayRegion.headerH, 16, 16, 0, 0)
    love.graphics.setFont(font(math.max(12, math.floor(13 * scale))))
    Theme.setColor(theme.onAccent)
    local headerTitle = runtime.editMode
      and (i18n and i18n:t("overlay_edit_mode") or "MODO EDICIÓN DE OVERLAY")
      or (i18n and i18n:t("companion_title") or "COMPAÑERO DE KANTO")
    love.graphics.print(headerTitle, x + 15, y + 10 * scale)

    -- Body
    love.graphics.setFont(font(math.max(17, math.floor(20 * scale))))
    Theme.setColor(theme.nightText)
    love.graphics.print(summary.name, x + 17, y + runtime.overlayRegion.headerH + 15 * scale)

    love.graphics.setFont(font(math.max(11, math.floor(12 * scale))))
    Theme.setColor(theme.accent)
    love.graphics.print(summary.map:upper(), x + 17, y + runtime.overlayRegion.headerH + 43 * scale)

    Theme.setColor(theme.nightMuted)
    local partyText = i18n and i18n:t("party_summary", summary.party, summary.money, summary.time)
      or string.format("EQUIPO %d/6     ¥%d     %s", summary.party, summary.money, summary.time)
    love.graphics.print(partyText, x + 17, y + runtime.overlayRegion.headerH + 70 * scale)

    local hintStr = runtime.editMode
      and (i18n and i18n:t("edit_hint") or "ARRASTRA EL ENCABEZADO - F9 PARA FIJAR")
      or (i18n and i18n:t("shortcut_hint") or "F8 OCULTAR - F9 EDITAR")
    love.graphics.print(hintStr, x + 17, y + runtime.overlayRegion.headerH + 99 * scale)

    love.graphics.pop()
    return true
  end

  local function drawDiagnostics(game, viewport, profile, i18n, enabled)
    if not enabled then return end
    local theme = Theme.get(profile and profile.theme)
    local ok, state, reason = isSupportedStartMenu(game)
    local stateName = ok and (i18n and i18n:t("start_menu_detected") or "MENÚ INICIO")
      or (i18n and i18n:t("native_world") or "MUNDO NATIVO")
    local label = string.format("KRS 0.1.0 - %s - %s", stateName, text(reason or (state and state.screenId) or "ok"))

    local f = font(11)
    local width = math.min(viewport.width - 32, f:getWidth(label) + 28)
    local x, y = 16, viewport.height - 36

    love.graphics.push("all")
    love.graphics.origin()
    Theme.setColor(theme.night)
    love.graphics.rectangle("fill", x, y, width, 24, 6)
    Theme.setColor(ok and theme.accent or theme.nightMuted)
    love.graphics.rectangle("fill", x, y, 5, 24, 6, 0, 0, 6)
    love.graphics.setFont(f)
    Theme.setColor(theme.nightText)
    love.graphics.print(label, x + 14, y + 6)
    love.graphics.pop()
  end

  local function hitTest(x, y)
    local menu = runtime.startMenu
    if menu then
      for _, region in ipairs(menu.regions or {}) do
        if x >= region.x and x <= region.x + region.w
            and y >= region.y and y <= region.y + region.h then
          return region
        end
      end
    end
    local overlay = runtime.overlayRegion
    if overlay and x >= overlay.x and x <= overlay.x + overlay.w
        and y >= overlay.y and y <= overlay.y + overlay.h then
      return overlay
    end
    return nil
  end

  return {
    topState = topState,
    isSupportedStartMenu = isSupportedStartMenu,
    drawStartMenu = drawStartMenu,
    drawOverlay = drawOverlay,
    drawDiagnostics = drawDiagnostics,
    hitTest = hitTest,
  }
end

return createPresenter
