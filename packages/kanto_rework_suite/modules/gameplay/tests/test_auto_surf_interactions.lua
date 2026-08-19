local root=assert(arg[1],'root path required')
local registered={}
package.preload['src.world.Collision']=function()
  return {occupied=function() return false end,target=function(x,y,dir) return x,y end}
end
package.preload['src.core.Music']=function() return {setSurfing=function() end} end
package.preload['src.render.TextBox']=function() return {} end
package.preload['src.render.Transition']=function() return {whiteFlash=function() return {} end} end

local stack={state=nil,top=function(self) return self.state end,push=function() end}
local player={cellX=5,cellY=5,facing='up',moving=false,surfing=false,
  facingCell=function() return 5,4 end}
local surfChecks=0
local ow={player=player,map={id='PEWTER_GYM'},entities={},
  useSurfFieldMove=function() surfChecks=surfChecks+1;return 'ok' end,
  trySurf=function() return true end,pushableAtCell=function() return nil end}
stack.state=ow
local game={overworld=ow,stack=stack,
  save={inventory={HM_SURF=1,SOULBADGE=1}},
  data={field={hiddenExtras={gymStatues={PEWTER_GYM={{x=5,y=4}}}}}}}
local options={field_move_mode='automatic',lawn_mower=false}
local mod={id='kanto_rework_gameplay',options={get=function(_,k) return options[k] end},
  events={on=function() return function() return true end end}}
local OverworldState={
  partyKnows=function() return nil end,
  handleInput=function() return 'native' end,
  checkBoulderPush=function() return false end,
}
local Core={fieldActions={
  register=function(def) registered[def.id]=def;return function() return true end end,
  execute=function(id,context)
    local d=assert(registered[id]);local a=d.availability(context)
    if not a.available then return false,a.reason end
    return d.execute(context)
  end,
}}
local service=assert(loadfile(root..'/field_moves.lua'))()({mod=mod,Core=Core,Game=game,OverworldState=OverworldState})
local surf=assert(registered['kanto.surf'])
local auto={game=game,overworld=ow,automatic=true}
local a=surf.availability(auto)
assert(a.available==false and a.reason=='interactive_target' and a.target=='gym_statue',
  'automatic Surf must yield to the Gym statue hidden interaction')
assert(surfChecks==0,'automatic statue guard must run before the native shore/water probe')
local ok,why=surf.execute(auto)
assert(ok==false and why=='interactive_target' and surfChecks==0,
  'execute path must re-check the semantic interaction target')

local manual={game=game,overworld=ow,automatic=false}
a=surf.availability(manual)
assert(a.available==true and surfChecks==1,
  'manual Surf must preserve the native field-move probe on the same tile')

game.data.field.hiddenExtras.gymStatues.PEWTER_GYM={}
surfChecks=0
a=surf.availability(auto)
assert(a.available==true and surfChecks==1,
  'automatic Surf must remain available on a genuine non-statue surf target')

service.unregister()
print('Automatic Surf semantic-interaction guard tests passed')
