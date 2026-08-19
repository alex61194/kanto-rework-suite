local root=assert(arg[1],'root path required')
local OakSpeech={};OakSpeech.__index=OakSpeech
local TextBox={};TextBox.__index=TextBox
package.preload['src.ui.OakSpeech']=function()return OakSpeech end
package.preload['src.render.TextBox']=function()return TextBox end
package.preload['src.core.GameVersion']=function()return{isBlue=function()return false end,isYellow=function()return false end}end
local images={}
local function img(name,w,h)return{name=name,getDimensions=function()return w or 64,h or 64 end,setFilter=function()end}end
local drawn={}
love={timer={getTime=function()return .30 end},graphics={}}
for _,k in ipairs({'push','pop','origin','setColor','setScissor','rectangle'})do love.graphics[k]=function()end end
love.graphics.newQuad=function(x,y,w,h,iw,ih)return{viewport={x,y,w,h},getViewport=function(self)return table.unpack(self.viewport)end}end
love.graphics.draw=function(image,...) drawn[#drawn+1]=image end
local dialogue
local function resolve(context,request)
  if context=='intro.scene' then return{path='gfx:oak_lab',filter='linear'} end
  if context=='intro.trainer' then return{path='gfx:'..tostring(request.id),filter='linear'} end
  if context=='intro.pokemon' then return{path='gfx:'..tostring(request.species),filter='nearest',frameCount=2,frameWidth=32,frameHeight=32,frameDuration=.25} end
end
local runtime={viewport={},Core={graphics={resolve=resolve}},Layout={isWide=function()return true end,metrics=function()return{ox=0,oy=0,scale=1}end},Theme={resolveAll=function()return{}end},
  assetPath=function(p)return p end,assets={image=function(_,path)images[path]=images[path]or img(path,path:find('gfx:oak',1,true) and 2048 or 64,path:find('gfx:oak',1,true) and 1364 or 32);return images[path]end},
  DialogueAdapter={model=function(_,state)return{text='HELLO',waiting=false}end},
  DialoguePanel={draw=function(_,_,_,model)dialogue=model;return{}end}}
local Presenter=assert(loadfile(root..'/ui/intro_presenter.lua'))()(runtime)
local speech=setmetatable({step=1,steps={{id='oak_welcome'}},demoSpecies='NIDORINO',playerPic=img('player')},OakSpeech)
local text=setmetatable({game=nil},TextBox)
local game={stack={states={speech,text}},data={pokemon={}}};text.game=game
assert(Presenter.ownsText(game,text,{})==true,'intro TextBox is KRS-owned presentation')
assert(Presenter.draw(game,{})==true,'Oak intro presenter draws')
assert(dialogue and dialogue.speaker=='PROFESSOR OAK','intro uses KRS dialogue with Oak speaker')
assert(images['gfx:oak_lab'],'KRS Graphics owns Oak lab scene')
assert(images['gfx:oak'],'KRS Graphics owns Professor Oak intro artwork')
speech.step=2;speech.steps[2]={id='demo_mon'};Presenter.draw(game,{})
assert(images['gfx:NIDORINO'],'Nidorino routes through intro.pokemon Graphics context')
speech.step=3;speech.steps[3]={id='ask_rival_name'};Presenter.draw(game,{})
assert(images['gfx:blue'],'Blue/Gary routes through intro.trainer Graphics context')
speech.step=4;speech.steps[4]={id='ask_player_name'};Presenter.draw(game,{})
assert(images['gfx:red'],'Red routes through intro.trainer Graphics context')
speech.demoSpecies='PIKACHU';speech.step=5;speech.steps[5]={id='demo_mon'};Presenter.draw(game,{})
assert(images['gfx:PIKACHU'],'Yellow Pikachu uses the same intro.pokemon context and layout rule')
local src=assert(io.open(root..'/ui/intro_presenter.lua','rb')):read('*a')
assert(src:find("drawArt(m,mon,960,930,420,420",1,true),'intro Pokémon share the reference-derived stage anchor/scale envelope')
assert(src:find("drawArt(m,loadResolved(trainer,'linear')",1,true) and src:find(',960,970,560,680',1,true),'trainer artwork is lowered to the dialogue mask line')
assert(src:find("filter='nearest'",1,true),'intro Pokémon use nearest filtering')
assert(src:find('runtime.PokemonArt:materialize',1,true),'intro Pokémon uses the shared animated atlas materializer')
assert(src:find('shrinkScale',1,true) and src:find('speech.fadeLevel',1,true),'KRS mirrors engine shrink/fade without replacing timeline')
print('Oak intro KRS Graphics/placement tests passed')
