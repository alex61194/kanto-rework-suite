-- Semantic pointer adapters for the official Gen1Recomp native UI.
--
-- The adapters never call private callbacks directly. They translate a
-- window-space pointer target into the active native UI surface, update the
-- real screen selection, then inject an ordinary Game Boy action through
-- mod.input. This preserves native sounds, transitions, callbacks, validation
-- and other mod hooks.
return function(deps)
  local mod = assert(deps.mod)
  local runtime = assert(deps.runtime)
  local presenter = assert(deps.presenter)
  local mapInteraction = deps.mapInteraction

  local Native = {}

  local function game()
    return runtime.game
  end

  local function topState()
    local current = game()
    local stack = current and current.stack
    return stack and type(stack.top) == "function" and stack:top() or nil
  end

  local function isOverworld(state)
    local current = game()
    return state ~= nil and current and current.overworld
      and state == current.overworld
  end

  local function isBattleShape(state)
    return type(state) == "table"
      and type(state.phase) == "string"
      and type(state.menuIndex) == "number"
      and type(state.moveIndex) == "number"
      and state.player ~= nil and state.enemy ~= nil
  end

  local function surfaceSize(viewport)
    local gw = tonumber(viewport and viewport.gameWidth)
      or tonumber(viewport and viewport.width) or 0
    local gh = tonumber(viewport and viewport.gameHeight)
      or tonumber(viewport and viewport.height) or 0
    local scale = tonumber(viewport and viewport.scale)
    local dpiX = tonumber(viewport and viewport.dpiX) or 1
    local dpiY = tonumber(viewport and viewport.dpiY) or 1
    if scale and scale > 0 and gw > 0 and gh > 0 then
      local w = math.floor(gw * dpiX / scale + 0.5)
      local h = math.floor(gh * dpiY / scale + 0.5)
      if w >= 160 and h >= 144 and w <= 640 and h <= 576 then
        return w, h
      end
    end
    return 160, 144
  end

  -- Reverse Renderer:setUIAnchor for the anchored element currently on top.
  -- This matters for DYNAMIC UI layout: a ChoiceBox/TextBox may be drawn near
  -- the window edge rather than at its source location in the 160x144 canvas.
  local function anchoredCanvasPoint(state, x, y)
    if type(state) ~= "table" or not state.anchor then return nil end
    local current = game()
    local renderer = current and current.renderer
    local viewport = runtime.viewport
    if not renderer or not viewport or renderer.uiCentered
        or renderer.uiAnchorHold then return nil end
    if type(renderer.uiScale) ~= "function" then return nil end

    local okScale, up = pcall(renderer.uiScale, renderer)
    if not okScale or type(up) ~= "number" or up <= 0 then return nil end
    local uiw, uih = 160, 144
    if type(renderer.uiSize) == "function" then
      local okSize, w, h = pcall(renderer.uiSize, renderer)
      if okSize and type(w) == "number" and type(h) == "number" then
        uiw, uih = w, h
      end
    end

    local tx, ty = tonumber(state.tx), tonumber(state.ty)
    local tw, th = tonumber(state.tw), tonumber(state.th)
    if not (tx and ty and tw and th) then
      tx, ty = tonumber(state.boxTx), tonumber(state.boxTy)
      tw, th = tonumber(state.boxTw), tonumber(state.boxTh)
    end
    if not (tx and ty and tw and th) then return nil end

    local dpiX = tonumber(viewport.dpiX) or 1
    local dpiY = tonumber(viewport.dpiY) or 1
    local Ux, Uy = up / dpiX, up / dpiY
    local ww = tonumber(viewport.width) or 0
    local wh = tonumber(viewport.height) or 0
    if ww <= 0 or wh <= 0 then return nil end
    local pw, ph = ww * dpiX, wh * dpiY
    local uox = math.floor((pw - uiw * up) / 2) / dpiX
    local uoy = math.floor((ph - uih * up) / 2) / dpiY

    local sx, sy, sw, sh = tx * 8, ty * 8, tw * 8, th * 8
    local dw, dh = sw * Ux, sh * Uy
    local gapR = (uiw - (sx + sw)) * Ux
    local gapB = (uih - (sy + sh)) * Uy
    local dx, dy
    if state.anchor == "bottom" then
      dx = uox + sx * Ux
      dy = wh - gapB - dh
    elseif state.anchor == "topright" then
      dx = ww - gapR - dw
      dy = sy * Uy
    else
      dx, dy = uox + sx * Ux, uoy + sy * Uy
    end
    if x < dx or y < dy or x > dx + dw or y > dy + dh then return nil end
    return sx + (x - dx) / Ux, sy + (y - dy) / Uy
  end

  local function windowToCanvas(x, y, state)
    local ax, ay = anchoredCanvasPoint(state, x, y)
    if ax then return ax, ay end

    local viewport = runtime.viewport
    if not viewport then return nil end
    local gx = tonumber(viewport.gameX) or tonumber(viewport.x) or 0
    local gy = tonumber(viewport.gameY) or tonumber(viewport.y) or 0
    local gw = tonumber(viewport.gameWidth) or tonumber(viewport.width) or 0
    local gh = tonumber(viewport.gameHeight) or tonumber(viewport.height) or 0
    if gw <= 0 or gh <= 0 then return nil end
    if x < gx or y < gy or x > gx + gw or y > gy + gh then return nil end

    local surfaceW, surfaceH = surfaceSize(viewport)
    local ux = (x - gx) * surfaceW / gw
    local uy = (y - gy) * surfaceH / gh

    -- A classic menu pushed over a 304x144 wide battle is drawn in a centred
    -- 160x144 sub-surface. BattleState itself owns all 304 columns.
    if surfaceW > 160 and not isBattleShape(state) then
      ux = ux - (surfaceW - 160) / 2
    end
    if surfaceH > 144 and not isBattleShape(state) then
      uy = uy - (surfaceH - 144) / 2
    end
    return ux, uy
  end

  local function tap(button)
    mod.input:tap(game(), button)
    return true
  end

  local function tapA()
    return tap("a")
  end

  local function clampIndex(state, value, count)
    if count <= 0 then return false end
    state.index = math.max(1, math.min(count, value))
    if type(state.clampScroll) == "function" then state:clampScroll() end
    return true
  end

  local function looksLikeParty(state)
    if type(state) ~= "table" or type(state.index) ~= "number" then return false end
    if state.items ~= nil or state.rows ~= nil then return false end
    return type(state.bottomMessage) == "function"
      or state.subItems ~= nil
      or state.pickOnly ~= nil
      or state.tmhm ~= nil
      or state.onSwitch ~= nil
      or state.swapFrom ~= nil
      or state.softboiledFrom ~= nil
  end

  local function partyTarget(state, ux, uy)
    if state.heal then return nil end
    if state.submenu and type(state.subItems) == "table" then
      local n = #state.subItems
      if n <= 0 then return nil end
      local y0 = (17 - n * 2) * 8
      if ux < 72 or ux > 160 or uy < y0 or uy >= y0 + n * 16 then return nil end
      return "subIndex", math.floor((uy - y0) / 16) + 1, n
    end
    local current = game()
    local party = state.party or (current and current.save and current.save.party) or {}
    local count = #party
    if count <= 0 or ux < 0 or ux > 160 or uy < 0 or uy >= count * 16 then
      return nil
    end
    return "index", math.floor(uy / 16) + 1, count
  end


  local function looksLikeTownMap(state)
    return mapInteraction and mapInteraction.isTownMap
      and mapInteraction.isTownMap(state) or false
  end

  local function townMapTarget(state, ux, uy)
    if not looksLikeTownMap(state) then return nil end
    local index = mapInteraction.locationAt(state, ux, uy)
    if not index then return nil end
    return "mapLocation", index, #state.locs
  end

  local function looksLikeList(state)
    return type(state) == "table"
      and type(state.items) == "table"
      and type(state.rows) == "number"
      and state.startCloses == nil
      and (state.onChoose ~= nil or state.title ~= nil or state.footer ~= nil)
  end

  local function listTarget(state, ux, uy)
    if state.script or #state.items == 0 then return nil end
    local visible = math.max(0, math.floor(state.rows or 0))
    if ux < 0 or ux > 160 or uy < 16 or uy >= 16 + visible * 16 then return nil end
    local slot = math.floor((uy - 16) / 16) + 1
    local itemIndex = (state.scroll or 0) + slot
    if not state.items[itemIndex] then return nil end
    return "index", itemIndex, #state.items
  end

  local function looksLikeOptionRows(state)
    return type(state) == "table"
      and type(state.rows) == "table"
      and type(state.index) == "number"
      and state.items == nil
  end

  local function optionTarget(state, ux, uy)
    if ux < 0 or ux > 160 or uy < 0 or uy > 144 then return nil end
    if uy >= 128 then
      return "index", #state.rows + 1, #state.rows + 1
    end
    local slot = math.floor(uy / 32) + 1
    if slot < 1 or slot > 4 then return nil end
    local itemIndex = (state.scroll or 0) + slot
    if not state.rows[itemIndex] then return nil end
    return "index", itemIndex, #state.rows + 1
  end

  local function looksLikeBoxedMenu(state)
    return type(state) == "table"
      and type(state.items) == "table"
      and type(state.index) == "number"
      and type(state.tx) == "number"
      and type(state.ty) == "number"
      and type(state.tw) == "number"
      and type(state.th) == "number"
      and type(state.rowStep) == "number"
  end

  local function boxedMenuTarget(state, ux, uy)
    local count = #state.items
    if count <= 0 then return nil end
    local visible = state.maxVisible and math.min(state.maxVisible, count) or count
    local left, right = state.tx * 8, (state.tx + state.tw) * 8
    if ux < left or ux > right then return nil end
    local firstY = (state.ty + state.th - 2 - (visible - 1) * state.rowStep) * 8
    local step = state.rowStep * 8
    if step <= 0 then return nil end
    local row = math.floor((uy - firstY + step / 2) / step) + 1
    if row < 1 or row > visible then return nil end
    local rowY = firstY + (row - 1) * step
    if uy < rowY - step / 2 or uy > rowY + step / 2 then return nil end
    local itemIndex = (state.scroll or 0) + row
    if not state.items[itemIndex] then return nil end
    return "index", itemIndex, count
  end

  local function looksLikeChoice(state)
    return type(state) == "table"
      and type(state.index) == "number"
      and type(state.onChoose) == "function"
      and type(state.tx) == "number"
      and type(state.ty) == "number"
      and type(state.tw) == "number"
      and type(state.th) == "number"
      and state.items == nil and state.rows == nil
  end

  local function choiceTarget(state, ux, uy)
    if state.pending ~= nil then return nil end
    local left, right = state.tx * 8, (state.tx + state.tw) * 8
    local top, bottom = state.ty * 8, (state.ty + state.th) * 8
    if ux < left or ux > right or uy < top or uy > bottom then return nil end

    -- Match the two actual text rows rather than broad outward-biased bands.
    -- YES is drawn at ty+1, NO at ty+3; choose whichever row centre is nearer.
    local yesCenter = (state.ty + 1.5) * 8
    local noCenter = (state.ty + 3.5) * 8
    local index = math.abs(uy - yesCenter) <= math.abs(uy - noCenter) and 1 or 2
    return "index", index, 2
  end

  local function looksLikeSummary(state)
    return type(state) == "table"
      and state.mon ~= nil
      and (state.page == 1 or state.page == 2)
      and state.items == nil and state.rows == nil
  end

  local function looksLikeTextBox(state)
    return type(state) == "table"
      and type(state.pages) == "table"
      and type(state.pageIndex) == "number"
      and type(state.boxTx) == "number"
      and type(state.boxTy) == "number"
      and type(state.boxTw) == "number"
      and type(state.boxTh) == "number"
      and state.items == nil and state.rows == nil
  end

  local function textBoxTarget(state, ux, uy)
    local left, right = state.boxTx * 8, (state.boxTx + state.boxTw) * 8
    local top, bottom = state.boxTy * 8, (state.boxTy + state.boxTh) * 8
    if ux >= left and ux <= right and uy >= top and uy <= bottom then
      return "advance", 1, 1
    end
    return nil
  end

  local function looksLikeModManager(state)
    return type(state) == "table"
      and (state.screenId == "ManagerState"
        or (type(state.screen) == "string"
          and type(state.cursor) == "number"
          and type(state.scroll) == "number"
          and type(state.backStack) == "table"
          and type(state.rowsForScreen) == "function"))
  end

  -- LinkState is not a Menu/ListMenu and therefore needs a semantic adapter of
  -- its own. Keep it here, in the native-pointer compatibility layer, so the
  -- Kanto UI does not reach into link internals or duplicate link behaviour.
  local function looksLikeLink(state)
    return type(state) == "table"
      and type(state.stage) == "string"
      and type(state.exitWith) == "function"
      and type(state.startMode) == "function"
      and type(state.game) == "table"
  end

  local function linkRow(ux, uy, ys)
    if ux < 16 or ux > 152 then return nil end
    for i, y in ipairs(ys) do
      if uy >= y - 7 and uy <= y + 10 then return "linkIndex", i, #ys end
    end
    return nil
  end

  local function linkPrompt(ux, uy, confirmLabel)
    if uy < 116 or uy > 144 then return nil end
    if ux < 0 or ux > 160 then return nil end
    if ux <= 100 then return confirmLabel or "linkConfirm", 1, 1 end
    return "linkBack", 1, 1
  end

  local function linkTarget(state, ux, uy)
    local stage = state.stage
    if stage == "menu" then return linkRow(ux, uy, { 44, 60, 76 }) end
    if stage == "lanMenu" or stage == "onlineMenu" or stage == "modeSelect" then
      return linkRow(ux, uy, { 48, 68 })
    end
    if stage == "codeEntry" then
      if uy >= 52 and uy <= 92 and ux >= 8 and ux <= 152 then
        local best, dist
        local len = state.codeEntry and #(state.codeEntry.chars or {}) or 0
        for i = 1, len do
          local x = 16 + (i - 1) * 16
          local d = math.abs(ux - x)
          if not dist or d < dist then best, dist = i, d end
        end
        if best then return "linkCodePos", best, len end
      end
      return linkPrompt(ux, uy)
    end
    if stage == "addrEntry" then
      if uy >= 52 and uy <= 92 and ux >= 8 and ux <= 152 then
        local best, dist
        for i = 1, 12 do
          local octet = math.floor((i - 1) / 3)
          local x = 16 + (i - 1) * 8 + octet * 8
          local d = math.abs(ux - x)
          if not dist or d < dist then best, dist = i, d end
        end
        if best then return "linkAddrPos", best, 12 end
      end
      return linkPrompt(ux, uy)
    end
    if stage == "battleOptions" then
      if ux >= 72 and ux <= 152 and uy >= 44 and uy <= 80 then
        return "linkCycle", ux < 112 and -1 or 1, 1
      end
      return linkPrompt(ux, uy)
    end
    if stage == "notice" then
      if uy >= 116 and uy <= 144 and ux >= 0 and ux <= 160 then
        return "linkConfirm", 1, 1
      end
      return nil
    end
    if stage == "trade" then
      local trade = state.trade
      if trade and trade.stage == "picking" and ux >= 4 and ux <= 80 then
        local count = #((state.game.save and state.game.save.party) or {})
        for i = 1, count do
          local y = 20 + i * 12
          if uy >= y - 5 and uy <= y + 8 then return "linkIndex", i, count end
        end
      elseif trade and trade.stage == "confirming" then
        return linkPrompt(ux, uy)
      end
    end
    return nil
  end

  local function battleWide(state)
    if type(state.wideLayout) == "function" then
      local ok, result = pcall(state.wideLayout, state)
      if ok then return result == true end
    end
    local w = surfaceSize(runtime.viewport)
    return w > 160
  end

  local function battleTarget(state, ux, uy)
    local phase = state.phase
    local wide = battleWide(state)

    if phase == "menu" then
      if state.demo then return nil end
      if uy < 104 or uy > 144 then return nil end
      local col, row
      if state.safari then
        local rightStart = wide and 160 or 104
        local maxX = wide and 304 or 160
        if ux < 0 or ux > maxX then return nil end
        col = ux >= rightStart and 1 or 0
      else
        local left = wide and 160 or 64
        local rightStart = wide and 232 or 120
        local maxX = wide and 304 or 160
        if ux < left or ux > maxX then return nil end
        col = ux >= rightStart and 1 or 0
      end
      row = uy >= 124 and 1 or 0
      return "battleMenuIndex", row * 2 + col + 1, 4
    end

    if phase == "moveSelect" then
      local moves = state.player and state.player.curMoves or {}
      local count = #moves
      if count <= 0 then return nil end
      if wide then
        if ux < 0 or ux >= 224 or uy < 104 or uy > 144 then return nil end
        local col = ux >= 112 and 1 or 0
        local row = uy >= 124 and 1 or 0
        local index = row * 2 + col + 1
        if index > count then return nil end
        return "battleMoveIndex", index, count
      end
      if ux < 32 or ux > 160 or uy < 104 or uy >= 104 + count * 8 then return nil end
      return "battleMoveIndex", math.floor((uy - 104) / 8) + 1, count
    end

    if phase == "mimicSelect" then
      local moves = state.mimicMoves or {}
      local count = #moves
      if count <= 0 then return nil end
      if wide then
        if ux < 0 or ux >= 224 or uy < 104 or uy > 144 then return nil end
        local col = ux >= 112 and 1 or 0
        local row = uy >= 124 and 1 or 0
        local index = row * 2 + col + 1
        if index > count then return nil end
        return "battleMimicIndex", index, count
      end
      if ux < 0 or ux > 128 or uy < 64 or uy >= 64 + count * 8 then return nil end
      return "battleMimicIndex", math.floor((uy - 64) / 8) + 1, count
    end

    if phase == "messages" then
      local maxX = wide and 304 or 160
      if ux >= 0 and ux <= maxX and uy >= 104 and uy <= 144 then
        return "advance", 1, 1
      end
    end
    return nil
  end

  local function targetAt(state, ux, uy)
    if isBattleShape(state) then return battleTarget(state, ux, uy) end
    if looksLikeLink(state) then return linkTarget(state, ux, uy) end
    if looksLikeParty(state) then return partyTarget(state, ux, uy) end
    if looksLikeTownMap(state) then return townMapTarget(state, ux, uy) end
    if looksLikeList(state) then return listTarget(state, ux, uy) end
    if looksLikeOptionRows(state) then return optionTarget(state, ux, uy) end
    if looksLikeBoxedMenu(state) then return boxedMenuTarget(state, ux, uy) end
    if looksLikeChoice(state) then return choiceTarget(state, ux, uy) end
    if looksLikeTextBox(state) then return textBoxTarget(state, ux, uy) end
    if looksLikeSummary(state) and ux >= 0 and ux <= 160 and uy >= 0 and uy <= 144 then
      return "advance", 1, 1
    end
    return nil
  end

  local function applyTarget(state, field, value, count, activate)
    if field == "advance" then
      return activate and tapA() or true
    elseif field == "subIndex" then
      state.subIndex = math.max(1, math.min(count, value))
    elseif field == "index" then
      if not clampIndex(state, value, count) then return false end
    elseif field == "battleMenuIndex" then
      state.menuIndex = math.max(1, math.min(count, value))
    elseif field == "battleMoveIndex" then
      state.moveIndex = math.max(1, math.min(count, value))
    elseif field == "battleMimicIndex" then
      state.mimicIndex = math.max(1, math.min(count, value))
    elseif field == "mapLocation" then
      if activate then return mapInteraction.activate(game(), state, value) end
      return mapInteraction.select(game(), state, value)
    elseif field == "linkIndex" then
      state.index = math.max(1, math.min(count, value))
    elseif field == "linkCodePos" then
      if state.codeEntry then state.codeEntry.pos = math.max(1, math.min(count, value)) end
      return true
    elseif field == "linkAddrPos" then
      state.addrPos = math.max(1, math.min(count, value))
      return true
    elseif field == "linkCycle" then
      return activate and tap(value < 0 and "left" or "right") or true
    elseif field == "linkConfirm" then
      return activate and tapA() or true
    elseif field == "linkBack" then
      return activate and tap("b") or true
    else
      return false
    end
    if activate then return tapA() end
    return true
  end

  function Native.isOverworld()
    return isOverworld(topState())
  end

  function Native.inGameViewport(x, y)
    return windowToCanvas(x, y, topState()) ~= nil
  end

  function Native.hover(x, y)
    local state = topState()
    if not state or isOverworld(state) then return false end
    local supported = presenter.isSupportedStartMenu(game())
    if supported then return false end
    local ux, uy = windowToCanvas(x, y, state)
    if not ux then return false end
    local field, value, count = targetAt(state, ux, uy)
    if not field or field == "advance" then return false end
    return applyTarget(state, field, value, count, false)
  end

  function Native.activate(x, y)
    local state = topState()
    if not state or isOverworld(state) then return false end
    local supported = presenter.isSupportedStartMenu(game())
    if supported then return false end
    local ux, uy = windowToCanvas(x, y, state)
    if not ux then return false end
    local field, value, count = targetAt(state, ux, uy)
    if not field then return false end
    return applyTarget(state, field, value, count, true)
  end

  local function partyDragAllowed(state)
    if not looksLikeParty(state) then return false end
    if state.submenu or state.heal or state.tmhm or state.pickOnly
        or state.onSwitch or state.battle or state.forceSwitch
        or state.softboiledFrom or state.swapFrom then return false end
    local current = game()
    local party = state.party or (current and current.save and current.save.party) or {}
    return current and current.save and party == current.save.party and #party > 1
  end

  function Native.partyDragBegin(x, y)
    local state = topState()
    if not partyDragAllowed(state) then return nil end
    local ux, uy = windowToCanvas(x, y, state)
    if not ux then return nil end
    local field, index, count = partyTarget(state, ux, uy)
    if field ~= "index" then return nil end
    state.index = index
    local current = game()
    local party = state.party or current.save.party
    local session = { state = state, party = party, from = index, to = index,
      mon = party[index], active = false, x = x, y = y, count = count }
    runtime.partyDrag = session
    return session
  end

  function Native.partyDragMove(session, x, y)
    if not session or topState() ~= session.state or not partyDragAllowed(session.state) then
      return false
    end
    local ux, uy = windowToCanvas(x, y, session.state)
    if not ux then return false end
    local field, index = partyTarget(session.state, ux, uy)
    if field ~= "index" then return false end
    session.active = true
    session.to, session.x, session.y = index, x, y
    session.state.index = index
    local current = game()
    if current then current.partyMenuSavedIndex = index end
    runtime.partyDrag = session
    return true
  end

  function Native.partyDragEnd(session, x, y, cancelled)
    if not session then return false end
    if not cancelled then Native.partyDragMove(session, x or session.x, y or session.y) end
    local swapped = false
    if not cancelled and session.active and session.to and session.to ~= session.from
        and session.party[session.from] and session.party[session.to] then
      session.party[session.from], session.party[session.to] =
        session.party[session.to], session.party[session.from]
      session.state.index = session.to
      swapped = true
      pcall(function() require("src.core.Sound").play(game().data, "Swap") end)
    else
      session.state.index = session.from
    end
    runtime.partyDrag = nil
    return swapped or session.active
  end

  function Native.wheel(dy)
    if dy == 0 then return false end
    local state = topState()
    if not state or isOverworld(state) then return false end
    local supported = presenter.isSupportedStartMenu(game())
    if supported then return false end

    local delta = dy > 0 and -1 or 1
    if looksLikeModManager(state) then
      -- ManagerState owns header skipping, scrolling, options and overlays.
      return tap(delta < 0 and "up" or "down")
    elseif looksLikeLink(state) then
      local stage = state.stage
      if stage == "codeEntry" or stage == "addrEntry" then
        return tap(delta < 0 and "up" or "down")
      elseif stage == "battleOptions" then
        return tap(delta < 0 and "right" or "left")
      elseif stage == "menu" then
        state.index = ((state.index or 1) - 1 + delta) % 3 + 1
        return true
      elseif stage == "lanMenu" or stage == "onlineMenu" or stage == "modeSelect" then
        state.index = state.index == 1 and 2 or 1
        return true
      elseif stage == "trade" and state.trade and state.trade.stage == "picking" then
        local count = #((state.game.save and state.game.save.party) or {})
        if count > 0 then state.index = math.max(1, math.min(count, (state.index or 1) + delta)); return true end
      end
      return false
    elseif isBattleShape(state) then
      if state.phase == "menu" and not state.demo then
        state.menuIndex = ((state.menuIndex or 1) - 1 + delta) % 4 + 1
        return true
      elseif state.phase == "moveSelect" then
        local count = #(state.player and state.player.curMoves or {})
        if count > 0 then
          state.moveIndex = ((state.moveIndex or 1) - 1 + delta) % count + 1
          return true
        end
      elseif state.phase == "mimicSelect" then
        local count = #(state.mimicMoves or {})
        if count > 0 then
          state.mimicIndex = ((state.mimicIndex or 1) - 1 + delta) % count + 1
          return true
        end
      end
    elseif looksLikeParty(state) then
      if state.submenu and type(state.subItems) == "table" and #state.subItems > 0 then
        local n = #state.subItems
        state.subIndex = ((state.subIndex or 1) - 1 + delta) % n + 1
        return true
      end
      local current = game()
      local party = state.party or (current and current.save and current.save.party) or {}
      if #party > 0 then
        state.index = ((state.index or 1) - 1 + delta) % #party + 1
        return true
      end
    elseif looksLikeList(state) and #state.items > 0 then
      state.index = math.max(1, math.min(#state.items, (state.index or 1) + delta))
      if state.index - (state.scroll or 0) > state.rows then
        state.scroll = state.index - state.rows
      elseif state.index - (state.scroll or 0) < 1 then
        state.scroll = state.index - 1
      end
      return true
    elseif looksLikeOptionRows(state) then
      local count = #state.rows + 1
      state.index = ((state.index or 1) - 1 + delta) % count + 1
      return true
    elseif looksLikeBoxedMenu(state) and #state.items > 0 then
      state.index = ((state.index or 1) - 1 + delta) % #state.items + 1
      if type(state.clampScroll) == "function" then state:clampScroll() end
      return true
    elseif looksLikeChoice(state) then
      state.index = state.index == 1 and 2 or 1
      return true
    end
    return false
  end

  -- Internal diagnostic used by contract tests. Coordinates remain exact; it
  -- does not broaden hit targets.
  function Native.toCanvas(x,y,state) return windowToCanvas(x,y,state or topState()) end

  function Native.kind()
    local state = topState()
    if isOverworld(state) then return "overworld" end
    if isBattleShape(state) then return "battle" end
    if looksLikeLink(state) then return "link" end
    if looksLikeModManager(state) then return "mod_manager" end
    if looksLikeParty(state) then return "party" end
    if looksLikeTownMap(state) then return "town_map" end
    if looksLikeList(state) then return "list" end
    if looksLikeOptionRows(state) then return "options" end
    if looksLikeBoxedMenu(state) then return "menu" end
    if looksLikeChoice(state) then return "choice" end
    if looksLikeTextBox(state) then return "dialogue" end
    if looksLikeSummary(state) then return "summary" end
    return nil
  end

  return Native
end
