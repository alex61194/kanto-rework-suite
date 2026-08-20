local Module={}
function Module.factory(runtime)
  local Core=assert(runtime.Core);local Screen={};Screen.__index=Screen;Screen.isOpaque=false
  local LIST_PITCH,LIST_ROW_H,MAX_LIST_H=76,64,600
  local function context(game) return {game=game,overworld=game and game.overworld,automatic=false,fieldPopup=true} end
  function Screen.new(game)
    local self=setmetatable({game=game,kind="field_actions_popup",index=1,hoverIndex=nil,scrollY=0,scrollDrag=nil,nav=runtime.Focus.new("kanto_rework_ui.field_actions")},Screen)
    self:refresh();if #self.rows==0 then return nil,"no_field_actions" end
    for i,row in ipairs(self.rows) do if row.available then self.index=i break end end
    runtime.Focus.navigation(self.nav,self:activeId());return self
  end
  function Screen:isWide() return runtime.Layout.isWide(runtime.viewport) end
  function Screen:activeId() local row=self.rows[self.index];return row and ("field:"..row.id) or nil end
  function Screen:popupGeometry()
    local total=runtime.Scroll.total(#(self.rows or {}),LIST_PITCH,LIST_ROW_H);local listH=math.min(MAX_LIST_H,total)
    local popupH=88+listH;local x,y,w=96,math.floor((1080-popupH)/2),448
    return {x=x,y=y,w=w,h=popupH,viewport={x=x+24,y=y+60,w=376,h=listH},trackX=x+w-24}
  end
  function Screen:listMetrics() local g=self:popupGeometry();return g.viewport,runtime.Scroll.total(#(self.rows or {}),LIST_PITCH,LIST_ROW_H),LIST_PITCH,LIST_ROW_H end
  function Screen:setScroll(value) local v,total=self:listMetrics();self.scrollY=runtime.Scroll.clamp(value,total,v.h);return self.scrollY end
  function Screen:ensureVisible()
    local v,total,pitch,rowH=self:listMetrics();local top=(self.index-1)*pitch
    self.scrollY=runtime.Scroll.ensure(self.scrollY,top,top+rowH,total,v.h)
  end
  function Screen:scrollbar() local g=self:popupGeometry();local v,total=self:listMetrics();return runtime.Scroll.model(self.scrollY,total,v,g.trackX) end
  function Screen:refresh()
    local selected=self.rows and self.rows[self.index] and self.rows[self.index].id
    local rows=Core.fieldActions.list(context(self.game),{trigger="manual",includeUnknown=true}) or {}
    local filtered = {}
    table.insert(filtered, {
      id = "kanto.fly_map",
      label = "VUELO (MAPA)",
      available = true,
      known = true,
      status = "available"
    })
    table.insert(filtered, {
      id = "kanto.free_fly",
      label = "VUELO LIBRE 3D",
      available = true,
      known = true,
      status = "available"
    })
    for _, r in ipairs(rows) do
      if r.id ~= "kanto.fly" and r.id ~= "kanto.fly_map" and r.id ~= "kanto.free_fly" then
        table.insert(filtered, r)
      end
    end
    self.rows=filtered;self.index=math.max(1,math.min(self.index or 1,#filtered))
    if selected then for i,row in ipairs(filtered) do if row.id==selected then self.index=i break end end end
    self:setScroll(self.scrollY);self:ensureVisible()
  end
  function Screen:move(step)
    if #self.rows<2 then return end;self.index=(self.index-1+step)%#self.rows+1
    self:ensureVisible();runtime.Focus.navigation(self.nav,self:activeId())
  end
  function Screen:close() if self.game.stack:top()==self then self.game.stack:pop() end end
  function Screen:activate(index)
    index=index or self.index;local row=self.rows[index];if not row then return false end
    self.index=index;self:close()
    if row.id=="kanto.free_fly" then
      local ok, freeFlyMod = pcall(function() return require("src.mods.Runtime").activeMod("free_fly") end)
      if ok and freeFlyMod and freeFlyMod.exports and type(freeFlyMod.exports.takeoff)=="function" then
        freeFlyMod.exports.takeoff()
        return true
      end
    end
    if (row.id=="kanto.fly_map" or row.id=="kanto.fly" or tostring(row.label):find("VUELO")) and runtime.MapFactory then
      local screen = runtime.MapFactory.new(self.game)
      if screen then self.game.stack:push(screen); return true end
    end
    return Core.fieldActions.execute(row.id,context(self.game))==true
  end
  function Screen:update()
    self:refresh();if #self.rows==0 then self:close();return end
    runtime.Focus.syncDevice(self.nav,self:activeId());local input=self.game.input
    if input:wasPressed("up") or input:wasPressed("left") then self:move(-1)
    elseif input:wasPressed("down") or input:wasPressed("right") then self:move(1)
    elseif input:wasPressed("a") then self:activate()
    elseif input:wasPressed("b") then self:close() end
  end
  local function hit(self,rects,x,y)
    local view=self:listMetrics();if not runtime.Layout.contains(x,y,view) then return nil end
    for i,r in pairs(rects or {}) do if runtime.Layout.contains(x,y,r) then return i end end
  end
  function Screen:pointerEvent(event,lx,ly)
    if event.phase=="moved" and self.scrollDrag then local sb=self:scrollbar();if sb then self:setScroll(runtime.Scroll.dragValue(self.scrollDrag,ly,sb)) end;return true end
    if (event.phase=="released" or event.phase=="cancelled") and self.scrollDrag then self.scrollDrag=nil;return true end
    if event.phase=="moved" then
      self.hoverIndex=hit(self,runtime.fieldActionRects,lx,ly)
      runtime.Focus.pointerMove(self.nav,self.hoverIndex and ("field:"..self.rows[self.hoverIndex].id) or nil,function() if self.hoverIndex then self.index=self.hoverIndex end end)
      return true
    end
    if event.phase~="pressed" then return true end
    if event.source=="mouse" and event.button==2 then self:close();return true end
    if not(event.source=="touch" or event.button==1) then return true end
    local sb=self:scrollbar();if sb and runtime.Layout.contains(lx,ly,sb.hit) then self.scrollDrag={startY=ly,startScroll=self.scrollY};return true end
    local i=hit(self,runtime.fieldActionRects,lx,ly);if i then self.index=i;runtime.Focus.pointerPress(self.nav,"field:"..self.rows[i].id);self:activate(i) end
    return true
  end
  function Screen:wheel(_,dy,lx,ly)
    if dy==0 then return false end;local view=self:listMetrics()
    if not runtime.Layout.contains(lx,ly,view) or not self:scrollbar() then return false end
    self:setScroll(self.scrollY-dy*LIST_PITCH);return true
  end
  function Screen:draw()
    if runtime.MenuPresenter and type(runtime.MenuPresenter.drawFieldActions)=="function" then
      local m=runtime.Layout.metrics(runtime.viewport)
      local colors=runtime.Theme and runtime.Theme.resolveAll(runtime,self.game) or {}
      runtime.MenuPresenter.drawFieldActions(runtime,m,colors,self)
    end
  end
  function Screen:exit() if type(Core.clearFocus)=="function" then Core.clearFocus("kanto_rework_ui.field_actions") end end
  return Screen
end
return Module
