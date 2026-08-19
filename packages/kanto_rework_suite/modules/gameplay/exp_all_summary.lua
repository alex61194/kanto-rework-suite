-- EXP.ALL presentation policy for Kanto Rework Gameplay.
--
-- Combat math and progression remain engine-owned. This module replaces only
-- the public battle.exp_award orchestration when EXP.ALL is present: it runs
-- the exact vanilla two-pass divisors through ctx.applyShare, suppresses the
-- second pass's per-mon text, and appends one readable team summary.
return function(mod)
  local Strings=require("src.core.Strings")
  return mod.hooks:wrap("battle.exp_award",function(next,ctx)
    local battle=ctx and ctx.battle
    local game=battle and battle.game
    local save=game and game.save
    if not (battle and save and save.inventory and (save.inventory.EXP_ALL or 0)>0
        and type(ctx.applyShare)=="function" and type(ctx.alive)=="table") then
      return next(ctx)
    end

    -- First half: surviving participants, exactly as vanilla.
    for _,mon in ipairs(ctx.alive) do
      ctx.applyShare(mon,ctx.participants*2,true)
    end

    -- Second half: every non-fainted party member, using the stock divisor.
    -- applyShare still emits battle.exp_gained and queues level-ups, stats
    -- windows and move-learning; announce=false changes presentation only.
    local party=save.party or {}
    local split=math.max(1,ctx.participants)*#party*2
    local restTotal=0
    local active=battle.player and battle.player.mon
    for _,mon in ipairs(party) do
      if (tonumber(mon.hp) or 0)>0 then
        local before=tonumber(mon.exp) or 0
        ctx.applyShare(mon,split,false)
        if mon~=active then
          restTotal=restTotal+math.max(0,(tonumber(mon.exp) or before)-before)
        end
      end
    end
    if restTotal>0 and type(battle.sayNext)=="function" then
      battle:sayNext(Strings("The rest of the team earned\n%d EXP!",restTotal))
    end
    return true
  end,120)
end
