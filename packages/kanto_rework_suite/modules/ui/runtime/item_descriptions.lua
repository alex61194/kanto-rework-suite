-- Gen I item field notes for data extracted from Red/Blue/Yellow ROMs.
-- The ROM item table contains names/prices/flags but no description strings.
-- Runtime/mod-authored descriptions always win; this catalog is the semantic
-- fallback for the 97 base item-name IDs. TM/HM copy remains move-driven.
local M={}

local D={
  MASTER_BALL="Atrapa a cualquier Pokémon salvaje sin fallar jamás.",
  ULTRA_BALL="Una Poké Ball de alto rendimiento con mejor ratio de captura que una Super Ball.",
  GREAT_BALL="Una Poké Ball fiable con mejor ratio de captura que una Poké Ball estándar.",
  POKE_BALL="Una Poké Ball estándar usada para atrapar Pokémon salvajes.",
  TOWN_MAP="Muestra el mapa de la región de Kanto y la posición actual del jugador.",
  BICYCLE="Una bicicleta plegable para viajar más rápido por caminos permitidos.",
  SURFBOARD="Objeto de viaje interno no utilizado. No se puede obtener de forma normal.",
  SAFARI_BALL="Poké Ball especial suministrada para capturar Pokémon en la Zona Safari.",
  POKEDEX="Registra datos sobre los Pokémon que el jugador ha visto o atrapado.",
  MOON_STONE="Evoluciona a ciertos Pokémon compatibles. Se consume tras su uso.",
  ANTIDOTE="Cura el envenenamiento de un Pokémon.",
  BURN_HEAL="Cura las quemaduras de un Pokémon.",
  ICE_HEAL="Descongela a un Pokémon congelado.",
  AWAKENING="Despierta a un Pokémon dormido.",
  PARLYZ_HEAL="Cura la parálisis de un Pokémon.",
  FULL_RESTORE="Restaura todos los PS de un Pokémon y cura cualquier problema de estado.",
  MAX_POTION="Restaura todos los PS de un Pokémon.",
  HYPER_POTION="Restaura 200 PS de un Pokémon.",
  SUPER_POTION="Restaura 50 PS de un Pokémon.",
  POTION="Restaura 20 PS de un Pokémon.",
  BOULDERBADGE="Prueba de la victoria sobre Brock en el Gimnasio de Ciudad Plateada.",
  CASCADEBADGE="Prueba de la victoria sobre Misty en el Gimnasio de Ciudad Celeste.",
  THUNDERBADGE="Prueba de la victoria sobre Lt. Surge en el Gimnasio de Ciudad Carmín.",
  RAINBOWBADGE="Prueba de la victoria sobre Erika en el Gimnasio de Ciudad Azulona.",
  SOULBADGE="Prueba de la victoria sobre Koga en el Gimnasio de Ciudad Fucsia.",
  MARSHBADGE="Prueba de la victoria sobre Sabrina en el Gimnasio de Ciudad Azafrán.",
  VOLCANOBADGE="Prueba de la victoria sobre Blaine en el Gimnasio de Isla Canela.",
  EARTHBADGE="Prueba de la victoria sobre Giovanni en el Gimnasio de Ciudad Verde.",
  ESCAPE_ROPE="Transporta al jugador a la entrada de la cueva o mazmorra actual.",
  REPEL="Durante 100 pasos, evita encuentros con Pokémon salvajes más débiles que el líder del equipo.",
  OLD_AMBER="Un trozo de ámbar antiguo que puede revivirse en Aerodactyl en el Laboratorio.",
  FIRE_STONE="Evoluciona a ciertos Pokémon compatibles. Se consume tras su uso.",
  THUNDER_STONE="Evoluciona a ciertos Pokémon compatibles. Se consume tras su uso.",
  WATER_STONE="Evoluciona a ciertos Pokémon compatibles. Se consume tras su uso.",
  HP_UP="Aumenta los puntos de esfuerzo de los PS de un Pokémon.",
  PROTEIN="Aumenta los puntos de esfuerzo del Ataque de un Pokémon.",
  IRON="Aumenta los puntos de esfuerzo de la Defensa de un Pokémon.",
  CARBOS="Aumenta los puntos de esfuerzo de la Velocidad de un Pokémon.",
  CALCIUM="Aumenta los puntos de esfuerzo del Especial de un Pokémon.",
  RARE_CANDY="Sube un Pokémon un nivel, hasta el nivel 100.",
  DOME_FOSSIL="Fósil que puede revivirse en Kabuto en el Laboratorio Pokémon.",
  HELIX_FOSSIL="Fósil que puede revivirse en Omanyte en el Laboratorio Pokémon.",
  SECRET_KEY="Abre la puerta del Gimnasio de Isla Canela.",
  ITEM_2C="Ranura de objeto interno sin efecto de campo compatible.",
  BIKE_VOUCHER="Canjeable por una Bicicleta en la Tienda de Bicis de Ciudad Celeste.",
  X_ACCURACY="Hace que los ataques del Pokémon activo no fallen durante el combate actual.",
  LEAF_STONE="Evoluciona a ciertos Pokémon compatibles. Se consume tras su uso.",
  CARD_KEY="Abre las puertas electrónicas de Silph S.A.",
  NUGGET="Una pepita de oro puro que se puede vender a un precio muy alto.",
  ITEM_32="Ranura duplicada de Más PP sin efecto de campo compatible.",
  POKE_DOLL="Permite huir inmediatamente de un combate contra un Pokémon salvaje.",
  FULL_HEAL="Cura a un Pokémon de veneno, quemadura, congelación, sueño o parálisis.",
  REVIVE="Revive a un Pokémon debilitado y le restaura la mitad de sus PS máximos.",
  MAX_REVIVE="Revive a un Pokémon debilitado y le restaura todos sus PS.",
  GUARD_SPEC="Evita que bajen las estadísticas del Pokémon activo durante el combate.",
  SUPER_REPEL="Durante 200 pasos, evita encuentros con Pokémon salvajes más débiles que el líder.",
  MAX_REPEL="Durante 250 pasos, evita encuentros con Pokémon salvajes más débiles que el líder.",
  DIRE_HIT="Aumenta la probabilidad de asestar golpes críticos en el combate actual.",
  COIN="Ficha para jugar en el Casino de Ciudad Azulona.",
  FRESH_WATER="Restaura 50 PS de un Pokémon.",
  SODA_POP="Restaura 60 PS de un Pokémon.",
  LEMONADE="Restaura 80 PS de un Pokémon.",
  S_S_TICKET="Billete de pasaje para embarcar en el S.S. Anne en Ciudad Carmín.",
  GOLD_TEETH="La dentadura de oro perdida del Guarda de la Zona Safari.",
  X_ATTACK="Aumenta el Ataque del Pokémon activo durante el combate actual.",
  X_DEFEND="Aumenta la Defensa del Pokémon activo durante el combate actual.",
  X_SPEED="Aumenta la Velocidad del Pokémon activo durante el combate actual.",
  X_SPECIAL="Aumenta el Especial del Pokémon activo durante el combate actual.",
  COIN_CASE="Guarda y muestra las fichas del Casino de Ciudad Azulona.",
  OAKS_PARCEL="Un paquete del Poké Mart de Ciudad Verde para el Profesor Oak.",
  ITEMFINDER="Indica si hay un objeto oculto en las cercanías del área actual.",
  SILPH_SCOPE="Revela la verdadera identidad de los fantasmas en la Torre Pokémon.",
  POKE_FLUTE="Despierta a Pokémon dormidos, incluidos los Snorlax que bloquean caminos.",
  LIFT_KEY="Activa el ascensor en la Guarida del Team Rocket.",
  EXP_ALL="Reparte la experiencia de combate entre todos los miembros del equipo.",
  OLD_ROD="Caña de pescar básica para atrapar Pokémon en masas de agua.",
  GOOD_ROD="Buena caña de pescar que permite picar a una mayor variedad de Pokémon de agua.",
  SUPER_ROD="La mejor caña de pescar, capaz de enganchar a Pokémon acuáticos poderosos.",
  PP_UP="Aumenta de forma permanente los PP máximos de un movimiento.",
  ETHER="Restaura 10 PP de un movimiento seleccionado.",
  MAX_ETHER="Restaura todos los PP de un movimiento seleccionado.",
  ELIXER="Restaura 10 PP de todos los movimientos de un Pokémon.",
  MAX_ELIXER="Restaura todos los PP de todos los movimientos de un Pokémon.",

  FLOOR_B2F="Etiqueta interna de ascensor para planta B2F.",
  FLOOR_B1F="Etiqueta interna de ascensor para planta B1F.",
  FLOOR_1F="Etiqueta interna de ascensor para planta 1F.",
  FLOOR_2F="Etiqueta interna de ascensor para planta 2F.",
  FLOOR_3F="Etiqueta interna de ascensor para planta 3F.",
  FLOOR_4F="Etiqueta interna de ascensor para planta 4F.",
  FLOOR_5F="Etiqueta interna de ascensor para planta 5F.",
  FLOOR_6F="Etiqueta interna de ascensor para planta 6F.",
  FLOOR_7F="Etiqueta interna de ascensor para planta 7F.",
  FLOOR_8F="Etiqueta interna de ascensor para planta 8F.",
  FLOOR_9F="Etiqueta interna de ascensor para planta 9F.",
  FLOOR_10F="Etiqueta interna de ascensor para planta 10F.",
  FLOOR_11F="Etiqueta interna de ascensor para planta 11F.",
  FLOOR_B4F="Etiqueta interna de ascensor para planta B4F.",
}

M.baseItemIds={
  "MASTER_BALL","ULTRA_BALL","GREAT_BALL","POKE_BALL","TOWN_MAP","BICYCLE","SURFBOARD","SAFARI_BALL","POKEDEX","MOON_STONE",
  "ANTIDOTE","BURN_HEAL","ICE_HEAL","AWAKENING","PARLYZ_HEAL","FULL_RESTORE","MAX_POTION","HYPER_POTION","SUPER_POTION","POTION",
  "BOULDERBADGE","CASCADEBADGE","THUNDERBADGE","RAINBOWBADGE","SOULBADGE","MARSHBADGE","VOLCANOBADGE","EARTHBADGE","ESCAPE_ROPE","REPEL",
  "OLD_AMBER","FIRE_STONE","THUNDER_STONE","WATER_STONE","HP_UP","PROTEIN","IRON","CARBOS","CALCIUM","RARE_CANDY","DOME_FOSSIL","HELIX_FOSSIL","SECRET_KEY","ITEM_2C","BIKE_VOUCHER","X_ACCURACY","LEAF_STONE","CARD_KEY","NUGGET","ITEM_32","POKE_DOLL","FULL_HEAL","REVIVE","MAX_REVIVE","GUARD_SPEC","SUPER_REPEL","MAX_REPEL","DIRE_HIT","COIN","FRESH_WATER","SODA_POP","LEMONADE","S_S_TICKET","GOLD_TEETH","X_ATTACK","X_DEFEND","X_SPEED","X_SPECIAL","COIN_CASE","OAKS_PARCEL","ITEMFINDER","SILPH_SCOPE","POKE_FLUTE","LIFT_KEY","EXP_ALL","OLD_ROD","GOOD_ROD","SUPER_ROD","PP_UP","ETHER","MAX_ETHER","ELIXER","MAX_ELIXER",
  "FLOOR_B2F","FLOOR_B1F","FLOOR_1F","FLOOR_2F","FLOOR_3F","FLOOR_4F","FLOOR_5F","FLOOR_6F","FLOOR_7F","FLOOR_8F","FLOOR_9F","FLOOR_10F","FLOOR_11F","FLOOR_B4F",
}

function M.catalog() return D end

function M.resolve(game,itemId,def,resolveText)
  -- A ROM extension or content mod is the source of truth for its own copy.
  for _,key in ipairs({"description","desc","summary","text","effectText"}) do
    local value=def and def[key]
    if type(resolveText)=="function" then value=resolveText(game,value) end
    if type(value)=="string" and value~="" then return value,"definition."..key end
  end
  local value=D[tostring(itemId or "")]
  if value then return value,"krs.gen1_catalog" end
  return nil,nil
end

return M
