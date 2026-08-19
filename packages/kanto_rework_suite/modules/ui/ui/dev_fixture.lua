-- Development-only provider. It never mutates the game save and is disabled
-- by default. The fixture resolves move names against live ROM data so it does
-- not depend on numeric move IDs.
local Fixture = {}

local NAMES = { "AGILITY", "SLAM", "REST", "TOXIC" }

local function normalized(value)
  return tostring(value or ""):upper():gsub("[^A-Z0-9]", "")
end

function Fixture.learnedMoves(game, active)
  local activeById = {}
  for _, move in ipairs(active or {}) do activeById[move.id] = true end
  local wanted = {}
  for _, name in ipairs(NAMES) do wanted[normalized(name)] = true end
  local out = {}
  for id, def in pairs(game and game.data and game.data.moves or {}) do
    local key = normalized(def and def.name)
    if wanted[key] and not activeById[id] then
      out[#out + 1] = {
        id = id,
        pp = tonumber(def.pp) or 0,
        ppUps = 0,
        developmentFixture = true,
      }
    end
  end
  table.sort(out, function(a, b)
    local da = game.data.moves[a.id] or {}
    local db = game.data.moves[b.id] or {}
    return tostring(da.name) < tostring(db.name)
  end)
  return out
end

return Fixture
