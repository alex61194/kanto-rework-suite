local Module={}
function Module.factory(runtime)
  local Core=assert(runtime.Core);local Screen={};Screen.__index=Screen;Screen.isOpaque=false
  function Screen.new(game)
    local st=Core.overlayState();return setmetatable({game=game,kind="overlay_context",focused=st.focused or "encounters"},Screen)
  end
  function Screen:isWide() return runtime.Layout.isWide(runtime.viewport) end
  function Screen:enabled() return runtime.ModularOverlays.enabledIds(self.game) end
  function Screen:cycleMode(step)
    local modes={"overworld","battle","both","none"};local st=Core.overlayState();local widget=st.widgets and st.widgets[self.focused] or {};local at=1
    for i,value in ipairs(modes) do if value==widget.mode then at=i break end end
    at=(at-1+(step or 1))%#modes+1
    return Core.setOverlayMode(self.focused,modes[at],true)
  end
  function Screen:cycleWidget(step)
    local ids=self:enabled();local at=1;for i,id in ipairs(ids) do if id==self.focused then at=i break end end
    at=(at-1+(step or 1))%#ids+1;self.focused=ids[at];Core.setOverlayFocus(self.focused)
  end
  function Screen:update()
    local st=Core.overlayState();if not(st.visible and st.contextMode) then if self.game.stack:top()==self then self.game.stack:pop() end;return end
    self.focused=st.focused or self.focused;local input=self.game.input
    if input:wasPressed("left") then self:cycleMode(-1)
    elseif input:wasPressed("right") or input:wasPressed("a") then self:cycleMode(1)
    elseif input:wasPressed("up") then self:cycleWidget(-1)
    elseif input:wasPressed("down") or input:wasPressed("select") then self:cycleWidget(1)
    elseif input:wasPressed("b") then Core.runAction("overlay.context_toggle") end
  end
  function Screen:pointerEvent() return true end
  function Screen:draw() end
  return Screen
end
return Module
