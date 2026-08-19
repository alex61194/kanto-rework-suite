local root=assert(arg[1])
package.preload['src.ui.TownMap']=function()return{new=function(game)
  local locs={{name='PALLET TOWN',x=2,y=11},{name='ROUTE 1',x=2,y=10},{name='VIRIDIAN FOREST',x=2,y=4},{name='SAFARI ZONE',x=8,y=12},{name='POWER PLANT',x=15,y=4}}
  local byMap={};for i,l in ipairs(locs) do byMap['M'..i]=l end
  return{locs=locs,byMap=byMap,sel=1,blink=0,moveList=function(self,d)self.sel=((self.sel-1+d)%#self.locs)+1 end,sgbPalettes=function()end}
end}end
package.preload['src.core.Sound']=function()return{play=function()end}end
package.preload['src.render.SpriteRenderer']=function()return{STAND={down=0}}end
love={graphics={newImage=function()return{getDimensions=function()return 1920,1080 end,setFilter=function()end}end}}
local chunk=assert(loadfile(root..'/screens/map_screen.lua'));local M=chunk()
local runtime={viewport={width=1920,height=1080},assetPath=function(p)return root..'/'..p end,
 Layout={isWide=function()return true end,contains=function(x,y,r)return x>=r.x and y>=r.y and x<=r.x+r.w and y<=r.y+r.h end},
 Focus={new=function()return{}end,navigation=function()end,syncDevice=function()end,pointerMove=function()end,pointerPress=function()end},
 Scroll={total=function(n,p,row)return n*p end,clamp=function(v,total,h)return math.max(0,math.min(v,math.max(0,total-h)))end,ensure=function(v)return v end,model=function()return nil end},
 Core={mapFlyStatus=function()return{available=false}end,mapDestinationFor=function()end,activateMapFly=function()return false end}}
local Factory=M.factory(runtime);local stack={};function stack:push(v)self[#self+1]=v end;function stack:pop()return table.remove(self)end;function stack:top()return self[#self]end
local pressed={};local down={};local game={data={field={townMap={cursorOrder={}}}},stack=stack,input={wasPressed=function(_,k)local v=pressed[k];pressed[k]=nil;return v end,isDown=function(_,k)return down[k]end}}
local s=Factory.new(game);stack:push(s)
local b=s:panBounds();assert(math.abs(b.contentW-2150.4)<.01 and math.abs(b.contentH-1209.6)<.01,'content bounds use image x zoom')
assert(math.abs(b.minX-(1520-2150.4))<.01 and b.maxX==0,'horizontal bounds expose both edges in safe viewport')
assert(math.abs(b.minY-(1080-1209.6))<.01 and b.maxY==0,'vertical bounds expose both edges')
s.panX=999;s.panY=999;s:clampPan();assert(s.panX==b.maxX and s.panY==b.maxY,'clamp top-left')
s.panX=-9999;s.panY=-9999;s:clampPan();assert(math.abs(s.panX-b.minX)<.01 and math.abs(s.panY-b.minY)<.01,'clamp bottom-right')
local forest=s:anchor({name='VIRIDIAN FOREST',x=2,y=4});assert(forest.x==650 and forest.y==500,'Forest uses illustration calibration')
local safari=s:anchor({name='SAFARI ZONE',x=8,y=12});assert(safari.x==985 and safari.y==810,'Safari uses calibrated authored position')
local route=s:anchor({name='ROUTE 1',x=2,y=10});assert(route.x==535 and route.y==742,'route uses explicit source-pixel mapping')
local before=s.panX;assert(s:keypressed('a')==false and s.panX==before,'WASD keyboard pan must be disabled')
local beforeSel=s.inner.sel;down.select=true;pressed.right=true;s:update();assert(s.inner.sel==beforeSel and s.panX==before,'Select+D-pad must not pan the map')
down.select=false;pressed.down=true;s:update();assert(s.inner.sel~=beforeSel,'controller/keyboard Down navigates the destination list')
print('round7 map pan/calibration tests passed')

local source=assert(io.open(root..'/screens/map_screen.lua','rb')):read('*a')
local canonicalIndoor={'0:7','4:5','7:13','9:13'}
for _,k in ipairs(canonicalIndoor) do assert(source:find('["'..k..'"]',1,true),'calibration covers official alternate TownMap coordinate '..k) end
assert(source:find('["DIGLETT\'S CAVE"]',1,true),'Diglett cave has explicit illustration calibration')
