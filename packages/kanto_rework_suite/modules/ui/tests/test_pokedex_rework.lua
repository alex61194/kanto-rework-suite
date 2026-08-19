local root=assert(arg[1],"root path required")
local function loadModule(path)local chunk,err=loadfile(root.."/"..path);assert(chunk,err);return chunk() end
local function check(value,label)if not value then error(label or "check failed",2) end end
local function eq(actual,expected,label)if actual~=expected then error((label or "value")..": expected "..tostring(expected)..", got "..tostring(actual),2) end end

local sounds={}
package.preload["src.ui.PokedexMenu"]=function()return{new=function()return{update=function()end}end}end
package.preload["src.ui.TownMap"]=function()return{new=function()return{nests={{name="VIRIDIAN FOREST"},{name="POWER PLANT"}}}end}end
package.preload["src.core.Sound"]=function()return{
  play=function(_,name)sounds[#sounds+1]=name end,
  playCry=function(_,species)sounds[#sounds+1]="cry:"..species end,
}end

local actionPressed={}
local runtime={lastPokedexIndex=25,pokedexFooterRects={},pokedexRowRects={},pokedexTabRects={},pokedexAreaRects={}}
runtime.Layout={isWide=function()return true end,contains=function(x,y,r)return x>=r.x and x<=r.x+r.w and y>=r.y and y<=r.y+r.h end}
runtime.Focus={new=function()return{}end,navigation=function()end,pointerMove=function()end}
runtime.Core={inputActions={wasPressed=function(id)return actionPressed[id]==true end}}

local pressed={}
local input={wasPressed=function(_,id)if pressed[id]then pressed[id]=nil;return true end return false end}
local stack={popped=0};function stack:pop()self.popped=self.popped+1 end
local pokemon={PIKACHU={id="PIKACHU",name="PIKACHU",dex=25},RAICHU={id="RAICHU",name="RAICHU",dex=26},ARBOK={id="ARBOK",name="ARBOK",dex=24}}
local game={input=input,stack=stack,data={pokemon=pokemon,constants={dexSize=151},text={_DexRatingText_Own0To9="Oak says keep going."}},save={pokedex={seen={PIKACHU=true,RAICHU=true},owned={PIKACHU=true}}}}
local Screen=loadModule("screens/pokedex_menu.lua").factory(runtime)
local screen=Screen.new(game)
eq(screen.index,25,"restored dex index");eq(screen.status,"caught","owned status");eq(screen.seen,2,"seen count");eq(screen.caught,1,"caught count")

pressed.a=true;screen:update();eq(screen.view,"index","A/Enter no longer duplicates view navigation")
screen:keypressed("tab",nil,false);eq(screen.view,"data","Tab reaches DATA")
screen:keypressed("tab",nil,false);eq(screen.view,"area","Tab reaches AREA")
eq(#screen.area.nests,2,"TownMap habitat model retained")
pressed.down=true;screen:update();eq(screen.areaIndex,2,"area focus advances")
local oldPanX=screen.areaPanX
screen:pointerEvent({phase="pressed",source="mouse",button=1},600,500)
screen:pointerEvent({phase="moved",source="mouse",button=1},500,500)
screen:pointerEvent({phase="released",source="mouse",button=1},500,500)
check(screen.areaPanX~=oldPanX,"AREA map supports pointer dragging")

actionPressed.POKEDEX_CRY=true;screen:update();actionPressed.POKEDEX_CRY=nil
eq(sounds[#sounds],"cry:PIKACHU","custom keyboard/controller cry action")
actionPressed.POKEDEX_OAK_EVAL=true;screen:update();actionPressed.POKEDEX_OAK_EVAL=nil
check(screen.oakOpen,"Oak evaluation opens");eq(screen.oakText,"Oak says keep going.","official tier text")
pressed.b=true;screen:update();check(not screen.oakOpen,"native back closes Oak modal")

screen:setView("index");screen:setIndex(24);eq(screen.status,"unseen","unrecorded species status")
check(not screen:openData(),"unseen DATA remains locked");eq(screen.view,"index","unseen view remains INDEX")

runtime.pokedexFooterRects.oak={x=10,y=10,w=100,h=40}
screen:pointerEvent({phase="pressed",source="mouse",button=1},20,20)
check(screen.oakOpen,"mouse footer opens Oak evaluation")
screen:pointerEvent({phase="pressed",source="mouse",button=2},20,20)
check(not screen.oakOpen,"right click closes Oak evaluation")

screen:back();eq(stack.popped,1,"back from INDEX closes Pokédex")
print("Pokédex INDEX/DATA/AREA, cry, gating and Oak evaluation tests passed")
