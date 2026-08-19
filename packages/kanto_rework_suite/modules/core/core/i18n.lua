local I18n = {}
I18n.__index = I18n

function I18n.new(opts)
  opts = opts or {}
  local self = setmetatable({
    currentLocale = opts.defaultLocale or "es",
    locales = {},
    loadLocale = opts.loadLocale,
  }, I18n)

  if opts.locales then
    for code, dict in pairs(opts.locales) do
      self.locales[code] = dict
    end
  end

  return self
end

function I18n:setLocale(code)
  if not code then return end
  self.currentLocale = tostring(code):lower()
  if not self.locales[self.currentLocale] and self.loadLocale then
    local ok, dict = pcall(self.loadLocale, self.currentLocale)
    if ok and type(dict) == "table" then
      self.locales[self.currentLocale] = dict
    end
  end
end

function I18n:getLocale()
  return self.currentLocale
end

function I18n:t(key, ...)
  if not key then return "" end
  local dict = self.locales[self.currentLocale] or self.locales["en"] or self.locales["es"] or {}
  local text = dict[key]
  if text == nil then
    -- Fallback to english
    local fallback = self.locales["en"] or {}
    text = fallback[key] or key
  end

  if select("#", ...) > 0 and type(text) == "string" then
    local ok, formatted = pcall(string.format, text, ...)
    if ok then return formatted end
  end

  return tostring(text)
end

return I18n
