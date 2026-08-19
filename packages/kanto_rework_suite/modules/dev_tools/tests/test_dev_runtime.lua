local root=assert(arg[1],"root path required")
local BattleState={};BattleState.__index=BattleState
local created={}
function BattleState.newWild(game,species,level)
  local b=setmetatable({kind="wild",enemy={mon={species=species,level=level},def=game.data.pokemon[species]},data=game.data},BattleState)
  created.wild=b;return b
end
function BattleState.newTrainer(game,classId,partyIndex)
  local mon={species="WEEDLE",level=9,hp=30,stats={hp=30}}
  local b=setmetatable({kind="trainer",oppClass=classId,partyIndex=partyIndex,data=game.data,
    enemy={mon=mon,def={name="Weedle"}}},BattleState)
  created.trainer=b;return b
end
function BattleState:applyDamage(target,dmg)
  self.damageCalls=(self.damageCalls or 0)+1
  target.mon.hp=math.max(0,(target.mon.hp or 0)-(dmg or 0))
  return dmg
end
function BattleState:onFaint(target)
  self.faintCalls=(self.faintCalls or 0)+1
  target.faintQueued=true
end
package.preload['src.battle.BattleState']=function() return BattleState end

local optionValues={dev_overlay=true,move_preview_overlay=true}
local registered={}
local pressedActions={}
local Core={
  inputActions={
    register=function(def) registered[def.id]=def;return function() end end,
    wasPressed=function(id) return pressedActions[id]==true end,
    binding=function(id) return id=="KRS_DEV_OVERLAY" and "F3" or "INSERT" end,
  },
  registerInputLayer=function(def) registered.inputLayer=def;return function() end end,
  notifications={emit=function() end},
}
local readyHook,optionsHook
local hooks={}
local mod={
  id="kanto_rework_dev",path=root,
  find=function(id) if id=="core" then return {exports=Core} end end,
  options={
    define=function(_,defs) for _,d in ipairs(defs) do if optionValues[d.key]==nil then optionValues[d.key]=d.default end end end,
    get=function(_,key) return optionValues[key] end,
  },
  events={on=function(_,name,fn) if name=="game.ready" then readyHook=fn elseif name=="mod.options_changed" then optionsHook=fn end end},
  hooks={wrap=function(_,name,fn,priority) hooks[name]={fn=fn,priority=priority};return function() end end},
  log={info=function() end,error=function() end,warn=function() end},
  exports={},
}

local init=assert(loadfile(root.."/main.lua"))();init(mod)
assert(mod.exports.release=="0.2.5","dev release")
assert(registered.KRS_DEV_OVERLAY and registered.inputLayer,"interactive dev overlay is registered")

local overworld={kind="overworld"}
local game={
  data={
    pokemon={PIKACHU={name="Pikachu",dex=25},MEWTWO={name="Mewtwo",dex=150}},
    moves={TACKLE={name="Tackle",type="NORMAL"},THUNDERBOLT={name="Thunderbolt",type="ELECTRIC"}},
    trainers={OPP_BUG_CATCHER={name="BUG CATCHER",parties={{{species="CATERPIE",level=7}},{{species="WEEDLE",level=9}}}}},
  },
  save={inventory={},flags={KEEP_ME=true},party={{species="PIKACHU",hp=20}}},
  overworld=overworld,
}
game.stack={states={overworld},top=function(self) return self.states[#self.states] end,push=function(self,s) self.states[#self.states+1]=s end}
function overworld:pushBattle(battle) game.stack:push(battle) end
function overworld:afterBattle() end
if readyHook then readyHook({game=game}) end

-- F3 must be physically reachable even while the overlay is closed. The input
-- layer stays registered but declines pointer ownership until a Dev surface is
-- actually visible. Core's logical action edge may arrive on the same frame;
-- de-duplication must prevent the overlay from toggling twice.
assert(registered.inputLayer.active(game)==true,"Dev input layer remains keyboard-active while closed")
assert(registered.inputLayer.pointer(game,{phase="moved",x=10,y=10,source="mouse"})==false,
  "closed Dev overlay never steals Voxel/menu pointer ownership")
assert(registered.inputLayer.keypressed(game,"f3",nil,false)==true and mod.exports.status().open==true,
  "physical F3 opens the Dev overlay")
assert(hooks["input.step"] and hooks["input.step"].priority==60,"Dev logical action runs after Core input promotion")
pressedActions.KRS_DEV_OVERLAY=true
hooks["input.step"].fn(function() return true end,game,1/60)
pressedActions.KRS_DEV_OVERLAY=false
assert(mod.exports.status().open==true,"physical and logical F3 edges cannot double-toggle")
mod.exports.open(false)
assert(mod.exports.status().pointerSurfaceActive==false,"closing Dev releases pointer ownership immediately")

local ok,wild=mod.exports.triggerWild(game,"MEWTWO",73,true)
assert(ok and wild==created.wild,"wild trigger")
assert(wild.enemy.mon.species=="MEWTWO" and wild.enemy.mon.level==73 and wild.enemy.mon.shiny==true,
  "wild selector applies any loaded species, level and shiny flag")

game.stack.states={overworld}
local okTrainer,trainer=mod.exports.triggerTrainer(game,"OPP_BUG_CATCHER",2)
assert(okTrainer and trainer==created.trainer and trainer.oppClass=="OPP_BUG_CATCHER" and trainer.partyIndex==2,
  "trainer selector launches the chosen loaded trainer party")

-- Move preview must drive only the animation player; it must not consume PP,
-- apply damage or clear an in-flight pendingHit from the real battle.
local pending={damage=12}
local animationCalls={}
trainer.animPlayer={
  start=function(_,moveId,playerSide) animationCalls[#animationCalls+1]={moveId,playerSide} end,
  isDone=function() return false end,
  pollEffects=function() return {} end,
}
trainer.pendingHit=pending
trainer.resetPicFx=function() trainer.resetCalled=true end
trainer.applyAnimEffect=function() end
game.stack.states={overworld,trainer}
local okAnim=mod.exports.playMoveAnimation(game,"THUNDERBOLT")
assert(okAnim and #animationCalls==1 and animationCalls[1][1]=="THUNDERBOLT" and animationCalls[1][2]==true,
  "move overlay previews the chosen loaded animation")
assert(trainer.animPlaying==true and trainer.animName=="THUNDERBOLT" and trainer.pendingHit==pending,
  "move preview leaves battle damage state untouched")

-- The battle move browser is a real movable/resizable/collapsible overlay,
-- but its state is private under the v0.1.86 sandbox. Exercise it through the
-- public render/input seams rather than a shared _G test backdoor.
love={graphics={}}
for _,name in ipairs({'push','pop','origin','setColor','rectangle','setLineWidth','setFont','print','printf','line'}) do
  love.graphics[name]=function() end
end
love.graphics.newFont=function(size) return {size=size,getWidth=function(_,text) return #tostring(text)*size*.5 end} end
mod.exports.open(true)
local render=assert(hooks["render.hud"],"Dev render.hud hook registered")
render.fn(function() return true end,game,{width=1920,height=1080})
local initial=mod.exports.status().movePanel
assert(initial.x and initial.y and initial.w and initial.h,"move browser lays out through render.hud")
local sx,sy=initial.x+20,initial.y+20
assert(registered.inputLayer.pointer(game,{phase="pressed",source="mouse",button=1,x=sx,y=sy})==true,"move browser drag starts")
registered.inputLayer.pointer(game,{phase="moved",source="mouse",button=1,x=sx-200,y=sy+100})
registered.inputLayer.pointer(game,{phase="released",source="mouse",button=1,x=sx-200,y=sy+100})
local moved=mod.exports.status().movePanel
assert(moved.x==initial.x-200 and moved.y==initial.y+100,"move browser can be repositioned")

-- Re-render refreshes hit rectangles at the new geometry before resizing.
render.fn(function() return true end,game,{width=1920,height=1080})
moved=mod.exports.status().movePanel
local rx,ry=moved.x+moved.w-10,moved.y+moved.h-10
assert(registered.inputLayer.pointer(game,{phase="pressed",source="mouse",button=1,x=rx,y=ry})==true,"move browser resize starts")
registered.inputLayer.pointer(game,{phase="moved",source="mouse",button=1,x=rx+100,y=ry+50})
registered.inputLayer.pointer(game,{phase="released",source="mouse",button=1,x=rx+100,y=ry+50})
local resized=mod.exports.status().movePanel
assert(resized.w==moved.w+100 and resized.h==moved.h+50,"move browser can be resized within viewport bounds")
render.fn(function() return true end,game,{width=1920,height=1080})
resized=mod.exports.status().movePanel
registered.inputLayer.pointer(game,{phase="pressed",source="mouse",button=1,x=resized.x+resized.w-30,y=resized.y+20})
assert(mod.exports.status().movePanel.collapsed==true,"move browser can collapse to its header")

-- User option disables only the move browser; the compact battle tool remains
-- active, so F3 still owns the pointer surface and ONE-SHOT remains available.
optionValues.move_preview_overlay=false
assert(optionsHook,"Dev options_changed listener registered")
optionsHook({mod="kanto_rework_dev",key="move_preview_overlay",value=false})
render.fn(function() return true end,game,{width=1920,height=1080})
assert(mod.exports.status().movePreview==false,"Battle Move Preview can be disabled from the Dev mod option")
assert(mod.exports.status().pointerSurfaceActive==true,"disabling Move Preview keeps F3 battle tools active")
local shot=mod.exports.oneShotEnemy(game)
assert(shot==true and trainer.enemy.mon.hp==0,"ONE-SHOT ENEMY reduces the active enemy to zero HP")
assert(trainer.damageCalls==1 and trainer.faintCalls==1 and trainer.enemy.faintQueued==true,
  "ONE-SHOT ENEMY uses BattleState applyDamage/onFaint instead of bypassing the native KO pipeline")
optionValues.move_preview_overlay=true
optionsHook({mod="kanto_rework_dev",key="move_preview_overlay",value=true})

-- The Live Graphics Editor is modal over an active battle. Even if the F3 Dev
-- overlay remains open and its battle finder can still see the BattleState
-- below, Dev must suspend both rendering/pointer ownership and let the editor
-- receive mouse, wheel and keyboard events. Closing the editor restores the
-- still-open Dev battle tools.
local editor={kind="graphics_editor"}
game.stack.states={overworld,trainer,editor}
render.fn(function() return true end,game,{width=1920,height=1080})
assert(mod.exports.status().open==true,"Live Graphics Editor does not forcibly close the Dev overlay session")
assert(mod.exports.status().pointerSurfaceActive==false,"Live Graphics Editor suspends Dev pointer ownership")
assert(registered.inputLayer.pointer(game,{phase="moved",x=100,y=100,source="mouse"})==false,
  "Dev pointer layer yields to Live Graphics Editor")
assert(registered.inputLayer.wheel(game,0,1,100,100)==false,
  "Dev wheel layer yields to Live Graphics Editor")
assert(registered.inputLayer.keypressed(game,"left",nil,false)==false,
  "Dev keyboard layer yields non-F3 keys to Live Graphics Editor")
game.stack.states={overworld,trainer}
render.fn(function() return true end,game,{width=1920,height=1080})
assert(mod.exports.status().pointerSurfaceActive==true,"Dev battle tools resume after Live Graphics Editor closes")
mod.exports.open(false)

local beforeFlag=game.save.flags.KEEP_ME
assert(mod.exports.setFlyUnlocked(true)==true and mod.exports.flyUnlocked()==true,"session Fly override on")
assert(game.save.flags.KEEP_ME==beforeFlag and game.save.flyUnlocked==nil and game.save.devFlyUnlocked==nil,
  "Fly override never writes progression into the save")
if readyHook then readyHook({game=game}) end
assert(mod.exports.flyUnlocked()==false,"Fly override resets for a new game session")
print("Dev runtime overlay tests passed")
