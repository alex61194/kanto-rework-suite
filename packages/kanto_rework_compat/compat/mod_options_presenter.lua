local function createModOptionsPresenter(deps)
  local Core = deps.Core
  local Theme = deps.Theme
  local I18n = deps.I18n

  local Presenter = {}

  local function font(size)
    size = math.floor(math.max(10, size or 14))
    return love.graphics.newFont and love.graphics.newFont(size) or love.graphics.getFont()
  end

  function Presenter.drawModManager(managerState, viewport, profile, i18n)
    if not (love and love.graphics and viewport) then return false end
    i18n = i18n or (Core and Core.i18n)
    local theme = Theme and Theme.get(profile and profile.theme) or {}

    local width = tonumber(viewport.width) or 1920
    local height = tonumber(viewport.height) or 1080
    local boxW = math.min(1040, math.floor(width * 0.78))
    local boxH = math.min(720, math.floor(height * 0.84))
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
    love.graphics.rectangle("fill", x, y, boxW, 60, 18, 18, 0, 0)
    love.graphics.setFont(font(18))
    Theme.setColor(theme.onAccent or { 1, 1, 1, 1 })
    love.graphics.print(i18n and i18n:t("mods_manager_title") or "GESTOR DE MODS", x + 24, y + 18)

    -- Left: Installed Mods List
    local leftW = math.floor((boxW - 72) * 0.40)
    local leftX = x + 24
    local rightX = leftX + leftW + 24
    local rightW = boxW - leftW - 72
    local contentY = y + 80

    love.graphics.setFont(font(14))
    Theme.setColor(theme.ink or { 0.1, 0.1, 0.1, 1 })
    love.graphics.print(i18n and i18n:t("installed_mods") or "MODS INSTALADOS", leftX, contentY)

    local mods = managerState and managerState.mods or {
      { id = "kanto_rework_core", name = "Kanto Rework Core", enabled = true },
      { id = "kanto_rework_ui", name = "Kanto Rework UI", enabled = true },
      { id = "kanto_rework_compat", name = "Kanto Rework Compat", enabled = true },
    }

    local my = contentY + 28
    for i, m in ipairs(mods) do
      Theme.setColor(theme.night or { 0.2, 0.2, 0.25, 0.1 })
      love.graphics.rectangle("fill", leftX, my, leftW, 44, 8)

      love.graphics.setFont(font(13))
      Theme.setColor(theme.ink or { 0.1, 0.1, 0.1, 1 })
      love.graphics.print(m.name or m.id, leftX + 14, my + 13)

      -- Enabled toggle badge
      Theme.setColor(m.enabled and { 0.2, 0.7, 0.3, 1 } or { 0.6, 0.6, 0.6, 1 })
      love.graphics.rectangle("fill", leftX + leftW - 32, my + 14, 18, 18, 4)

      my = my + 52
    end

    -- Right: Settings for Selected Mod
    love.graphics.setFont(font(14))
    Theme.setColor(theme.ink or { 0.1, 0.1, 0.1, 1 })
    love.graphics.print(i18n and i18n:t("mod_settings") or "AJUSTES DEL MOD", rightX, contentY)

    Theme.setColor(theme.night or { 0.15, 0.15, 0.2, 0.95 })
    love.graphics.rectangle("fill", rightX, contentY + 28, rightW, boxH - 130, 12)

    -- Accessibility Section
    local sy = contentY + 48
    love.graphics.setFont(font(15))
    Theme.setColor(theme.nightText or { 1, 1, 1, 1 })
    love.graphics.print(i18n and i18n:t("accessibility") or "ACCESIBILIDAD", rightX + 20, sy)

    love.graphics.setFont(font(12))
    Theme.setColor(theme.nightMuted or { 0.7, 0.7, 0.7, 1 })
    love.graphics.print(i18n and i18n:t("color_vision") or "VISIÓN DE COLOR", rightX + 20, sy + 28)

    local profiles = { "color_standard", "color_protanopia", "color_deuteranopia", "color_tritanopia" }
    local px = rightX + 20
    for _, pr in ipairs(profiles) do
      Theme.setColor(theme.accent or { 0.8, 0.2, 0.2, 1 })
      love.graphics.rectangle("fill", px, sy + 52, 110, 28, 6)
      love.graphics.setFont(font(10))
      Theme.setColor(theme.onAccent or { 1, 1, 1, 1 })
      love.graphics.printf(i18n and i18n:t(pr) or pr, px, sy + 60, 110, "center")
      px = px + 120
    end

    -- Footer Buttons
    local footerY = y + boxH - 48
    Theme.setColor(theme.accent or { 0.8, 0.2, 0.2, 1 })
    love.graphics.rectangle("fill", x + boxW - 200, footerY, 176, 36, 8)
    love.graphics.setFont(font(12))
    Theme.setColor(theme.onAccent or { 1, 1, 1, 1 })
    love.graphics.printf(i18n and i18n:t("save_changes") or "GUARDAR CAMBIOS", x + boxW - 200, footerY + 10, 176, "center")

    love.graphics.pop()
    return true
  end

  return Presenter
end

return createModOptionsPresenter
