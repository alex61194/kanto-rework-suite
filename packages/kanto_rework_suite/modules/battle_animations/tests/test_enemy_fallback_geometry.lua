local root=assert(arg[1],'root required')
local DATA=assert(loadfile(root..'/data/gen1_anims.lua'))()
local src=assert(io.open(root..'/scripts/essentials_player.lua','rb')):read('*a')
local SUX,SUY,STX,STY=128,224,384,96
local function classify(anim)
  if not (anim and type(anim.frames)=='table') then return 'reflect' end
  local visible,targetLocal,userLocal=0,0,0
  for _,frame in ipairs(anim.frames) do
    for _,c in ipairs(frame) do
      local pattern=c[9]
      if pattern and pattern>=0 and c[8]==1 and (c[10] or 0)>0 then
        visible=visible+1
        local x,y=c[1] or 0,c[2] or 0
        local dt=(x-STX)^2+(y-STY)^2
        local du=(x-SUX)^2+(y-SUY)^2
        if dt<du then targetLocal=targetLocal+1 elseif du<dt then userLocal=userLocal+1 end
      end
    end
  end
  if visible>0 and targetLocal==visible then return 'target' end
  if visible>0 and userLocal==visible then return 'user' end
  return 'reflect'
end
local counts={target=0,user=0,reflect=0}; local missing=0; local dedicated=0
for _,rec in pairs(DATA.moves) do
  if rec.opp then dedicated=dedicated+1 else
    missing=missing+1
    local mode=classify(rec.player); counts[mode]=counts[mode]+1
  end
end
assert(missing==100 and dedicated==65,'unexpected opponent variant inventory')
assert(counts.target==55 and counts.user==18 and counts.reflect==27,'fallback class totals changed')
for _,move in ipairs({'WRAP','CONSTRICT','FIRESPIN','CLAMP','BITE','SUPERFANG','VISEGRIP','STRINGSHOT','POISONPOWDER','SLEEPPOWDER','STUNSPORE','SPORE','SMOG','POISONGAS','SMOKESCREEN','TOXIC','THUNDERWAVE'}) do
  local rec=assert(DATA.moves[move],move)
  assert(rec.opp==nil,move..' unexpectedly gained dedicated opp animation')
  assert(classify(rec.player)=='target',move..' must remain target-local')
end
assert(src:find('enemyFallbackMode=classifyEnemyFallback(rec.player)',1,true),'runtime must classify only missing-opponent fallback sessions')
assert(src:find('px=target.x+(cx-SRC_TARGET_X)*WIDE_EFFECT_SCALE',1,true),'Wide target-local path must anchor directly to live defender')
assert(src:find('px=user.x+(cx-SRC_USER_X)*WIDE_EFFECT_SCALE',1,true),'Wide user-local path must anchor directly to live attacker')
assert(src:find('Dedicated opponent sequences and mixed/directional fallbacks use',1,true),'Wide reflect path documentation missing')
assert(not src:find('battleArtStageApi',1,true),'Battle Art divergent compositor code must not be merged with placement patch')
print('Enemy fallback geometry tests passed: 55 target / 18 user / 27 reflect')
