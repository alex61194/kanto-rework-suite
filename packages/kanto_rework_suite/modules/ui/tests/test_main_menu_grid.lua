local root=assert(arg[1],"root path required")
local function check(value,label)if not value then error(label or "check failed",2)end end
local enabled={"pokedex","pokemon","bag","pc","save","link","options","mods","close"}
local entries={};for _,id in ipairs(enabled)do entries[#entries+1]={id=id,enabled=true}end
local activated
local session={supported=true,native={},entries=entries,trainerModel=function()return{}end,activate=function(_,id)activated=id;return true end}
local Core={createStartMenuRuntime=function()return session end,journalContext=function()return{objective="Reach Cerulean City through Mt. Moon."}end}
local runtime={Core=Core,mainRects={
  pokedex={x=512,y=252,w=310,h=352},pokemon={x=846,y=252,w=310,h=352},bag={x=1180,y=252,w=312,h=351},pc={x=1516,y=252,w=312,h=351},
  save={x=512,y=648,w=648,h=120},link={x=1184,y=648,w=648,h=120},options={x=512,y=812,w=424,h=136},mods={x=960,y=812,w=424,h=136},close={x=1408,y=812,w=424,h=136},
},Layout={isWide=function()return true end,contains=function(x,y,r)return x>=r.x and x<=r.x+r.w and y>=r.y and y<=r.y+r.h end},Focus={
  new=function(owner)return{owner=owner}end,navigation=function()end,pointerMove=function()end,pointerPress=function(_,_,commit)if commit then commit(_)end end,syncDevice=function()end,
}}
local stack={pop=function()end,push=function()end};local game={stack=stack}
local Factory=assert(loadfile(root.."/screens/start_menu.lua"))().factory(runtime)
local screen=Factory.new(game)
check(screen.focusId=="pokedex","Pokédex is the initial Selected card")
screen:move("right");check(screen.focusId=="pokemon","right moves within Adventure")
screen:move("right");check(screen.focusId=="bag","second right reaches Bag")
screen:move("down");check(screen.focusId=="link","down chooses the geometrically closest Connectivity card")
screen:move("down");check(screen.focusId=="close","down chooses the geometrically closest System card")
screen:move("left");check(screen.focusId=="mods","left moves within System")
screen.focusId="pokedex";screen:pointerEvent({phase="moved",source="mouse"},600,700)
check(screen.focusId=="pokedex","mouse Hover preserves keyboard Selected card")
check(screen.hoverId=="save","mouse Hover is exposed independently")
screen:activate("save");check(activated=="save","Save activation remains wired")
print("Main Menu four-direction navigation tests passed")
