-- Kanto presenter for native ListMenu/TextBox states opened by a mod adapter.
-- The source mod still owns its rows, callbacks, values and persistence.
local Extension={}

function Extension.factory(runtime)
  local function capture(game,callback)
    local stack=game and game.stack
    if not(stack and type(stack.push)=="function") then return false,nil,"stack unavailable" end
    local original=stack.push;local captured={}
    stack.push=function(_,state) captured[#captured+1]=state;return state end
    local ok,err=xpcall(callback,tostring)
    stack.push=original
    if not ok then return false,nil,err end
    return true,captured
  end

  local function classify(state)
    if type(state)~="table" then return nil end
    if type(state.items)=="table" and type(state.title)=="string" then return "list" end
    if type(state.pages)=="table" and state.pageIndex~=nil and not state.auto and not state.stay then return "text" end
  end

  local Screen={};Screen.__index=Screen;Screen.isOpaque=true
  function Screen.new(game,state,context)
    local kind=assert(classify(state),"unsupported external mod state")
    local presentation=context and context.presentation or nil
    local readerPolicy=type(presentation)=="table" and presentation.reader or nil
    local self=setmetatable({game=game,inner=state,kind="mod_extension",viewKind=kind,source=context and context.mod,
      title=kind=="list" and state.title or ((context and context.title) or "MOD DETAILS"),index=1,scroll=0,hoverIndex=nil,
      presentation=presentation,readerScrollY=0,readerContentHeight=0,readerViewportHeight=0,readerDrag=nil,
      document=kind=="text" and runtime.DocumentReader.build(state.pages,readerPolicy) or nil,
      choiceIndex=state.defaultNo and 2 or 1,notice=nil,nav=runtime.Focus.new("kanto_rework_ui.mod_extension")},Screen)
    runtime.Focus.navigation(self.nav,self:activeId());return self
  end
  function Screen:isWide() return runtime.Layout.isWide(nil) end
  function Screen:draw() if not self:isWide() and self.inner and self.inner.draw then self.inner:draw() end end
  function Screen:sgbPalettes(game) if self.inner and self.inner.sgbPalettes then return self.inner:sgbPalettes(game) end end
  function Screen:items() return self.inner.items or {} end
  function Screen:activeId() return self.viewKind=="list" and ("extension:"..self.index) or (self:choosing() and ("choice:"..self.choiceIndex) or "extension:document") end
  function Screen:hasChoice() return self.viewKind=="text" and type(self.inner.choice)=="function" end
  function Screen:readerMaxScroll() return math.max(0,(self.readerContentHeight or 0)-(self.readerViewportHeight or 0)) end
  function Screen:readerAtEnd() return self.readerScrollY>=self:readerMaxScroll()-1 end
  function Screen:choosing() return self:hasChoice() and self:readerAtEnd() end
  function Screen:setReaderMetrics(contentHeight,viewportHeight)
    self.readerContentHeight=math.max(0,tonumber(contentHeight) or 0)
    self.readerViewportHeight=math.max(0,tonumber(viewportHeight) or 0)
    self.readerScrollY=math.max(0,math.min(self.readerScrollY or 0,self:readerMaxScroll()))
  end
  function Screen:scrollReader(delta)
    local before=self.readerScrollY or 0
    self.readerScrollY=math.max(0,math.min(before+(tonumber(delta) or 0),self:readerMaxScroll()))
    return self.readerScrollY~=before
  end
  function Screen:readerPageStep()
    return math.max(120,(self.readerViewportHeight or 0)-72)
  end
  function Screen:move(dir)
    if self.viewKind=="text" then if self:choosing() then self.choiceIndex=self.choiceIndex==1 and 2 or 1 end;runtime.Focus.navigation(self.nav,self:activeId());return end
    local n=#self:items();if n==0 then return end
    self.index=((self.index-1+dir)%n)+1
    local visible=8;if self.index<=self.scroll then self.scroll=self.index-1 elseif self.index>self.scroll+visible then self.scroll=self.index-visible end
    runtime.Focus.navigation(self.nav,self:activeId())
  end
  function Screen:pushCaptured(states)
    for _,state in ipairs(states or {}) do
      local wrapped=Extension.wrap(runtime,self.game,state,{mod=self.source,title=self.title,presentation=self.presentation})
      self.game.stack:push(wrapped)
    end
    return true
  end
  function Screen:activateList()
    local item=self:items()[self.index];if not item then return false end
    local callback=self.inner.onChoose
    if type(callback)~="function" and type(item.onSelect)=="function" then callback=function() item.onSelect() end end
    if type(callback)~="function" then return false end
    local ok,states,err=capture(self.game,function() callback(item,self.inner) end)
    if not ok then self.notice=tostring(err);return false end
    return self:pushCaptured(states)
  end
  function Screen:finishText(choice)
    self.game.stack:pop()
    local callback=choice~=nil and self.inner.choice or self.inner.onDone
    if type(callback)~="function" then return true end
    local ok,states,err=capture(self.game,function() if choice~=nil then callback(choice) else callback() end end)
    if not ok then return false,err end
    return self:pushCaptured(states)
  end
  function Screen:activateText()
    if not self:readerAtEnd() then self:scrollReader(self:readerPageStep());return true end
    if self:choosing() then return self:finishText(self.choiceIndex==1) end
    return self:finishText(nil)
  end
  function Screen:activate() return self.viewKind=="list" and self:activateList() or self:activateText() end
  function Screen:back()
    if self.viewKind=="text" then return self:activateText() end
    self.game.stack:pop();if type(self.inner.onCancel)=="function" then self.inner.onCancel() end;return true
  end
  function Screen:rowRects() return runtime.extensionRowRects or {} end
  function Screen:hit(lx,ly)
    for i,r in pairs(self:rowRects()) do if runtime.Layout.contains(lx,ly,r) then return i end end
  end
  function Screen:pointerEvent(event,lx,ly)
    if not self:isWide() then return false end
    if event.phase=="moved" and self.readerDrag then
      local sb=runtime.extensionScrollbar
      if sb and sb.maxScroll>0 and sb.travel>0 then self.readerScrollY=math.max(0,math.min(sb.maxScroll,self.readerDrag.startScroll+(ly-self.readerDrag.startY)*sb.maxScroll/sb.travel)) end
      return true
    end
    if event.phase=="released" or event.phase=="cancelled" then self.readerDrag=nil;return true end
    if event.phase=="moved" then
      local i=self:hit(lx,ly);self.hoverIndex=i
      runtime.Focus.pointerMove(self.nav,i and ("extension:"..i) or nil,function() if i then self.index=i end end);return true
    end
    if event.phase~="pressed" then return event.phase=="released" or event.phase=="cancelled" end
    if event.source=="mouse" and event.button==2 then return self:back() end
    if not(event.source=="touch" or event.button==1) then return true end
    if self.viewKind=="text" then
      local sb=runtime.extensionScrollbar
      if sb and sb.hit and runtime.Layout.contains(lx,ly,sb.hit) then self.readerDrag={startY=ly,startScroll=self.readerScrollY};return true end
    end
    if self.viewKind=="text" and self:choosing() then
      for i,r in pairs(runtime.extensionChoiceRects or {}) do if runtime.Layout.contains(lx,ly,r) then self.choiceIndex=i;return self:activate() end end
      return self:activate()
    end
    local i=self:hit(lx,ly);if i then self.index=i end;return self:activate()
  end
  function Screen:wheel(_,dy)
    if dy==0 then return false end
    if self.viewKind=="text" then self:scrollReader(-dy*72);return true end
    self:move(dy>0 and -1 or 1);return true
  end
  function Screen:update(dt)
    if not self:isWide() then return self.inner:update(dt) end
    runtime.Focus.syncDevice(self.nav,self:activeId());local input=self.game.input
    if self.viewKind=="text" then
      if self:choosing() and (input:wasPressed("left") or input:wasPressed("right")) then self.choiceIndex=self.choiceIndex==1 and 2 or 1
      elseif input:wasPressed("up") then self:scrollReader(-72)
      elseif input:wasPressed("down") then self:scrollReader(72)
      elseif input:wasPressed("left") then self:scrollReader(-self:readerPageStep())
      elseif input:wasPressed("right") then self:scrollReader(self:readerPageStep())
      elseif input:wasPressed("a") then self:activate()
      elseif input:wasPressed("b") then self:back() end
      runtime.Focus.navigation(self.nav,self:activeId());return
    end
    if input:wasPressed("up") or input:wasPressed("left") then self:move(-1)
    elseif input:wasPressed("down") or input:wasPressed("right") then self:move(1)
    elseif input:wasPressed("a") then self:activate()
    elseif input:wasPressed("b") then self:back() end
  end
  return Screen
end

function Extension.wrap(runtime,game,state,context)
  local kind=type(state)=="table" and ((type(state.items)=="table" and type(state.title)=="string" and "list") or (type(state.pages)=="table" and state.pageIndex~=nil and not state.auto and not state.stay and "text"))
  if not kind then return state end
  runtime.ExtensionScreen=runtime.ExtensionScreen or Extension.factory(runtime)
  return runtime.ExtensionScreen.new(game,state,context)
end

return Extension
