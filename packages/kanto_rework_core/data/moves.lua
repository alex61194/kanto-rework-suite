local Moves = {}

Moves.DATABASE = {
  POUND = { id = "POUND", name_en = "Pound", name_es = "Destructor", type = "NORMAL", power = 40, accuracy = 100, pp = 35, desc_es = "Golpea al rival con las extremidades o la cola.", desc_en = "Pounds with forelegs or tail." },
  KARATE_CHOP = { id = "KARATE_CHOP", name_en = "Karate Chop", name_es = "Golpe Kárate", type = "NORMAL", power = 50, accuracy = 100, pp = 25, desc_es = "Ataque cortante con alta probabilidad de golpe crítico.", desc_en = "Has a high critical hit ratio." },
  DOUBLE_SLAP = { id = "DOUBLE_SLAP", name_en = "Double Slap", name_es = "Doble Bofetón", type = "NORMAL", power = 15, accuracy = 85, pp = 10, desc_es = "Abofetea al objetivo de 2 a 5 veces consecutivas.", desc_en = "Repeatedly slaps 2-5 times." },
  COMET_PUNCH = { id = "COMET_PUNCH", name_en = "Comet Punch", name_es = "Puño Cometa", type = "NORMAL", power = 18, accuracy = 85, pp = 15, desc_es = "Golpea al rival repetidamente de 2 a 5 veces.", desc_en = "Repeatedly punches 2-5 times." },
  MEGA_PUNCH = { id = "MEGA_PUNCH", name_en = "Mega Punch", name_es = "Megapuño", type = "NORMAL", power = 80, accuracy = 85, pp = 20, desc_es = "Un puñetazo de gran potencia y fuerza descomunal.", desc_en = "A powerful punch thrown with incredible power." },
  PAY_DAY = { id = "PAY_DAY", name_en = "Pay Day", name_es = "Día de Pago", type = "NORMAL", power = 40, accuracy = 100, pp = 20, desc_es = "Arroja monedas que se recogen al final del combate.", desc_en = "Throws coins that are retrieved after battle." },
  FIRE_PUNCH = { id = "FIRE_PUNCH", name_en = "Fire Punch", name_es = "Puño Fuego", type = "FIRE", power = 75, accuracy = 100, pp = 15, desc_es = "Un puñetazo ígneo que puede causar quemaduras.", desc_en = "A fiery punch that may burn the foe." },
  ICE_PUNCH = { id = "ICE_PUNCH", name_en = "Ice Punch", name_es = "Puño Hielo", type = "ICE", power = 75, accuracy = 100, pp = 15, desc_es = "Un puñetazo helado que puede congelar al objetivo.", desc_en = "An icy punch that may freeze the foe." },
  THUNDER_PUNCH = { id = "THUNDER_PUNCH", name_en = "Thunder Punch", name_es = "Puño Trueno", type = "ELECTRIC", power = 75, accuracy = 100, pp = 15, desc_es = "Un puñetazo eléctrico que puede paralizar al rival.", desc_en = "An electric punch that may paralyze the foe." },
  SCRATCH = { id = "SCRATCH", name_en = "Scratch", name_es = "Arañazo", type = "NORMAL", power = 40, accuracy = 100, pp = 35, desc_es = "Araña al objetivo con afiladas garras.", desc_en = "Scratches with sharp claws." },
  SWORDS_DANCE = { id = "SWORDS_DANCE", name_en = "Swords Dance", name_es = "Danza Espada", type = "NORMAL", power = 0, accuracy = 100, pp = 30, desc_es = "Danza frenética que aumenta el Ataque 2 niveles.", desc_en = "A fighting dance that sharply raises Attack." },
  CUT = { id = "CUT", name_en = "Cut", name_es = "Corte", type = "NORMAL", power = 50, accuracy = 95, pp = 30, desc_es = "Corta con garras o espadas. Corta arbustos en el mapa.", desc_en = "Cuts the foe and small bushes outside battle." },
  GUST = { id = "GUST", name_en = "Gust", name_es = "Tornado", type = "NORMAL", power = 40, accuracy = 100, pp = 35, desc_es = "Genera un fuerte torbellino agitando las alas.", desc_en = "Strikes the foe with a gust of wind." },
  WING_ATTACK = { id = "WING_ATTACK", name_en = "Wing Attack", name_es = "Ataque Ala", type = "FLYING", power = 35, accuracy = 100, pp = 35, desc_es = "Golpea al objetivo abriendo las alas ampliamente.", desc_en = "Strikes the target with widely spread wings." },
  WHIRLWIND = { id = "WHIRLWIND", name_en = "Whirlwind", name_es = "Remolino", type = "NORMAL", power = 0, accuracy = 85, pp = 20, desc_es = "Expulsa al rival del combate con un vendaval.", desc_en = "Blows away the foe & ends wild battles." },
  FLY = { id = "FLY", name_en = "Fly", name_es = "Vuelo", type = "FLYING", power = 70, accuracy = 95, pp = 15, desc_es = "Vuela en el primer turno y golpea en el segundo.", desc_en = "Flies up on first turn, then strikes next turn." },
  VINE_WHIP = { id = "VINE_WHIP", name_en = "Vine Whip", name_es = "Látigo Cepa", type = "GRASS", power = 35, accuracy = 100, pp = 10, desc_es = "Azota al rival con lianas finas y flexibles.", desc_en = "Strikes the foe with slender vines." },
  FLAMETHROWER = { id = "FLAMETHROWER", name_en = "Flamethrower", name_es = "Lanzallamas", type = "FIRE", power = 95, accuracy = 100, pp = 15, desc_es = "Potente chorro de fuego que puede causar quemaduras.", desc_en = "A powerful blast of fire that may burn the foe." },
  HYDRO_PUMP = { id = "HYDRO_PUMP", name_en = "Hydro Pump", name_es = "Hidrobomba", type = "WATER", power = 120, accuracy = 80, pp = 5, desc_es = "Lanza un descomunal torrente de agua a alta presión.", desc_en = "Blasts water at high pressure to attack." },
  SURF = { id = "SURF", name_en = "Surf", name_es = "Surf", type = "WATER", power = 95, accuracy = 100, pp = 15, desc_es = "Crea una gran ola. Permite navegar sobre el agua.", desc_en = "Creates a huge wave. Allows travel over water." },
  ICE_BEAM = { id = "ICE_BEAM", name_en = "Ice Beam", name_es = "Rayo Hielo", type = "ICE", power = 95, accuracy = 100, pp = 10, desc_es = "Rayo helado que puede congelar al objetivo.", desc_en = "Blasts the foe with an icy beam that may freeze." },
  BLIZZARD = { id = "BLIZZARD", name_en = "Blizzard", name_es = "Ventisca", type = "ICE", power = 120, accuracy = 90, pp = 5, desc_es = "Feroz tormenta de nieve con opción de congelación.", desc_en = "A howling blizzard that may freeze the foe." },
  PSYBEAM = { id = "PSYBEAM", name_en = "Psybeam", name_es = "Psicorrayo", type = "PSYCHIC", power = 65, accuracy = 100, pp = 20, desc_es = "Rayo de energía psíquica que puede causar confusión.", desc_en = "Fires a peculiar ray that may confuse the foe." },
  BUBBLE_BEAM = { id = "BUBBLE_BEAM", name_en = "Bubble Beam", name_es = "Rayo Burbuja", type = "WATER", power = 65, accuracy = 100, pp = 20, desc_es = "Chorro de burbujas que puede reducir la Velocidad.", desc_en = "Forcefully sprays bubbles that may lower Speed." },
  AURORA_BEAM = { id = "AURORA_BEAM", name_en = "Aurora Beam", name_es = "Rayo Aurora", type = "ICE", power = 65, accuracy = 100, pp = 20, desc_es = "Dispara un haz multicolor que puede bajar el Ataque.", desc_en = "Fires a rainbow-colored beam that may lower Attack." },
  HYPER_BEAM = { id = "HYPER_BEAM", name_en = "Hyper Beam", name_es = "Híper Rayo", type = "NORMAL", power = 150, accuracy = 90, pp = 5, desc_es = "Ataque devastador que requiere recargar si no debilita.", desc_en = "Powerful attack that requires recharge on next turn." },
  THUNDERBOLT = { id = "THUNDERBOLT", name_en = "Thunderbolt", name_es = "Rayo", type = "ELECTRIC", power = 95, accuracy = 100, pp = 15, desc_es = "Fuerte descarga eléctrica que puede paralizar.", desc_en = "A strong electrical attack that may paralyze." },
  THUNDER = { id = "THUNDER", name_en = "Thunder", name_es = "Trueno", type = "ELECTRIC", power = 120, accuracy = 70, pp = 10, desc_es = "Rayo fulminante caído del cielo que puede paralizar.", desc_en = "A wicked thunderbolt that may paralyze the foe." },
  EARTHQUAKE = { id = "EARTHQUAKE", name_en = "Earthquake", name_es = "Terremoto", type = "GROUND", power = 100, accuracy = 100, pp = 10, desc_es = "Sacudida sísmica de enorme potencia sobre el terreno.", desc_en = "Causes an earthquake that inflicts heavy damage." },
  TOXIC = { id = "TOXIC", name_en = "Toxic", name_es = "Tóxico", type = "POISON", power = 0, accuracy = 85, pp = 10, desc_es = "Envenena gravemente al rival incrementando el daño.", desc_en = "Poisons the foe with an intensifying toxin." },
  PSYCHIC = { id = "PSYCHIC", name_en = "Psychic", name_es = "Psíquico", type = "PSYCHIC", power = 90, accuracy = 100, pp = 10, desc_es = "Poderosa fuerza mental que puede reducir el Especial.", desc_en = "A powerful psychic attack that may lower Special." },
  HYPNOSIS = { id = "HYPNOSIS", name_en = "Hypnosis", name_es = "Hipnosis", type = "PSYCHIC", power = 0, accuracy = 60, pp = 20, desc_es = "Sugestión hipnótica que duerme al objetivo.", desc_en = "A hypnotizing move that puts the foe to sleep." },
  RECOVER = { id = "RECOVER", name_en = "Recover", name_es = "Recuperación", type = "NORMAL", power = 0, accuracy = 100, pp = 20, desc_es = "Restaura hasta la mitad de los PS máximos del usuario.", desc_en = "Restores up to half of the user's max HP." },
  CONFUSE_RAY = { id = "CONFUSE_RAY", name_en = "Confuse Ray", name_es = "Rayo Confuso", type = "GHOST", power = 0, accuracy = 100, pp = 10, desc_es = "Rayo siniestro que confunde irremediablemente al rival.", desc_en = "A sinister ray that confuses the foe." },
  REST = { id = "REST", name_en = "Rest", name_es = "Descanso", type = "PSYCHIC", power = 0, accuracy = 100, pp = 10, desc_es = "El usuario duerme 2 turnos para curar PS y estados.", desc_en = "The user sleeps for 2 turns, restoring HP & status." },
  ROCK_SLIDE = { id = "ROCK_SLIDE", name_en = "Rock Slide", name_es = "Avalancha", type = "ROCK", power = 75, accuracy = 90, pp = 10, desc_es = "Lanza grandes rocas sobre el enemigo para dañarlo.", desc_en = "Large boulders are hurled at the foe to damage." },
  TRI_ATTACK = { id = "TRI_ATTACK", name_en = "Tri Attack", name_es = "Triataque", type = "NORMAL", power = 80, accuracy = 100, pp = 10, desc_es = "Dispara simultáneamente fuego, hielo y electricidad.", desc_en = "Fires three simultaneous beams of different energy." },
  SLASH = { id = "SLASH", name_en = "Slash", name_es = "Cuchillada", type = "NORMAL", power = 70, accuracy = 100, pp = 20, desc_es = "Cuchillada con muy alta probabilidad de golpe crítico.", desc_en = "Has a high critical hit ratio." },
  SUBSTITUTE = { id = "SUBSTITUTE", name_en = "Substitute", name_es = "Sustituto", type = "NORMAL", power = 0, accuracy = 100, pp = 10, desc_es = "Usa 1/4 de los PS para crear un muñeco señuelo.", desc_en = "Creates a decoy using 1/4 of the user's max HP." },
  STRUGGLE = { id = "STRUGGLE", name_en = "Struggle", name_es = "Combate", type = "NORMAL", power = 50, accuracy = 100, pp = 10, desc_es = "Ataque desesperado cuando se agotan todos los PP.", desc_en = "Used only when all PP are gone. User takes recoil." },
}

-- Fallback generator for uncatalogued moves
local function normalizeKey(name)
  if not name then return "UNKNOWN" end
  return tostring(name):upper():gsub("[^%w]", "_")
end

function Moves.get(moveNameOrId)
  if not moveNameOrId then return nil end
  local key = normalizeKey(moveNameOrId)
  local move = Moves.DATABASE[key]
  if move then return move end

  -- Dynamic fallback
  return {
    id = key,
    name_en = tostring(moveNameOrId),
    name_es = tostring(moveNameOrId),
    type = "NORMAL",
    power = 40,
    accuracy = 100,
    pp = 20,
    desc_es = "Movimiento de combate Pokémon.",
    desc_en = "A Pokémon battle move.",
  }
end

function Moves.getName(moveNameOrId, locale)
  local m = Moves.get(moveNameOrId)
  if not m then return tostring(moveNameOrId) end
  return locale == "es" and m.name_es or m.name_en
end

function Moves.getDescription(moveNameOrId, locale)
  local m = Moves.get(moveNameOrId)
  if not m then return "" end
  return locale == "es" and m.desc_es or m.desc_en
end

return Moves
