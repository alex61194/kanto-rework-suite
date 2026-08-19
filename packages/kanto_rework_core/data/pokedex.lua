local Pokedex = {}

Pokedex.SPECIES = {
  [1] = { name = "Bulbasaur", category_es = "Semilla", category_en = "Seed", type1 = "GRASS", type2 = "POISON" },
  [2] = { name = "Ivysaur", category_es = "Semilla", category_en = "Seed", type1 = "GRASS", type2 = "POISON" },
  [3] = { name = "Venusaur", category_es = "Semilla", category_en = "Seed", type1 = "GRASS", type2 = "POISON" },
  [4] = { name = "Charmander", category_es = "Lagartija", category_en = "Lizard", type1 = "FIRE" },
  [5] = { name = "Charmeleon", category_es = "Llama", category_en = "Flame", type1 = "FIRE" },
  [6] = { name = "Charizard", category_es = "Llama", category_en = "Flame", type1 = "FIRE", type2 = "FLYING" },
  [7] = { name = "Squirtle", category_es = "Tortuguita", category_en = "Tiny Turtle", type1 = "WATER" },
  [8] = { name = "Wartortle", category_es = "Tortuga", category_en = "Turtle", type1 = "WATER" },
  [9] = { name = "Blastoise", category_es = "Armazón", category_en = "Shellfish", type1 = "WATER" },
  [25] = { name = "Pikachu", category_es = "Ratón", category_en = "Mouse", type1 = "ELECTRIC" },
  [26] = { name = "Raichu", category_es = "Ratón", category_en = "Mouse", type1 = "ELECTRIC" },
  [133] = { name = "Eevee", category_es = "Evolución", category_en = "Evolution", type1 = "NORMAL" },
  [143] = { name = "Snorlax", category_es = "Dormilón", category_en = "Sleeping", type1 = "NORMAL" },
  [150] = { name = "Mewtwo", category_es = "Genético", category_en = "Genetic", type1 = "PSYCHIC" },
  [151] = { name = "Mew", category_es = "Nueva Especie", category_en = "New Species", type1 = "PSYCHIC" },
}

function Pokedex.get(index)
  index = tonumber(index) or 1
  return Pokedex.SPECIES[index] or {
    name = "POKéMON #" .. tostring(index),
    category_es = "Desconocido",
    category_en = "Unknown",
    type1 = "NORMAL",
  }
end

return Pokedex
