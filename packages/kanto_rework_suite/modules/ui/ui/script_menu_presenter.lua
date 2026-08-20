-- Generic Wide KRS presentation for engine-owned script ListMenus.
-- The native ListMenu remains the authoritative update/callback/timing owner;
-- this presenter only mirrors its pixels and pointer actions. This is the
-- shared pattern for elevator/fossil/Game Corner/Safari/trade/scripted menus
-- that do not have a dedicated KRS screen yet.
return function(runtime)
  local ListMenu=require('src.ui.ListMenu')
  local P={}
  local function isList(v) return type(v)=='table' and getmetatable(v)==ListMenu end
  local function stackStates(game) return game and game.stack and game.stack.states or {} end
  local function hasOverworldOwner(game,state)
    if not (game and game.overworld and state) then return false end
    for _,v in ipairs(stackStates(game)) do
      if v==state then break end
      if v==game.overworld then return true end
    end
    return false
  end
  local function excluded(state)
    local kind=tostring(state and state.kind or '')
    if state and state.__kantoPocketState then return true end
    if kind=='shop_buy' or kind=='shop_sell' then return true end
    if kind:find('pc_box_',1,true) or kind:find('pc_item_',1,true) then return true end
    return false
  end
  function P.handles(game,state,viewport)
    return runtime.Layout.isWide(viewport or runtime.viewport)
      and isList(state) and state.script==true and not excluded(state)
      and hasOverworldOwner(game,state)
  end
  local function label(row)
    if type(row)=='table' then return tostring(row.label or row.name or row.text or row.value or '') end
    return tostring(row or '')
  end
  local function right(row)
    return type(row)=='table' and tostring(row.right or row.detail or '') or ''
  end
  local function selectedWindow(state,count,visible)
    if count<=visible then return 1,count end
    local index=math.max(1,math.min(count,tonumber(state.index) or 1))
    local first=math.max(1,index-math.floor(visible/2))
    first=math.min(first,count-visible+1)
    return first,math.min(count,first+visible-1)
  end
  function P.draw(game,viewport)
    local state=game and game.stack and game.stack.top and game.stack:top()
    if not P.handles(game,state,viewport) then return false end
    local m=runtime.Layout.metrics(viewport);local c=runtime.Theme.resolveAll(runtime,game);local D=runtime.Draw
    local items=state.items or {};local visible=math.min(8,math.max(1,#items))
    local rowH=62;local h=128+visible*rowH+62;local w=760;local x=1100;local y=math.max(126,math.floor((1080-h)/2))
    runtime.scriptMenuRects={}
    love.graphics.push('all');love.graphics.origin()
    local ok, res = pcall(function()
      D.panel(m,x,y,w,h,18,c.panel,c.borderStrong or c.border)
      D.text(runtime,m,'SCRIPTED CHOICE',x+28,y+24,10,c.textSecondary,{weight='bold'})
      D.text(runtime,m,tostring(state.title or state.prompt or 'CHOOSE AN OPTION'):upper(),x+28,y+52,24,c.text,{weight='bold',width=w-56})
      local first,last=selectedWindow(state,#items,visible)
      local yy=y+108
      for i=first,last do
        local row=items[i];local r={x=x+28,y=yy,w=w-56,h=50};runtime.scriptMenuRects[i]=r
        local focused=i==(tonumber(state.index) or 1);local hovered=runtime.scriptMenuHover==i;local pressed=runtime.scriptMenuPressed==i
        local fill=pressed and (c.inverseRaised or c.inverse) or focused and c.inverse or hovered and c.subtle or c.panel
        local border=focused and c.focus or hovered and c.focus or c.border
        D.panel(m,r.x,r.y,r.w,r.h,10,fill,border)
        if focused then D.roundRect(m,'fill',r.x+10,r.y+10,5,r.h-20,2.5,c.focus) end
        D.text(runtime,m,label(row),r.x+26,r.y+16,14,focused and c.textInverse or c.text,{weight='semibold',width=r.w-160})
        local rt=right(row);if rt~='' then D.text(runtime,m,rt,r.x+r.w-132,r.y+16,12,focused and c.faint or c.textSecondary,{weight='semibold',width=108,align='right'}) end
        yy=yy+rowH
      end
      D.line(m,x+28,y+h-58,x+w-28,y+h-58,c.border,1)
      D.text(runtime,m,'↑↓',x+28,y+h-42,10,c.text,{weight='bold'});D.text(runtime,m,'SELECT',x+70,y+h-42,10,c.textSecondary,{weight='semibold'})
      D.text(runtime,m,'ENTER',x+170,y+h-42,10,c.text,{weight='bold'});D.text(runtime,m,'CONFIRM',x+230,y+h-42,10,c.textSecondary,{weight='semibold'})
      D.text(runtime,m,'A',x+330,y+h-42,10,c.text,{weight='bold'});D.text(runtime,m,'BACK',x+360,y+h-42,10,c.textSecondary,{weight='semibold'})
      return true
    end)
    love.graphics.pop()
    if not ok then return nil, res end
    return res == true
  end
  function P.pointer(game,event,lx,ly)
    local state=game and game.stack and game.stack.top and game.stack:top()
    if not P.handles(game,state,runtime.viewport) then return false end
    if event.phase=='moved' then
      runtime.scriptMenuHover=nil
      for i,r in pairs(runtime.scriptMenuRects or {}) do if runtime.Layout.contains(lx,ly,r) then runtime.scriptMenuHover=i;break end end
      return true
    end
    if event.phase=='pressed' then
      if event.source=='mouse' and event.button==2 then runtime.mod.input:tap(game,'b');return true end
      if event.source=='touch' or event.button==1 then
        for i,r in pairs(runtime.scriptMenuRects or {}) do
          if runtime.Layout.contains(lx,ly,r) then state.index=i;runtime.scriptMenuPressed=i;runtime.mod.input:tap(game,'a');return true end
        end
      end
      return true
    end
    if event.phase=='released' or event.phase=='cancelled' then runtime.scriptMenuPressed=nil;return true end
    return true
  end
  function P.wheel(game,dy)
    local state=game and game.stack and game.stack.top and game.stack:top()
    if not P.handles(game,state,runtime.viewport) or dy==0 then return false end
    runtime.mod.input:tap(game,dy>0 and 'down' or 'up');return true
  end
  return P
end
