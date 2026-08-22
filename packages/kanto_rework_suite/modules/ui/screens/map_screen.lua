local Module={}
function Module.factory(runtime)
  local TownMap=require("src.ui.TownMap");local Sound=require("src.core.Sound")
  local SpriteRenderer=require("src.render.SpriteRenderer")
  -- Explicit source-pixel calibration for the authored 1920x1080 Kanto
  -- illustration.  TownMap coordinates remain the authoritative semantic
  -- location data, but the illustration is not the ROM's regular 20x18 grid;
  -- every supported canonical grid point below is therefore independently
  -- calibrated onto the actual road/building/cave artwork.  Runtime rendering
  -- never applies an affine/grid approximation.
  local MAJOR_ANCHORS={
    ["INDIGO PLATEAU"]={x=410,y=145,labelX=190,labelY=126}, ["MESETA AÑIL"]={x=410,y=145,labelX=190,labelY=126}, ["MESETA ANIL"]={x=410,y=145,labelX=190,labelY=126},
    ["PEWTER CITY"]={x=630,y=295,labelX=410,labelY=278}, ["CIUDAD PLATEADA"]={x=630,y=295,labelX=410,labelY=278},
    ["CERULEAN CITY"]={x=1275,y=185,labelX=1038,labelY=136}, ["CIUDAD CELESTE"]={x=1275,y=185,labelX=1038,labelY=136},
    ["CELADON CITY"]={x=955,y=420,labelX=730,labelY=392}, ["CIUDAD AZULONA"]={x=955,y=420,labelX=730,labelY=392},
    ["SAFFRON CITY"]={x=1275,y=420,labelX=1050,labelY=445}, ["CIUDAD AZAFRAN"]={x=1275,y=420,labelX=1050,labelY=445}, ["CIUDAD AZAFRÁN"]={x=1275,y=420,labelX=1050,labelY=445},
    ["LAVENDER TOWN"]={x=1535,y=570,labelX=1290,labelY=548}, ["PUEBLO LAVANDA"]={x=1535,y=570,labelX=1290,labelY=548},
    ["VERMILION CITY"]={x=1125,y=680,labelX=875,labelY=682}, ["CIUDAD CARMIN"]={x=1125,y=680,labelX=875,labelY=682}, ["CIUDAD CARMÍN"]={x=1125,y=680,labelX=875,labelY=682},
    ["FUCHSIA CITY"]={x=985,y=830,labelX=742,labelY=840}, ["CIUDAD FUCSIA"]={x=985,y=830,labelX=742,labelY=840},
    ["VIRIDIAN CITY"]={x=565,y=665,labelX=330,labelY=642}, ["CIUDAD VERDE"]={x=565,y=665,labelX=330,labelY=642},
    ["PALLET TOWN"]={x=455,y=805,labelX=225,labelY=790}, ["PUEBLO PALETA"]={x=455,y=805,labelX=225,labelY=790},
    ["CINNABAR ISLAND"]={x=350,y=955,labelX=140,labelY=930}, ["ISLA CANELA"]={x=350,y=955,labelX=140,labelY=930},
  }
  local GRID_CALIBRATION={
    ["0:2"]={410,145}, ["0:4"]={382,276}, ["0:6"]={365,420}, ["0:7"]={375,535}, ["0:8"]={385,650},
    ["2:3"]={630,295}, ["2:4"]={615,465}, ["2:6"]={602,545}, ["2:8"]={565,665},
    ["2:10"]={535,742}, ["2:11"]={455,805}, ["2:13"]={435,882}, ["2:15"]={350,955},
    ["4:3"]={748,294}, ["4:5"]={720,420}, ["4:8"]={722,604}, ["4:15"]={555,987},
    ["5:2"]={815,212}, ["5:5"]={790,420}, ["5:15"]={750,994},
    ["6:2"]={900,184}, ["6:13"]={820,830}, ["6:15"]={920,930}, ["7:13"]={900,830},
    ["7:5"]={955,420},
    ["8:2"]={1045,184}, ["8:5"]={1115,420}, ["8:12"]={985,810}, ["8:13"]={985,830},
    ["9:1"]={1160,138}, ["9:5"]={1115,420}, ["9:10"]={1125,700}, ["9:13"]={1090,830},
    ["10:1"]={1275,116}, ["10:2"]={1275,185}, ["10:3"]={1275,272}, ["10:4"]={1275,342},
    ["10:5"]={1275,420}, ["10:6"]={1275,500}, ["10:8"]={1215,608}, ["10:9"]={1125,680},
    ["10:13"]={1200,830},
    ["11:0"]={1430,150}, ["11:5"]={1390,420}, ["11:12"]={1315,760},
    ["12:0"]={1590,165}, ["12:9"]={1315,680},
    ["13:2"]={1435,185}, ["13:5"]={1485,420}, ["13:9"]={1450,680}, ["13:11"]={1450,760},
    ["14:3"]={1582,205}, ["14:4"]={1538,330}, ["14:5"]={1535,570}, ["14:7"]={1535,625},
    ["14:9"]={1535,700}, ["14:10"]={1535,748}, ["15:4"]={1570,330},
  }
  -- Semantic POIs sharing a TownMap grid coordinate are snapped to the actual
  -- authored landmark rather than to a generic route intersection.
  local POI_ANCHORS={
    ["VIRIDIAN FOREST"]={x=650,y=500}, ["BOSQUE VERDE"]={x=650,y=500},
    -- The current illustrated map has no drawn cave-mouth at the Gen 1 Town
    -- Map position for Diglett's Cave (3,4). Keep an explicit calibrated point
    -- east/south-east of Pewter instead of inventing an affine grid position.
    ["DIGLETT'S CAVE"]={x=700,y=390}, ["DIGLETTS CAVE"]={x=700,y=390}, ["CUEVA DIGLETT"]={x=700,y=390},
    ["MT.MOON"]={x=900,y=184}, ["MT. MOON"]={x=900,y=184}, ["MONTE MOON"]={x=900,y=184},
    ["ROCK TUNNEL"]={x=1582,y=205}, ["TUNEL ROCA"]={x=1582,y=205}, ["TÚNEL ROCA"]={x=1582,y=205},
    ["POWER PLANT"]={x=1570,y=330}, ["CENTRAL DE ENERGIA"]={x=1570,y=330}, ["CENTRAL DE ENERGÍA"]={x=1570,y=330},
    ["POKéMON TOWER"]={x=1535,y=535}, ["POKEMON TOWER"]={x=1535,y=535}, ["TORRE POKEMON"]={x=1535,y=535}, ["TORRE POKÉMON"]={x=1535,y=535},
    ["SEAFOAM ISLANDS"]={x=750,y=994}, ["ISLAS ESPUMA"]={x=750,y=994},
    ["VICTORY ROAD"]={x=382,y=276}, ["CALLE VICTORIA"]={x=382,y=276},
    ["SAFARI ZONE"]={x=985,y=810}, ["ZONA SAFARI"]={x=985,y=810},
    ["POKéMON MANSION"]={x=350,y=955}, ["POKEMON MANSION"]={x=350,y=955}, ["MANSION POKEMON"]={x=350,y=955}, ["MANSIÓN POKÉMON"]={x=350,y=955},
    ["ROCKET HQ"]={x=955,y=420}, ["ROCKET HIDEOUT"]={x=955,y=420}, ["GUARIDA ROCKET"]={x=955,y=420},
    ["SILPH CO."]={x=1275,y=420}, ["SILPH CO"]={x=1275,y=420}, ["SILPH S.A."]={x=1275,y=420},
    ["S.S. ANNE"]={x=1125,y=700}, ["SS ANNE"]={x=1125,y=700}, ["S.S. ANNA"]={x=1125,y=700},
    ["CERULEAN CAVE"]={x=1160,y=138}, ["CUEVA CELESTE"]={x=1160,y=138},
  }
  local function key(name)
    return tostring(name or ""):upper():gsub("_"," "):gsub("%s+"," ")
  end
  local function locKey(loc)
    if not loc then return "" end
    return ("%s:%s:%s"):format(key(loc.name),tostring(loc.x or ""),tostring(loc.y or ""))
  end
  local function labelPlacement(x,y)
    local lx,ly=x+18,y-24
    if lx>1320 then lx=x-206 end
    if lx<24 then lx=24 end
    if ly<96 then ly=96 end
    if ly>998 then ly=998 end
    return lx,ly
  end
  local function calibratedAnchor(loc)
    if not loc then return nil end
    local semantic=POI_ANCHORS[key(loc.name)] or MAJOR_ANCHORS[key(loc.name)]
    if semantic then
      if semantic.labelX then return semantic end
      local lx,ly=labelPlacement(semantic.x,semantic.y)
      return {x=semantic.x,y=semantic.y,labelX=lx,labelY=ly,calibrated=true}
    end
    local gx,gy=tonumber(loc.x),tonumber(loc.y)
    local point=gx and gy and GRID_CALIBRATION[("%d:%d"):format(gx,gy)] or nil
    if not point then return nil end
    local lx,ly=labelPlacement(point[1],point[2])
    return {x=point[1],y=point[2],labelX=lx,labelY=ly,calibrated=true}
  end
  -- The official extracted Town Map cursor order is the canonical Kanto
  -- navigation sequence: cities, routes, dungeons and major locations. Do
  -- not maintain a second KRS story list that can drift from Gen1Recomp.
  local function orderDestinations(inner,game)
    if not(inner and type(inner.locs)=='table' and #inner.locs>0) then return end
    local selected=inner.locs[inner.sel or 1];local selectedKey=locKey(selected)
    local ordered,seen={},{}
    local tm=game and game.data and game.data.field and game.data.field.townMap or {}
    for _,mapId in ipairs(type(tm.cursorOrder)=='table' and tm.cursorOrder or {}) do
      local loc=inner.byMap and inner.byMap[mapId]
      local k=locKey(loc)
      if loc and k~='' and not seen[k] then seen[k]=true;ordered[#ordered+1]=loc end
    end
    for _,loc in ipairs(inner.locs) do
      local k=locKey(loc);if k~='' and not seen[k] then seen[k]=true;ordered[#ordered+1]=loc end
    end
    inner.locs=ordered
    inner.sel=1
    for i,loc in ipairs(ordered) do if locKey(loc)==selectedKey then inner.sel=i break end end
  end
  local function buildMapLocations(inner)
    local out={};for _,loc in ipairs(inner and inner.locs or {}) do out[#out+1]=loc end;return out
  end
  local function loadMapImage()
    if runtime.kantoMapImage~=nil then return runtime.kantoMapImage or nil end
    local path=runtime.assetPath("assets/map/kanto_fullscreen_16x9.png")
    local ok,image=pcall(love.graphics.newImage,path)
    if not ok or not image then runtime.kantoMapImage=false;return nil end
    if image.setFilter then image:setFilter("linear","linear") end
    runtime.kantoMapImage=image;return image
  end
  local Screen={};Screen.__index=Screen;Screen.isOpaque=true
  local LIST_VIEW={x=1548,y=122,w=320,h=824};local LIST_PITCH,LIST_ROW_H=76,64
  function Screen.new(game)
    local self=setmetatable({game=game,kind="krs_map",hoverIndex=nil,mapImage=loadMapImage(),nav=runtime.Focus.new("kanto_rework_ui.map"),mapScale=1.12,panX=0,panY=0,mapDrag=nil,scrollY=0,scrollDrag=nil},Screen)
    -- Always construct the complete TownMap viewer. Fly eligibility is
    -- resolved per row through Core; it never replaces the map/list dataset.
    self.inner=TownMap.new(game,{})
    orderDestinations(self.inner,game)
    self.mapLocations=buildMapLocations(self.inner)
    self:centerOn(self.inner.playerLoc or self.inner.locs[self.inner.sel])
    runtime.Focus.navigation(self.nav,self:activeId());return self
  end
  function Screen:isWide() return runtime.Layout.isWide(runtime.viewport) end
  function Screen:activeId() return "map:"..tostring(self.inner.sel or 1) end
  function Screen:activeItemId() return self:activeId() end
  function Screen:sgbPalettes(game) return self.inner:sgbPalettes(game) end
  function Screen:listMetrics() return LIST_VIEW,runtime.Scroll.total(#self.inner.locs,LIST_PITCH,LIST_ROW_H),LIST_PITCH,LIST_ROW_H end
  function Screen:setScroll(value) local v,total=self:listMetrics();self.scrollY=runtime.Scroll.clamp(value,total,v.h);return self.scrollY end
  function Screen:ensureListVisible(index)
    local v,total,pitch,rowH=self:listMetrics();local top=(math.max(1,index or self.inner.sel or 1)-1)*pitch
    self.scrollY=runtime.Scroll.ensure(self.scrollY,top,top+rowH,total,v.h)
  end
  function Screen:scrollbar() local v,total=self:listMetrics();return runtime.Scroll.model(self.scrollY,total,v,1884) end
  function Screen:listRowRect(index) local v,_,pitch,rowH=self:listMetrics();return {x=v.x,y=v.y+(index-1)*pitch-self.scrollY,w=v.w,h=rowH} end
  function Screen:setSelection(index)
    if not self.inner.locs[index] then return false end
    local changed=self.inner.sel~=index;self.inner.sel=index
    self:ensureListVisible(index)
    if changed then pcall(Sound.play,self.game.data,"Tink");self:ensureVisibleOnMap(self.inner.locs[index]) end
    runtime.Focus.navigation(self.nav,self:activeId());return true
  end
  function Screen:flyMapId(index)
    if type(runtime.Core.mapDestinationFor)~='function' then return nil end
    local ok,value=pcall(runtime.Core.mapDestinationFor,self.game,self.inner,index)
    return ok and value or nil
  end
  function Screen:rowFlyAvailable(index)
    return self:flyMapId(index)~=nil and self:flyStatus().available==true
  end
  function Screen:activate(index)
    if not self:setSelection(index) then return false end
    local consumed,reason=runtime.Core.activateMapFly(self.game,self.inner,index,self)
    if consumed and reason==nil then pcall(Sound.play,self.game.data,"Press_AB") end
    return consumed==true,reason
  end
  function Screen:flyStatus()
    local value=runtime.Core.mapFlyStatus(self.game)
    return type(value)=="table" and value or {available=false,reason="engine_unavailable"}
  end
  function Screen:moveSelection(step)
    local before=self.inner.sel
    if type(self.inner.moveList)=='function' then self.inner:moveList(step)
    else self.inner.sel=math.max(1,math.min(#self.inner.locs,(tonumber(self.inner.sel) or 1)+(tonumber(step) or 0))) end
    self:ensureListVisible(self.inner.sel)
    if before~=self.inner.sel then
      self:ensureVisibleOnMap(self.inner.locs[self.inner.sel])
      runtime.Focus.navigation(self.nav,self:activeId())
      return true
    end
    runtime.Focus.syncDevice(self.nav,self:activeId());return false
  end
  function Screen:update(dt)
    if not self:isWide() then self.inner:update(dt);return end
    self.inner.blink=((self.inner.blink or 0)+1)%32
    local input=self.game.input
    if input:wasPressed("b") then
      pcall(Sound.play,self.game.data,"Press_AB");self.game.stack:pop();return
    end
    -- Latest KRS input rule: keyboard/controller own only the destination list.
    -- Free map pan is pointer-only, so list focus and viewport centering can
    -- never diverge because of a hidden Select+D-pad/WASD camera state.
    if input:wasPressed("a") then self:activate(self.inner.sel)
    elseif input:wasPressed("up") then self:moveSelection(-1)
    elseif input:wasPressed("down") then self:moveSelection(1)
    else runtime.Focus.syncDevice(self.nav,self:activeId()) end
  end
  function Screen:visibleWindow(rows)
    local v,_,pitch=self:listMetrics();local n=#self.inner.locs;local first=math.max(1,math.floor(self.scrollY/pitch)+1)
    local last=math.min(n,math.floor((self.scrollY+v.h-1)/pitch)+1);return first,last
  end
  function Screen:allMapLocations() return self.mapLocations or {} end
  function Screen:destinationIndex(loc)
    for i,destination in ipairs(self.inner.locs or {}) do if destination==loc then return i end end
    return nil
  end
  function Screen:anchor(loc) return calibratedAnchor(loc) end
  -- The authored map keeps major city/town labels permanently visible.
  -- Routes and dungeon POIs remain present as markers and gain their full
  -- label when selected/hovered; the right-hand list always names every
  -- canonical TownMap location. This preserves cartographic information
  -- without stacking dozens of route/dungeon boxes over the artwork.
  function Screen:isMajorMapLabel(loc)
    return MAJOR_ANCHORS[key(loc and loc.name)]~=nil
  end
  -- The map remains full-bleed under the destination sheet.  Interaction and
  -- automatic centering use the uncovered area so a selected POI never ends
  -- up hidden beneath the sheet.
  function Screen:mapViewport() return {x=0,y=0,w=1920,h=1080} end
  function Screen:mapSafeViewport() return {x=0,y=0,w=1520,h=1080} end
  function Screen:sourceDimensions()
    if self.mapImage and self.mapImage.getDimensions then
      local ok,w,h=pcall(self.mapImage.getDimensions,self.mapImage)
      if ok and tonumber(w) and tonumber(h) and w>0 and h>0 then return w,h end
    end
    return 1920,1080
  end
  function Screen:imageBaseScale()
    local v=self:mapViewport();local iw,ih=self:sourceDimensions()
    return v.w/iw,v.h/ih
  end
  function Screen:contentSize()
    local iw,ih=self:sourceDimensions();local bx,by=self:imageBaseScale()
    return iw*bx*self.mapScale,ih*by*self.mapScale
  end
  local function clampAxis(value,viewStart,viewSize,contentSize)
    if contentSize<=viewSize then return viewStart+(viewSize-contentSize)*.5 end
    local lo=viewStart+viewSize-contentSize
    return math.max(lo,math.min(viewStart,tonumber(value) or viewStart))
  end
  function Screen:panBounds()
    local v=self:mapSafeViewport();local w,h=self:contentSize()
    local minX=w<=v.w and v.x+(v.w-w)*.5 or v.x+v.w-w
    local maxX=w<=v.w and minX or v.x
    local minY=h<=v.h and v.y+(v.h-h)*.5 or v.y+v.h-h
    local maxY=h<=v.h and minY or v.y
    return {minX=minX,maxX=maxX,minY=minY,maxY=maxY,contentW=w,contentH=h,viewport=v}
  end
  function Screen:clampPan()
    local v=self:mapSafeViewport();local w,h=self:contentSize()
    self.panX=clampAxis(self.panX,v.x,v.w,w)
    self.panY=clampAxis(self.panY,v.y,v.h,h)
    return self.panX,self.panY
  end
  function Screen:mapPoint(x,y)
    local bx,by=self:imageBaseScale()
    return (self.panX or 0)+x*bx*self.mapScale,(self.panY or 0)+y*by*self.mapScale
  end
  function Screen:panBy(dx,dy) self.panX=(self.panX or 0)+(tonumber(dx) or 0);self.panY=(self.panY or 0)+(tonumber(dy) or 0);self:clampPan();return true end
  function Screen:centerOn(loc)
    local a=self:anchor(loc);if not a then return false end
    local v=self:mapSafeViewport();local bx,by=self:imageBaseScale()
    self.panX=v.x+v.w*.5-a.x*bx*self.mapScale;self.panY=v.y+v.h*.5-a.y*by*self.mapScale
    self:clampPan()
    return true
  end
  function Screen:ensureVisibleOnMap(loc)
    local a=self:anchor(loc);if not a then return false end
    local v=self:mapSafeViewport();local x,y=self:mapPoint(a.x,a.y);local margin=120
    if x<v.x+margin then self.panX=self.panX+(v.x+margin-x)
    elseif x>v.x+v.w-margin then self.panX=self.panX-(x-(v.x+v.w-margin)) end
    if y<v.y+margin then self.panY=self.panY+(v.y+margin-y)
    elseif y>v.y+v.h-margin then self.panY=self.panY-(y-(v.y+v.h-margin)) end
    self:clampPan();return true
  end
  function Screen:playerSprite()
    local p=self.game.overworld and self.game.overworld.player;if not p then return nil end
    local renderer=(p.fishing and p.sprite) or (p.surfing and p.surfingPikachu and p.surfPikachuSprite) or (p.surfing and p.surfSprite) or (p.onBike and p.bikeSprite) or p.sprite
    if not (renderer and renderer.frames and type(renderer.resolveImage)=="function") then return nil end
    local ok,image=pcall(renderer.resolveImage,renderer);if not ok or not image then return nil end
    local facing=p.facing or "down";local frame=SpriteRenderer.STAND[facing] or 0;local quad=renderer.frames[frame] or renderer.frames[0]
    return image,quad,facing=="right"
  end
  local function hit(rects,x,y) for i,r in pairs(rects or {}) do if runtime.Layout.contains(x,y,r) then return i end end end
  function Screen:pointerEvent(event,lx,ly)
    local v=self:mapSafeViewport()
    if event.phase=="moved" and self.scrollDrag then local sb=self:scrollbar();if sb then self:setScroll(runtime.Scroll.dragValue(self.scrollDrag,ly,sb)) end;return true end
    if (event.phase=="released" or event.phase=="cancelled") and self.scrollDrag then self.scrollDrag=nil;return true end
    if self.mapDrag then
      if event.phase=="moved" then
        self.panX=self.mapDrag.panX+(lx-self.mapDrag.x);self.panY=self.mapDrag.panY+(ly-self.mapDrag.y);self:clampPan()
        self.mapDrag.moved=self.mapDrag.moved or math.abs(lx-self.mapDrag.x)+math.abs(ly-self.mapDrag.y)>8
        self.hoverIndex=nil;runtime.Focus.pointerMove(self.nav,nil);return true
      end
      if event.phase=="released" or event.phase=="cancelled" then self.mapDrag=nil;return true end
    end
    if event.phase=="moved" then
      local listView=self:listMetrics();self.hoverIndex=(runtime.Layout.contains(lx,ly,listView) and hit(runtime.mapDestinationRects,lx,ly) or nil) or hit(runtime.mapPoiRects,lx,ly)
      runtime.Focus.pointerMove(self.nav,self.hoverIndex and ("map:"..self.hoverIndex) or nil)
      return true
    end
    if event.phase~="pressed" then return true end
    if event.source=="mouse" and event.button==2 then self.game.stack:pop();return true end
    if not(event.source=="touch" or event.button==1) then return true end
    local sb=self:scrollbar();if sb and runtime.Layout.contains(lx,ly,sb.hit) then self.scrollDrag={startY=ly,startScroll=self.scrollY};return true end
    local listView=self:listMetrics();local index=(runtime.Layout.contains(lx,ly,listView) and hit(runtime.mapDestinationRects,lx,ly) or nil) or hit(runtime.mapPoiRects,lx,ly)
    if index then local same=self.inner.sel==index;self:setSelection(index);runtime.Focus.pointerPress(self.nav,self:activeId());if same then self:activate(index) end end
    if not index and lx>=v.x and ly>=v.y and lx<=v.x+v.w and ly<=v.y+v.h then
      self.mapDrag={x=lx,y=ly,panX=self.panX,panY=self.panY,moved=false}
    end
    return true
  end
  function Screen:keypressed(key)
    -- WASD is intentionally not a map-pan path. Engine semantic Up/Down input
    -- is handled by update() and moves only the destination list.
    return false
  end
  function Screen:wheel(_,dy,lx,ly)
    if dy==0 then return false end;local view=self:listMetrics()
    if not runtime.Layout.contains(lx,ly,view) or not self:scrollbar() then return false end
    self:setScroll(self.scrollY-dy*LIST_PITCH);return true
  end
  function Screen:draw() if not self:isWide() then self.inner:draw() end end
  return Screen
end
return Module
