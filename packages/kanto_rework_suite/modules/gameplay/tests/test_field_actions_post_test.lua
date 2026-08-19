local root=assert(arg[1],'root path required')
local registered={}
package.preload['src.world.Collision']=function() return {occupied=function()return false end,target=function(x,y)return x,y end} end
package.preload['src.core.Music']=function() return {setSurfing=function()end} end
package.preload['src.render.TextBox']=function() return {} end
package.preload['src.render.Transition']=function() return {whiteFlash=function()return{}end} end
package.preload['src.world.Map']=function() return {isOutside=function()return true end} end
package.preload['src.world.FieldDefaults']=function() return {field=function()return{}end} end
package.preload['src.ui.PartyMenu']=function() return {new=function()return{}end} end
package.preload['src.world.Encounter']=function() return {} end
package.preload['src.battle.BattleState']=function() return {newWild=function()return{}end} end

local stack={state=nil,top=function(self)return self.state end,push=function()end}
local ow={map={id='ROCK_TUNNEL_1F',def={tileset='CAVERN'}},player={moving=false}}
stack.state=ow
local game={overworld=ow,stack=stack,save={inventory={HM_CUT=1,CASCADEBADGE=1},party={{species='CHARIZARD',moves={}}}},data={moves={DIG={}},field={}}}
local options={field_move_mode='automatic',lawn_mower=false}
local mod={id='kanto_rework_gameplay',options={get=function(_,k)return options[k]end},events={on=function()return function()return true end end}}
local Core={
  knownMoves=function(mon) if mon.species=='CHARIZARD' then return {{id='DIG'}} end return{} end,
  fieldActions={register=function(def)registered[def.id]=def;return function()return true end end},
}
-- Deliberately provide none of the historical engine internals. Registration
-- must remain intact instead of aborting the Gameplay module.
local OverworldState={}
local service=assert(loadfile(root..'/field_moves.lua'))()({mod=mod,Core=Core,Game=game,OverworldState=OverworldState})
for _,id in ipairs({'kanto.cut','kanto.surf','kanto.strength','kanto.flash'}) do
  assert(registered[id],id..' must register even when optional engine adapters are absent')
end
local cutReq=assert(registered['kanto.cut'].requirements)
local cut=cutReq({game=game,overworld=ow,automatic=false,fieldPopup=true})
assert(cut.ok==false and cut.reason=='move_not_known','manual HM action must require permanent party capability')
game.save.party[1].moves={{id='CUT'}}
cut=cutReq({game=game,overworld=ow,automatic=false,fieldPopup=true})
assert(cut.ok==true and cut.capabilitySource=='active','manual HM action must accept active move knowledge')
-- Automatic mode keeps the already validated inventory+badge QoL policy.
game.save.party[1].moves={}
cut=cutReq({game=game,overworld=ow,automatic=true})
assert(cut.ok==true and cut.eligibility=='inventory_hm_and_badge','automatic HM action must preserve HM+badge policy')
service.unregister()

assert(loadfile(root..'/manual_field_moves.lua'))()({mod=mod,Core=Core,Game=game})
local dig=assert(registered['kanto.dig'],'Dig must be registered')
local req=assert(dig.requirements)({game=game,overworld=ow,automatic=false,fieldPopup=true})
assert(req.ok==true and req.capabilitySource=='memory','Dig must be known through permanent Move Memory')
assert(dig.availability({game=game,overworld=ow,fieldPopup=true}).available==true,'remembered Dig must be usable in a valid cave')
print('Field Actions post-test regression tests passed')
