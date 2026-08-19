-- Battle trainer semantic presentation state. This mirrors the engine's
-- lifecycle without mutating BattleState.showEnemyTrainer.
return function()
  local flow=setmetatable({},{__mode='k'})
  local service={}
  function service.phase(battle)
    if not battle or (battle.kind~='trainer' and battle.kind~='link') then return nil end
    local rec=flow[battle]
    if not rec then rec={seenNative=false,seenBattle=false};flow[battle]=rec end
    if battle.showEnemyTrainer then
      rec.seenNative=true
      return rec.seenBattle and 'post' or 'intro'
    end
    if rec.seenNative or battle.phase~='intro' then rec.seenBattle=true end
    return 'battle'
  end
  function service.showPersistent(battle,keep)
    return keep==true and service.phase(battle)=='battle' and battle and battle.kind=='trainer'
  end
  function service.reset(battle) flow[battle]=nil end
  return service
end
