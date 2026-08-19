local root=assert(arg[1],"root path required")
local function loadModule(path)local chunk,err=loadfile(root.."/"..path);assert(chunk,err);return chunk() end
local function check(v,msg)if not v then error(msg or 'check failed',2)end end
local function eq(a,b,msg)if a~=b then error((msg or 'value')..': expected '..tostring(b)..', got '..tostring(a),2)end end

local locs={
  {name='PALLET TOWN',x=2,y=11},
  {name='ROUTE 1',x=2,y=10},
  {name='VIRIDIAN CITY',x=2,y=8},
  {name="DIGLETT's CAVE",x=3,y=4},
  {name='MT. MOON',x=6,y=2},
  {name='ROCK TUNNEL',x=13,y=4},
  {name='POKéMON TOWER',x=15,y=6},
  {name='SEAFOAM ISLANDS',x=6,y=15},
  {name='VICTORY ROAD',x=1,y=4},
  {name='INDIGO PLATEAU',x=0,y=2},
}
local ids={'PALLET_TOWN','ROUTE_1','VIRIDIAN_CITY','DIGLETTS_CAVE','MT_MOON_1F','ROCK_TUNNEL_1F','POKEMON_TOWER_2F','SEAFOAM_ISLANDS_B1F','VICTORY_ROAD_3F','INDIGO_PLATEAU'}
local byMap={};for i,id in ipairs(ids)do byMap[id]=locs[i] end
local TownMap={}
function TownMap.new(game,opts)
  check(not opts.fly,'KRS map must construct the complete TownMap viewer, never Fly-filtered state')
  local o={locs={},byMap=byMap,mode='grid',sel=3,blink=0,playerLoc=locs[3]}
  for i,v in ipairs(locs)do o.locs[i]=v end
  function o:moveList(step)self.sel=(self.sel-1+step)%#self.locs+1 end
  function o:update()end;function o:draw()end;function o:sgbPalettes()return{}end
  return o
end
package.preload['src.ui.TownMap']=function()return TownMap end
package.preload['src.core.Sound']=function()return{play=function()end}end
package.preload['src.render.SpriteRenderer']=function()return{STAND={down=0}}end

love={graphics={newImage=function()error('map image intentionally absent in unit test')end}}
local Focus={
  new=function()return{}end,navigation=function()end,syncDevice=function()end,pointerMove=function()end,pointerPress=function()end,
}
local Scroll={
  total=function(n,pitch,rowH)return math.max(0,n*pitch-(pitch-rowH))end,
  clamp=function(v,total,h)return math.max(0,math.min(v,math.max(0,total-h)))end,
  ensure=function(scroll,top,bottom,total,h)if top<scroll then return top elseif bottom>scroll+h then return bottom-h end return scroll end,
  model=function()return nil end,dragValue=function()return 0 end,
}
local runtime={
  viewport={width=1920,height=1080},Focus=Focus,Scroll=Scroll,
  Layout={isWide=function()return true end,contains=function()return false end},
  assetPath=function(p)return p end,
  Core={
    mapDestinationFor=function(_,state,index)return (index==1 or index==3 or index==10) and ids[index] or nil end,
    mapFlyStatus=function()return{available=true}end,
    activateMapFly=function(_,_,index)return true,index and nil end,
  },
}
local Screen=loadModule('screens/map_screen.lua').factory(runtime)
local game={data={field={townMap={cursorOrder=ids}}},stack={top=function()return nil end,pop=function()end},input={wasPressed=function()return false end}}
local s=Screen.new(game)
eq(#s.inner.locs,#locs,'full viewer preserves cities, routes and dungeons regardless of Fly')
eq(s.inner.locs[2].name,'ROUTE 1','cursorOrder keeps real Kanto route sequence')
eq(s.inner.locs[4].name,"DIGLETT's CAVE",'dungeon remains a navigation row')
check(type(s.activeItemId)=='function' and s:activeItemId()=='map:3','presenter-facing activeItemId contract exists')
check(s:rowFlyAvailable(3),'visited Fly town is independently marked usable')
check(not s:rowFlyAvailable(2),'route remains visible without pretending it is a Fly destination')
check(#s:allMapLocations()==#locs,'map labels use the same complete canonical dataset')
check(s:anchor(locs[2])~=nil and s:anchor(locs[5])~=nil,'non-city official TownMap coordinates project onto the stylised KRS map')
check(s:isMajorMapLabel(locs[3]) and not s:isMajorMapLabel(locs[2]),'major city labels stay permanent while route/dungeon labels reveal on selection or hover')
print('Map/Fly full dataset and Fly-capability separation tests passed')
