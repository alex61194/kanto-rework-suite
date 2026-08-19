local OptionsMenu={}
function OptionsMenu.factory(runtime)
  local Core=assert(runtime.Core)
  local Screen={};Screen.__index=Screen;Screen.isOpaque=true
  local CATEGORY_TOP,CATEGORY_H,CATEGORY_PITCH,CATEGORY_ROW_H=224,736,64,56
  local SETTING_BOTTOM=960

  local function injectThemeRow(session,game)
    if not (runtime.Theme and type(runtime.Theme.value)=="function" and type(runtime.Theme.step)=="function") then return end
    local row={
      id="krsTheme",label="TEMA DE LA INTERFAZ",type="choice",category="GRÁFICOS",krsOwned=true,
      description="Elige entre Crema, Grafito, Noche Púrpura o Retro para la interfaz de Kanto Rework. Los perfiles de accesibilidad se configuran aparte.",
      value=function() return runtime.Theme.value() end,
      step=function(_,dir) local changed=runtime.Theme.step(game,dir);return changed==true end,
    }
    local insertAt=#session.rows+1
    for i,native in ipairs(session.rows) do if native.id=="colors" then insertAt=i+1;break end end
    table.insert(session.rows,insertAt,row)
  end

  function Screen.new(game,opts)
    local session=assert(Core.createOptionsRuntime(game,opts),"Core Options runtime unavailable")
    injectThemeRow(session,game)
    local categories=runtime.Catalog.categories(session.rows)
    local self=setmetatable({
      game=game,session=session,inner=session.native,kind="options",categories=categories,
      categoryIndex=1,headerIndex=1,region="header",settingIndex=1,hoverCategory=nil,hoverSetting=nil,
      categoryScrollY=0,settingScrollY=0,scrollDrag=nil,
      nav=runtime.Focus.new("kanto_rework_ui.options"),notice=nil,nativeCapture=nil,editing=false,
    },Screen)
    runtime.Focus.navigation(self.nav,"category:1")
    return self
  end

  function Screen:isWide() return runtime.Layout.isWide(runtime.viewport) end
  function Screen:enter(...) self.session:syncVideoMode();if self.inner and self.inner.enter then return self.inner:enter(...) end end
  function Screen:exit(...)
    self:cancelNativeCapture(false)
    if Core.inputActions and Core.inputActions.cancelCapture then Core.inputActions.cancelCapture() end
    if self.inner and self.inner.exit then return self.inner:exit(...) end
  end
  function Screen:sgbPalettes(game) if self.inner and self.inner.sgbPalettes then return self.inner:sgbPalettes(game) end end
  function Screen:draw() if not self:isWide() and self.inner and self.inner.draw then self.inner:draw() end end
  function Screen:category() return self.categories[self.categoryIndex] end
  function Screen:isControls() return self:category()=="CONTROLES" or self:category()=="CONTROLS" end
  function Screen:syncVideoModeFromWindow() return self.session:syncVideoMode() end
  function Screen:rows()
    if self:isControls() and runtime.ControlsCatalog then return runtime.ControlsCatalog.rows(self.game) end
    return runtime.Catalog.rows(self.session.rows,self:category())
  end
  function Screen:meta(row)
    if self:isControls() and runtime.ControlsCatalog then return runtime.ControlsCatalog.meta(row) end
    return runtime.Catalog.meta(row)
  end
  function Screen:focusedRow() if self.region~="settings" then return nil end;return self:rows()[self.settingIndex] end
  function Screen:activeItemId() return self.region=="header" and ("category:"..self.headerIndex) or ("setting:"..self.settingIndex) end
  function Screen:categoryListMetrics()
    -- Categories are a fixed horizontal header hierarchy in the validated UI.
    local viewport={x=350,y=20,w=1220,h=48}
    return viewport,viewport.h,132,48
  end
  function Screen:settingListMetrics()
    local viewport={x=88,y=216,w=1176,h=692};local pitch,rowH=84,68
    return viewport,runtime.Scroll.total(#self:rows(),pitch,rowH),pitch,rowH
  end
  function Screen:setListScroll(kind,value)
    local viewport,total
    if kind=="categories" then viewport,total=self:categoryListMetrics();self.categoryScrollY=runtime.Scroll.clamp(value,total,viewport.h);return self.categoryScrollY end
    viewport,total=self:settingListMetrics();self.settingScrollY=runtime.Scroll.clamp(value,total,viewport.h);return self.settingScrollY
  end
  function Screen:ensureCategoryVisible()
    local viewport,total,pitch,rowH=self:categoryListMetrics();local top=(self.categoryIndex-1)*pitch
    self.categoryScrollY=runtime.Scroll.ensure(self.categoryScrollY,top,top+rowH,total,viewport.h)
  end
  function Screen:ensureSettingVisible()
    local viewport,total,pitch,rowH=self:settingListMetrics();local top=(self.settingIndex-1)*pitch
    self.settingScrollY=runtime.Scroll.ensure(self.settingScrollY,top,top+rowH,total,viewport.h)
  end
  function Screen:scrollbar(kind)
    if kind=="categories" then return nil end
    local v,total=self:settingListMetrics();return runtime.Scroll.model(self.settingScrollY,total,v,1280)
  end
  function Screen:syncFocus()
    if self.region=="header" then self:ensureCategoryVisible() else self:ensureSettingVisible() end
    runtime.Focus.navigation(self.nav,self:activeItemId())
  end
  function Screen:selectCategory(index)
    index=math.max(1,math.min(index,#self.categories));local changed=index~=self.categoryIndex
    self.categoryIndex=index;self.headerIndex=index;self.settingIndex=1;self.editing=false;if changed then self.settingScrollY=0 end
    self:ensureCategoryVisible();self:setListScroll("settings",self.settingScrollY)
  end
  function Screen:ensureIndices()
    self.categories=runtime.Catalog.categories(self.session.rows);if #self.categories==0 then self.categories={"OTHER"} end
    self.categoryIndex=math.max(1,math.min(self.categoryIndex,#self.categories))
    self.headerIndex=math.max(1,math.min(self.headerIndex or self.categoryIndex,#self.categories))
    local rows=self:rows();self.settingIndex=math.max(1,math.min(self.settingIndex,math.max(1,#rows)))
    self:setListScroll("categories",self.categoryScrollY);self:setListScroll("settings",self.settingScrollY)
  end

  function Screen:leave()
    self:cancelNativeCapture(false)
    if Core.inputActions and Core.inputActions.cancelCapture then Core.inputActions.cancelCapture() end
    local onCancel=self.inner and self.inner.onCancel
    self.game.stack:pop();if onCancel then onCancel() end
  end

  function Screen:activeSlot()
    local st=Core.inputDeviceStatus and Core.inputDeviceStatus() or {kind="keyboard"}
    return st.kind=="controller" and "pad" or "key"
  end

  function Screen:beginCustomCapture(row)
    if not (row and row.kind=="action") then return false end
    local slot=self:activeSlot()
    self.notice="PRESS A "..(slot=="pad" and "CONTROLLER BUTTON" or "KEY").." · RELEASE TO SET"
    local ok,reason=Core.inputActions.beginCapture(row.id,slot,function(success,why,detail)
      if success and why=="native_binding_overlap" then
        self.notice="BINDING UPDATED · SHARED WITH "..tostring(detail and detail.action or "NATIVE CONTROL"):upper()
      elseif success then self.notice="BINDING UPDATED"
      else self.notice="BINDING NOT CHANGED" end
    end)
    if not ok then self.notice=tostring(reason or "CAPTURE FAILED"):upper() end
    return true
  end

  function Screen:clearRawHandlers()
    self.onKeyPressed=nil;self.onKeyReleased=nil
    self.onGamepadPressed=nil;self.onGamepadReleased=nil
    self.onJoystickPressed=nil;self.onJoystickReleased=nil
  end

  function Screen:cancelNativeCapture(showNotice)
    local cap=self.nativeCapture
    if cap and cap.menu and cap.menu.endCapture then pcall(cap.menu.endCapture,cap.menu) end
    self.nativeCapture=nil;self:clearRawHandlers()
    if showNotice then self.notice="BINDING NOT CHANGED" end
  end

  function Screen:finishNativeCapture(committed)
    local cap=self.nativeCapture
    if committed and cap and cap.menu and cap.menu.commitBindings then pcall(cap.menu.commitBindings,cap.menu) end
    self.nativeCapture=nil;self:clearRawHandlers()
    self.notice=committed and "BINDING UPDATED" or "BINDING NOT CHANGED"
  end

  function Screen:beginNativeCapture(row)
    if not (row and row.kind=="native_action" and row.nativeAction) then return false end
    local ok,BindingsMenu=pcall(require,"src.ui.BindingsMenu")
    if not ok or not BindingsMenu or type(BindingsMenu.new)~="function" then
      self.notice="NATIVE BINDING EDITOR UNAVAILABLE";return false
    end
    local okMenu,menu=pcall(BindingsMenu.new,self.game)
    if not okMenu or type(menu)~="table" then self.notice="NATIVE BINDING EDITOR UNAVAILABLE";return false end
    local item
    for _,candidate in ipairs(menu.items or {}) do
      if candidate.button and candidate.button.id==row.nativeAction then item=candidate;break end
    end
    if not item or type(menu.beginCapture)~="function" then self.notice="NATIVE BINDING ROW UNAVAILABLE";return false end
    menu:beginCapture(item)
    self.nativeCapture={menu=menu,row=row}
    self.notice="PRESS A KEY OR CONTROLLER BUTTON · RELEASE TO SET"

    self.onKeyPressed=function(_,key)
      local before=menu.capture~=nil
      menu:captureKey(key)
      if before and not menu.capture then self:finishNativeCapture(false) end
    end
    self.onKeyReleased=function(_,key)
      local p=menu.pending;local commit=p and p.slot=="key" and p.value==key
      menu:captureKeyRelease(key)
      if commit and not menu.capture then self:finishNativeCapture(true) end
    end
    self.onGamepadPressed=function(_,button)
      local before=menu.capture~=nil
      menu:capturePad(button)
      if before and not menu.capture then self:finishNativeCapture(false) end
    end
    self.onGamepadReleased=function(_,button)
      local p=menu.pending;local commit=p and p.slot=="pad" and p.value==button and not p.raw
      menu:capturePadRelease(button)
      if commit and not menu.capture then self:finishNativeCapture(true) end
    end
    self.onJoystickPressed=function(_,button)
      local before=menu.capture~=nil
      menu:captureJoy(button)
      if before and not menu.capture then self:finishNativeCapture(false) end
    end
    self.onJoystickReleased=function(_,button)
      local p=menu.pending;local commit=p and p.raw and p.value=="joy"..button
      menu:captureJoyRelease(button)
      if commit and not menu.capture then self:finishNativeCapture(true) end
    end
    return true
  end

  function Screen:activateControl(row)
    if not row then return false end
    if row.kind=="native_action" then return self:beginNativeCapture(row) end
    if row.kind=="action" then return self:beginCustomCapture(row) end
    return false
  end

  function Screen:clearControl(row)
    if not row then return false end
    if row.kind=="action" then
      local ok,reason=Core.inputActions.clearBinding(row.id,self:activeSlot())
      self.notice=ok and "DEFAULT BINDING RESTORED" or tostring(reason or "UNABLE TO CLEAR"):upper()
      return true
    end
    if row.kind=="native_action" then
      local opts=self.game.save and self.game.save.options
      if not opts then self.notice="UNABLE TO RESET BINDING";return true end
      opts.bindings=opts.bindings or {}
      opts.bindings[row.nativeAction]=nil
      if self.game.input and self.game.input.applyBindings then self.game.input:applyBindings(opts.bindings) end
      if self.game.writeOptions then self.game:writeOptions() end
      self.notice="DEFAULT BINDING RESTORED"
      return true
    end
    return false
  end

  function Screen:change(row,dir,activate)
    if not row then return false end
    local meta=self:meta(row);if meta.disabled then return false end
    if self:isControls() then return activate and self:activateControl(row) or false end
    if activate and row.activate then row.activate();return true end
    if row.step then
      local changed=row.step(self.game,dir or 1) and true or false
      if changed and row.id~="videoMode" and not row.krsOwned and self.game.writeOptions then self.game:writeOptions() end
      self:ensureIndices();return changed
    end
    return false
  end

  function Screen:hitCategory(lx,ly)
    for i,r in pairs(runtime.optionCategoryRects or {}) do if runtime.Layout.contains(lx,ly,r) then return i end end
  end
  function Screen:hitSetting(lx,ly)
    local viewport=self:settingListMetrics();if not runtime.Layout.contains(lx,ly,viewport) then return nil end
    for i,r in pairs(runtime.optionSettingRects or {}) do if runtime.Layout.contains(lx,ly,r) then return i,r end end
  end

  function Screen:pointerEvent(event,lx,ly)
    if not self:isWide() then return false end
    local customCapture=Core.inputActions.captureState and Core.inputActions.captureState()
    if self.nativeCapture or customCapture then return true end
    if event.phase=="moved" and self.scrollDrag then
      local model=self:scrollbar(self.scrollDrag.kind);if model then self:setListScroll(self.scrollDrag.kind,runtime.Scroll.dragValue(self.scrollDrag,ly,model)) end
      return true
    end
    if (event.phase=="released" or event.phase=="cancelled") and self.scrollDrag then self.scrollDrag=nil;return true end
    if event.phase=="moved" then
      local ci=self:hitCategory(lx,ly);local si=self:hitSetting(lx,ly)
      self.hoverCategory,self.hoverSetting=ci,si
      local target=ci and ("category:"..ci) or (si and ("setting:"..si) or nil)
      runtime.Focus.pointerMove(self.nav,target)
      return true
    end
    if event.phase=="pressed" then
      if event.source=="mouse" and event.button==2 then
        if self.editing then self.editing=false;self.notice=nil;self:syncFocus()
        elseif self.region~="header" then self.region="header";self.headerIndex=self.categoryIndex;self:syncFocus()
        else self:leave() end
        return true
      end
      if not(event.source=="touch" or event.button==1) then return true end
      for _,kind in ipairs({"categories","settings"}) do
        local sb=self:scrollbar(kind)
        if sb and runtime.Layout.contains(lx,ly,sb.hit) then self.scrollDrag={kind=kind,startY=ly,startScroll=kind=="categories" and self.categoryScrollY or self.settingScrollY};return true end
      end
      local ci=self:hitCategory(lx,ly)
      if ci then self.editing=false;self:selectCategory(ci);self.region="header";runtime.Focus.pointerPress(self.nav,"category:"..ci);return true end
      local si,rect=self:hitSetting(lx,ly)
      if si then
        self.settingIndex=si;self.region="settings";runtime.Focus.pointerPress(self.nav,"setting:"..si)
        local row=self:focusedRow();local meta=row and self:meta(row);if not row or not meta or meta.disabled then return true end
        if self:isControls() then self:activateControl(row);return true end
        local cr=runtime.optionControlRects and runtime.optionControlRects[si]
        if meta.control=="submenu" then
          if cr and runtime.Layout.contains(lx,ly,cr) then self:change(row,1,true) end
        elseif row.step then
          if not self.editing then
            -- First click/confirm locks this row for editing. The second
            -- interaction changes its value, preserving Focused != Editing.
            self.editing=true;self.notice="EDITING · LEFT / RIGHT CHANGE · BACK UNLOCKS"
          elseif cr and runtime.Layout.contains(lx,ly,cr) then
            self:change(row,lx<cr.x+cr.w/2 and -1 or 1,false)
          end
        elseif cr and runtime.Layout.contains(lx,ly,cr) then
          self:change(row,1,false)
        end
        return true
      end
      return true
    end
    return event.phase=="released" or event.phase=="cancelled"
  end

  function Screen:wheel(_,dy,lx,ly)
    if not self:isWide() or dy==0 then return false end
    local sv=self:settingListMetrics()
    if (lx==nil or runtime.Layout.contains(lx,ly,sv)) and self:scrollbar("settings") then local _,_,pitch=self:settingListMetrics();self:setListScroll("settings",self.settingScrollY-dy*pitch);return true end
    return false
  end

  function Screen:update(dt)
    if not self:isWide() then return self.inner:update(dt) end
    self:syncVideoModeFromWindow();self:ensureIndices();runtime.Focus.syncDevice(self.nav,self:activeItemId())
    if self.nativeCapture then return end
    local customCapture=Core.inputActions.captureState and Core.inputActions.captureState();if customCapture then return end
    local input=self.game.input
    if self.region=="header" then
      if input:wasPressed("left") then self.headerIndex=self.headerIndex>1 and self.headerIndex-1 or #self.categories;self:syncFocus()
      elseif input:wasPressed("right") then self.headerIndex=self.headerIndex<#self.categories and self.headerIndex+1 or 1;self:syncFocus()
      elseif input:wasPressed("down") or input:wasPressed("a") then self:selectCategory(self.headerIndex);self.region="settings";self:syncFocus()
      elseif input:wasPressed("b") or input:wasPressed("start") then self:leave() end
      return
    end

    local rows=self:rows();if #rows==0 then self.region="header";self:syncFocus();return end
    if self:isControls() then
      if input:wasPressed("up") then
        self.settingIndex=math.max(1,self.settingIndex-1);self:syncFocus()
      elseif input:wasPressed("down") then self.settingIndex=math.min(#rows,self.settingIndex+1);self:syncFocus()
      elseif input:wasPressed("a") then self:activateControl(rows[self.settingIndex])
      elseif input:wasPressed("b") then self.region="header";self.headerIndex=self.categoryIndex;self:syncFocus()
      elseif input:wasPressed("start") then self:leave() end
      return
    end

    if self.editing then
      if input:wasPressed("left") then self:change(self:focusedRow(),-1,false)
      elseif input:wasPressed("right") then self:change(self:focusedRow(),1,false)
      elseif input:wasPressed("b") then self.editing=false;self.notice=nil;self:syncFocus()
      elseif input:wasPressed("start") then self.editing=false;self.notice=nil;self:leave() end
      return
    end
    if input:wasPressed("up") then
      self.settingIndex=math.max(1,self.settingIndex-1);self:syncFocus()
    elseif input:wasPressed("down") then self.settingIndex=math.min(#rows,self.settingIndex+1);self:syncFocus()
    elseif input:wasPressed("left") then
      local row=self:focusedRow();if row and row.step then self:change(row,-1,false) end
    elseif input:wasPressed("right") then
      local row=self:focusedRow();if row and row.step then self:change(row,1,false) end
    elseif input:wasPressed("a") then local row=self:focusedRow();if row and row.activate then self:change(row,1,true) elseif row and row.step then self.editing=true;self.notice="EDITING · LEFT / RIGHT CHANGE · BACK UNLOCKS" end
    elseif input:wasPressed("b") then self.region="header";self.headerIndex=self.categoryIndex;self:syncFocus()
    elseif input:wasPressed("start") then self:leave() end
  end

  return Screen
end
return OptionsMenu
