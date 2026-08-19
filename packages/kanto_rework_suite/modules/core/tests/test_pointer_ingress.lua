local root=assert(arg[1],"root path required")
local oldLove=love
love={mouse={getPosition=function() return 0,0 end}}

local runtime={
  viewport={width=1920,height=1080,gameX=0,gameY=0,gameWidth=1920,gameHeight=1080},
  overlayRegions={},profile={},pointerSessions={},
  inputMode={pointerEvent=function() return true end},
}
local game={stack={top=function() return {kind="main"} end}}
runtime.game=game
local foundation=assert(loadfile(root.."/core/foundation.lua"))()({runtime=runtime,release="test"})
local phases={}
foundation.registerInputLayer({
  id="test.menu",priority=100,
  active=function() return true end,
  pointer=function(_,event) phases[#phases+1]=event.phase;return true end,
})
local mod={
  path=root,
  input={tap=function() end},
  hooks={wrap=function() return function() return true end end},
}
local Layout={
  safeArea=function(viewport) return {x=0,y=0,w=viewport.width,h=viewport.height} end,
  windowToNormalized=function(x,y) return x,y end,
}
local presenter={topState=function(current) return current.stack:top() end}
local Pointer=assert(loadfile(root.."/core/pointer.lua"))()({
  mod=mod,runtime=runtime,presenter=presenter,foundation=foundation,
  Layout=Layout,persist=function() return true end,
  loadModule=function(relative) return assert(loadfile(root.."/"..relative))() end,
})

assert(Pointer.handle(game,{source="mouse",id="mouse",phase="moved",x=500,y=300})==true,
  "external physical event enters the complete Core pointer pipeline")
assert(Pointer.handle(game,{source="mouse",id="mouse",phase="pressed",x=500,y=300,button=1})==true,
  "pointer press is captured by the active KRS layer")
assert(Pointer.handle(game,{source="mouse",id="mouse",phase="released",x=500,y=300,button=1})==true,
  "pointer release returns to the captured KRS layer")
assert(table.concat(phases,",")=="moved,pressed,released","canonical event order is preserved")

love=oldLove
print("Core physical-pointer ingress tests passed")
