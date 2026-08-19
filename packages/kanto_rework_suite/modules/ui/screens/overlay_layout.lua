local Module={}
function Module.factory(runtime)
  local Core=assert(runtime.Core);local Screen={};Screen.__index=Screen;Screen.isOpaque=false
  function Screen.new(game)
    local st=Core.overlayState()
    return setmetatable({game=game,kind="overlay_layout",focused=st.focused or "encounters"},Screen)
  end
  function Screen:isWide() return runtime.Layout.isWide(runtime.viewport) end
  function Screen:visibleIds()
    local ids=type(Core.visibleOverlayIds)=="function" and Core.visibleOverlayIds() or runtime.ModularOverlays.enabledIds(self.game)
    return #ids>0 and ids or runtime.ModularOverlays.enabledIds(self.game)
  end
  function Screen:cycle(step)
    local ids=self:visibleIds();local at=1
    for i,id in ipairs(ids) do if id==self.focused then at=i break end end
    at=(at-1+(step or 1))%#ids+1;self.focused=ids[at];Core.setOverlayFocus(self.focused)
  end
  function Screen:update()
    local st=Core.overlayState()
    if not(st.visible and runtime.overlayLayoutMode==true and not st.contextMode) then
      if self.game.stack:top()==self then self.game.stack:pop() end;return
    end
    self.focused=st.focused or self.focused
    local widget=st.widgets and st.widgets[self.focused];local input=self.game.input;local moveStep=.012;local sizeStep=.05
    if input:wasPressed("select") then self:cycle(1)
    elseif input:wasPressed("start") then Core.setOverlayCollapsed(self.focused,not(widget and widget.collapsed==true),true)
    elseif input:wasPressed("a") then
      if widget and widget.collapsed then Core.setOverlayCollapsed(self.focused,false,true)
      else runtime.overlayLayoutOperation=runtime.overlayLayoutOperation=="resize" and "move" or "resize" end
    elseif input:wasPressed("b") then runtime.overlayLayoutMode=false
    elseif widget and widget.collapsed then
      if input:wasPressed("left") then Core.moveOverlay(self.focused,-moveStep,0)
      elseif input:wasPressed("right") then Core.moveOverlay(self.focused,moveStep,0)
      elseif input:wasPressed("up") then Core.moveOverlay(self.focused,0,-moveStep)
      elseif input:wasPressed("down") then Core.moveOverlay(self.focused,0,moveStep) end
    elseif runtime.overlayLayoutOperation=="resize" then
      if input:wasPressed("left") then Core.setOverlaySize(self.focused,(widget.width or 1)-sizeStep,widget.height or 1,true)
      elseif input:wasPressed("right") then Core.setOverlaySize(self.focused,(widget.width or 1)+sizeStep,widget.height or 1,true)
      elseif input:wasPressed("up") then Core.setOverlaySize(self.focused,widget.width or 1,(widget.height or 1)-sizeStep,true)
      elseif input:wasPressed("down") then Core.setOverlaySize(self.focused,widget.width or 1,(widget.height or 1)+sizeStep,true) end
    else
      if input:wasPressed("left") then Core.moveOverlay(self.focused,-moveStep,0)
      elseif input:wasPressed("right") then Core.moveOverlay(self.focused,moveStep,0)
      elseif input:wasPressed("up") then Core.moveOverlay(self.focused,0,-moveStep)
      elseif input:wasPressed("down") then Core.moveOverlay(self.focused,0,moveStep) end
    end
  end
  function Screen:pointerEvent() return true end
  function Screen:draw() end
  return Screen
end
return Module
