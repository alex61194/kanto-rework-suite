local root=assert(arg[1])
local graphicsExports={menuPresentation=function()return{realSize='yes',source='test'}end}
local internalMod={find=function(id)
  if id=='graphics' or id=='graphics' then return {id='graphics',exports=graphicsExports} end
  return nil
end}
local chunk=assert(loadfile(root..'/runtime/menu_pokemon_presentation.lua'));local M=chunk()({mod=internalMod})
local game={data={pokemon={
 PIKACHU={dexEntry={heightFt=1,heightIn=4}},CHARIZARD={dexEntry={heightFt=5,heightIn=7}},GYARADOS={dexEntry={heightFt=21,heightIn=4}},DIGLETT={dexEntry={heightFt=0,heightIn=8}},
}}}
local image={getDimensions=function()return 96,96 end};local box={x=0,y=0,w=120,h=120}
local mons={pik={species='PIKACHU'},char={species='CHARIZARD'},gya={species='GYARADOS'},dig={species='DIGLETT'}}
local fp=M.sizeFactor(game,mons.pik);local fc=M.sizeFactor(game,mons.char);local fg=M.sizeFactor(game,mons.gya);assert(fc>fp and fg>fc,'species hierarchy is perceptible')
for _,mon in pairs(mons) do local g=M.geometry(game,mon,image,box,{baseFraction=.68,ceiling=.92,floorFraction=.30});assert(g.w<=box.w*.92+.01 and g.h<=box.h*.92+.01,'menu fit is bounded') end
local party=assert(io.open(root..'/ui/party_presenter.lua','rb')):read('*a');local pc=assert(io.open(root..'/ui/menu_presenter.lua','rb')):read('*a')
assert(party:find('MenuPokemonPresentation.geometry',1,true) and party:find('frontSprite(game,p',1,true),'Party uses menu Real Size geometry')
assert(pc:find("'pc.icon'",1,true) and pc:find('runtime.Graphics.draw',1,true),'PC uses the shared animated two-frame icon context')
assert(not pc:find("kind='pc'",1,true),'PC no longer requests provider front art')
print('round7 bounded menu Real Size Candidate tests passed')
