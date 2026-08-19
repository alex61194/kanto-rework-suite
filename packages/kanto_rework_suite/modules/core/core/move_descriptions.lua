-- Shared functional move-description provider with Spanish and English translation support.
return function(deps)
  local mod = assert(deps.mod)
  local Service = {}

  local MovesData = nil
  local function getMovesCatalog()
    if not MovesData then
      local source, err = mod:read("modules/core/data/moves.lua")
      if source then
        local chunk = load(source, "@kanto_rework_suite/modules/core/data/moves.lua")
        if chunk then MovesData = chunk() end
      end
    end
    return MovesData
  end

  local function normalize(value)
    return tostring(value or ""):upper():gsub("[^A-Z0-9]+", "_"):gsub("^_+", ""):gsub("_+$", "")
  end

  function Service.describe(def, id, lang)
    def = type(def) == "table" and def or {}
    id = normalize(id or def.id or def.name)
    lang = lang or (mod.options and mod.options.get and mod.options:get("language")) or "es"

    local catalog = getMovesCatalog()
    if catalog and catalog.getDescription then
      local desc = catalog.getDescription(id, lang)
      if desc and desc ~= "" then
        return desc, "krs.moves_catalog." .. tostring(lang)
      end
    end

    for _, key in ipairs({ "description", "desc", "summary", "text" }) do
      local v = def[key]
      if type(v) == "string" and v ~= "" then
        return v, "move_def." .. key
      end
    end

    local power = tonumber(def.power) or 0
    local typeName = tostring(def.type or ""):gsub("_", " "):lower()
    if lang == "es" then
      if power > 0 then
        return "Causa daño con un ataque de tipo " .. typeName .. ".", "rom.metadata"
      end
      return "Aplica su efecto de combate sin causar daño directo.", "rom.metadata"
    else
      if power > 0 then
        return "Deals damage with a " .. typeName .. "-type attack.", "rom.metadata"
      end
      return "Applies its battle effect without dealing direct damage.", "rom.metadata"
    end
  end

  function Service.catalogStatus()
    return { curated = true, metadataFallback = true, engineFlavorText = false, i18n = true }
  end

  mod.log:info("Move description service active: bilingual Spanish/English catalog enabled.")
  return Service
end
