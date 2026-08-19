local function check(cond, msg)
  if not cond then
    error("ASSERTION FAILED: " .. tostring(msg), 2)
  end
end

love = {
  filesystem = {
    load = function(path)
      local chunk, err = loadfile(path)
      return chunk, err
    end
  },
  graphics = {
    newFont = function(_)
      return {
        getWidth = function(_, str) return #(str or "") * 8 end,
        getHeight = function(_) return 14 end,
      }
    end,
    getFont = function()
      return {
        getWidth = function(_, str) return #(str or "") * 8 end,
        getHeight = function(_) return 14 end,
      }
    end,
    push = function() end,
    pop = function() end,
    origin = function() end,
    setColor = function() end,
    rectangle = function() end,
    print = function() end,
    printf = function() end,
    setLineWidth = function() end,
    setFont = function() end,
  }
}

-- 1. Test Types
local Types = loadfile("packages/kanto_rework_core/data/types.lua")()
check(Types.getName("FIRE", "es") == "Fuego", "FIRE in Spanish must be Fuego")
check(Types.getName("WATER", "en") == "Water", "WATER in English must be Water")
check(Types.getEffectiveness("WATER", "FIRE") == 2.0, "Water on Fire must be x2")
check(Types.getEffectiveness("ELECTRIC", "GROUND") == 0.0, "Electric on Ground must be x0 (immune)")
check(Types.getEffectiveness("FIRE", "WATER") == 0.5, "Fire on Water must be x0.5")

-- 2. Test Moves
local Moves = loadfile("packages/kanto_rework_core/data/moves.lua")()
local flamethrower = Moves.get("FLAMETHROWER")
check(flamethrower ~= nil, "FLAMETHROWER must exist")
check(flamethrower.name_es == "Lanzallamas", "FLAMETHROWER in Spanish must be Lanzallamas")
check(flamethrower.type == "FIRE", "FLAMETHROWER type must be FIRE")
check(flamethrower.power == 95, "FLAMETHROWER power must be 95")

-- 3. Test Items & Pockets
local Items = loadfile("packages/kanto_rework_core/data/items.lua")()
local potion = Items.get("POTION")
check(potion ~= nil, "POTION must exist")
check(potion.name_es == "Poción", "POTION in Spanish must be Poción")
check(potion.pocket == "medicine", "POTION pocket must be medicine")

local ultraBall = Items.get("ULTRA_BALL")
check(ultraBall.pocket == "balls", "ULTRA_BALL pocket must be balls")

-- 4. Test UI Presenters
local Theme = loadfile("packages/kanto_rework_core/core/theme.lua")()
local I18nClass = loadfile("packages/kanto_rework_core/core/i18n.lua")()
local locale_es = loadfile("packages/kanto_rework_core/locales/es.lua")()
local locale_en = loadfile("packages/kanto_rework_core/locales/en.lua")()

local i18n = I18nClass.new({
  defaultLocale = "es",
  locales = { es = locale_es, en = locale_en },
})

local createSummaryPresenter = loadfile("packages/kanto_rework_ui/ui/summary_presenter.lua")()
local summaryPresenter = createSummaryPresenter({
  Types = Types,
  Moves = Moves,
  Theme = Theme,
  I18n = i18n,
})

local testMon = {
  name = "CHARIZARD",
  level = 36,
  hp = 120,
  maxHp = 120,
  attack = 84,
  defense = 78,
  speed = 100,
  special = 85,
  dvs = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 },
  statExp = { hp = 65535, attack = 65535, defense = 65535, speed = 65535, special = 65535 },
  moves = {
    { id = "FLAMETHROWER", name = "FLAMETHROWER", pp = 15, maxPP = 15 },
    { id = "FLY", name = "FLY", pp = 15, maxPP = 15 },
    { id = "SLASH", name = "SLASH", pp = 20, maxPP = 20 },
    { id = "FIRE_PUNCH", name = "FIRE_PUNCH", pp = 15, maxPP = 15 },
  }
}

local ok = summaryPresenter.drawSummary(testMon, { width = 1920, height = 1080 }, { theme = "field_journal" }, i18n)
check(ok == true, "Summary presenter should render successfully")

print("✓ All data integrity and UI presenter tests passed successfully!")
