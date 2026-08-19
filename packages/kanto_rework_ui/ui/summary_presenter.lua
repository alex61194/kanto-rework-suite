local function createSummaryPresenter(deps)
  local Core = deps.Core
  local Types = deps.Types
  local Moves = deps.Moves
  local Theme = deps.Theme
  local I18n = deps.I18n

  local Presenter = {}

  local function font(size)
    size = math.floor(math.max(10, size or 14))
    return love.graphics.newFont and love.graphics.newFont(size) or love.graphics.getFont()
  end

  function Presenter.drawSummary(mon, viewport, profile, i18n)
    if not (love and love.graphics and mon and viewport) then return false end
    i18n = i18n or (Core and Core.i18n)
    local theme = Theme and Theme.get(profile and profile.theme) or {}

    local width = tonumber(viewport.width) or 1920
    local height = tonumber(viewport.height) or 1080
    local boxW = math.min(1080, math.floor(width * 0.75))
    local boxH = math.min(740, math.floor(height * 0.85))
    local x = math.floor((width - boxW) * 0.5)
    local y = math.floor((height - boxH) * 0.5)

    love.graphics.push("all")
    love.graphics.origin()

    -- Backdrop
    if theme.backdrop then
      Theme.setColor(theme.backdrop)
      love.graphics.rectangle("fill", 0, 0, width, height)
    end

    -- Container card
    Theme.setColor(theme.paper or { 0.95, 0.95, 0.95, 1 })
    love.graphics.rectangle("fill", x, y, boxW, boxH, 18)
    Theme.setColor(theme.border or { 0.3, 0.3, 0.3, 1 })
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, boxW, boxH, 18)

    -- Header bar
    Theme.setColor(theme.accent or { 0.8, 0.2, 0.2, 1 })
    love.graphics.rectangle("fill", x, y, boxW, 64, 18, 18, 0, 0)
    love.graphics.setFont(font(20))
    Theme.setColor(theme.onAccent or { 1, 1, 1, 1 })
    local monName = tostring(mon.nickname or mon.name or "POKéMON"):upper()
    love.graphics.print(monName, x + 24, y + 18)

    local lvlStr = i18n and i18n:t("summary_level", tonumber(mon.level) or 1) or string.format("NIVEL %d", tonumber(mon.level) or 1)
    love.graphics.print(lvlStr, x + boxW - 160, y + 18)

    -- Left Column: Stats & DV / Stat Experience
    local colW = math.floor((boxW - 72) * 0.5)
    local leftX = x + 24
    local contentY = y + 84

    love.graphics.setFont(font(15))
    Theme.setColor(theme.ink or { 0.1, 0.1, 0.1, 1 })
    love.graphics.print(i18n and i18n:t("summary_stats") or "ESTADÍSTICAS", leftX, contentY)

    local statsList = {
      { key = "stat_hp", label = "PS", val = tonumber(mon.hp) or 0, max = tonumber(mon.maxHp) or 100, dv = mon.dvs and mon.dvs.hp or 0, exp = mon.statExp and mon.statExp.hp or 0 },
      { key = "stat_attack", label = "Ataque", val = tonumber(mon.attack) or 0, dv = mon.dvs and mon.dvs.attack or 0, exp = mon.statExp and mon.statExp.attack or 0 },
      { key = "stat_defense", label = "Defensa", val = tonumber(mon.defense) or 0, dv = mon.dvs and mon.dvs.defense or 0, exp = mon.statExp and mon.statExp.defense or 0 },
      { key = "stat_speed", label = "Velocidad", val = tonumber(mon.speed) or 0, dv = mon.dvs and mon.dvs.speed or 0, exp = mon.statExp and mon.statExp.speed or 0 },
      { key = "stat_special", label = "Especial", val = tonumber(mon.special) or 0, dv = mon.dvs and mon.dvs.special or 0, exp = mon.statExp and mon.statExp.special or 0 },
    }

    local sy = contentY + 32
    for _, s in ipairs(statsList) do
      love.graphics.setFont(font(13))
      Theme.setColor(theme.subtle or { 0.4, 0.4, 0.4, 1 })
      local statLabel = i18n and i18n:t(s.key) or s.label
      love.graphics.print(statLabel, leftX, sy)

      Theme.setColor(theme.ink or { 0.1, 0.1, 0.1, 1 })
      local valText = s.max and string.format("%d / %d", s.val, s.max) or string.format("%d", s.val)
      love.graphics.print(valText, leftX + 110, sy)

      -- DV / Stat Exp indicator
      love.graphics.setFont(font(11))
      Theme.setColor(theme.accent or { 0.8, 0.2, 0.2, 1 })
      local dvText = string.format("GEN: %d/15", s.dv)
      love.graphics.print(dvText, leftX + 220, sy + 2)

      -- Progress bar for Stat Exp (0 to 65535)
      local barX = leftX + 310
      local barW = math.max(60, colW - 320)
      local barH = 8
      Theme.setColor(theme.border or { 0.7, 0.7, 0.7, 0.5 })
      love.graphics.rectangle("fill", barX, sy + 4, barW, barH, 4)
      local fillRatio = math.min(1.0, (s.exp or 0) / 65535)
      Theme.setColor(theme.accent or { 0.8, 0.2, 0.2, 1 })
      love.graphics.rectangle("fill", barX, sy + 4, math.floor(barW * fillRatio), barH, 4)

      sy = sy + 40
    end

    -- Right Column: Moves with Descriptions
    local rightX = leftX + colW + 24
    love.graphics.setFont(font(15))
    Theme.setColor(theme.ink or { 0.1, 0.1, 0.1, 1 })
    love.graphics.print(i18n and i18n:t("summary_moves") or "MOVIMIENTOS", rightX, contentY)

    local my = contentY + 32
    local moves = mon.moves or {}
    local locale = i18n and i18n:getLocale() or "es"

    for i = 1, 4 do
      local mv = moves[i]
      local boxH = 92
      Theme.setColor(theme.night or { 0.2, 0.2, 0.25, 0.9 })
      love.graphics.rectangle("fill", rightX, my, colW, boxH, 10)

      if mv then
        local moveData = Moves and Moves.get(mv.name or mv.id or mv) or {}
        local moveName = Moves and Moves.getName(mv.name or mv.id or mv, locale) or tostring(mv.name or mv):upper()
        local moveDesc = Moves and Moves.getDescription(mv.name or mv.id or mv, locale) or ""

        -- Type badge
        local mType = Types and Types.get(moveData.type) or {}
        if mType.color then
          love.graphics.setColor(mType.color[1], mType.color[2], mType.color[3], 1.0)
          love.graphics.rectangle("fill", rightX + 12, my + 10, 80, 20, 6)
          love.graphics.setFont(font(11))
          Theme.setColor({ 1, 1, 1, 1 })
          local typeName = Types.getName(moveData.type, locale)
          love.graphics.printf(typeName, rightX + 12, my + 13, 80, "center")
        end

        -- Move Name
        love.graphics.setFont(font(14))
        Theme.setColor(theme.nightText or { 1, 1, 1, 1 })
        love.graphics.print(moveName, rightX + 102, my + 11)

        -- PP
        local curPP = tonumber(mv.pp) or moveData.pp or 20
        local maxPP = tonumber(mv.maxPP) or moveData.pp or 20
        love.graphics.setFont(font(12))
        Theme.setColor(theme.nightMuted or { 0.7, 0.7, 0.7, 1 })
        love.graphics.print(string.format("PP %d/%d", curPP, maxPP), rightX + colW - 90, my + 12)

        -- Move Description
        love.graphics.setFont(font(11))
        Theme.setColor(theme.nightMuted or { 0.8, 0.8, 0.8, 1 })
        love.graphics.printf(moveDesc, rightX + 12, my + 38, colW - 24, "left")
      else
        love.graphics.setFont(font(13))
        Theme.setColor(theme.nightMuted or { 0.5, 0.5, 0.5, 1 })
        love.graphics.print("- - -", rightX + 16, my + (boxH - 14) * 0.5)
      end

      my = my + boxH + 12
    end

    love.graphics.pop()
    return true
  end

  return Presenter
end

return createSummaryPresenter
