local Items = {}

Items.POCKETS = {
  medicine = { id = "medicine", name_es = "Medicinas", name_en = "Medicine", icon = "💊" },
  balls = { id = "balls", name_es = "Poké Balls", name_en = "Poké Balls", icon = "🔴" },
  battle = { id = "battle", name_es = "Combate", name_en = "Battle Items", icon = "⚔️" },
  berries = { id = "berries", name_es = "Bayas", name_en = "Berries", icon = "🍒" },
  other = { id = "other", name_es = "Objetos", name_en = "Other Items", icon = "🎒" },
  tmhm = { id = "tmhm", name_es = "MTs y MOs", name_en = "TMs & HMs", icon = "💿" },
  treasures = { id = "treasures", name_es = "Tesoros", name_en = "Treasures", icon = "💎" },
  key = { id = "key", name_es = "Obj. Clave", name_en = "Key Items", icon = "🔑" },
}

Items.DATABASE = {
  -- Poké Balls
  MASTER_BALL = { id = "MASTER_BALL", pocket = "balls", name_es = "Master Ball", name_en = "Master Ball", desc_es = "La mejor Ball. Captura a cualquier Pokémon sin fallar.", desc_en = "The best Ball. Captures any wild Pokémon without fail." },
  ULTRA_BALL = { id = "ULTRA_BALL", pocket = "balls", name_es = "Ultra Ball", name_en = "Ultra Ball", desc_es = "Ball de altísimo rendimiento y gran tasa de éxito.", desc_en = "An ultra-high performance Ball with high success rate." },
  GREAT_BALL = { id = "GREAT_BALL", pocket = "balls", name_es = "Super Ball", name_en = "Great Ball", desc_es = "Buena Ball con mayor índice de éxito que la Poké Ball.", desc_en = "A good Ball with a higher catch rate than a Poké Ball." },
  POKE_BALL = { id = "POKE_BALL", pocket = "balls", name_es = "Poké Ball", name_en = "Poké Ball", desc_es = "Dispositivo esférico para capturar Pokémon salvajes.", desc_en = "A tool for catching wild Pokémon." },
  SAFARI_BALL = { id = "SAFARI_BALL", pocket = "balls", name_es = "Safari Ball", name_en = "Safari Ball", desc_es = "Ball especial para usar únicamente en la Zona Safari.", desc_en = "A special Ball for use only in the Safari Zone." },

  -- Medicinas
  POTION = { id = "POTION", pocket = "medicine", name_es = "Poción", name_en = "Potion", desc_es = "Restaura 20 PS de un Pokémon herido.", desc_en = "Restores 20 HP to an injured Pokémon." },
  SUPER_POTION = { id = "SUPER_POTION", pocket = "medicine", name_es = "Superpoción", name_en = "Super Potion", desc_es = "Restaura 50 PS de un Pokémon herido.", desc_en = "Restores 50 HP to an injured Pokémon." },
  HYPER_POTION = { id = "HYPER_POTION", pocket = "medicine", name_es = "Hiperpoción", name_en = "Hyper Potion", desc_es = "Restaura 200 PS de un Pokémon herido.", desc_en = "Restores 200 HP to an injured Pokémon." },
  MAX_POTION = { id = "MAX_POTION", pocket = "medicine", name_es = "Poción Máxima", name_en = "Max Potion", desc_es = "Restaura por completo todos los PS de un Pokémon.", desc_en = "Fully restores the HP of a Pokémon." },
  FULL_RESTORE = { id = "FULL_RESTORE", pocket = "medicine", name_es = "Restaurar Todo", name_en = "Full Restore", desc_es = "Restaura todos los PS y cura cualquier problema de estado.", desc_en = "Fully restores HP and eliminates all status problems." },
  ANTIDOTE = { id = "ANTIDOTE", pocket = "medicine", name_es = "Antídoto", name_en = "Antidote", desc_es = "Cura a un Pokémon del envenenamiento.", desc_en = "Cures a poisoned Pokémon." },
  BURN_HEAL = { id = "BURN_HEAL", pocket = "medicine", name_es = "Antiquemar", name_en = "Burn Heal", desc_es = "Cura a un Pokémon de las quemaduras.", desc_en = "Heals a Pokémon of a burn." },
  ICE_HEAL = { id = "ICE_HEAL", pocket = "medicine", name_es = "Antihielo", name_en = "Ice Heal", desc_es = "Descongela a un Pokémon congelado.", desc_en = "Defrosts a frozen Pokémon." },
  AWAKENING = { id = "AWAKENING", pocket = "medicine", name_es = "Despertar", name_en = "Awakening", desc_es = "Despierta a un Pokémon dormido.", desc_en = "Awakens a sleeping Pokémon." },
  PARALYZE_HEAL = { id = "PARALYZE_HEAL", pocket = "medicine", name_es = "Antiparalizador", name_en = "Paralyze Heal", desc_es = "Cura la parálisis de un Pokémon.", desc_en = "Cures a Pokémon of paralysis." },
  FULL_HEAL = { id = "FULL_HEAL", pocket = "medicine", name_es = "Cura Total", name_en = "Full Heal", desc_es = "Cura todos los problemas de estado de un Pokémon.", desc_en = "Eliminates all status problems of a Pokémon." },
  REVIVE = { id = "REVIVE", pocket = "medicine", name_es = "Revivir", name_en = "Revive", desc_es = "Reanima a un Pokémon debilitado con la mitad de sus PS.", desc_en = "Revives a fainted Pokémon with half HP." },
  MAX_REVIVE = { id = "MAX_REVIVE", pocket = "medicine", name_es = "Revivir Máximo", name_en = "Max Revive", desc_es = "Reanima a un Pokémon debilitado con todos sus PS.", desc_en = "Revives a fainted Pokémon with full HP." },
  ETHER = { id = "ETHER", pocket = "medicine", name_es = "Éter", name_en = "Ether", desc_es = "Restaura 10 PP de un movimiento seleccionado.", desc_en = "Restores 10 PP of a selected move." },
  MAX_ETHER = { id = "MAX_ETHER", pocket = "medicine", name_es = "Éter Máximo", name_en = "Max Ether", desc_es = "Restaura todos los PP de un movimiento seleccionado.", desc_en = "Fully restores the PP of a selected move." },
  ELIXIR = { id = "ELIXIR", pocket = "medicine", name_es = "Elixir", name_en = "Elixir", desc_es = "Restaura 10 PP de todos los movimientos.", desc_en = "Restores 10 PP to all moves of a Pokémon." },
  MAX_ELIXIR = { id = "MAX_ELIXIR", pocket = "medicine", name_es = "Elixir Máximo", name_en = "Max Elixir", desc_es = "Restaura todos los PP de todos los movimientos.", desc_en = "Fully restores the PP of all moves." },

  -- Objetos de Combate
  X_ATTACK = { id = "X_ATTACK", pocket = "battle", name_es = "Ataque X", name_en = "X Attack", desc_es = "Aumenta el Ataque en combate.", desc_en = "Raises Attack in battle." },
  X_DEFEND = { id = "X_DEFEND", pocket = "battle", name_es = "Defensa X", name_en = "X Defend", desc_es = "Aumenta la Defensa en combate.", desc_en = "Raises Defense in battle." },
  X_SPEED = { id = "X_SPEED", pocket = "battle", name_es = "Velocidad X", name_en = "X Speed", desc_es = "Aumenta la Velocidad en combate.", desc_en = "Raises Speed in battle." },
  X_SPECIAL = { id = "X_SPECIAL", pocket = "battle", name_es = "Especial X", name_en = "X Special", desc_es = "Aumenta el Especial en combate.", desc_en = "Raises Special in battle." },
  X_ACCURACY = { id = "X_ACCURACY", pocket = "battle", name_es = "Precisión X", name_en = "X Accuracy", desc_es = "Aumenta la Precisión en combate.", desc_en = "Raises Accuracy in battle." },
  DIRE_HIT = { id = "DIRE_HIT", pocket = "battle", name_es = "Directo", name_en = "Dire Hit", desc_es = "Aumenta la probabilidad de asestar golpes críticos.", desc_en = "Raises the critical-hit ratio in battle." },
  GUARD_SPEC = { id = "GUARD_SPEC", pocket = "battle", name_es = "Protec. Esp.", name_en = "Guard Spec.", desc_es = "Protege contra reducciones de características.", desc_en = "Prevents stat reductions in battle." },

  -- Objetos Clave
  BICYCLE = { id = "BICYCLE", pocket = "key", name_es = "Bicicleta", name_en = "Bicycle", desc_es = "Permite desplazarse al doble de velocidad.", desc_en = "Allows faster travel than walking." },
  OLD_ROD = { id = "OLD_ROD", pocket = "key", name_es = "Caña Vieja", name_en = "Old Rod", desc_es = "Pesca Pokémon acuáticos salvajes como Magikarp.", desc_en = "Use by water to fish for wild Pokémon." },
  GOOD_ROD = { id = "GOOD_ROD", pocket = "key", name_es = "Caña Buena", name_en = "Good Rod", desc_es = "Caña de pescar mejorada para capturar más variedad.", desc_en = "A good fishing rod for catching wild Pokémon." },
  SUPER_ROD = { id = "SUPER_ROD", pocket = "key", name_es = "Supercaña", name_en = "Super Rod", desc_es = "La mejor caña para pescar los Pokémon más raros.", desc_en = "The ultimate rod for fishing rare Pokémon." },
  POKE_FLUTE = { id = "POKE_FLUTE", pocket = "key", name_es = "Poké Flauta", name_en = "Poké Flute", desc_es = "Despierta a cualquier Pokémon dormido con su dulce melodía.", desc_en = "Sweet melody that awakens all sleeping Pokémon." },
  SILPH_SCOPE = { id = "SILPH_SCOPE", pocket = "key", name_es = "Scope Silph", name_en = "Silph Scope", desc_es = "Permite identificar a los fantasmas de la Torre Pokémon.", desc_en = "A scope that sees through Ghost disguises." },
  TOWN_MAP = { id = "TOWN_MAP", pocket = "key", name_es = "Mapa", name_en = "Town Map", desc_es = "Muestra la región de Kanto y la posición actual.", desc_en = "A map showing your location in Kanto." },

  -- Tesoros
  NUGGET = { id = "NUGGET", pocket = "treasures", name_es = "Pepita", name_en = "Nugget", desc_es = "Pepita de oro puro. Se vende a muy buen precio.", desc_en = "A nugget of pure gold. Sells at a high price." },

  -- Otros
  ESCAPE_ROPE = { id = "ESCAPE_ROPE", pocket = "other", name_es = "Cuerda Huida", name_en = "Escape Rope", desc_es = "Cuerda larga que permite salir de cuevas y mazmorras.", desc_en = "A long rope that allows escape from caves." },
  REPEL = { id = "REPEL", pocket = "other", name_es = "Repelente", name_en = "Repel", desc_es = "Repele a Pokémon salvajes débiles durante 100 pasos.", desc_en = "Repels weak wild Pokémon for 100 steps." },
  SUPER_REPEL = { id = "SUPER_REPEL", pocket = "other", name_es = "Superrepelente", name_en = "Super Repel", desc_es = "Repele a Pokémon salvajes débiles durante 200 pasos.", desc_en = "Repels weak wild Pokémon for 200 steps." },
  MAX_REPEL = { id = "MAX_REPEL", pocket = "other", name_es = "Repelente Máx.", name_en = "Max Repel", desc_es = "Repele a Pokémon salvajes débiles durante 250 pasos.", desc_en = "Repels weak wild Pokémon for 250 steps." },
  MOON_STONE = { id = "MOON_STONE", pocket = "other", name_es = "Piedra Lunar", name_en = "Moon Stone", desc_es = "Piedra peculiar que hace evolucionar a ciertos Pokémon.", desc_en = "A peculiar stone that evolves certain Pokémon." },
  FIRE_STONE = { id = "FIRE_STONE", pocket = "other", name_es = "Piedra Fuego", name_en = "Fire Stone", desc_es = "Piedra ígnea que hace evolucionar a ciertos Pokémon.", desc_en = "An elemental stone that evolves certain Pokémon." },
  THUNDER_STONE = { id = "THUNDER_STONE", pocket = "other", name_es = "Piedra Trueno", name_en = "Thunder Stone", desc_es = "Piedra eléctrica que hace evolucionar a ciertos Pokémon.", desc_en = "An elemental stone that evolves certain Pokémon." },
  WATER_STONE = { id = "WATER_STONE", pocket = "other", name_es = "Piedra Agua", name_en = "Water Stone", desc_es = "Piedra acuática que hace evolucionar a ciertos Pokémon.", desc_en = "An elemental stone that evolves certain Pokémon." },
  LEAF_STONE = { id = "LEAF_STONE", pocket = "other", name_es = "Piedra Hoja", name_en = "Leaf Stone", desc_es = "Piedra vegetal que hace evolucionar a ciertos Pokémon.", desc_en = "An elemental stone that evolves certain Pokémon." },
}

local function normalizeKey(name)
  if not name then return "UNKNOWN" end
  return tostring(name):upper():gsub("[^%w]", "_")
end

function Items.get(itemNameOrId)
  if not itemNameOrId then return nil end
  local key = normalizeKey(itemNameOrId)
  local item = Items.DATABASE[key]
  if item then return item end

  -- Check if it's a TM or HM
  if key:match("^TM%d+") or key:match("^HM%d+") then
    return {
      id = key,
      pocket = "tmhm",
      name_es = tostring(itemNameOrId),
      name_en = tostring(itemNameOrId),
      desc_es = "Máquina para enseñar un movimiento a un Pokémon compatible.",
      desc_en = "Teaches a move to a compatible Pokémon.",
    }
  end

  return {
    id = key,
    pocket = "other",
    name_es = tostring(itemNameOrId),
    name_en = tostring(itemNameOrId),
    desc_es = "Un objeto útil para tu viaje.",
    desc_en = "A useful item for your journey.",
  }
end

function Items.getName(itemNameOrId, locale)
  local item = Items.get(itemNameOrId)
  if not item then return tostring(itemNameOrId) end
  return locale == "es" and item.name_es or item.name_en
end

function Items.getDescription(itemNameOrId, locale)
  local item = Items.get(itemNameOrId)
  if not item then return "" end
  return locale == "es" and item.desc_es or item.desc_en
end

function Items.getPocket(itemNameOrId)
  local item = Items.get(itemNameOrId)
  return item and item.pocket or "other"
end

return Items
