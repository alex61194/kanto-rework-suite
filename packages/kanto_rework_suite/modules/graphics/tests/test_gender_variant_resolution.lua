local root=assert(arg[1],'root required')
local factory=assert(loadfile(root..'/main.lua'))()
local registered
local Core={version=40,graphics={registerProvider=function(spec)registered=spec;return function()end end}}
local vals={pokemon_provider='krs',battle_sprite_mode='animated',front_generation='gen5',back_generation='gen5',player_art='red',sprite_animation=true,animation_speed='normal',battle_scale='default',real_size='auto',battle_backgrounds=true,time_mode='day',time_cycle_length='20',world_lighting=true}
local mod={id='kanto_rework_graphics',path=root,exports={},find=function(id)if id=='core'then return{exports=Core}end end,
 read=function(_,rel)local f=assert(io.open(root..'/'..rel,'rb'));local s=f:read('*a');f:close();return s end,
 assets={path=function(_,rel)return root..'/'..rel end},options={define=function()end,get=function(_,k)return vals[k]end},
 hooks={wrap=function()return function()end end},events={on=function()return function()end end},save={get=function()end,set=function()end},log={info=function()end}}
factory(mod);assert(registered and type(registered.resolve)=='function','graphics provider registered')
local male=assert(registered.resolve('battle.opponent',{species='KOFFING',gender='male'}))
local female=assert(registered.resolve('battle.opponent',{species='KOFFING',gender='female'}))
assert(male.atlas and male.atlas.variantRows==2 and male.atlas.variantIndex==1,'male/common Koffing selects one top track')
assert(female.atlas and female.atlas.variantRows==2 and female.atlas.variantIndex==2,'female Koffing selects one bottom track')
local common=assert(registered.resolve('battle.opponent',{species='PIKACHU',gender='female'}))
assert(common.atlas and common.atlas.variantRows==nil and common.genderVariant=='common','species without stacked variant stays one common resource')
local shiny=assert(registered.resolve('battle.opponent',{species='KOFFING',gender='female',shiny=true}))
assert(shiny.atlas and shiny.atlas.variantRows==nil,'shiny Koffing is not falsely split when supplied cell is single-track')
print('Graphics gender-variant resolution tests passed')
