local root=assert(arg[1],'root required')
local originalCalls=0
local O={stepHealAnim=function(ha) originalCalls=originalCalls+1;ha.timer=(ha.timer or 0)+1;return 'tick' end}
package.preload['src.world.OverworldController']=function() return O end
local ensured=0
package.preload['src.pokemon.Boxes']=function() return {ensure=function(save) ensured=ensured+1;return save.boxes end} end
local healCalls=0
package.preload['src.pokemon.Pokemon']=function() return {heal=function(mon)
  healCalls=healCalls+1;mon.hp=mon.stats.hp;mon.status=nil
  for _,mv in ipairs(mon.moves or {}) do mv.pp=mv.maxPP or 20 end
end} end
local m1={hp=0,status='PSN',stats={hp=55},moves={{pp=0,maxPP=15}}}
local m2={hp=3,status='PAR',stats={hp=72},moves={{pp=1,maxPP=10}}}
local m3={hp=1,status='SLP',stats={hp=88},moves={{pp=0,maxPP=5}}}
local game={save={boxes={{m1},{m2},{},{m3}}}}
local adapter=assert(loadfile(root..'/center_heal_boxes.lua'))()({Game=game})
local ha={timer=0};assert(O.stepHealAnim(ha)=='tick');assert(O.stepHealAnim(ha)=='tick')
assert(healCalls==3 and ensured==1,'all stored Pokémon heal exactly once per Center animation')
for _,m in ipairs({m1,m2,m3}) do assert(m.hp==m.stats.hp and m.status==nil and m.moves[1].pp==m.moves[1].maxPP,'official heal semantics reach HP/status/PP in boxes') end
local st=adapter.status();assert(st.centerOnly and st.healRuns==1 and st.healedMons==3,'center heal adapter reports one scoped run')
assert(adapter.uninstall() and O.stepHealAnim~=nil,'adapter uninstalls cleanly')
print('Pokemon Center box heal tests passed')
