-- Wide KRS presentation for the engine-owned NamingScreen. The native state
-- remains authoritative for glyphs, limits, presets and onDone callbacks.
return function(runtime)
  local NamingScreen=require('src.ui.NamingScreen')
  local Menu=require('src.ui.Menu')
  local P={}
  local function ismt(v,t) return type(v)=='table' and getmetatable(v)==t end
  local function states(game) return game and game.stack and game.stack.states or {} end
  local function context(game)
    local ss=states(game);local top=ss[#ss]
    if ismt(top,NamingScreen) then return top,top,nil end
    if ismt(top,Menu) and ismt(ss[#ss-1],NamingScreen) then return ss[#ss-1],top,top end
    return nil,top,nil
  end
  function P.handles(game,viewport)
    return select(1,context(game))~=nil and runtime.Layout.isWide(viewport or runtime.viewport)
  end
  local function who(state)
    local t=tostring(state and state.title or ''):upper()
    if t:find('HIS NAME',1,true) or t:find('RIVAL',1,true) then return 'NOMBRE DEL RIVAL','RIVAL' end
    if t:find('BOX',1,true) then return 'NOMBRE DE LA CAJA','CAJA' end
    if t:find('POK',1,true) then return 'MOTE DEL POKÉMON','POKÉMON' end
    return 'NOMBRE DEL JUGADOR','JUGADOR'
  end
  local function shell(m,c,title,sub)
    local D=runtime.Draw
    D.roundRect(m,'fill',0,0,1920,1080,0,c.canvas)
    D.roundRect(m,'fill',0,0,1920,88,0,c.inverse)
    D.text(runtime,m,'KANTO JOURNAL',32,18,24,c.textInverse,{weight='bold'})
    D.text(runtime,m,'MENÚ PRINCIPAL',32,54,11,c.textInverse,{weight='bold',alpha=.72})
    D.text(runtime,m,title,0,26,16,c.textInverse,{weight='semibold',width=1920,align='center'})
    D.text(runtime,m,sub,1570,28,12,c.textInverse,{weight='semibold',width=318,align='right',alpha=.76})
    D.roundRect(m,'fill',0,1016,1920,64,0,c.inverse)
  end
  local function footer(m,c,prompts)
    local D=runtime.Draw;local x=32
    for _,p in ipairs(prompts) do D.text(runtime,m,p[1],x,1037,12,c.textInverse,{weight='bold'});D.text(runtime,m,p[2],x+72,1038,11,c.textInverse,{alpha=.72});x=x+230 end
    local label=runtime.Footer and runtime.Footer.deviceLabel and runtime.Footer.deviceLabel() or 'TECLADO + RATÓN'
    D.text(runtime,m,label,1640,1038,12,c.textInverse,{weight='semibold',width=248,align='right'})
  end
  local function nameString(state)
    local value=table.concat(state.glyphs or {})
    local slots={}
    for i=1,state.maxLen or 7 do slots[i]=(state.glyphs and state.glyphs[i]) or '—' end
    return value,table.concat(slots,'  ')
  end
  local function drawPresets(game,m,c,state,menu)
    local D=runtime.Draw;local title,sub=who(state);shell(m,c,title,sub)
    D.text(runtime,m,'ELIGE UN NOMBRE',280,174,11,c.textSecondary,{weight='bold'})
    D.text(runtime,m,'Elige un nombre predefinido o introduce uno nuevo.',280,208,30,c.text,{weight='bold'})
    runtime.namingRects={}
    local items=menu.items or {};local y=308
    local hover=runtime.namingPresetHover
    local selected=menu.__krsSelectedIndex
    local pressed=runtime.namingPresetPressed
    local aDown=game and game.input and type(game.input.isDown)=='function' and game.input:isDown('a')
    for i,item in ipairs(items) do
      local r={x=280,y=y+(i-1)*92,w=760,h=72};runtime.namingRects[i]=r
      local focused=i==(menu.index or 1)
      local isPressed=(pressed==i) or (focused and aDown)
      local isSelected=selected==i
      local isHover=hover==i and not focused
      local fill=c.panel;local border=c.border;local textColor=c.text
      if isPressed then fill=c.inverse;border=c.focus;textColor=c.textInverse
      elseif isSelected then fill=c.subtle;border=c.selected
      elseif focused then border=c.focus
      elseif isHover then border=c.selected end
      local inset=isPressed and 2 or 0
      D.panel(m,r.x+inset,r.y+inset,r.w-2*inset,r.h-2*inset,12,fill,border)
      -- Shape/text cues keep the state readable without depending on colour.
      if focused then D.text(runtime,m,'▶',r.x+18,r.y+22,14,textColor,{weight='bold'}) end
      if isSelected then D.text(runtime,m,'✓',r.x+r.w-42,r.y+21,17,textColor,{weight='bold'}) end
      D.text(runtime,m,tostring(item.label or ''),r.x+48,r.y+22,17,textColor,{weight='semibold'})
    end
    D.panel(m,1110,308,530,350,16,c.panel,c.border)
    D.text(runtime,m,'ENTRADA',1142,338,10,c.textSecondary,{weight='bold'})
    D.text(runtime,m,'NUEVO NOMBRE',1142,380,24,c.text,{weight='bold'})
    D.text(runtime,m,'El teclado permite escribir directamente mientras el campo está activo. Con mando o táctil se usa la cuadrícula de caracteres.',1142,430,15,c.textSecondary,{width=458})
    footer(m,c,{{'↑↓','SELECCIONAR'},{'ENTER','ABRIR'},{'A','VOLVER'}})
  end
  local function drawGrid(m,c,state)
    local D=runtime.Draw;local title,sub=who(state);shell(m,c,title,sub)
    local value,slots=nameString(state)
    D.text(runtime,m,'NOMBRE ACTUAL',176,146,10,c.textSecondary,{weight='bold'})
    D.panel(m,176,178,1568,116,14,c.panel,c.borderStrong)
    D.text(runtime,m,value~='' and value or 'ESCRIBE UN NOMBRE',208,204,32,value~='' and c.text or c.textSecondary,{weight='bold'})
    D.text(runtime,m,slots,208,252,13,c.textSecondary,{weight='semibold'})
    local grid=state:grid();runtime.namingRects={};local startX,startY=176,348;local cellW,cellH,gx,gy=154,72,14,14
    local pointerIndex=0
    for r,row in ipairs(grid) do
      if #row==1 then
        local rect={x=startX,y=startY+(r-1)*(cellH+gy),w=9*cellW+8*gx,h=cellH,row=r,col=1};pointerIndex=pointerIndex+1;runtime.namingRects[pointerIndex]=rect
        local focus=(state.row==r)
        D.panel(m,rect.x,rect.y,rect.w,rect.h,10,focus and c.inverse or c.panel,focus and c.inverse or c.border)
        D.text(runtime,m,tostring(row[1]),rect.x,rect.y+23,15,focus and c.textInverse or c.text,{weight='semibold',width=rect.w,align='center'})
      else
        for col,cell in ipairs(row) do
          local rect={x=startX+(col-1)*(cellW+gx),y=startY+(r-1)*(cellH+gy),w=cellW,h=cellH,row=r,col=col};pointerIndex=pointerIndex+1;runtime.namingRects[pointerIndex]=rect
          local focus=state.row==r and state.col==col
          D.panel(m,rect.x,rect.y,rect.w,rect.h,10,focus and c.inverse or c.panel,focus and c.inverse or c.border)
          D.text(runtime,m,tostring(cell),rect.x,rect.y+22,16,focus and c.textInverse or c.text,{weight='semibold',width=rect.w,align='center'})
        end
      end
    end
    footer(m,c,{{'TECLADO','ESCRIBIR'},{'BORRAR','BORRAR'},{'ENTER','CONFIRMAR'},{'A','VOLVER'}})
  end
  function P.draw(game,viewport)
    local state,top,preset=context(game);if not state or not runtime.Layout.isWide(viewport) then return false end
    local m=runtime.Layout.metrics(viewport);local c=runtime.Theme.resolveAll(runtime,game)
    love.graphics.push('all');love.graphics.origin()
    if preset then drawPresets(game,m,c,state,preset) else drawGrid(m,c,state) end
    love.graphics.pop();return true
  end
  function P.pointer(game,event,lx,ly)
    local state,top,preset=context(game);if not state then return false end
    if event.phase=='pressed' and event.source=='mouse' and event.button==2 then
      if preset then runtime.mod.input:tap(game,'b')
      elseif state.presets and #state.presets>0 then state:enter() end
      return true
    end
    if event.phase=='moved' then
      if preset then
        runtime.namingPresetHover=nil
        for i,r in ipairs(runtime.namingRects or {}) do if runtime.Layout.contains(lx,ly,r) then runtime.namingPresetHover=i;break end end
      else
        for _,r in ipairs(runtime.namingRects or {}) do if runtime.Layout.contains(lx,ly,r) then state.row,state.col=r.row,r.col;break end end
      end
      return true
    end
    if event.phase=='pressed' and (event.source=='touch' or event.button==1) then
      if preset then
        for i,r in ipairs(runtime.namingRects or {}) do if runtime.Layout.contains(lx,ly,r) then
          preset.index=i;preset.__krsSelectedIndex=i;runtime.namingPresetPressed=i
          runtime.mod.input:tap(game,'a');return true
        end end
      else
        for _,r in ipairs(runtime.namingRects or {}) do if runtime.Layout.contains(lx,ly,r) then state.row,state.col=r.row,r.col;runtime.mod.input:tap(game,'a');return true end end
      end
      return true
    end
    if event.phase=='released' or event.phase=='cancelled' then runtime.namingPresetPressed=nil;return true end
    return false
  end
  return P
end
