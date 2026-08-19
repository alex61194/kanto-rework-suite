local root=assert(arg[1],"root path required")
local function check(value,label)if not value then error(label or "check failed",2)end end

package.preload["src.core.Sound"]=function()return{play=function()end}end

local runtime={viewport={width=1920,height=1080},partyNav={},Focus={
  pointerMove=function()end,pointerPress=function()end,navigation=function()end,syncDevice=function()end,
}}
local Layout={
  toLogical=function(_,x,y)return x,y,true end,
  contains=function(region,x,y)return x>=region.x and y>=region.y and x<=region.x+region.w and y<=region.y+region.h end,
  partyNeighbor=function(index)return index end,
}
local foundation={
  setFocus=function()end,clearFocus=function()end,beginDrag=function()end,endDrag=function()end,
}
local Adapter={
  party=function()return{}end,pokemon=function()return{}end,learnedMoves=function()return{},{}end,
}
local factory=assert(loadfile(root.."/ui/party_controller.lua"))()
local controller=factory({Adapter=Adapter,Layout=Layout,C={DRAG_THRESHOLD=8},runtime=runtime,foundation=foundation})

local state={
  mode="MovesActive",movePhase="active",activeMoveFocus=1,learnedFocus=nil,
  regions={
    {kind="active_move",id="move.1",index=1,x=10,y=10,w=100,h=40},
    {kind="learned_move",id="learned.2",index=2,x=10,y=70,w=100,h=40},
  },
  learned={{id="OTHER"},{id="WRAP",disabled=true}},learnedFirst=1,
}
local game={stack={top=function()return state end}}
runtime.state=state

check(controller:pointer(game,{phase="moved",source="mouse",x=20,y=80}),"learned row hover handled")
check(state.learnedFocus==2,"learned detail focus follows pointer even when replacement is disabled")
check(runtime.hoveredRegion=="learned.2","learned hover region is exposed")

check(controller:pointer(game,{phase="moved",source="mouse",x=20,y=20}),"active row hover handled")
check(state.activeMoveFocus==1 and state.learnedFocus==nil,"active hover clears stale learned detail")

check(controller:pointer(game,{phase="pressed",source="mouse",button=1,x=20,y=80}),"learned row press handled")
check(state.learnedFocus==2,"learned detail focus follows pointer press")

print("Pokémon menu learned-move hover tests passed")
