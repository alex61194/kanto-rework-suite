local root=assert(arg[1])
local locs={};for i=1,24 do locs[i]={name='LOCATION '..i,x=2,y=math.min(15,i%16)} end
package.preload['src.ui.TownMap']=function()return{new=function()
  local o={locs=locs,byMap={},sel=1,blink=0,playerLoc=locs[1],mode='grid'}
  function o:moveList(d) self.sel=math.max(1,math.min(#self.locs,self.sel+d)) end
  function o:sgbPalettes()return{}end
  return o
end}end
package.preload['src.core.Sound']=function()return{play=function()end}end
package.preload['src.render.SpriteRenderer']=function()return{STAND={down=0}}end
love={graphics={newImage=function()error('no image in unit test')end}}
local Scroll=assert(loadfile(root..'/ui/scroll_list.lua'))()
local runtime={viewport={width=1920,height=1080},assetPath=function(p)return p end,
  Layout={isWide=function()return true end,contains=function()return false end},Scroll=Scroll,
  Focus={new=function()return{}end,navigation=function()end,syncDevice=function()end,pointerMove=function()end,pointerPress=function()end},
  Core={mapFlyStatus=function()return{available=false}end,mapDestinationFor=function()end,activateMapFly=function()return false end}}
local Screen=assert(loadfile(root..'/screens/map_screen.lua'))().factory(runtime)
local pressed={};local stack={};function stack:push(v)self[#self+1]=v end;function stack:top()return self[#self]end;function stack:pop()return table.remove(self)end
local game={data={field={townMap={cursorOrder={}}}},stack=stack,input={wasPressed=function(_,k)local v=pressed[k];pressed[k]=nil;return v end}}
local s=Screen.new(game);stack:push(s)
local function visible(index)
  local v=s:listMetrics();local r=s:listRowRect(index)
  return r.y>=v.y-0.001 and r.y+r.h<=v.y+v.h+0.001
end
assert(visible(1),'first row visible initially')
for i=2,24 do pressed.down=true;s:update();assert(s.inner.sel==i,'down selects '..i);assert(visible(i),'selected row '..i..' must auto-scroll fully into view') end
for i=23,1,-1 do pressed.up=true;s:update();assert(s.inner.sel==i,'up selects '..i);assert(visible(i),'selected row '..i..' must remain fully visible') end
local panX,panY=s.panX,s.panY
pressed.left=true;s:update();assert(s.panX==panX and s.panY==panY,'left/right must not free-pan for keyboard/controller')
print('Map list auto-scroll and input ownership tests passed')
