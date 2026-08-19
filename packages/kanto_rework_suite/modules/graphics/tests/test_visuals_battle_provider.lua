local root=assert(arg[1],'root required')
local factory=assert(loadfile(root..'/main.lua'))()
local provider,hooks={},{ }
local registered
local Core={version=40,graphics={registerProvider=function(spec)registered=spec;return function()end end}}
local vals={pokemon_provider='krs',battle_sprite_mode='animated',front_generation='gen5',back_generation='gen5',player_art='red',sprite_animation=true,animation_speed='normal',battle_scale='default',real_size='auto',battle_backgrounds=true,time_mode='day',time_cycle_length='20',world_lighting=true}
local mod={id='kanto_rework_graphics',path=root,exports={},find=function(id)if id=='core'then return{exports=Core}end end,
 read=function(_,rel)local f=assert(io.open(root..'/'..rel,'rb'));local s=f:read('*a');f:close();return s end,
 assets={path=function(_,rel)return root..'/'..rel end},options={define=function()end,get=function(_,k)return vals[k]end},
 hooks={wrap=function(_,name,fn)hooks[name]=fn;return function()end end},events={on=function()return function()end end},save={get=function()end,set=function()end},log={info=function()end}}
factory(mod);assert(registered and hooks['pokemon.sprite'] and hooks['player.sprite'],'Graphics registers first-party providers and official sprite hooks')
local hook=hooks['pokemon.sprite']
local front=hook(function(path)return path end,'gen1/front.png',{species='PIKACHU',side='front',mon={shiny=false}})
local back=hook(function(path)return path end,'gen1/back.png',{species='PIKACHU',side='back',mon={shiny=false}})
local shiny=hook(function(path)return path end,'gen1/front.png',{species='PIKACHU',side='front',mon={shiny=true}})
assert(front:find('/assets/battle_art/front_first/gen5/normal/pikachu.png',1,true),'KRS front works with no Voxel provider')
assert(back:find('/assets/battle_art/back_first/gen5/normal/pikachu.png',1,true),'KRS back works with no Voxel provider')
assert(shiny:find('/assets/battle_art/front_first/gen5/shiny/pikachu.png',1,true),'KRS shiny works with no Voxel provider')
vals.pokemon_provider='gen1';assert(hook(function()error('must not invoke external provider')end,'gen1/front.png',{species='PIKACHU',side='front'})=='gen1/front.png','GEN1RECOMP mode is clean ROM fallback')
vals.pokemon_provider='krs';local p=mod.exports.battlePresentation();assert(p.pixelScale==1 and p.realSize=='auto','Graphics owns battle presentation options')
local player=mod.exports.playerArt();assert(player.choice=='red' and player.animated and player.atlas and player.atlas.frameCount==5,'Red player five-pose strip is exposed to KRS battle UI')
print('Graphics battle sprite autonomy tests passed')
