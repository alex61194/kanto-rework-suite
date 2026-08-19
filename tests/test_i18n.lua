local function check(cond, msg)
  if not cond then
    error("ASSERTION FAILED: " .. tostring(msg), 2)
  end
end

-- Mock love filesystem
love = {
  filesystem = {
    load = function(path)
      local chunk, err = loadfile(path)
      return chunk, err
    end
  }
}

local I18n = loadfile("packages/kanto_rework_core/core/i18n.lua")()
local locale_en = loadfile("packages/kanto_rework_core/locales/en.lua")()
local locale_es = loadfile("packages/kanto_rework_core/locales/es.lua")()

check(type(locale_en) == "table", "en locale must be a table")
check(type(locale_es) == "table", "es locale must be a table")

-- Ensure all keys in en exist in es
for k, _ in pairs(locale_en) do
  check(locale_es[k] ~= nil, "missing key in es locale: " .. tostring(k))
end

-- Ensure all keys in es exist in en
for k, _ in pairs(locale_es) do
  check(locale_en[k] ~= nil, "missing key in en locale: " .. tostring(k))
end

local i18n = I18n.new({
  defaultLocale = "es",
  locales = {
    en = locale_en,
    es = locale_es,
  }
})

check(i18n:getLocale() == "es", "default locale should be es")
check(i18n:t("app_name") == "DIARIO DE CAMPO", "es app_name should be DIARIO DE CAMPO")
check(i18n:t("pokedex") == "POKéDEX", "pokedex translation check")
check(i18n:t("entries_count", 6) == "06 ENTRADAS", "es entries_count formatting check")

i18n:setLocale("en")
check(i18n:getLocale() == "en", "current locale should be en")
check(i18n:t("app_name") == "FIELD JOURNAL", "en app_name should be FIELD JOURNAL")
check(i18n:t("entries_count", 6) == "06 ENTRIES", "en entries_count formatting check")

-- Fallback check
check(i18n:t("non_existent_key") == "non_existent_key", "non-existent key should return key itself")

print("✓ All i18n tests passed successfully!")
