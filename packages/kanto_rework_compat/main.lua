return function(mod)
  local function loadModule(relative)
    local path = mod.path .. "/" .. relative
    local chunk, err = love.filesystem.load(path)
    assert(chunk, err or ("Unable to load " .. path))
    return chunk()
  end

  local Core = _G.__KANTO_REWORK_CORE_P0 or {}
  local Theme = Core.Theme
  local i18n = Core.i18n

  local createModOptionsPresenter = loadModule("compat/mod_options_presenter.lua")
  local modOptionsPresenter = createModOptionsPresenter({
    Core = Core,
    Theme = Theme,
    I18n = i18n,
  })

  mod.exports = {
    modOptionsPresenter = modOptionsPresenter,
    version = "0.1.0",
  }

  mod.log:info("Kanto Rework Compatibility 0.1.0 loaded: Mod Manager and Options interface ready.")
end
