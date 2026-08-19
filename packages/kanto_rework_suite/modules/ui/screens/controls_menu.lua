local Controls={}
function Controls.factory(runtime)
  local Core=assert(runtime.Core)
  local Screen={};Screen.__index=Screen;Screen.isOpaque=true
  local VIEW={x=412,y=224,w=820,h=676};local PITCH,ROW_H=76,64
  function Screen.new(game)
    local self=setmetatable({game=game,kind="controls",index=1,hoverIndex=nil,scrollY=0,scrollDrag=nil,nav=runtime.Focus.new("kanto_rework_ui.controls"),notice=nil},Screen)
    runtime.Focus.navigation(self.nav,"controls:1")
    return self
  end
  function Screen:isWide() return runtime.Layout.isWide(runtime.viewport) end
  function Screen:draw() end
  function Screen:rows()
    local rows={{kind="native",id="NATIVE",label="CONTROLES GAME BOY",description="Configura las direcciones nativas del motor y las asignaciones de A/B/START/SELECT."}}
    local actions=Core.inputActions and Core.inputActions.list and Core.inputActions.list() or {}
    for _,a in ipairs(actions) do rows[#rows+1]={kind="action",id=a.id,label=a.label,description=a.description,action=a} end
    return rows
  end
  function Screen:activeId() return "controls:"..self.index end
  function Screen:listMetrics() return VIEW,runtime.Scroll.total(#self:rows(),PITCH,ROW_H),PITCH,ROW_H end
  function Screen:setScroll(value) local v,total=self:listMetrics();self.scrollY=runtime.Scroll.clamp(value,total,v.h);return self.scrollY end
  function Screen:ensureVisible()
    local v,total,pitch,rowH=self:listMetrics();local top=(self.index-1)*pitch
    self.scrollY=runtime.Scroll.ensure(self.scrollY,top,top+rowH,total,v.h)
  end
  function Screen:scrollbar() local v,total=self:listMetrics();return runtime.Scroll.model(self.scrollY,total,v,1240) end
  function Screen:syncFocus() self:ensureVisible();runtime.Focus.navigation(self.nav,self:activeId()) end
  function Screen:ensureIndex() local rows=self:rows();self.index=math.max(1,math.min(self.index,math.max(1,#rows)));self:setScroll(self.scrollY) end
  function Screen:leave()
    if Core.inputActions and Core.inputActions.cancelCapture then Core.inputActions.cancelCapture() end
    self.game.stack:pop()
  end
  function Screen:activeSlot()
    local st=Core.inputDeviceStatus and Core.inputDeviceStatus() or {kind="keyboard"}
    return st.kind=="controller" and "pad" or "key"
  end
  function Screen:beginCapture(row)
    if not (row and row.kind=="action") then return false end
    local slot=self:activeSlot();self.notice="PULSA "..(slot=="pad" and "UN BOTÓN DEL MANDO" or "UNA TECLA").." · SUELTA PARA ASIGNAR"
    local ok,reason=Core.inputActions.beginCapture(row.id,slot,function(success,why,detail)
      if success and why=="native_binding_overlap" then
        self.notice="ASIGNACIÓN ACTUALIZADA · COMPARTIDA CON "..tostring(detail and detail.action or "CONTROL NATIVO"):upper()
      elseif success then self.notice="ASIGNACIÓN ACTUALIZADA"
      else self.notice="ASIGNACIÓN SIN CAMBIOS" end
    end)
    if not ok then self.notice=tostring(reason or "ERROR DE ASIGNACIÓN"):upper() end
    return true
  end
  function Screen:activate(row)
    if not row then return false end
    if row.kind=="native" then
      local ok,Screens=pcall(require,"src.ui.Screens")
      if ok and Screens then Screens.push(self.game,"BindingsMenu");return true end
      return false
    end
    return self:beginCapture(row)
  end
  function Screen:clear(row)
    if not (row and row.kind=="action") then return false end
    local ok,reason=Core.inputActions.clearBinding(row.id,self:activeSlot())
    self.notice=ok and "DEFAULT BINDING RESTORED" or tostring(reason or "UNABLE TO CLEAR"):upper()
    return true
  end
  function Screen:hit(lx,ly)
    if not runtime.Layout.contains(lx,ly,VIEW) then return nil end
    for i,r in pairs(runtime.controlsRects or {}) do if runtime.Layout.contains(lx,ly,r) then return i end end
  end
  function Screen:pointerEvent(event,lx,ly)
    if not self:isWide() then return false end
    if event.phase=="moved" and self.scrollDrag then local sb=self:scrollbar();if sb then self:setScroll(runtime.Scroll.dragValue(self.scrollDrag,ly,sb)) end;return true end
    if (event.phase=="released" or event.phase=="cancelled") and self.scrollDrag then self.scrollDrag=nil;return true end
    if event.phase=="moved" then
      local i=self:hit(lx,ly);self.hoverIndex=i
      runtime.Focus.pointerMove(self.nav,i and ("controls:"..i) or nil,function() if i then self.index=i end end)
      return true
    end
    if event.phase=="pressed" then
      if event.source=="mouse" and event.button==2 then self:leave();return true end
      if not(event.source=="touch" or event.button==1) then return true end
      local sb=self:scrollbar();if sb and runtime.Layout.contains(lx,ly,sb.hit) then self.scrollDrag={startY=ly,startScroll=self.scrollY};return true end
      local i=self:hit(lx,ly);if i then self.index=i;runtime.Focus.pointerPress(self.nav,"controls:"..i);self:activate(self:rows()[i]) end
      return true
    end
    return event.phase=="released" or event.phase=="cancelled"
  end
  function Screen:wheel(_,dy,lx,ly)
    if not self:isWide() or dy==0 then return false end
    if not runtime.Layout.contains(lx,ly,VIEW) or not self:scrollbar() then return false end
    self:setScroll(self.scrollY-dy*PITCH);return true
  end
  function Screen:update(dt)
    if not self:isWide() then
      -- This screen is only routed from the Kanto Wide Options flow. If the
      -- layout changes while open, leave cleanly rather than invent a Classic UI.
      return self:leave()
    end
    self:ensureIndex();runtime.Focus.syncDevice(self.nav,self:activeId())
    local capture=Core.inputActions.captureState and Core.inputActions.captureState()
    if capture then return end
    local input=self.game.input;local rows=self:rows()
    if input:wasPressed("up") then self.index=self.index>1 and self.index-1 or #rows;self:syncFocus()
    elseif input:wasPressed("down") then self.index=self.index<#rows and self.index+1 or 1;self:syncFocus()
    elseif input:wasPressed("a") then self:activate(rows[self.index])
    elseif input:wasPressed("select") then self:clear(rows[self.index])
    elseif input:wasPressed("b") or input:wasPressed("start") then self:leave() end
  end
  return Screen
end
return Controls
