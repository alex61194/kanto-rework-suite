local Register={}
function Register.factory(runtime)
  local Screen={};Screen.__index=Screen
  function Screen.new(game,itemId,itemName)
    local handle=runtime.mod.find('gameplay');local gp=handle and handle.exports
    local service=gp and gp.registeredItems
    if not(service and type(service.assign)=='function') then return nil end
    return setmetatable({game=game,kind='bag_register',itemId=itemId,itemName=itemName or itemId,index=1,hover=nil,service=service,nav=runtime.Focus.new('kanto_rework_ui.bag_register')},Screen)
  end
  function Screen:isWide() return runtime.Layout.isWide(runtime.viewport) end
  function Screen:move(dx,dy)local col=(self.index-1)%3;local row=math.floor((self.index-1)/3);col=(col+dx)%3;row=(row+dy)%3;self.index=row*3+col+1;runtime.Focus.navigation(self.nav,'reg.'..self.index) end
  function Screen:activate() local ok=self.service.assign(self.index,self.itemId);if ok then self.game.stack:pop() end;return ok end
  function Screen:update(dt)local i=self.game.input;if i:wasPressed('left')then self:move(-1,0)elseif i:wasPressed('right')then self:move(1,0)elseif i:wasPressed('up')then self:move(0,-1)elseif i:wasPressed('down')then self:move(0,1)elseif i:wasPressed('a')then self:activate()elseif i:wasPressed('b')then self.game.stack:pop()end end
  function Screen:hitTest(x,y)for i,r in ipairs(runtime.bagRegisterRects or {})do if runtime.Layout.contains(x,y,r)then return i end end end
  function Screen:pointerEvent(e,x,y)if e.phase=='moved'then local i=self:hitTest(x,y);self.hover=i;if i then self.index=i end;return true elseif e.phase=='pressed'then if e.source=='mouse'and e.button==2 then self.game.stack:pop();return true end;if e.source=='touch'or e.button==1 then local i=self:hitTest(x,y);if i then self.index=i;self:activate() end;return true end end;return e.phase=='released'or e.phase=='cancelled'end
  function Screen:draw() end
  return Screen
end
return Register
