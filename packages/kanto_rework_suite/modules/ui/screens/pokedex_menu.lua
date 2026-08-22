local Dex={}

function Dex.factory(runtime)
  local Native=require("src.ui.PokedexMenu")
  local Sound=require("src.core.Sound")
  local Screen={};Screen.__index=Screen

  local function byDex(game)
    local out={}
    for id,def in pairs(game.data.pokemon or {}) do if def.dex then out[def.dex]={id=id,def=def} end end
    return out
  end

  local function status(game,id)
    local pokedex=game.save.pokedex or {}
    if id and pokedex.owned and pokedex.owned[id] then return "caught" end
    if id and pokedex.seen and pokedex.seen[id] then return "seen" end
    return "unseen"
  end

  local function countSet(values)
    local count=0;for _ in pairs(values or {}) do count=count+1 end;return count
  end

  local function ratingKey(owned)
    if owned>=150 then return "_DexRatingText_Own150To151" end
    local low=math.floor(owned/10)*10
    return ("_DexRatingText_Own%dTo%d"):format(low,low+9)
  end

  function Screen.new(game,opts)
    local self=setmetatable({
      game=game,kind="krs_pokedex",inner=Native.new(game,opts),view="index",
      index=runtime.lastPokedexIndex or 1,hover=nil,areaIndex=1,oakOpen=false,
      areaScale=1.12,areaPanX=0,areaPanY=88,areaDrag=nil,areaPanReady=false,
      nav=runtime.Focus.new("kanto_rework_ui.pokedex"),pageSize=11,
    },Screen)
    self.dex=byDex(game);self.max=(game.data.constants or {}).dexSize or 151
    self.index=math.max(1,math.min(self.max,self.index));self:refresh()
    return self
  end

  function Screen:isWide() return runtime.Layout.isWide(runtime.viewport) end

  function Screen:refresh()
    local entry=self.dex[self.index]
    self.entry=entry;self.species=entry and entry.id or nil
    self.status=self.species and status(self.game,self.species) or "unseen"
    local pokedex=self.game.save.pokedex or {}
    self.seen=countSet(pokedex.seen);self.caught=countSet(pokedex.owned)
    if self.view~="index" and self.status=="unseen" then self.view="index" end
    runtime.lastPokedexIndex=self.index
    self.area=nil
    if self.view=="area" and self.species then
      local ok,TownMap=pcall(require,"src.ui.TownMap")
      if ok then local built,value=pcall(TownMap.new,self.game,{nestSpecies=self.species});if built then self.area=value end end
      local total=self.area and #(self.area.nests or {}) or 0
      self.areaIndex=total>0 and math.max(1,math.min(total,self.areaIndex or 1)) or 1
      if not self.areaPanReady then self:centerAreaOn(self.area and self.area.nests and self.area.nests[self.areaIndex]);self.areaPanReady=true end
    end
  end

  function Screen:setIndex(value)
    self.index=((math.floor(value)-1)%self.max)+1;self.areaIndex=1;self.areaPanReady=false;self:refresh()
    runtime.Focus.navigation(self.nav,"dex."..self.index)
  end

  function Screen:setView(value)
    if value~="index" and self.status=="unseen" then return false end
    self.view=value;self:refresh();return true
  end

  function Screen:cycleView(step)
    local order={"index","data","area"};local position=1
    for i,value in ipairs(order) do if value==self.view then position=i end end
    for _=1,3 do
      position=((position-1+step)%3)+1
      if self:setView(order[position]) then return true end
    end
    return false
  end

  function Screen:openData() return self:setView("data") end

  function Screen:cry()
    if self.status=="unseen" or not self.species then return false end
    Sound.playCry(self.game.data,self.species);return true
  end

  function Screen:openOak()
    if self.oakOpen then return false end
    self.oakText=(self.game.data.text or {})[ratingKey(self.caught)] or "¡Tu POKÉDEX va progresando muy bien! ¡Sigue con el buen trabajo!"
    self.oakOpen=true;pcall(Sound.play,self.game.data,"Pokedex_Rating");return true
  end

  function Screen:closeOak()
    if not self.oakOpen then return false end
    self.oakOpen=false;return true
  end

  function Screen:moveArea(step)
    local total=self.area and #(self.area.nests or {}) or 0
    if total==0 then return false end
    self.areaIndex=((self.areaIndex-1+step)%total)+1
    self:ensureAreaVisible(self.area.nests[self.areaIndex])
    runtime.Focus.navigation(self.nav,"area."..self.areaIndex)
    return true
  end

  local AREA_ANCHORS={
    ["VIRIDIAN FOREST"]={366,394},["POWER PLANT"]={1074,326},["PEWTER CITY"]={350,336},
    ["CERULEAN CITY"]={830,282},["LAVENDER TOWN"]={1034,552},["CELADON CITY"]={652,590},
    ["SAFFRON CITY"]={960,520},["VERMILION CITY"]={1130,710},["FUCHSIA CITY"]={930,820},
    ["VIRIDIAN CITY"]={540,650},["PALLET TOWN"]={470,805},["CINNABAR ISLAND"]={340,900},["INDIGO PLATEAU"]={410,150},
  }
  local function areaAnchor(location)
    local name=tostring(location and (location.name or location.mapId) or "KANTO"):upper():gsub("_"," ")
    local point=AREA_ANCHORS[name]
    if point then return point[1],point[2] end
    if location and tonumber(location.x) and tonumber(location.y) then return 170+tonumber(location.x)*62,150+tonumber(location.y)*47 end
  end
  function Screen:areaViewport() return {x=0,y=88,w=1312,h=928} end
  function Screen:clampAreaPan()
    local v=self:areaViewport();local w,h=1920*self.areaScale,1080*self.areaScale
    self.areaPanX=math.max(v.x+v.w-w,math.min(v.x,self.areaPanX or 0))
    self.areaPanY=math.max(v.y+v.h-h,math.min(v.y,self.areaPanY or v.y))
    return self.areaPanX,self.areaPanY
  end
  function Screen:areaMapPoint(x,y) return (self.areaPanX or 0)+x*self.areaScale,(self.areaPanY or 0)+y*self.areaScale end
  function Screen:centerAreaOn(location)
    local x,y=areaAnchor(location);if not x then self:clampAreaPan();return false end
    local v=self:areaViewport();self.areaPanX=v.x+v.w*.5-x*self.areaScale;self.areaPanY=v.y+v.h*.5-y*self.areaScale
    self:clampAreaPan();return true
  end
  function Screen:ensureAreaVisible(location)
    local ax,ay=areaAnchor(location);if not ax then return false end
    local v=self:areaViewport();local x,y=self:areaMapPoint(ax,ay);local margin=96
    if x<v.x+margin then self.areaPanX=self.areaPanX+(v.x+margin-x)
    elseif x>v.x+v.w-margin then self.areaPanX=self.areaPanX-(x-(v.x+v.w-margin)) end
    if y<v.y+margin then self.areaPanY=self.areaPanY+(v.y+margin-y)
    elseif y>v.y+v.h-margin then self.areaPanY=self.areaPanY-(y-(v.y+v.h-margin)) end
    self:clampAreaPan();return true
  end

  function Screen:back()
    if self.oakOpen then return self:closeOak() end
    if self.view=="index" then self.game.stack:pop() else self:setView("index") end
    return true
  end

  function Screen:update(dt)
    if not self:isWide() then return self.inner:update(dt) end
    local input=self.game.input;local actions=runtime.Core.inputActions
    if self.oakOpen then
      if input:wasPressed("a") or input:wasPressed("b") or actions.wasPressed("POKEDEX_OAK_EVAL") then self:closeOak() end
      return
    end
    if actions.wasPressed("POKEDEX_OAK_EVAL") then self:openOak();return end
    if actions.wasPressed("POKEDEX_CRY") then self:cry();return end
    if input:wasPressed("select") then self:cycleView(1);return end
    if self.view=="index" then
      if input:wasPressed("up") then self:setIndex(self.index-1)
      elseif input:wasPressed("down") then self:setIndex(self.index+1)
      elseif input:wasPressed("left") then self:setIndex(self.index-self.pageSize)
      elseif input:wasPressed("right") then self:setIndex(self.index+self.pageSize)
      elseif input:wasPressed("b") then self:back() end
    elseif self.view=="area" then
      if input:wasPressed("up") or input:wasPressed("left") then self:moveArea(-1)
      elseif input:wasPressed("down") or input:wasPressed("right") then self:moveArea(1)
      elseif input:wasPressed("b") then self:back() end
    else
      if input:wasPressed("left") then self:cycleView(-1)
      elseif input:wasPressed("right") then self:cycleView(1)
      elseif input:wasPressed("b") then self:back() end
    end
  end

  function Screen:wheel(_,dy,_,_)
    if not self:isWide() or dy==0 then return false end
    if self.oakOpen then return true end
    if self.view=="index" then self:setIndex(self.index+(dy>0 and -1 or 1))
    elseif self.view=="area" then self:moveArea(dy>0 and -1 or 1) end
    return true
  end

  function Screen:keypressed(key,_,isrepeat)
    if not self:isWide() or isrepeat then return false end
    if self.oakOpen and (key=="return" or key=="kpenter" or key=="a" or key=="escape" or key=="o") then self:closeOak();return true end
    if key=="tab" or key=="f" then self:cycleView(1);return true end
    if key=="c" then return self:cry() end
    if key=="o" then return self:openOak() end
    if key=="1" then return self:setView("index") end
    if key=="2" then return self:setView("data") end
    if key=="3" then return self:setView("area") end
    if key=="space" or key=="return" or key=="kpenter" then if self.view=="index" then return self:openData() end end
    return false
  end

  function Screen:hitTest(lx,ly)
    for id,rect in pairs(runtime.pokedexFooterRects or {}) do if runtime.Layout.contains(lx,ly,rect) then return "footer",id,rect end end
    if self.oakOpen then return nil end
    for i,rect in pairs(runtime.pokedexRowRects or {}) do if runtime.Layout.contains(lx,ly,rect) then return "row",i end end
    for id,rect in pairs(runtime.pokedexTabRects or {}) do if runtime.Layout.contains(lx,ly,rect) then return "tab",id end end
    for i,rect in pairs(runtime.pokedexAreaRects or {}) do if runtime.Layout.contains(lx,ly,rect) then return "area",i end end
  end

  function Screen:activateFooter(id,rect)
    if rect and rect.disabled then return true end
    if id=="close" or id=="cancel" then return self:closeOak() end
    if id=="views" then return self:cycleView(1) end
    if id=="cry" then return self:cry() end
    if id=="back" then return self:back() end
    if id=="oak" then return self:openOak() end
    return false
  end

  function Screen:pointerEvent(event,lx,ly)
    if self.view=="area" and self.areaDrag then
      if event.phase=="moved" then
        self.areaPanX=self.areaDrag.panX+(lx-self.areaDrag.x);self.areaPanY=self.areaDrag.panY+(ly-self.areaDrag.y);self:clampAreaPan()
        self.areaDrag.moved=self.areaDrag.moved or math.abs(lx-self.areaDrag.x)+math.abs(ly-self.areaDrag.y)>8
        self.hover=nil;runtime.Focus.pointerMove(self.nav,nil);return true
      end
      if event.phase=="released" or event.phase=="cancelled" then self.areaDrag=nil;return true end
    end
    if event.phase=="moved" then
      local kind,value=self:hitTest(lx,ly);self.hover=kind=="row" and value or nil
      runtime.Focus.pointerMove(self.nav,self.hover and ("dex."..self.hover) or nil);return true
    end
    if event.phase=="pressed" then
      if event.source=="mouse" and event.button==2 then return self:back() end
      if event.source=="touch" or event.button==1 then
        local kind,value,rect=self:hitTest(lx,ly)
        if kind=="footer" then return self:activateFooter(value,rect) end
        if self.oakOpen then return true end
        if kind=="row" then local same=value==self.index;self:setIndex(value);if same then self:openData() end;return true end
        if kind=="tab" then self:setView(value);return true end
        if kind=="area" then self.areaIndex=value;self:ensureAreaVisible(self.area and self.area.nests and self.area.nests[value]);runtime.Focus.pointerMove(self.nav,"area."..value);return true end
        if self.view=="area" then
          local v=self:areaViewport()
          if lx>=v.x and ly>=v.y and lx<=v.x+v.w and ly<=v.y+v.h then self.areaDrag={x=lx,y=ly,panX=self.areaPanX,panY=self.areaPanY,moved=false};return true end
        end
      end
    end
    return event.phase=="released" or event.phase=="cancelled"
  end

  function Screen:enter(...) if not self:isWide() and self.inner.enter then return self.inner:enter(...) end end
  function Screen:exit(...) if not self:isWide() and self.inner.exit then return self.inner:exit(...) end end
  function Screen:sgbPalettes(game) if not self:isWide() and self.inner.sgbPalettes then return self.inner:sgbPalettes(game) end end
  function Screen:draw() if not self:isWide() then return self.inner:draw() end end

  return Screen
end

return Dex
