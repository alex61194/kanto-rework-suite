-- Headless runtime smoke test for Kanto Rework Core
local function check(cond, msg)
  if not cond then
    error("ASSERTION FAILED: " .. tostring(msg), 2)
  end
end

local packageDir = "packages/kanto_rework_core"
local hooks = {}
local events = {}
local optionValues = {}
local taps = {}
local clearCount = 0
local mouseX, mouseY = 0, 0
local profileStorage = {}

local function mockFont()
  return {
    getWidth = function(_, str) return #(str or "") * 8 end,
    getHeight = function(_) return 14 end,
  }
end

love = {
  filesystem = {
    load = function(path)
      local chunk, err = loadfile(path)
      return chunk, err
    end,
    getInfo = function(path)
      return profileStorage[path] ~= nil
    end,
    read = function(path)
      return profileStorage[path], nil
    end,
    write = function(path, data)
      profileStorage[path] = data
      return true
    end,
    createDirectory = function(_) return true end,
    remove = function(path)
      profileStorage[path] = nil
      return true
    end,
  },
  graphics = {
    push = function() end,
    pop = function() end,
    origin = function() end,
    setColor = function() end,
    rectangle = function() end,
    polygon = function() end,
    line = function() end,
    setLineWidth = function() end,
    setFont = function() end,
    print = function() end,
    printf = function() end,
    setCanvas = function() end,
    clear = function() clearCount = clearCount + 1 end,
    newFont = function(_) return mockFont() end,
    getFont = function() return mockFont() end,
  },
  mouse = {
    getPosition = function() return mouseX, mouseY end,
  },
  timer = {
    getTime = function() return 100.0 end,
  }
}

local menuClass = {}
menuClass.__index = menuClass

local mod = {
  id = "kanto_rework_core",
  path = packageDir,
  hooks = { wrap = function(_, name, callback) hooks[name] = callback end },
  events = { on = function(_, name, callback) events[name] = callback end },
  options = {
    define = function(_, schema)
      for _, row in ipairs(schema) do optionValues[row.key] = row.default end
    end,
    get = function(_, key) return optionValues[key] end,
  },
  ui = { Menu = menuClass },
  input = { tap = function(_, _, button) taps[#taps + 1] = button end },
  log = { info = function() end, warn = function() end, error = function() end },
  exports = {},
}

local installer, loadError = loadfile(packageDir .. "/main.lua")
check(installer, loadError)
installer = installer()
check(type(installer) == "function", "entry must return installer")
installer(mod)

for _, name in ipairs({
  "input.pointer", "input.step", "render.zones", "render.compose", "render.hud",
}) do
  check(type(hooks[name]) == "function", name .. " hook registered")
end
check(type(events["game.ready"]) == "function", "game.ready listener registered")

local startMenu = setmetatable({
  items = {
    { label = "POKéDEX" }, { label = "POKéMON" }, { label = "ITEM" },
    { label = "RED" }, { label = "SAVE" }, { label = "OPTION" },
  },
  index = 1,
  scroll = 0,
  startCloses = true,
  clampScroll = function() end,
}, { __index = menuClass })

local overworld = { screenId = "Overworld" }
local game = {
  overworld = overworld,
  save = {
    player = { name = "RED", map = "CELADON_MART" },
    party = { {}, {}, {} },
    money = 107207,
    playTime = 22 * 3600 + 54 * 60,
    pokedex = { owned = { a = true }, seen = { a = true, b = true } },
  },
  data = { maps = { CELADON_MART = { name = "CELADON MART" } } },
  stack = {
    states = { overworld, startMenu },
    top = function(self) return self.states[#self.states] end,
  },
}
local viewport = {
  width = 1920, height = 1080,
  gameX = 600, gameY = 0, gameWidth = 1200, gameHeight = 1080,
}
local function windowPoint(ux, uy)
  return viewport.gameX + ux / 160 * viewport.gameWidth,
         viewport.gameY + uy / 144 * viewport.gameHeight
end
local function clickWindow(x, y, button)
  mouseX, mouseY = x, y
  love.mousemoved(x, y, 0, 0, false)
  love.mousepressed(x, y, button or 1, false, 1)
  love.mousereleased(x, y, button or 1, false, 1)
end
local function clickCanvas(ux, uy, button)
  local x, y = windowPoint(ux, uy)
  clickWindow(x, y, button)
end
local function render()
  hooks["render.hud"](function() end, game, viewport)
end

events["game.ready"]({ game = game })
hooks["render.zones"](function(_, zones) return zones end, game, {})
render()
check(mod.exports.diagnostics().presenterReady == true, "Start menu is presented successfully")
hooks["render.compose"](function() return false end, {}, { uiCanvas = {} })
check(clearCount == 1, "native UI clears only after presenter success")

local runtime = _G.__KANTO_REWORK_CORE_P0
check(runtime and runtime.startMenu and #runtime.startMenu.regions > 0, "presenter publishes Start-menu regions")
local first = runtime.startMenu.regions[1]
local beforeStart = #taps
clickWindow(first.x + first.w / 2, first.y + first.h / 2, 1)
check(#taps == beforeStart + 1 and taps[#taps] == "a", "Start-menu click injects A")

print("✓ Runtime smoke test passed successfully!")
