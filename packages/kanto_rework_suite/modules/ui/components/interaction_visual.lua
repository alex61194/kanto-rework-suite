-- Visual feedback for Core-owned generic interaction state.
return function(deps)
  local Core=assert(deps.Core);local Palette=assert(deps.Palette)
  local V={}
  function V.draw(game)
    if type(Core.interactionModel)~="function" or not (love and love.graphics) then return false end
    local ok,m=pcall(Core.interactionModel);if not ok or type(m)~="table" or not m.active then return false end
    if m.kind~="party_drag" then return false end
    local c=Palette.resolve(game).colors;local x,y=(m.x or 0)+14,(m.y or 0)+14
    love.graphics.push("all");love.graphics.origin();love.graphics.setColor(c.header);love.graphics.rectangle("fill",x,y,190,62,8);love.graphics.setColor(c.border);love.graphics.rectangle("line",x,y,190,62,8);love.graphics.setColor(c.textInverse);love.graphics.print(tostring(m.name or "POKÉMON"),x+12,y+10);love.graphics.print(("MOVE %d > %d"):format(m.from or 0,m.to or m.from or 0),x+12,y+34);love.graphics.pop();return true
  end
  return V
end
