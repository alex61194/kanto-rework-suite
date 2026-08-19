local moduleDir='.'
local source=assert(io.open(moduleDir..'/main.lua','rb')):read('*a')
local init=assert(load(source,'@main.lua'))()
local registered
local Core={version=40,graphics={registerProvider=function(spec)registered=spec;return function()end end}}
local exports={}
local optionValues={pokemon_provider='krs',battle_sprite_mode='animated',front_generation='gen5',back_generation='gen5',player_art='red',sprite_animation=true,animation_speed='normal',battle_scale='default',real_size='auto',battle_backgrounds=true,time_mode='day',time_cycle_length='20',world_lighting=true}
local mod={id='kanto_rework_graphics',path=moduleDir,exports=exports,
  find=function(id)if id=='core'then return{exports=Core}end end,
  read=function(self,rel)local f=assert(io.open(moduleDir..'/'..rel,'rb'));local s=f:read('*a');f:close();return s end,
  assets={path=function(self,rel)return moduleDir..'/'..rel end},
  options={define=function()end,get=function(_,key)return optionValues[key]end},
  hooks={wrap=function()return function()end end},events={on=function()return function()end end},save={get=function()end,set=function()end},log={info=function()end}}
init(mod)
assert(registered and registered.resolve,'provider registered')
local r=registered.resolve
local data={pokemon={NIDORINO={dex=33},PIKACHU={dex=25}}}
local n=r('intro.pokemon',{species='NIDORINO',data=data})
assert(n and n.assetId:find('assets/battle_art/front/gen5/normal/nidorino.png',1,true),'Nidorino intro uses selected KRS Gen5 front atlas')
assert(n.atlas and n.atlas.frameCount>1 and n.filter=='nearest' and n.integerScale and n.battleScale==false,'intro front is animated, crisp, and battle-scale isolated')
local namedP=r('summary.preview',{species='PIKACHU',data=data})
assert(namedP and namedP.atlas and namedP.assetId:find('/front/gen5/normal/pikachu.png',1,true),'menu preview uses selected animated Gen5 front art')
local ns=r('intro.pokemon',{species='NIDORINO',data=data,shiny=true})
assert(ns and ns.assetId:find('/front/gen5/shiny/nidorino.png',1,true),'Nidorino shiny intro uses same-generation shiny art')
local p=r('party.icon',{species=25,form=1})
assert(p and p.assetId=='assets/pokemon/icon/0025_01.png' and p.frameCount==2 and p.frameDuration==0.15,'Pikachu menu icon remains two-frame at fixed menu cadence')
assert(p.atlas and p.atlas.frameDurationMs==150,'menu icon metadata is also consumable through PokemonArt atlas materialization')
local movesIcon=r('moves.icon',{species=25});assert(movesIcon and movesIcon.frameCount==2,'Moves compact representation resolves to menu icon')
local pf=r('save.icon',{species=25,gender='female'})
assert(pf and pf.assetId=='assets/pokemon/icon/0025f.png','Save uses the same female menu-icon family as Party/PC')
local psf=r('pc.icon',{species=25,gender='female',shiny=true})
assert(psf and psf.assetId=='assets/pokemon/icon/0025sf.png','PC shiny female icon')
local back=r('battle.player',{species='PIKACHU',data=data})
assert(back and back.atlas and back.assetId:find('/back/gen5/normal/pikachu.png',1,true) and back.battleScale==true,'Gen5 player back is animated and battle-scaled')
optionValues.back_generation='gen4'
local back4=r('battle.player',{species='PIKACHU',data=data})
assert(back4 and not back4.atlas and back4.assetId:find('/back_static/gen4/normal/pikachu.png',1,true),'Gen4 back correctly remains static')
optionValues.back_generation='gen5';optionValues.sprite_animation=false
local frozen=r('battle.opponent',{species='PIKACHU',data=data})
assert(frozen and not frozen.atlas and frozen.nativePath,'animation OFF freezes the selected generation on a static fallback')
optionValues.sprite_animation=true
local red=r('intro.trainer',{id='red'})
assert(red and red.presentationScale==0.5 and red.noUpscale and red.filter=='nearest','Red intro artwork uses validated half-scale source presentation')
local blue=r('intro.trainer',{id='blue'})
assert(blue and blue.presentationScale==0.5 and blue.noUpscale and blue.filter=='nearest','Blue intro artwork uses validated half-scale source presentation')
local fallback=r('summary.preview',{species='MISSINGNO'})
assert(fallback==nil,'missing species falls back locally')
print('graphics asset resolution tests passed')
