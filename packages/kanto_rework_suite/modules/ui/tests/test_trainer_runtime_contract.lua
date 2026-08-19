local f=assert(io.open('ui/battle_presenter.lua','rb'));local s=f:read('*a');f:close()
assert(s:find("runtime.Graphics:resolve('battle.trainer'",1,true),'BattlePresenter consumes real Graphics trainer source')
assert(s:find("trainerPhase=='battle'",1,true),'persistent trainer has semantic battle branch')
assert(s:find('Engine showEnemyTrainer stays untouched.',1,true),'engine trainer flag ownership documented')
local l=assert(io.open('runtime/battle_layout_config.lua','rb'));local c=l:read('*a');l:close()
for _,k in ipairs({'trainer_intro','trainer_battle','trainer_post','trainer_style'}) do assert(c:find(k,1,true),k..' config missing') end
print('trainer runtime contract: PASS')
