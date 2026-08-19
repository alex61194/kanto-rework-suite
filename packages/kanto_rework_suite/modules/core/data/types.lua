local Types = {}

Types.LIST = {
  NORMAL = { id = "NORMAL", name_en = "Normal", name_es = "Normal", color = { 0.65, 0.65, 0.55, 1.0 } },
  FIRE = { id = "FIRE", name_en = "Fire", name_es = "Fuego", color = { 0.95, 0.40, 0.20, 1.0 } },
  WATER = { id = "WATER", name_en = "Water", name_es = "Agua", color = { 0.25, 0.55, 0.95, 1.0 } },
  GRASS = { id = "GRASS", name_en = "Grass", name_es = "Planta", color = { 0.45, 0.78, 0.30, 1.0 } },
  ELECTRIC = { id = "ELECTRIC", name_en = "Electric", name_es = "Eléctrico", color = { 0.98, 0.80, 0.15, 1.0 } },
  ICE = { id = "ICE", name_en = "Ice", name_es = "Hielo", color = { 0.50, 0.82, 0.85, 1.0 } },
  FIGHTING = { id = "FIGHTING", name_en = "Fighting", name_es = "Lucha", color = { 0.75, 0.20, 0.15, 1.0 } },
  POISON = { id = "POISON", name_en = "Poison", name_es = "Veneno", color = { 0.65, 0.25, 0.65, 1.0 } },
  GROUND = { id = "GROUND", name_en = "Ground", name_es = "Tierra", color = { 0.85, 0.70, 0.35, 1.0 } },
  FLYING = { id = "FLYING", name_en = "Flying", name_es = "Volador", color = { 0.65, 0.55, 0.90, 1.0 } },
  PSYCHIC = { id = "PSYCHIC", name_en = "Psychic", name_es = "Psíquico", color = { 0.98, 0.35, 0.55, 1.0 } },
  BUG = { id = "BUG", name_en = "Bug", name_es = "Bicho", color = { 0.65, 0.72, 0.15, 1.0 } },
  ROCK = { id = "ROCK", name_en = "Rock", name_es = "Roca", color = { 0.70, 0.60, 0.25, 1.0 } },
  GHOST = { id = "GHOST", name_en = "Ghost", name_es = "Fantasma", color = { 0.45, 0.35, 0.60, 1.0 } },
  DRAGON = { id = "DRAGON", name_en = "Dragon", name_es = "Dragón", color = { 0.40, 0.20, 0.90, 1.0 } },
}

-- Matriz de efectividad en Gen 1: [Atacante][Defensor] = Multiplicador
local CHART = {
  NORMAL = { ROCK = 0.5, GHOST = 0.0 },
  FIRE = { FIRE = 0.5, WATER = 0.5, GRASS = 2.0, ICE = 2.0, BUG = 2.0, ROCK = 0.5, DRAGON = 0.5 },
  WATER = { FIRE = 2.0, WATER = 0.5, GRASS = 0.5, GROUND = 2.0, ROCK = 2.0, DRAGON = 0.5 },
  GRASS = { FIRE = 0.5, WATER = 2.0, GRASS = 0.5, POISON = 0.5, GROUND = 2.0, FLYING = 0.5, BUG = 0.5, ROCK = 2.0, DRAGON = 0.5 },
  ELECTRIC = { WATER = 2.0, GRASS = 0.5, ELECTRIC = 0.5, GROUND = 0.0, FLYING = 2.0, DRAGON = 0.5 },
  ICE = { WATER = 0.5, GRASS = 2.0, ICE = 0.5, GROUND = 2.0, FLYING = 2.0, DRAGON = 2.0 },
  FIGHTING = { NORMAL = 2.0, ICE = 2.0, POISON = 0.5, FLYING = 0.5, PSYCHIC = 0.5, BUG = 0.5, ROCK = 2.0, GHOST = 0.0 },
  POISON = { GRASS = 2.0, POISON = 0.5, GROUND = 0.5, BUG = 2.0, ROCK = 0.5, GHOST = 0.5 },
  GROUND = { FIRE = 2.0, GRASS = 0.5, ELECTRIC = 2.0, POISON = 2.0, FLYING = 0.0, BUG = 0.5, ROCK = 2.0 },
  FLYING = { GRASS = 2.0, ELECTRIC = 0.5, FIGHTING = 2.0, BUG = 2.0, ROCK = 0.5 },
  PSYCHIC = { FIGHTING = 2.0, POISON = 2.0, PSYCHIC = 0.5 },
  BUG = { FIRE = 0.5, GRASS = 2.0, FIGHTING = 0.5, POISON = 2.0, FLYING = 0.5, PSYCHIC = 2.0, GHOST = 0.5 },
  ROCK = { FIRE = 2.0, ICE = 2.0, FIGHTING = 0.5, GROUND = 0.5, FLYING = 2.0, BUG = 2.0 },
  GHOST = { NORMAL = 0.0, PSYCHIC = 0.0, GHOST = 2.0 },
  DRAGON = { DRAGON = 2.0 },
}

function Types.get(typeId)
  if not typeId then return nil end
  return Types.LIST[tostring(typeId):upper()]
end

function Types.getName(typeId, locale)
  local t = Types.get(typeId)
  if not t then return tostring(typeId) end
  if locale == "es" then return t.name_es end
  return t.name_en
end

function Types.getEffectiveness(moveType, defType1, defType2)
  moveType = moveType and moveType:upper()
  defType1 = defType1 and defType1:upper()
  defType2 = defType2 and defType2:upper()

  local mult = 1.0
  if CHART[moveType] and defType1 and CHART[moveType][defType1] ~= nil then
    mult = mult * CHART[moveType][defType1]
  end
  if CHART[moveType] and defType2 and defType2 ~= defType1 and CHART[moveType][defType2] ~= nil then
    mult = mult * CHART[moveType][defType2]
  end
  return mult
end

return Types
