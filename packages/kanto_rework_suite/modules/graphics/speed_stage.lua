-- KRS battle-sprite animation cadence modifier.
-- This is a visual mapping, not a Pokémon damage/stat formula. It consumes the
-- real BattleState battler `stages.speed` value, clamped to Gen I's -6..+6.
local M={}
function M.clamp(stage) local v=tonumber(stage) or 0;v=v>=0 and math.floor(v+.5) or math.ceil(v-.5);return math.max(-6,math.min(6,v)) end
function M.rate(stage)
  -- Symmetric, monotone and deliberately conservative: every 12 stages doubles
  -- cadence, so ±6 produces sqrt(2) / 1/sqrt(2) around configured stage 0.
  return 2^(M.clamp(stage)/12)
end
function M.duration(baseMs,stage)
  local base=math.max(12,tonumber(baseMs) or 12)
  return math.max(12,math.floor(base/M.rate(stage)+.5))
end
return M
