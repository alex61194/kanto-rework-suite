return function(mod)
  local function loadModule(relative)
    local path = mod.path .. "/" .. relative
    local chunk, err = love.filesystem.load(path)
    assert(chunk, err or ("Unable to load " .. path))
    return chunk()
  end

  local Core = _G.__KANTO_REWORK_CORE_P0 or {}
  local Types = Core.loadModule and Core.loadModule("data/types.lua") or (love.filesystem.load("packages/kanto_rework_core/data/types.lua") and love.filesystem.load("packages/kanto_rework_core/data/types.lua")())
  local Moves = Core.loadModule and Core.loadModule("data/moves.lua") or (love.filesystem.load("packages/kanto_rework_core/data/moves.lua") and love.filesystem.load("packages/kanto_rework_core/data/moves.lua")())
  local Items = Core.loadModule and Core.loadModule("data/items.lua") or (love.filesystem.load("packages/kanto_rework_core/data/items.lua") and love.filesystem.load("packages/kanto_rework_core/data/items.lua")())

  local Theme = Core.Theme or (love.filesystem.load("packages/kanto_rework_core/core/theme.lua") and love.filesystem.load("packages/kanto_rework_core/core/theme.lua")())
  local i18n = Core.i18n

  local createSummaryPresenter = loadModule("ui/summary_presenter.lua")
  local createBagPresenter = loadModule("ui/bag_presenter.lua")
  local createBattlePresenter = loadModule("ui/battle_presenter.lua")

  local summaryPresenter = createSummaryPresenter({
    Core = Core,
    Types = Types,
    Moves = Moves,
    Theme = Theme,
    I18n = i18n,
  })

  local bagPresenter = createBagPresenter({
    Core = Core,
    Items = Items,
    Theme = Theme,
    I18n = i18n,
  })

  local battlePresenter = createBattlePresenter({
    Core = Core,
    Types = Types,
    Moves = Moves,
    Theme = Theme,
    I18n = i18n,
  })

  mod.exports = {
    summaryPresenter = summaryPresenter,
    bagPresenter = bagPresenter,
    battlePresenter = battlePresenter,
    version = "0.1.0",
  }

  mod.log:info("Kanto Rework UI 0.1.0 loaded: Summary, Bag, and Battle HUD initialized.")
end
