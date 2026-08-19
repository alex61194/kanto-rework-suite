local function createBagPresenter(deps)
  deps = deps or {}
  local Core = deps.Core or _G.__KANTO_REWORK_CORE_P0 or {}
  local Items = deps.Items or Core.Items
  local Theme = deps.Theme or Core.Theme
  local I18n = deps.I18n or Core.i18n

  local Presenter = {}

  local fontCache = {}
  local function font(size)
    size = math.floor(math.max(9, size or 14))
    if not fontCache[size] and love and love.graphics and love.graphics.newFont then
      local ok, f = pcall(love.graphics.newFont, size)
      if ok and f then fontCache[size] = f end
    end
    return fontCache[size] or (love and love.graphics and love.graphics.getFont and love.graphics.getFont())
  end

  function Presenter.drawBag(bagState, viewport, profile, i18n)
    if not (love and love.graphics and bagState and viewport) then return false end
    i18n = i18n or I18n
    local theme = Theme and Theme.get(profile and profile.theme) or {}

    local width = tonumber(viewport.width) or 1920
    local height = tonumber(viewport.height) or 1080
    local boxW = math.min(1140, math.floor(width * 0.80))
    local boxH = math.min(760, math.floor(height * 0.86))
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

    -- Header bar with Pockets
    Theme.setColor(theme.accent or { 0.8, 0.2, 0.2, 1 })
    love.graphics.rectangle("fill", x, y, boxW, 58, 18)
    love.graphics.setFont(font(18))
    Theme.setColor(theme.onAccent or { 1, 1, 1, 1 })
    love.graphics.print(i18n and i18n:t("item") or "MOCHILA", x + 24, y + 16)

    -- Pocket Tabs
    local pockets = { "medicine", "balls", "battle", "berries", "other", "tmhm", "treasures", "key" }
    local tabX = x + 160
    local tabW = math.floor((boxW - 180) / #pockets)
    local activePocket = bagState.activePocket or "medicine"
    local locale = i18n and i18n:getLocale() or "es"

    for _, pKey in ipairs(pockets) do
      local pInfo = Items and Items.POCKETS and Items.POCKETS[pKey] or {}
      local pName = i18n and i18n:t("pocket_" .. pKey) or pInfo.name_es or pKey
      local isActive = pKey == activePocket

      if isActive then
        Theme.setColor(theme.paper or { 1, 1, 1, 1 })
        love.graphics.rectangle("fill", tabX, y + 10, tabW - 4, 48, 8)
        Theme.setColor(theme.accent or { 0.8, 0.2, 0.2, 1 })
      else
        Theme.setColor({ 1, 1, 1, 0.6 })
      end

      love.graphics.setFont(font(11))
      love.graphics.printf(string.format("%s %s", pInfo.icon or "•", pName), tabX, y + 22, tabW - 4, "center")
      tabX = tabX + tabW
    end

    -- Left: Items in current pocket
    local leftW = math.floor((boxW - 48) * 0.55)
    local leftX = x + 24
    local rightX = leftX + leftW + 24
    local rightW = boxW - leftW - 72
    local contentY = y + 74

    local items = bagState.items or {}
    local selectedIndex = bagState.selectedIndex or 1
    local rowH = 46

    for i = 1, math.min(10, #items) do
      local itm = items[i]
      local ry = contentY + (i - 1) * (rowH + 6)
      local isSelected = i == selectedIndex

      if isSelected then
        Theme.setColor(theme.accent or { 0.8, 0.2, 0.2, 1 })
        love.graphics.rectangle("fill", leftX, ry, leftW, rowH, 8)
        Theme.setColor(theme.onAccent or { 1, 1, 1, 1 })
      else
        Theme.setColor(theme.night or { 0.2, 0.2, 0.25, 0.1 })
        love.graphics.rectangle("fill", leftX, ry, leftW, rowH, 8)
        Theme.setColor(theme.ink or { 0.1, 0.1, 0.1, 1 })
      end

      local itmName = Items and Items.getName(itm.name or itm.id or itm, locale) or tostring(itm.name or itm)
      local count = tonumber(itm.count) or 1

      love.graphics.setFont(font(14))
      love.graphics.print(itmName, leftX + 16, ry + 12)

      if count > 1 then
        love.graphics.setFont(font(12))
        love.graphics.print(string.format("x%02d", count), leftX + leftW - 60, ry + 14)
      end
    end

    -- Right: Selected Item Details
    local selectedItem = items[selectedIndex]
    if selectedItem then
      local itmName = Items and Items.getName(selectedItem.name or selectedItem.id or selectedItem, locale)
        or tostring(selectedItem.name or selectedItem)
      local itmDesc = Items and Items.getDescription(selectedItem.name or selectedItem.id or selectedItem, locale)
        or "Objeto del inventario."

      Theme.setColor(theme.night or { 0.15, 0.15, 0.2, 0.95 })
      love.graphics.rectangle("fill", rightX, contentY, rightW, boxH - 100, 12)

      love.graphics.setFont(font(18))
      Theme.setColor(theme.nightText or { 1, 1, 1, 1 })
      love.graphics.print(itmName, rightX + 20, contentY + 24)

      Theme.setColor(theme.accent or { 0.8, 0.2, 0.2, 1 })
      love.graphics.rectangle("fill", rightX + 20, contentY + 54, 40, 3)

      love.graphics.setFont(font(13))
      Theme.setColor(theme.nightMuted or { 0.85, 0.85, 0.85, 1 })
      love.graphics.printf(itmDesc, rightX + 20, contentY + 74, rightW - 40, "left")
    end

    love.graphics.pop()
    return true
  end

  return Presenter
end

return createBagPresenter
