-- Limit the Gen 1 low-HP siren to one three-second real-time burst for each
-- continuous visit to the red zone. Leaving the danger state resets the
-- budget, so a later critical-HP event may alert again.
return function(mod)
  local budget=setmetatable({},{__mode='k'})
  local function nowSeconds()
    local timer=love and love.timer
    if timer and type(timer.getTime)=='function' then
      local ok,value=pcall(timer.getTime)
      if ok and tonumber(value) then return tonumber(value) end
    end
    return os.clock()
  end
  return mod.hooks:wrap('battle.low_health_alarm',function(next,ctx)
    ctx=ctx or {}
    local battle=ctx.battle
    if not battle then return next(ctx) end
    local rec=budget[battle]
    if ctx.on then
      local now=nowSeconds()
      if not rec then rec={started=now};budget[battle]=rec end
      if now-(rec.started or now)>=3 then ctx.on=false end
    else
      budget[battle]=nil
    end
    return next(ctx)
  end,120)
end
