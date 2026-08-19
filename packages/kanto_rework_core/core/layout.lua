local Layout = {}

function Layout.classify(width, height)
  width = tonumber(width) or 1920
  height = tonumber(height) or 1080
  local aspect = width / math.max(1, height)

  if aspect >= 2.2 then
    return "ultrawide"
  elseif aspect >= 1.65 then
    return "widescreen" -- 16:9
  elseif aspect >= 1.45 then
    return "steamdeck"  -- 16:10
  elseif aspect >= 1.05 then
    return "classic"    -- 4:3 or 10:9
  else
    return "portrait"   -- 9:16
  end
end

function Layout.computeStartMenu(viewport, rowCount)
  local width = tonumber(viewport and viewport.width) or 1920
  local height = tonumber(viewport and viewport.height) or 1080
  local class = Layout.classify(width, height)
  rowCount = math.max(1, tonumber(rowCount) or 6)

  local menu = {
    class = class,
    viewport = { width = width, height = height },
    totalRows = rowCount,
    headerHeight = 92,
    footerHeight = 52,
  }

  if class == "ultrawide" then
    menu.w = math.min(620, math.floor(width * 0.28))
    menu.h = math.min(880, math.max(480, height - 160))
    menu.x = math.floor((width - menu.w) * 0.5)
    menu.y = math.floor((height - menu.h) * 0.5)
    menu.visibleRows = math.min(rowCount, math.max(4, math.floor((menu.h - menu.headerHeight - menu.footerHeight) / 58)))
    menu.rowHeight = math.floor((menu.h - menu.headerHeight - menu.footerHeight) / menu.visibleRows)
  elseif class == "widescreen" then
    menu.w = math.min(560, math.floor(width * 0.36))
    menu.h = math.min(840, math.max(460, height - 120))
    menu.x = math.floor(width * 0.08)
    menu.y = math.floor((height - menu.h) * 0.5)
    menu.visibleRows = math.min(rowCount, math.max(4, math.floor((menu.h - menu.headerHeight - menu.footerHeight) / 54)))
    menu.rowHeight = math.floor((menu.h - menu.headerHeight - menu.footerHeight) / menu.visibleRows)
  elseif class == "steamdeck" then
    menu.w = math.min(540, math.floor(width * 0.40))
    menu.h = math.min(800, math.max(440, height - 90))
    menu.x = math.floor(width * 0.06)
    menu.y = math.floor((height - menu.h) * 0.5)
    menu.visibleRows = math.min(rowCount, math.max(4, math.floor((menu.h - menu.headerHeight - menu.footerHeight) / 52)))
    menu.rowHeight = math.floor((menu.h - menu.headerHeight - menu.footerHeight) / menu.visibleRows)
  elseif class == "classic" then
    menu.w = math.min(520, math.floor(width * 0.88))
    menu.h = math.min(760, math.max(400, height - 80))
    menu.x = math.floor((width - menu.w) * 0.5)
    menu.y = math.floor((height - menu.h) * 0.5)
    menu.visibleRows = math.min(rowCount, math.max(3, math.floor((menu.h - menu.headerHeight - menu.footerHeight) / 50)))
    menu.rowHeight = math.floor((menu.h - menu.headerHeight - menu.footerHeight) / menu.visibleRows)
  else -- portrait
    menu.w = math.floor(width * 0.92)
    menu.h = math.min(720, math.max(380, height * 0.65))
    menu.x = math.floor((width - menu.w) * 0.5)
    menu.y = math.floor(height * 0.20)
    menu.visibleRows = math.min(rowCount, math.max(3, math.floor((menu.h - menu.headerHeight - menu.footerHeight) / 48)))
    menu.rowHeight = math.floor((menu.h - menu.headerHeight - menu.footerHeight) / menu.visibleRows)
  end

  return menu
end

function Layout.normalizedToWindow(profile, viewport, widgetWidth, widgetHeight)
  local vpWidth = tonumber(viewport and viewport.width) or 1920
  local vpHeight = tonumber(viewport and viewport.height) or 1080
  local nx = tonumber(profile and profile.widgetX) or 0.04
  local ny = tonumber(profile and profile.widgetY) or 0.08

  local maxX = math.max(0, vpWidth - (widgetWidth or 300))
  local maxY = math.max(0, vpHeight - (widgetHeight or 160))

  local x = math.floor(math.max(8, math.min(maxX - 8, nx * vpWidth)))
  local y = math.floor(math.max(8, math.min(maxY - 8, ny * vpHeight)))

  return x, y
end

return Layout
