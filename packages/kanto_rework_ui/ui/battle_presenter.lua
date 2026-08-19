local function createBattlePresenter(deps)
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

  function Presenter.drawBattleHUD(battleState, viewport, profile, i18n)
    if not (love and love.graphics and battleState and viewport) then return false end
    i18n = i18n or (Core and Core.i18n)
    local theme = Theme and Theme.get(profile and profile.theme) or {}
    local locale = i18n and i18n:getLocale() or "es"

    local width = tonumber(viewport.width) or 1920
    local height = tonumber(viewport.height) or 1080

    love.graphics.push("all")
    love.graphics.origin()

    -- Player Battler Card
    local player = battleState.player or {}
    local pCardW, pCardH = 340, 110
    local pCardX = width - pCardW - 60
    local pCardY = height - 260

    Theme.setColor(theme.night or { 0.15, 0.15, 0.20, 0.92 })
    love.graphics.rectangle("fill", pCardX, pCardY, pCardW, pCardH, 12)
    Theme.setColor(theme.border or { 0.35, 0.35, 0.40, 0.9 })
    love.graphics.rectangle("line", pCardX, pCardY, pCardW, pCardH, 12)

    love.graphics.setFont(font(16))
    Theme.setColor(theme.nightText or { 1, 1, 1, 1 })
    love.graphics.print(tostring(player.name or "PIKACHU"):upper(), pCardX + 16, pCardY + 12)

    love.graphics.setFont(font(13))
    Theme.setColor(theme.accent or { 0.9, 0.6, 0.2, 1 })
    love.graphics.print(string.format(":L%d", tonumber(player.level) or 25), pCardX + pCardW - 70, pCardY + 14)

    -- HP Bar
    local curHP = tonumber(player.hp) or 50
    local maxHP = tonumber(player.maxHp) or 50
    local hpRatio = math.max(0, math.min(1.0, curHP / math.max(1, maxHP)))

    local hpBarX = pCardX + 16
    local hpBarY = pCardY + 44
    local hpBarW = pCardW - 32
    local hpBarH = 12

    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", hpBarX, hpBarY, hpBarW, hpBarH, 4)

    if hpRatio > 0.5 then
      love.graphics.setColor(0.25, 0.80, 0.30, 1.0) -- Green
    elseif hpRatio > 0.2 then
      love.graphics.setColor(0.95, 0.75, 0.15, 1.0) -- Yellow
    else
      love.graphics.setColor(0.90, 0.20, 0.20, 1.0) -- Red
    end
    love.graphics.rectangle("fill", hpBarX, hpBarY, math.floor(hpBarW * hpRatio), hpBarH, 4)

    love.graphics.setFont(font(12))
    Theme.setColor(theme.nightMuted or { 0.8, 0.8, 0.8, 1 })
    love.graphics.print(string.format("%d / %d PS", curHP, maxHP), hpBarX, hpBarY + 18)

    -- Stat Modifiers for Player (e.g. ATK +2, SPD -1)
    local mods = player.modifiers or {}
    local modX = hpBarX + 130
    for statKey, modVal in pairs(mods) do
      if modVal ~= 0 then
        local modStr = string.format("%s %s%d", statKey:upper():sub(1, 3), modVal > 0 and "+" or "", modVal)
        Theme.setColor(modVal > 0 and { 0.3, 0.9, 0.4, 1 } or { 0.9, 0.3, 0.3, 1 })
        love.graphics.print(modStr, modX, hpBarY + 18)
        modX = modX + 60
      end
    end

    -- Bottom Move Selection and Effectiveness Bar (if active)
    if battleState.phase == "moveSelect" and battleState.selectedMove then
      local mv = Moves and Moves.get(battleState.selectedMove) or {}
      local enemy = battleState.enemy or {}
      local eff = Types and Types.getEffectiveness(mv.type, enemy.type1, enemy.type2) or 1.0

      local infoW, infoH = math.min(760, width - 80), 60
      local infoX = math.floor((width - infoW) * 0.5)
      local infoY = height - 80

      Theme.setColor(theme.night or { 0.1, 0.1, 0.15, 0.95 })
      love.graphics.rectangle("fill", infoX, infoY, infoW, infoH, 10)
      Theme.setColor(theme.accent or { 0.8, 0.2, 0.2, 1 })
      love.graphics.rectangle("line", infoX, infoY, infoW, infoH, 10)

      local moveName = Moves and Moves.getName(mv.id, locale) or mv.id or "MOVIMIENTO"
      love.graphics.setFont(font(15))
      Theme.setColor(theme.nightText or { 1, 1, 1, 1 })
      love.graphics.print(moveName, infoX + 20, infoY + 18)

      -- Effectiveness tag
      love.graphics.setFont(font(13))
      if eff >= 2.0 then
        love.graphics.setColor(0.3, 0.9, 0.4, 1)
        love.graphics.print(i18n and i18n:t("battle_super_effective") or "¡Es muy eficaz! (x2)", infoX + 220, infoY + 20)
      elseif eff == 0.0 then
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.print(i18n and i18n:t("battle_immune") or "¡No le afecta! (x0)", infoX + 220, infoY + 20)
      elseif eff <= 0.5 then
        love.graphics.setColor(0.9, 0.4, 0.3, 1)
        love.graphics.print(i18n and i18n:t("battle_not_very_effective") or "No es muy eficaz... (x0.5)", infoX + 220, infoY + 20)
      end
    end

    love.graphics.pop()
    return true
  end

  return Presenter
end

return createBattlePresenter
