local root=assert(arg[1],"UI root required")
local function loadAt(path)local chunk,err=loadfile(root.."/"..path);assert(chunk,err);return chunk()end
local events={}
local currentCompare,currentValue=nil,nil
love={graphics={}}
local g=love.graphics
g.setColor=function()end
g.rectangle=function(mode,x,y,w,h,rx,ry)
  events[#events+1]={kind="mask",mode=mode,x=x,y=y,w=w,h=h,rx=rx,ry=ry}
end
g.stencil=function(fn,action,value,keep)
  events[#events+1]={kind="stencil",action=action,value=value,keep=keep}
  fn()
end
g.getStencilTest=function()return currentCompare,currentValue end
g.setStencilTest=function(compare,value)
  currentCompare,currentValue=compare,value
  events[#events+1]={kind="test",compare=compare,value=value}
end

local Draw=loadAt("ui/menu_draw.lua")
local called=false
local clipped=Draw.withRoundedClip({ox=10,oy=20,scale=2},5,7,100,40,12,function()
  called=true
  events[#events+1]={kind="content",compare=currentCompare,value=currentValue}
end)
assert(clipped==true,"rounded clip should use the stencil path")
assert(called,"rounded clip should draw its content")
assert(events[1].kind=="stencil" and events[1].action=="replace" and events[1].value==1,"stencil contract")
assert(events[2].kind=="mask","rounded mask emitted")
assert(events[2].x==20 and events[2].y==34 and events[2].w==200 and events[2].h==80,"mask transform")
assert(events[2].rx==24 and events[2].ry==24,"mask keeps scaled 12 px radius")
assert(events[3].kind=="test" and events[3].compare=="greater" and events[3].value==0,"clip enabled")
assert(events[4].kind=="content" and events[4].compare=="greater","content is drawn while clipped")
assert(events[5].kind=="test" and events[5].compare==nil,"clip restored")
print("Main Menu rounded clipping tests passed")
