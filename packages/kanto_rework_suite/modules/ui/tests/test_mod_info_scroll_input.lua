local root=assert(arg[1],"root path required")
local session={native={}}
local runtime={
  Core={createModRuntime=function() return session end},
  Focus={
    new=function(owner) return {owner=owner} end,
    navigation=function() end,
  },
  Layout={
    isWide=function() return true end,
    contains=function(x,y,r) return r and x>=r.x and y>=r.y and x<=r.x+r.w and y<=r.y+r.h end,
  },
}
runtime.Scroll=assert(loadfile(root.."/ui/scroll_list.lua"))()
local factory=assert(loadfile(root.."/screens/mods_menu.lua"))().factory(runtime)
local screen=factory.new({})

screen.region="content"
screen:setInfoMetrics(1000,400,"mod:a")
assert(screen:infoMaxScroll()==600,"overflow height is derived from real content and viewport")
assert(screen:enterInfo()==true and screen.region=="info","keyboard/controller can focus long details")
screen:scrollInfoBy(48)
assert(screen.infoScrollY==48,"detail navigation scrolls by a predictable step")
screen:setInfoScroll(9999)
assert(screen.infoScrollY==600,"detail scroll is clamped at the document end")

runtime.modInfoViewport={x=100,y=100,w=400,h=500}
screen.infoScrollY=0
assert(screen:wheel(0,-1,200,200)==true and screen.infoScrollY==56,"wheel scroll is routed to the info viewport")
screen:setInfoMetrics(300,400,"mod:b")
assert(screen.infoScrollY==0 and screen:infoMaxScroll()==0 and screen.region=="content","new short content resets scrolling and returns focus to the list")

print("Responsive mod info input tests passed")
