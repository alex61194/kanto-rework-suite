local Presenter={}

-- TITLE ---------------------------------------------------------------------
function Presenter.drawTitle(runtime,m,colors,screen)
  local D=runtime.Draw
  if screen.image then
    local iw,ih=screen.image:getDimensions();love.graphics.setColor(1,1,1,1)
    love.graphics.draw(screen.image,m.ox,m.oy,0,1920/iw*m.scale,1080/ih*m.scale)
  elseif not screen.nativeBackdrop then
    D.roundRect(m,"fill",0,0,1920,1080,0,colors.canvas)
  end
  if screen.version=="yellow" and screen.inner and not screen.image then
    -- Safety fallback only: if the authored Yellow plate cannot be loaded,
    -- reuse the engine-imported version-correct pieces in Wide space instead
    -- of falling back to a wrong Red/Blue plate.
    local inner=screen.inner;local scy=tonumber(inner.scy) or 0
    local yShift=-scy*4
    local function pixel(img,x,y,scale)
      if not img then return end;if img.setFilter then pcall(img.setFilter,img,'nearest','nearest') end
      love.graphics.setColor(1,1,1,1);love.graphics.draw(img,m.ox+x*m.scale,m.oy+(y+yShift)*m.scale,0,scale*m.scale,scale*m.scale)
    end
    pixel(inner.logo,710,92,4)
    if inner.showBubble then pixel(inner.yellowBubble,1030,334,4) end
    pixel(inner.yellowPikachu,940,500,4)
    local blink=type(inner.blinkOverlay)=='function' and inner:blinkOverlay() or nil
    if blink then pixel(blink,1036,564,4) end
    D.text(runtime,m,'YELLOW VERSION',930,410,22,colors.text,{weight='bold',width=420,align='center'})
  end
  -- Title actions deliberately have no shared container, tint or black bar.
  -- Their small floating footprint preserves the artwork as the title screen.
  local x,y,w,rowH,gap=112,676,352,56,12
  local rows=screen.rows or {};local perColumn=5;local columnGap=24
  runtime.titleRects={}
  for i,row in ipairs(rows) do
    local column=math.floor((i-1)/perColumn);local slot=(i-1)%perColumn
    local r={x=x+column*(w+columnGap),y=y+slot*(rowH+gap),w=w,h=rowH};runtime.titleRects[i]=r
    local id="title:"..row.id
    local hover=screen.hoverIndex and ("title:"..screen.rows[screen.hoverIndex].id) or nil
    local st=runtime.Focus.visual(screen.nav,id,screen:activeItemId(),hover)
    local fill=row.enabled and (st=="hover" and {colors.subtle[1],colors.subtle[2],colors.subtle[3],.94} or {colors.panel[1],colors.panel[2],colors.panel[3],.90}) or {colors.subtle[1],colors.subtle[2],colors.subtle[3],.72}
    D.panel(m,r.x,r.y,r.w,r.h,12,fill,row.enabled and colors.border or colors.disabled)
    if st=="focus" and row.enabled then D.focusBorder(m,r.x,r.y,r.w,r.h,12,colors.focus)
    elseif st=="hover" and row.enabled then D.roundRect(m,"line",r.x,r.y,r.w,r.h,12,colors.selected,2) end
    D.text(runtime,m,row.label,r.x+20,r.y+17,17,row.enabled and colors.text or colors.disabled,{weight="semibold"})
  end
end

local function safeValue(row,game)
  if not row or not row.value then return "" end
  local ok,v=pcall(row.value,game); return ok and v~=nil and tostring(v) or "----"
end
local function formatMoney(v)
  local s=tostring(math.floor(tonumber(v) or 0)); local sign,body=s:match("^([%-]?)(%d+)$"); body=body or s
  while true do local n,c=body:gsub("^(%d+)(%d%d%d)","%1,%2"); body=n; if c==0 then break end end
  return (sign or "")..body
end
local function playTime(seconds) local t=math.floor(seconds or 0); return ("%d:%02d"):format(math.floor(t/3600),math.floor(t/60)%60) end
local function drawMoney(runtime,m,value,x,y,w,size,color,weight)
  local D=runtime.Draw;local label=formatMoney(value);local font=D.font(runtime,m,size,weight or "medium")
  local amountW=(font and font.getWidth and font:getWidth(label) or (#label*size*.55))/math.max(.001,m.scale)
  local glyphW=size*.72;local gap=7;local start=x+w-(glyphW+gap+amountW)
  D.pokedollar(m,start,y+1,size,color)
  D.text(runtime,m,label,start+glyphW+gap,y,size,color,{weight=weight or "medium"})
end
local function drawPixelImage(m,img,x,y,w,h,quad)
  if not img then return end; local iw,ih
  if quad and quad.getViewport then local _,_,qw,qh=quad:getViewport(); iw,ih=qw,qh else iw,ih=img:getDimensions() end
  if not iw or iw<=0 or not ih or ih<=0 then return end
  local tw,th=w*m.scale,h*m.scale; local k=math.max(1,math.floor(math.min(tw/iw,th/ih))); local dw,dh=iw*k,ih*k
  love.graphics.setColor(1,1,1,1)
  local px=m.ox+x*m.scale+(tw-dw)/2; local py=m.oy+y*m.scale+(th-dh)/2
  if quad then love.graphics.draw(img,quad,px,py,0,k,k) else love.graphics.draw(img,px,py,0,k,k) end
  return px,py,dw,dh
end
-- MAIN ----------------------------------------------------------------------
local function mainState(screen,id)
  if screen.focusId==id then return "selected" end
  if screen.hoverId==id then return "hover" end
  return "default"
end
local function drawScaledImage(m,img,x,y,w,h)
  if not img then return false end
  local iw,ih=img:getDimensions();if not iw or iw<=0 or not ih or ih<=0 then return false end
  love.graphics.setColor(1,1,1,1)
  love.graphics.draw(img,m.ox+x*m.scale,m.oy+y*m.scale,0,w*m.scale/iw,h*m.scale/ih)
  return true
end
local function mainCardImage(runtime,id,state)
  runtime.mainCardImages=runtime.mainCardImages or {}
  state=(state=="hover" or state=="selected") and state or "default"
  local key=tostring(id)..":"..state
  if runtime.mainCardImages[key]~=nil then return runtime.mainCardImages[key] or nil end
  local relative="assets/menu/main/states/main_card_"..tostring(id).."_"..state..".png"
  local path=runtime.assetPath(relative)
  local image=runtime.assets:image(path,"linear");runtime.mainCardImages[key]=image or false;return image
end

local function drawMainCardCopy(runtime,m,r,entry,retro)
  local D=runtime.Draw
  local primary=r.h>=300;local secondary=r.h<=122
  local labelSize=primary and 32 or (secondary and 28 or 18)
  local labelY=r.y+r.h-64;local descY=r.y+r.h-36
  local titleWeight=retro and "bold" or "semibold"
  local titleColor=(primary or secondary) and {1,1,1,1} or {247/255,241/255,223/255,1}
  local descColor=(primary or secondary) and {1,1,1,.80} or {129/255,123/255,107/255,1}
  local descSize=secondary and 13 or 14
  D.text(runtime,m,entry.label,r.x+16,labelY,labelSize,titleColor,{weight=titleWeight,tracking=.1,width=r.w-32})
  D.clipText(runtime,m,entry.desc,r.x+16,descY,r.w-32,descSize,descColor,{weight="regular",tracking=.1,width=r.w-32})
end

local function mainShadowSamples(runtime)
  local elevation=runtime.Core and runtime.Core.elevation
  if elevation and type(elevation.shadowSamples)=="function" and type(elevation.cardShadow)=="function" then
    return elevation.shadowSamples(elevation.cardShadow())
  end
  return {{offsetX=0,offsetY=4,spread=0,color={0,0,0,.4}}}
end
local function drawMainCard(runtime,m,colors,screen,id,r)
  local D=runtime.Draw;local entry=screen.entriesById[id];if not entry then return end
  local state=mainState(screen,id);runtime.mainCardStates=runtime.mainCardStates or {};runtime.mainCardStates[id]=state
  if entry.enabled and state~="default" then D.dropShadow(m,r.x,r.y,r.w,r.h,12,mainShadowSamples(runtime)) end
  local image=mainCardImage(runtime,id,state)
  -- Each bitmap is the exact textless Figma variant for this card and state.
  -- Runtime only supplies localized copy and the external elevation shadow.
  D.roundRect(m,"fill",r.x,r.y,r.w,r.h,12,colors.inverse)
  D.withRoundedClip(m,r.x,r.y,r.w,r.h,12,function()
    if not drawScaledImage(m,image,r.x,r.y,r.w,r.h) then
      D.icon(runtime,m,entry.icon,r.x+16,r.y+16,40,colors)
      D.text(runtime,m,entry.label,r.x+16,r.y+r.h-60,math.min(32,math.max(18,r.h*.13)),colors.textInverse,{weight="semibold"})
      D.text(runtime,m,entry.desc,r.x+16,r.y+r.h-30,math.min(14,math.max(11,r.h*.07)),colors.faint,{width=r.w-32})
    else
      drawMainCardCopy(runtime,m,r,entry,colors.themeId=="retro")
    end
    if not entry.enabled then D.roundRect(m,"fill",r.x,r.y,r.w,r.h,0,{0,0,0,.58}) end
  end)
  if not entry.enabled then
    D.text(runtime,m,"UNAVAILABLE",r.x,r.y+r.h/2-10,13,colors.textInverse,{weight="bold",width=r.w,align="center"})
  end
end
local function drawFooterPrompt(runtime,m,colors,key,label,x)
  local D=runtime.Draw;D.text(runtime,m,key,x,1037,14,colors.textInverse,{weight="semibold"})
  local f=D.font(runtime,m,14,"semibold");local keyWidth=f and f:getWidth(key)/m.scale or 52
  D.text(runtime,m,label,x+keyWidth+8,1038,13,colors.textInverse,{weight="medium",alpha=.76})
end
function Presenter.drawMain(runtime,m,colors,screen)
  local D=runtime.Draw
  runtime.Header.draw(runtime,m,D,colors,screen.game,"MENÚ PRINCIPAL")
  D.roundRect(m,"fill",0,88,1920,928,0,colors.canvas)
  local d=screen:trainerData()
  local tx,ty,tw,th=64,120,400,864
  D.panel(m,tx,ty,tw,th,20,colors.panel,colors.border)
  D.text(runtime,m,"FICHA DE ENTRENADOR",tx+24,ty+24,11,colors.textSecondary,{weight="bold",tracking=1})
  D.text(runtime,m,d.name,tx+24,ty+44,32,colors.text,{weight="bold",tracking=-.5})
  D.panel(m,tx+24,ty+104,352,280,14,colors.subtle,nil)
  local portrait=runtime.assets:trainerPortrait(d);drawPixelImage(m,portrait,tx+144,ty+106,112,276)
  D.text(runtime,m,"MEDALLAS",tx+24,ty+406,11,colors.textSecondary,{weight="bold",tracking=1})
  D.text(runtime,m,("%d / 8"):format(d.badgeCount),tx+296,ty+404,14,colors.text,{weight="semibold",tracking=.3,width=56,align="right"})
  local badgeSheet=runtime.assets:badgeSheet(d)
  for index=1,8 do
    local quad=badgeSheet and runtime.assets:badgeQuad(badgeSheet,index,d.badges[index] and true or false) or nil
    if badgeSheet and quad then drawPixelImage(m,badgeSheet,tx+24+(index-1)*40,ty+432,32,32,quad) end
  end
  D.line(m,tx+24,ty+484,tx+376,ty+484,colors.border,1)
  D.text(runtime,m,"POKÉDEX",tx+24,ty+507,14,colors.textSecondary,{weight="semibold",tracking=.3})
  D.text(runtime,m,("%d atrapados • %d vistos"):format(d.owned,d.seen),tx+150,ty+505,16,colors.text,{weight="medium",tracking=.1,width=202,align="right"})
  D.text(runtime,m,"DINERO",tx+24,ty+543,14,colors.textSecondary,{weight="semibold",tracking=.3})
  drawMoney(runtime,m,d.money,tx+200,ty+541,152,16,colors.text,"medium")
  D.line(m,tx+24,ty+585,tx+376,ty+585,colors.border,1)
  D.text(runtime,m,"OBJETIVO ACTUAL",tx+24,ty+606,11,colors.textSecondary,{weight="bold",tracking=1})
  D.text(runtime,m,d.objective,tx+24,ty+630,16,colors.text,{weight="medium",tracking=.1,width=352})

  local cx,cy,cw,ch=488,120,1368,864
  D.panel(m,cx,cy,cw,ch,20,colors.elevated,colors.border)
  D.text(runtime,m,"MENÚ PRINCIPAL",cx+24,cy+24,32,colors.text,{weight="bold",tracking=-.5})
  D.text(runtime,m,"Explora la región de Kanto o gestiona la configuración de tu aventura.",cx+24,cy+68,14,colors.textSecondary,{weight="regular",tracking=.1})
  D.text(runtime,m,"AVENTURA",cx+24,224,11,colors.textSecondary,{weight="bold",tracking=1,width=1320,align="center"})
  D.text(runtime,m,"CONEXIÓN",cx+24,620,11,colors.textSecondary,{weight="bold",tracking=1,width=1320,align="center"})
  D.text(runtime,m,"SISTEMA",cx+24,784,11,colors.textSecondary,{weight="bold",tracking=1,width=1320,align="center"})

  runtime.mainRects={};runtime.mainCardStates={}
  local fixed={
    pokedex={x=512,y=252,w=310,h=352},pokemon={x=846,y=252,w=310,h=352},
    bag={x=1180,y=252,w=312,h=351},pc={x=1516,y=252,w=312,h=351},
    save={x=512,y=648,w=648,h=120},link={x=1184,y=648,w=648,h=120},
  }
  for _,id in ipairs({"pokedex","pokemon","bag","pc","save","link"}) do local r=fixed[id];runtime.mainRects[id]=r;drawMainCard(runtime,m,colors,screen,id,r) end
  local system=screen.navRows and screen.navRows[3] or {"options","mods","close"};local count=math.max(1,#system)
  local gap=24;local width=count==3 and 424 or (1320-gap*(count-1))/count
  for index,id in ipairs(system) do local r={x=512+(index-1)*(width+gap),y=812,w=width,h=136};runtime.mainRects[id]=r;drawMainCard(runtime,m,colors,screen,id,r) end

  runtime.Footer.menuDraw(runtime,m,D,colors,screen.game,"main")
end

-- SAVE / LOAD ---------------------------------------------------------------
local function saveSlotState(screen,i)
  if screen.confirmDelete or screen.confirmSave or screen.saveNotice then return i==screen.index and "selected" or "default" end
  if i==screen.index then return "focus" end
  if screen.hover==i then return "hover" end
  return "default"
end
local function drawSavePartyIcon(runtime,m,slot,index,x,y,size)
  local mon=slot and slot.raw and slot.raw.party and slot.raw.party[index]
  if not mon then return false end
  -- Save uses the exact same KRS two-frame Gen5 icon family as Party/PC.
  -- This context is intentionally presentation-only: Battle Scale / Real Size
  -- are never read here.
  if runtime.Graphics and type(runtime.Graphics.draw)=='function' then
    love.graphics.push('all')
    love.graphics.translate(m.ox,m.oy);love.graphics.scale(m.scale,m.scale)
    local ok,drawn=pcall(runtime.Graphics.draw,runtime.Graphics,'save.icon',runtime.game or slot.game,mon,x,y,size,size)
    love.graphics.pop()
    if ok and drawn==true then return true end
  end
  local ok,PartyMenu=pcall(require,"src.ui.PartyMenu")
  if not(ok and PartyMenu and type(PartyMenu.drawIcon)=="function") then return false end
  love.graphics.push("all")
  love.graphics.translate(m.ox+x*m.scale,m.oy+y*m.scale)
  local k=(size/16)*m.scale;love.graphics.scale(k,k)
  local worked=pcall(PartyMenu.drawIcon,runtime.game or slot.game,mon,0,0,false,0,false)
  love.graphics.pop();return worked
end
local function drawSaveParty(runtime,m,colors,slot,x,y,w)
  local D=runtime.Draw;local party=slot.party or {};local cols=3;local cellW=(w-12)/3
  D.text(runtime,m,"ACTIVE PARTY",x,y,10,slot.exists and colors.textSecondary or colors.disabled,{weight="bold"})
  for i=1,6 do local p=party[i];local row=math.floor((i-1)/cols);local col=(i-1)%cols;local rx=x+col*(cellW+6);local ry=y+24+row*56
    D.roundRect(m,"fill",rx,ry,cellW,48,6,slot.exists and colors.subtle or colors.elevated)
    if p then
      drawSavePartyIcon(runtime,m,slot,i,rx+6,ry+8,32)
      D.clipText(runtime,m,p.name or tostring(p.species or "POKéMON"),rx+44,ry+8,cellW-50,9,colors.text,{weight="semibold"})
      D.text(runtime,m,("Lv. %s"):format(tostring(p.level or "—")),rx+44,ry+26,8,colors.textSecondary,{width=cellW-50})
    end
  end
end
function Presenter.drawSaveSlots(runtime,m,colors,screen)
  local D=runtime.Draw;local title=screen.mode=="load" and "CARGAR" or "GUARDAR"
  runtime.Header.draw(runtime,m,D,colors,screen.game,title)
  D.roundRect(m,"fill",0,88,1920,928,0,colors.canvas)
  runtime.saveSlotRects={};local gap=64;local x=64;local y=120;local w=400;local h=856
  for i=1,4 do local slot=screen.slots[i] or {exists=false,party={}};local sx=x+(i-1)*(w+gap);local st=saveSlotState(screen,i);runtime.saveSlotRects[i]={x=sx,y=y,w=w,h=h}
    local filled=slot.exists==true;local fill=st=="focus" and colors.elevated or colors.inverse
    D.panel(m,sx,y,w,h,18,fill,st=="focus" and colors.focus or colors.borderStrong)
    if st=="focus" then D.focusBorder(m,sx,y,w,h,18,colors.focus) end
    local tc=st=="focus" and colors.text or colors.textInverse;local mc=st=="focus" and colors.textSecondary or colors.faint
    D.text(runtime,m,("RANURA %02d"):format(i),sx+24,y+24,11,mc,{weight="bold"})
    D.text(runtime,m,filled and (slot.name or "ROJO") or "VACÍA",sx+24,y+58,28,tc,{weight="bold"})
    if filled then
      local trainer=type(runtime.Core.trainerModel)=="function" and runtime.Core.trainerModel() or nil
      local portrait=runtime.assets:trainerPortrait(trainer or {name=slot.name});drawPixelImage(m,portrait,sx+144,y+106,112,276)
      D.text(runtime,m,"MEDALLAS",sx+24,y+402,12,mc,{weight="semibold"});D.text(runtime,m,("%d / 8"):format(slot.badges or 0),sx+264,y+402,14,tc,{weight="semibold",width=112,align="right"})
      D.text(runtime,m,"POKÉDEX",sx+24,y+438,12,mc,{weight="semibold"});D.text(runtime,m,("%d atrapados • %d vistos"):format(slot.owned or 0,slot.seen or 0),sx+130,y+438,13,tc,{weight="medium",width=246,align="right"})
      D.text(runtime,m,"DINERO",sx+24,y+474,12,mc,{weight="semibold"});drawMoney(runtime,m,slot.money,sx+240,y+474,136,14,tc,"medium")
      D.mapPin(m,sx+31,y+532,14,mc);D.text(runtime,m,tostring(slot.location or "KANTO"),sx+48,y+520,14,mc,{weight="semibold",width=w-72})
      D.text(runtime,m,slot.timeText or "0:00:00",sx+24,y+558,11,mc,{width=150});D.text(runtime,m,slot.dateText or "",sx+196,y+558,11,mc,{width=180,align="right"})
      drawSaveParty(runtime,m,colors,slot,sx+24,y+610,w-48)
    else
      D.roundRect(m,"fill",sx+24,y+112,w-48,260,12,st=="focus" and colors.subtle or {colors.textSecondary[1],colors.textSecondary[2],colors.textSecondary[3],.22})
      D.text(runtime,m,"RANURA VACÍA",sx+24,y+226,18,mc,{weight="semibold",width=w-48,align="center"});D.text(runtime,m,"Sin datos de guardado",sx+24,y+256,12,mc,{width=w-48,align="center"})
      D.text(runtime,m,"MEDALLAS",sx+24,y+402,12,mc,{weight="semibold"});D.text(runtime,m,"0 / 8",sx+264,y+402,14,tc,{weight="semibold",width=112,align="right"})
      D.text(runtime,m,"POKÉDEX",sx+24,y+438,12,mc,{weight="semibold"});D.text(runtime,m,"0 atrapados • 0 vistos",sx+130,y+438,13,tc,{width=246,align="right"})
    end
  end
  if screen.confirmDelete then
    D.roundRect(m,"fill",0,0,1920,1080,0,{0,0,0,.42});local bx,by,bw,bh=786,458,348,170;D.panel(m,bx,by,bw,bh,14,colors.panel,colors.borderStrong)
    D.text(runtime,m,("¿BORRAR RANURA %d?"):format(screen.index),bx+24,by+24,18,colors.danger,{weight="bold",width=bw-48,align="center"});D.text(runtime,m,"Esta acción no se puede deshacer.",bx+24,by+62,12,colors.textSecondary,{width=bw-48,align="center"})
    runtime.saveDeleteRects={cancel={x=bx+38,y=by+108,w=120,h=40},delete={x=bx+190,y=by+108,w=120,h=40}}
    for _,id in ipairs({'cancel','delete'}) do local r=runtime.saveDeleteRects[id];local foc=screen.deleteChoice==id;local label=id=='delete' and 'BORRAR' or 'CANCELAR';D.panel(m,r.x,r.y,r.w,r.h,8,id=='delete' and (foc and colors.danger or colors.subtle) or colors.subtle,foc and colors.focus or colors.border);D.text(runtime,m,label,r.x,r.y+12,12,id=='delete' and foc and colors.textInverse or colors.text,{weight="bold",width=r.w,align="center"}) end
  end
  if screen.confirmSave then
    D.roundRect(m,"fill",0,0,1920,1080,0,{0,0,0,.42});local bx,by,bw,bh=700,420,520,236;D.panel(m,bx,by,bw,bh,16,colors.panel,colors.borderStrong)
    D.text(runtime,m,"CONFIRMAR GUARDADO",bx+32,by+28,11,colors.textSecondary,{weight="bold",width=bw-64,align="center"})
    D.text(runtime,m,("¿GUARDAR EN LA RANURA %02d?"):format(screen.index),bx+32,by+62,24,colors.text,{weight="bold",width=bw-64,align="center"})
    local slot=screen.slots and screen.slots[screen.index]
    D.text(runtime,m,slot and slot.exists and "Los datos existentes en esta ranura serán reemplazados." or "Crear nuevos datos de guardado en esta ranura.",bx+32,by+106,13,colors.textSecondary,{width=bw-64,align="center"})
    runtime.saveConfirmRects={save={x=bx+48,y=by+160,w=194,h=52},cancel={x=bx+278,y=by+160,w=194,h=52}}
    for _,id in ipairs({'save','cancel'}) do local r=runtime.saveConfirmRects[id];local foc=screen.saveChoice==id;local label=id=='save' and 'GUARDAR' or 'CANCELAR';D.panel(m,r.x,r.y,r.w,r.h,9,foc and colors.subtle or colors.panel,foc and colors.focus or colors.border);D.text(runtime,m,label,r.x,r.y+17,13,colors.text,{weight="bold",width=r.w,align="center"}) end
  end
  if screen.saveNotice then
    D.roundRect(m,"fill",0,0,1920,1080,0,{0,0,0,.42});local bx,by,bw,bh=740,440,440,196;D.panel(m,bx,by,bw,bh,16,colors.panel,colors.borderStrong)
    D.text(runtime,m,screen.saveNotice.ok and "GUARDADO COMPLETADO" or "ERROR AL GUARDAR",bx+32,by+30,11,screen.saveNotice.ok and colors.success or colors.danger,{weight="bold",width=bw-64,align="center"})
    D.text(runtime,m,tostring(screen.saveNotice.text or "GUARDADO"),bx+32,by+66,24,colors.text,{weight="bold",width=bw-64,align="center"})
    runtime.saveNoticeRect={x=bx+126,y=by+126,w=188,h=46};D.panel(m,runtime.saveNoticeRect.x,runtime.saveNoticeRect.y,runtime.saveNoticeRect.w,runtime.saveNoticeRect.h,9,colors.subtle,colors.focus);D.text(runtime,m,"ACEPTAR",runtime.saveNoticeRect.x,runtime.saveNoticeRect.y+14,13,colors.text,{weight="bold",width=runtime.saveNoticeRect.w,align="center"})
  end
  -- Save/Load footer follows the active device and actual native bindings.
  -- Delete is a raw keyboard-only shortcut in SaveSlots and is hidden when a
  -- controller/touch device is active instead of advertising a fake pad key.
  D.roundRect(m,"fill",0,1016,1920,64,0,colors.inverse)
  local semantic={{navigation=true,label='SELECCIONAR'},{action='a',label=screen.mode=='load' and 'CARGAR' or 'GUARDAR'},{keyboardOnly=true,key='SUPR',label='BORRAR'},{action='select',label=screen.mode=='load' and 'GUARDAR' or 'CARGAR'},{action='b',label='VOLVER'}}
  local prompts,device=runtime.Footer.resolve(screen.game,semantic);local px=32
  for _,p in ipairs(prompts) do D.text(runtime,m,p.key,px,1037,12,colors.textInverse,{weight='bold'});local f=D.font(runtime,m,12,'bold');local kw=f:getWidth(p.key)/m.scale;D.text(runtime,m,p.label,px+kw+9,1038,11,colors.textInverse,{alpha=.72});px=px+math.max(190,kw+125) end
  D.text(runtime,m,device,1640,1038,12,colors.textInverse,{weight='semibold',width=248,align='right'})
end

-- BAG REGISTER --------------------------------------------------------------
function Presenter.drawBagRegister(runtime,m,colors,screen)
  local D=runtime.Draw
  -- Keep the Bag visible as an implied context using the standard shell, then
  -- place the registration modal centrally like the current Figma target.
  runtime.Header.draw(runtime,m,D,colors,screen.game,"MOCHILA")
  D.roundRect(m,"fill",0,88,1920,928,0,colors.canvas)
  D.roundRect(m,"fill",0,88,1920,928,0,{0,0,0,.24})
  local x,y,w,h=560,248,800,584
  D.panel(m,x,y,w,h,18,colors.panel,colors.borderStrong)
  D.text(runtime,m,"ASIGNAR ACCESO RÁPIDO",x+32,y+30,11,colors.textSecondary,{weight="bold"})
  D.text(runtime,m,tostring(screen.itemName or screen.itemId or "OBJETO"),x+32,y+66,30,colors.text,{weight="bold"})
  D.text(runtime,m,"Elige una de las nueve ranuras. Usa CTRL + número en el mapa para usarlo directamente.",x+32,y+112,13,colors.textSecondary,{width=w-64})
  runtime.bagRegisterRects={}
  local cellW,cellH,gap=220,110,20;local ox=x+50;local oy=y+180
  local registered=screen.service.list and screen.service.list() or {}
  for i=1,9 do local col=(i-1)%3;local row=math.floor((i-1)/3);local r={x=ox+col*(cellW+gap),y=oy+row*(cellH+gap),w=cellW,h=cellH};runtime.bagRegisterRects[i]=r;local focused=i==screen.index
    D.panel(m,r.x,r.y,r.w,r.h,12,focused and colors.subtle or colors.panel,focused and colors.focus or colors.border)
    if focused then D.focusBorder(m,r.x,r.y,r.w,r.h,12,colors.focus) end
    D.text(runtime,m,"CTRL + "..i,r.x+18,r.y+18,13,colors.textSecondary,{weight="bold"})
    D.text(runtime,m,registered[i] and tostring(registered[i]):gsub("_"," ") or "VACÍO",r.x+18,r.y+52,15,registered[i] and colors.text or colors.disabled,{weight="semibold",width=r.w-36})
  end
  D.roundRect(m,"fill",0,1016,1920,64,0,colors.inverse)
  local prompts,device=runtime.Footer.resolve(screen.game,{{navigation=true,label='SELECCIONAR RANURA'},{action='a',label='ASIGNAR'},{action='b',label='VOLVER'}});local px=32
  for _,p in ipairs(prompts) do D.text(runtime,m,p.key,px,1037,12,colors.textInverse,{weight='bold'});local f=D.font(runtime,m,12,'bold');local kw=f:getWidth(p.key)/m.scale;D.text(runtime,m,p.label,px+kw+9,1038,11,colors.faint);px=px+math.max(190,kw+125) end
  D.text(runtime,m,device,1640,1038,12,colors.textInverse,{weight='semibold',width=248,align='right'})
end

-- OPTIONS -------------------------------------------------------------------
local function drawScrollbar(runtime,m,colors,model)
  if not model then return end;local D=runtime.Draw
  D.roundRect(m,"fill",model.track.x,model.track.y,model.track.w,model.track.h,model.track.w/2,colors.subtle)
  D.roundRect(m,"fill",model.thumb.x,model.thumb.y,model.thumb.w,model.thumb.h,model.thumb.w/2,colors.textSecondary)
end
local function drawOptionControl(runtime,m,colors,row,meta,r,game)
  local D=runtime.Draw; local value=safeValue(row,game); local cr
  if meta.disabled then cr={x=r.x+r.w-258,y=r.y+12,w=240,h=40}; D.roundRect(m,"fill",cr.x,cr.y,cr.w,cr.h,8,colors.subtle); D.roundRect(m,"line",cr.x,cr.y,cr.w,cr.h,8,colors.border,1); D.text(runtime,m,"NO DISPONIBLE",r.x+r.w-242,r.y+23,12,colors.disabled,{weight="bold",width=208,align="center"}); return cr end
  if meta.control=="binding" then
    cr={x=r.x+r.w-430,y=r.y+5,w=412,h=r.h-10}
    D.text(runtime,m,"TECLA  "..tostring(row.keyLabel or "SIN ASIGNAR"),cr.x,cr.y+4,11,colors.textSecondary,{weight="semibold",width=190,align="right"})
    D.text(runtime,m,"MANDO  "..tostring(row.padLabel or "SIN ASIGNAR"),cr.x+202,cr.y+4,11,colors.textSecondary,{weight="semibold",width=210,align="right"})
    return cr
  end
  if meta.control=="toggle" then cr={x=r.x+r.w-100,y=r.y+8,w=82,h=48}; local u=value:upper(); D.toggle(m,r.x+r.w-84,r.y+15,not(u=="OFF" or u=="DISABLED" or u=="FALSE" or u=="0"),colors,false)
  elseif meta.control=="stepper" then cr={x=r.x+r.w-194,y=r.y+8,w=176,h=48}; D.stepper(runtime,m,r.x+r.w-194,r.y+12,176,value,colors)
  elseif meta.control=="submenu" then cr={x=r.x+r.w-84,y=r.y+8,w=66,h=48}; D.chevron(runtime,m,r.x+r.w-58,r.y+12,colors)
  else cr={x=r.x+r.w-258,y=r.y+8,w=240,h=48}; D.selector(runtime,m,r.x+r.w-258,r.y+12,240,value,colors) end
  return cr
end
function Presenter.drawOptions(runtime,m,colors,screen)
  local D=runtime.Draw
  runtime.optionCategoryRects=runtime.Header.drawHierarchy(runtime,m,D,colors,screen.game,{
    subtitle='OPCIONES',parentLabel='OPCIONES',items=screen.categories,activeIndex=screen.categoryIndex,
    focusIndex=screen.headerIndex,hoverIndex=screen.hoverCategory,focused=screen.region=='header',
  })
  D.roundRect(m,'fill',0,88,1920,928,0,colors.optionsCanvas or colors.canvas)
  local center={x=64,y=120,w=1232,h=856};local info={x=1320,y=120,w=536,h=856}
  D.roundRect(m,'fill',center.x,center.y,center.w,center.h,20,colors.optionsCenter or colors.subtle)
  D.roundRect(m,'fill',info.x,info.y,info.w,info.h,20,colors.optionsInfo or colors.panel)

  local cat=screen:category() or 'OPCIONES';local controls=screen.isControls and screen:isControls()
  D.text(runtime,m,cat,center.x+28,center.y+24,24,colors.text,{weight='bold'})
  local sub=controls and 'Acciones de teclado, mando y personalización.' or 'Ajustes disponibles en esta categoría.'
  if cat=='SYSTEM' or cat=='SISTEMA' then sub='Ventana, rendimiento y herramientas del sistema.' end
  D.text(runtime,m,sub,center.x+28,center.y+62,14,colors.textSecondary,{})

  local rows=screen:rows();runtime.optionSettingRects={};runtime.optionControlRects={}
  local settingView={x=center.x+24,y=center.y+96,w=center.w-56,h=692};local settingPitch=84;local settingRowH=68
  local oldX,oldY,oldW,oldH=love.graphics.getScissor();love.graphics.setScissor(m.ox+settingView.x*m.scale,m.oy+settingView.y*m.scale,settingView.w*m.scale,settingView.h*m.scale)
  for i,row in ipairs(rows) do
    local r={x=settingView.x,y=settingView.y+(i-1)*settingPitch-(screen.settingScrollY or 0),w=settingView.w,h=settingRowH}
    if r.y+r.h>=settingView.y and r.y<=settingView.y+settingView.h then
      runtime.optionSettingRects[i]=r
      local meta=screen.meta and screen:meta(row) or runtime.Catalog.meta(row)
      local focused=screen.region=='settings' and i==screen.settingIndex;local hov=i==screen.hoverSetting;local foc=focused and not (hov and i~=screen.settingIndex);local editing=focused and screen.editing==true
      D.panel(m,r.x,r.y,r.w,r.h,12,colors.optionsRow or colors.panel,colors.border)
      local optionFocus=colors.optionsFocus or colors.focus;if foc or editing then D.focusBorder(m,r.x,r.y,r.w,r.h,12,optionFocus) elseif hov and not meta.disabled then D.roundRect(m,'line',r.x+.5,r.y+.5,r.w-1,r.h-1,12,optionFocus,1) end
      D.text(runtime,m,row.label or row.id,r.x+17,r.y+11,16,meta.disabled and colors.disabled or colors.text,{weight='semibold'})
      if controls then D.text(runtime,m,'TECLA  '..tostring(row.keyLabel or 'SIN ASIGNAR'),r.x+17,r.y+38,12,colors.textSecondary,{weight='regular'})
      elseif meta.description and meta.description~='' then D.clipText(runtime,m,meta.description,r.x+17,r.y+38,r.w-330,12,colors.textSecondary,{}) end
      runtime.optionControlRects[i]=drawOptionControl(runtime,m,colors,row,meta,r,screen.game)
    end
  end
  if oldX then love.graphics.setScissor(oldX,oldY,oldW,oldH) else love.graphics.setScissor() end
  local total=#rows*settingPitch;local max=math.max(0,total-settingView.h);runtime.optionSettingScrollbar=nil
  if max>0 then
    local track={x=1304,y=216,w=8,h=712};local th=math.max(56,track.h*settingView.h/total);local travel=track.h-th;local sy=track.y+(screen.settingScrollY or 0)/max*travel
    runtime.optionSettingScrollbar={track=track,thumb={x=track.x,y=sy,w=track.w,h=th},hit={x=1286,y=sy,w=44,h=math.max(44,th)},maxScroll=max,travel=travel};drawScrollbar(runtime,m,colors,runtime.optionSettingScrollbar)
  end

  D.text(runtime,m,'SOBRE ESTE AJUSTE',info.x+26,info.y+22,24,colors.text,{weight='bold'})
  D.text(runtime,m,controls and 'Información sobre el acceso rápido seleccionado.' or 'Información sobre la opción seleccionada.',info.x+26,info.y+60,14,colors.textSecondary,{})
  local row=screen:focusedRow();local meta=row and (screen.meta and screen:meta(row) or runtime.Catalog.meta(row))
  if row then
    D.roundRect(m,'fill',info.x+26,info.y+102,info.w-52,330,18,colors.inverse)
    D.text(runtime,m,tostring(row.label or row.id):upper(),info.x+50,info.y+126,11,colors.textInverse,{weight='bold',alpha=.72})
    D.clipText(runtime,m,safeValue(row,screen.game),info.x+50,info.y+156,info.w-100,28,colors.textInverse,{weight='bold'})
    D.text(runtime,m,meta and meta.description or 'No hay descripción disponible para este ajuste.',info.x+50,info.y+210,15,colors.textInverse,{width=info.w-100})
    D.roundRect(m,'fill',info.x+50,info.y+330,info.w-100,72,12,colors.inverseRaised or colors.inverse)
    D.text(runtime,m,screen.editing and 'EDITANDO' or 'SELECCIONADO',info.x+66,info.y+350,11,colors.textInverse,{weight='bold'})
    D.text(runtime,m,screen.editing and 'IZQ / DER para cambiar el valor seleccionado' or 'Usa las flechas para navegar o pulsa para editar',info.x+160,info.y+350,11,colors.textInverse,{width=info.w-226,alpha=.72})
  end
  if screen.notice then D.panel(m,center.x+360,center.y+800,520,40,10,colors.inverse,nil);D.text(runtime,m,screen.notice,center.x+372,center.y+812,12,colors.textInverse,{weight='semibold',width=496,align='center'}) end
  runtime.Footer.menuDraw(runtime,m,D,colors,screen.game,'options',controls and 'controls' or screen.region)
end

-- CONTROLS ------------------------------------------------------------------
function Presenter.drawControls(runtime,m,colors,screen)
  local D=runtime.Draw
  runtime.Header.draw(runtime,m,D,colors,screen.game,"CONTROLES")
  D.roundRect(m,"fill",0,88,1920,928,0,colors.canvas)
  D.panel(m,64,120,300,856,16,colors.panel,colors.border)
  D.panel(m,388,120,888,856,16,colors.panel,colors.border)
  D.panel(m,1300,120,556,856,16,colors.panel,colors.border)
  D.text(runtime,m,"CONTROLES",88,144,24,colors.text,{weight="bold"})
  D.text(runtime,m,"Configura los controles del juego y de Kanto Rework.",88,184,14,colors.textSecondary,{width=240})
  D.text(runtime,m,"ACCIONES DE ENTRADA",88,236,11,colors.textSecondary,{weight="bold"})
  D.text(runtime,m,"Las asignaciones son lógicas. La jugabilidad y la interfaz responden a estas acciones.",88,266,13,colors.textSecondary,{width=240})
  D.text(runtime,m,"ACCIONES PERSONALIZADAS",412,144,24,colors.text,{weight="bold"})
  D.text(runtime,m,"Pulsa en una fila para reasignar la tecla/botón. SELECT restablece por defecto.",412,184,14,colors.textSecondary,{})
  runtime.controlsRects={}
  local rows=screen:rows();local view,_,pitch,rowH=screen:listMetrics();local oldX,oldY,oldW,oldH=love.graphics.getScissor()
  love.graphics.setScissor(m.ox+view.x*m.scale,m.oy+view.y*m.scale,view.w*m.scale,view.h*m.scale)
  for i,row in ipairs(rows) do
    local r={x=view.x,y=view.y+(i-1)*pitch-(screen.scrollY or 0),w=view.w,h=rowH}
    if r.y+r.h>=view.y and r.y<=view.y+view.h then
      runtime.controlsRects[i]=r;local id="controls:"..i
      local st=runtime.Focus.visual(screen.nav,id,id==screen:activeItemId() and id or nil,screen.hoverIndex and ("controls:"..screen.hoverIndex) or nil)
      D.panel(m,r.x,r.y,r.w,r.h,12,st=="hover" and colors.subtle or colors.panel,colors.border)
      if st=="focus" then D.focusBorder(m,r.x,r.y,r.w,r.h,12,colors.focus)
      elseif st=="hover" then D.roundRect(m,"line",r.x,r.y,r.w,r.h,12,colors.selected,2) end
      D.text(runtime,m,row.label,r.x+18,r.y+12,15,colors.text,{weight="semibold"})
      if row.kind=="native" then
        D.text(runtime,m,"MOTOR",r.x+18,r.y+39,10,colors.textSecondary,{weight="bold"})
        D.text(runtime,m,"ABRIR",r.x+r.w-150,r.y+22,12,colors.textSecondary,{weight="bold",width=120,align="right"})
      else
        local a=row.action or {}
        D.text(runtime,m,tostring(a.source or ""),r.x+18,r.y+39,10,colors.textSecondary,{weight="bold"})
        local key=tostring(a.key or "SIN ASIGNAR"):upper();local pad=runtime.Footer.physicalLabel and runtime.Footer.physicalLabel(a.pad or "SIN ASIGNAR","controller") or tostring(a.pad or "SIN ASIGNAR"):upper()
        D.text(runtime,m,"TECLA  "..key,r.x+r.w-350,r.y+13,12,colors.textSecondary,{weight="semibold",width=150})
        D.text(runtime,m,"MANDO  "..pad,r.x+r.w-190,r.y+13,12,colors.textSecondary,{weight="semibold",width=160})
      end
    end
  end
  if oldX then love.graphics.setScissor(oldX,oldY,oldW,oldH) else love.graphics.setScissor() end
  runtime.controlsScrollbar=screen:scrollbar();drawScrollbar(runtime,m,colors,runtime.controlsScrollbar)
  local selected=rows[screen.index]
  D.text(runtime,m,"DETALLES",1324,144,24,colors.text,{weight="bold"})
  if selected then
    D.text(runtime,m,selected.label,1324,204,18,colors.text,{weight="semibold"})
    D.text(runtime,m,selected.description or "",1324,244,14,colors.textSecondary,{width=508})
    if selected.kind=="action" then
      local slot=screen:activeSlot():upper()
      D.line(m,1324,360,1832,360,colors.border,1)
      D.text(runtime,m,"DISPOSITIVO ACTIVO",1324,388,11,colors.textSecondary,{weight="bold"})
      D.text(runtime,m,slot,1324,416,15,colors.text,{weight="semibold"})
      D.text(runtime,m,"Cambia entre teclado y mando antes de confirmar para elegir qué botón se asigna.",1324,452,13,colors.textSecondary,{width=508})
    end
  end
  if screen.notice then D.panel(m,412,916,840,44,10,colors.inverse,nil);D.text(runtime,m,screen.notice,430,930,12,colors.textInverse,{weight="semibold",width=804,align="center"}) end
  runtime.Footer.menuDraw(runtime,m,D,colors,screen.game,"controls")
end

-- MODS ----------------------------------------------------------------------
local PERMS={{id="engine_internals",label="ENGINE INTERNALS"},{id="filesystem",label="FILESYSTEM"},{id="network",label="NETWORK"}}
local function hasPermission(mod,id)
  for _,v in ipairs((mod and mod.permissions) or {}) do
    if type(v)=="table" and v.id==id then return v.declared==true end
    if v==id then return true end
  end
  return false
end
local function drawModRuntimeInfo(runtime,m,colors,screen,mod,startY)
  local D=runtime.Draw;startY=startY or 414
  D.line(m,1324,startY,1832,startY,colors.border,1); D.text(runtime,m,"RUNTIME STATE",1324,startY+20,11,colors.textSecondary,{weight="bold"}); D.text(runtime,m,"THIS SESSION",1324,startY+48,12,colors.textSecondary,{weight="semibold"}); D.text(runtime,m,screen:bootEnabled(mod) and "ENABLED" or "DISABLED",1580,startY+48,13,colors.text,{weight="semibold",width=252,align="right"}); D.text(runtime,m,"NEXT LAUNCH",1324,startY+74,12,colors.textSecondary,{weight="semibold"}); D.text(runtime,m,mod.enabled and "ENABLED" or "DISABLED",1580,startY+74,13,colors.text,{weight="semibold",width=252,align="right"})
  if screen:isStaged(mod) then D.text(runtime,m,"RESTART REQUIRED",1324,startY+104,12,colors.warning,{weight="bold"}) elseif mod.error then D.text(runtime,m,"LOAD ERROR",1324,startY+104,12,colors.danger,{weight="bold"}) end
  D.text(runtime,m,"COMPATIBILITY",1324,startY+144,11,colors.textSecondary,{weight="bold"}); D.clipText(runtime,m,"Engine: "..tostring(mod.compatibility or "not declared"),1324,startY+170,508,12,colors.textSecondary,{weight="medium"}); if mod.dependencies and #mod.dependencies>0 then D.text(runtime,m,"Dependencies: "..table.concat(mod.dependencies,", "),1324,startY+194,12,colors.textSecondary,{width=508}) end
  local compatIssue=mod.compatibilityIssues and mod.compatibilityIssues[1]
  if compatIssue then D.clipText(runtime,m,tostring(compatIssue.severity or "warning"):upper().." · "..tostring(compatIssue.message or "Compatibility issue"),1324,startY+216,508,11,compatIssue.blocksEnable and colors.danger or colors.warning,{weight="bold"}) end
  D.line(m,1324,startY+236,1832,startY+236,colors.border,1); D.text(runtime,m,"DECLARED PERMISSIONS · READ ONLY",1324,startY+256,11,colors.textSecondary,{weight="bold"}); local py=startY+286
  for _,p in ipairs(PERMS) do local yes=hasPermission(mod,p.id); D.roundRect(m,"fill",1324,py,508,48,10,yes and colors.subtle or colors.panel); D.roundRect(m,"line",1324,py,508,48,10,colors.border,1); D.text(runtime,m,yes and "+" or "—",1340,py+13,14,yes and colors.text or colors.disabled,{weight="bold"}); D.text(runtime,m,p.label,1368,py+10,13,colors.text,{weight="semibold"}); D.text(runtime,m,yes and "DECLARED" or "NOT DECLARED",1660,py+12,11,yes and colors.text or colors.disabled,{weight="bold",width=154,align="right"}); py=py+56 end
end
local function drawModInfo(runtime,m,colors,screen,context)
  local D=runtime.Draw;local mod=context and context.mod
  D.text(runtime,m,"INFO & PERMISSIONS",1324,144,24,colors.text,{weight="bold"})
  D.text(runtime,m,context and context.kind=="option" and "Focused option details and parent mod permissions." or (context and context.kind=="utility" and "Ascendant utility presented inside the installed mod tree." or "Manifest and runtime state for the selected mod."),1324,184,14,colors.textSecondary,{weight="regular"})
  if not mod then D.text(runtime,m,"Select a mod to inspect its metadata and declared permissions.",1324,232,14,colors.textSecondary,{width=508}); return end
  if context.kind=="option" then
    D.panel(m,1324,224,508,260,16,colors.panel,colors.border)
    D.text(runtime,m,"ABOUT THIS OPTION",1348,246,11,colors.textSecondary,{weight="bold"})
    D.clipText(runtime,m,context.label or context.option.id,1348,278,460,20,colors.text,{weight="semibold"})
    D.text(runtime,m,"CURRENT VALUE",1348,326,11,colors.textSecondary,{weight="bold"})
    D.clipText(runtime,m,context.value or "",1348,350,460,14,colors.text,{weight="semibold"})
    D.line(m,1348,390,1808,390,colors.border,1)
    local description=context.description
    if not description or description=="" then description="No description is exposed for this option." end
    D.text(runtime,m,description,1348,410,14,colors.textSecondary,{weight="regular",width=460})
    D.text(runtime,m,"PARENT MOD  ·  "..tostring(mod.name or mod.id).."  ·  "..tostring(mod.version or "—"),1324,506,11,colors.textSecondary,{weight="bold",width=508})
    drawModRuntimeInfo(runtime,m,colors,screen,mod,528)
    return
  end
  if context.kind=="utility" then
    D.panel(m,1324,224,508,220,16,colors.panel,colors.border)
    D.text(runtime,m,"ABOUT THIS MOD FEATURE",1348,246,11,colors.textSecondary,{weight="bold"})
    D.clipText(runtime,m,context.label or "MOD FEATURE",1348,278,460,20,colors.text,{weight="semibold"})
    D.text(runtime,m,context.description or "Open this feature using the Kanto Rework navigation shell.",1348,326,14,colors.textSecondary,{weight="regular",width=460})
    D.text(runtime,m,"PARENT MOD  ·  "..tostring(mod.name or mod.id).."  ·  "..tostring(mod.version or "—"),1324,466,11,colors.textSecondary,{weight="bold",width=508})
    drawModRuntimeInfo(runtime,m,colors,screen,mod,488);return
  end
  local card=screen:modCard(mod); D.clipText(runtime,m,mod.name or mod.id,1324,224,508,22,colors.text,{weight="bold"}); D.text(runtime,m,"VERSION  "..tostring(mod.version or "—"),1324,260,12,colors.textSecondary,{weight="semibold"}); if card and card.author then D.clipText(runtime,m,"AUTHOR  "..tostring(card.author),1324,286,508,12,colors.textSecondary,{weight="semibold"}) end
  local desc=(card and (card.summary or card.description)) or mod.description; if desc and desc~="" then D.text(runtime,m,tostring(desc),1324,320,13,colors.textSecondary,{width=508}) end
  drawModRuntimeInfo(runtime,m,colors,screen,mod,414)
end
local function drawModControl(runtime,m,colors,screen,row,r)
  local D=runtime.Draw; local kind=screen:optionControl(row); local value=screen:optionValue(row); local cr
  if kind=="toggle" then cr={x=r.x+r.w-100,y=r.y+4,w=82,h=44}; local u=value:upper(); D.toggle(m,r.x+r.w-84,r.y+10,not(u=="OFF" or u=="FALSE" or u=="DISABLED" or u=="0"),colors,false)
  elseif kind=="stepper" then cr={x=r.x+r.w-194,y=r.y+3,w=176,h=46}; D.stepper(runtime,m,r.x+r.w-194,r.y+7,176,value,colors)
  elseif kind=="submenu" then cr={x=r.x+r.w-84,y=r.y+3,w=66,h=46}; D.chevron(runtime,m,r.x+r.w-58,r.y+7,colors)
  else cr={x=r.x+r.w-258,y=r.y+3,w=240,h=46}; D.selector(runtime,m,r.x+r.w-258,r.y+7,240,value,colors) end
  return cr
end
local function drawOverlay(runtime,m,colors,screen)
  local ov=screen:activeOverlay();runtime.modOverlayButtons={};if not ov then return end;local D=runtime.Draw;D.roundRect(m,"fill",0,0,1920,1080,0,{0,0,0,.42})
  if ov.kind=='error_detail' then local x,y,w,h=360,170,1200,740;D.panel(m,x,y,w,h,18,colors.panel,colors.border);D.text(runtime,m,'ERROR · '..tostring(ov.title or 'SYSTEM'),x+28,y+26,20,colors.text,{weight='bold'});local view={x=x+28,y=y+76,w=w-72,h=h-170};local font=D.font(runtime,m,14,'regular');local ok,_,lines=pcall(font.getWrap,font,tostring(ov.detail or ''),view.w*m.scale);if not ok or type(lines)~='table' or #lines==0 then lines={tostring(ov.detail or '')} end;local lineH=22;local total=#lines*lineH;ov.scroll=math.max(0,math.min(tonumber(ov.scroll) or 0,math.max(0,total-view.h)));local oldX,oldY,oldW,oldH=love.graphics.getScissor();love.graphics.setScissor(m.ox+view.x*m.scale,m.oy+view.y*m.scale,view.w*m.scale,view.h*m.scale);for i,line in ipairs(lines) do local yy=view.y+(i-1)*lineH-ov.scroll;if yy+lineH>=view.y and yy<=view.y+view.h then D.text(runtime,m,line,view.x,yy,14,colors.textSecondary,{}) end end;if oldX then love.graphics.setScissor(oldX,oldY,oldW,oldH) else love.graphics.setScissor() end;local sb=runtime.Scroll.model(ov.scroll,total,view,x+w-28,{trackWidth=6,minThumb=48,hitWidth=32});if sb then drawScrollbar(runtime,m,colors,sb) end;local button={x=x+28,y=y+h-70,w=w-56,h=46};runtime.modOverlayButtons.ok=button;D.panel(m,button.x,button.y,button.w,button.h,12,colors.inverse,colors.border);D.text(runtime,m,'OK',button.x,button.y+13,14,colors.textInverse,{weight='semibold',width=button.w,align='center'});return end
  local x,y,w,h=600,330,720,360;D.panel(m,x,y,w,h,18,colors.panel,colors.border);D.text(runtime,m,ov.kind=="restart" and "RESTART REQUIRED" or (ov.kind=="confirm" and "CONFIRM" or "NOTICE"),x+28,y+28,20,colors.text,{weight="bold"});D.text(runtime,m,table.concat(ov.lines or {},"\n"),x+28,y+82,14,colors.textSecondary,{width=w-56})
  if ov.kind=="restart" then
    local gap=14;local bw=(w-56-gap*2)/3;local labels={"RESTART NOW","LATER","DISCARD CHANGES"};local keys={"restart","later","discard"}
    for i=1,3 do local r={x=x+28+(i-1)*(bw+gap),y=y+h-82,w=bw,h=52};runtime.modOverlayButtons[keys[i]]=r;D.panel(m,r.x,r.y,r.w,r.h,12,ov.index==i and colors.inverse or colors.panel,colors.border);D.text(runtime,m,labels[i],r.x,r.y+16,13,ov.index==i and colors.textInverse or colors.text,{weight="semibold",width=r.w,align="center"}) end
  elseif ov.kind=="confirm" then local yes={x=x+28,y=y+h-82,w=310,h=52}; local no={x=x+w-338,y=y+h-82,w=310,h=52}; runtime.modOverlayButtons.yes=yes; runtime.modOverlayButtons.no=no; D.panel(m,yes.x,yes.y,yes.w,yes.h,12,ov.index==1 and colors.inverse or colors.panel,colors.border); D.panel(m,no.x,no.y,no.w,no.h,12,ov.index==2 and colors.inverse or colors.panel,colors.border); D.text(runtime,m,"YES",yes.x,yes.y+16,14,ov.index==1 and colors.textInverse or colors.text,{weight="semibold",width=yes.w,align="center"}); D.text(runtime,m,"NO",no.x,no.y+16,14,ov.index==2 and colors.textInverse or colors.text,{weight="semibold",width=no.w,align="center"})
  else local ok={x=x+28,y=y+h-82,w=w-56,h=52}; runtime.modOverlayButtons.ok=ok; D.panel(m,ok.x,ok.y,ok.w,ok.h,12,colors.inverse,colors.border); D.text(runtime,m,"OK",ok.x,ok.y+16,14,colors.textInverse,{weight="semibold",width=ok.w,align="center"}) end
end

local function wrappedLines(runtime,m,text,width,size,weight)
  local font=runtime.Draw.font(runtime,m,size,weight or "regular")
  local ok,_,lines=pcall(font.getWrap,font,tostring(text or ""),math.max(1,width*m.scale))
  if ok and type(lines)=="table" and #lines>0 then return lines end
  return {tostring(text or "")}
end

-- The card grows with the selected mod's real wrapped description. It may
-- never reach the white panel's edge: the outer panel keeps an explicit 8 px
-- floor. Content beyond the maximum height lives in a clipped, scrollable
-- viewport instead of colliding with runtime state or permissions.
local function drawResponsiveModInfo(runtime,m,colors,screen,info,context,layoutOpts)
  local D=runtime.Draw;local mod=context and context.mod
  runtime.modInfoViewport=nil;runtime.modInfoScrollbar=nil;runtime.modInfoCard=nil
  if not mod then
    D.text(runtime,m,"Select a mod to inspect its metadata.",info.x+24,info.y+112,14,colors.textSecondary,{width=info.w-48})
    return
  end

  local innerPad=20;local baseWidth=info.w-48-innerPad*2
  local source=screen:modCard(mod)
  local isOption=context and (context.kind=="option" or context.kind=="utility")
  local displayName=isOption and tostring(context.label or (context.option and context.option.id) or "OPTION") or tostring(mod.name or mod.id)
  local description=isOption and tostring(context.description or "") or tostring(mod.description or (source and (source.summary or source.description)) or "")
  local author=(not isOption) and source and source.author or nil
  local lines=wrappedLines(runtime,m,description,baseWidth,13,"regular")
  local layout=runtime.ModInfoLayout.build(info,#lines,author~=nil,false,layoutOpts)
  if layout.model.contentH>layout.view.h then
    lines=wrappedLines(runtime,m,description,baseWidth-20,13,"regular")
    layout=runtime.ModInfoLayout.build(info,#lines,author~=nil,true,layoutOpts)
  end
  local card,view,model=layout.card,layout.view,layout.model;model.descriptionLines=lines

  local key=tostring(mod.id or mod.name or "mod")..":"..tostring(context and context.kind or "mod")
  local scroll=screen:setInfoMetrics(model.contentH,view.h,key)
  D.panel(m,card.x,card.y,card.w,card.h,14,colors.subtle,colors.border)
  if screen.region=="info" then D.focusBorder(m,card.x,card.y,card.w,card.h,14,colors.focus) end
  runtime.modInfoCard=card;runtime.modInfoViewport=view;runtime.modInfoContentHeight=model.contentH

  local oldX,oldY,oldW,oldH=love.graphics.getScissor()
  love.graphics.setScissor(m.ox+view.x*m.scale,m.oy+view.y*m.scale,view.w*m.scale,view.h*m.scale)
  local function yy(value) return view.y+value-scroll end
  D.clipText(runtime,m,displayName,view.x,yy(model.nameY),view.w,20,colors.text,{weight="bold"})
  D.text(runtime,m,isOption and ("PARENT MOD  "..tostring(mod.name or mod.id)) or ("VERSION "..tostring(mod.version or "—")),view.x,yy(model.versionY),10,colors.textSecondary,{weight="semibold"})
  if author then D.clipText(runtime,m,"AUTHOR "..tostring(author),view.x,yy(model.authorY),view.w,10,colors.textSecondary,{weight="semibold"}) end
  for i,line in ipairs(model.descriptionLines) do
    D.text(runtime,m,line,view.x,yy(model.descriptionY+(i-1)*17),13,colors.textSecondary,{weight="regular"})
  end
  D.line(m,view.x,yy(model.dividerOneY),view.x+view.w,yy(model.dividerOneY),colors.border,1)
  D.text(runtime,m,"SUPER STATE",view.x,yy(model.stateY),10,colors.textSecondary,{weight="bold"})
  D.text(runtime,m,screen:bootEnabled(mod) and "ACTIVE" or "INACTIVE",view.x+view.w-150,yy(model.stateY),11,screen:bootEnabled(mod) and colors.focus or colors.textSecondary,{weight="bold",width=150,align="right"})
  D.text(runtime,m,"COMPATIBILITY",view.x,yy(model.compatibilityY),10,colors.textSecondary,{weight="bold"})
  D.clipText(runtime,m,tostring(mod.compatibility or "ENGINE 1.V2+"),view.x+view.w-220,yy(model.compatibilityY),220,11,colors.text,{weight="semibold",width=220,align="right"})
  D.line(m,view.x,yy(model.dividerTwoY),view.x+view.w,yy(model.dividerTwoY),colors.border,1)
  D.text(runtime,m,"DECLARED PERMISSIONS",view.x,yy(model.permissionsTitleY),10,colors.textSecondary,{weight="bold"})
  for i,permission in ipairs(PERMS) do
    local py=model.permissionY+(i-1)*24;local yes=hasPermission(mod,permission.id)
    D.text(runtime,m,yes and "●" or "•",view.x,yy(py),10,yes and colors.danger or colors.faint,{weight="bold"})
    D.text(runtime,m,permission.label..": "..(yes and "DECLARED" or "NOT DECLARED"),view.x+18,yy(py),10,yes and colors.text or colors.disabled,{weight="semibold"})
  end
  if oldX then love.graphics.setScissor(oldX,oldY,oldW,oldH) else love.graphics.setScissor() end

  local rh=runtime.graphicsEditorPopupResizeHandle;D.line(m,rh.x+5,rh.y+17,rh.x+17,rh.y+5,colors.textSecondary,2);D.line(m,rh.x+10,rh.y+17,rh.x+17,rh.y+10,colors.textSecondary,2)

  runtime.modInfoScrollbar=runtime.Scroll.model(scroll,model.contentH,view,card.x+card.w-14,{trackWidth=6,minThumb=56,hitWidth=44})
  if runtime.modInfoScrollbar then drawScrollbar(runtime,m,colors,runtime.modInfoScrollbar) end
end

function Presenter.drawMods(runtime,m,colors,screen)
  local D=runtime.Draw
  local tabs={'MOD LIST','PROFILES','ERRORS'}
  runtime.modTabRects=runtime.Header.drawHierarchy(runtime,m,D,colors,screen.game,{
    subtitle='START MENU',parentLabel='MODS',items=tabs,activeIndex=screen.tab,
    focusIndex=screen.headerIndex,hoverIndex=screen.hoverTab,focused=screen.region=='header',
  })
  D.roundRect(m,'fill',0,88,1920,928,0,colors.optionsCanvas or colors.canvas)
  local center={x=64,y=120,w=1224,h=856};local info={x=1312,y=120,w=544,h=856}
  D.roundRect(m,'fill',center.x,center.y,center.w,center.h,20,colors.optionsCenter or colors.subtle)
  D.roundRect(m,'fill',info.x,info.y,info.w,info.h,20,colors.optionsInfo or colors.panel)

  D.text(runtime,m,screen.tab==1 and 'INSTALLED MODS' or (screen.tab==2 and 'PROFILES' or 'ERRORS'),center.x+24,center.y+24,24,colors.text,{weight='bold'})
  D.text(runtime,m,screen.tab==1 and 'Confirm a mod to expand its inline options.' or 'Native manager data remains authoritative.',center.x+24,center.y+62,14,colors.textSecondary,{})
  local rows=screen:rows();runtime.modRowRects={};runtime.modToggleRects={};runtime.modControlRects={}
  local view={x=center.x+24,y=center.y+96,w=center.w-56,h=724};runtime.modScrollViewport=view;runtime.modScrollWheelRegion={x=center.x,y=center.y+88,w=center.w,h=center.h-100}
  local layout,total=screen:rowLayout(rows);local scroll=screen.scrollY or 0;local oldX,oldY,oldW,oldH=love.graphics.getScissor()
  love.graphics.setScissor(m.ox+view.x*m.scale,m.oy+view.y*m.scale,view.w*m.scale,view.h*m.scale)
  for i,g in ipairs(layout) do
    local row=g.row;local y=view.y+g.top-scroll
    if y+g.h>=view.y and y<=view.y+view.h then
      if row.header then
        D.text(runtime,m,row.label,view.x,y+8,11,row.subheader and colors.focus or colors.textSecondary,{weight='bold'})
      else
        local h=row.kind=='option' and 54 or 62;local r={x=row.kind=='option' and view.x+16 or view.x,y=y,w=row.kind=='option' and view.w-16 or view.w,h=h};runtime.modRowRects[i]=r
        local id=row.key or ('row:'..i);local logical=screen.region=='content' and screen:activeItemId() or nil;local hoverId=screen.hoverIndex and ((rows[screen.hoverIndex] or {}).key) or nil;local focused=(logical==id);local hovered=(hoverId==id)
        D.panel(m,r.x,r.y,r.w,r.h,12,colors.panel,colors.border)
        local modsFocus=colors.modsFocus or colors.focus
        if focused and not (hovered and hoverId~=logical) then D.focusBorder(m,r.x,r.y,r.w,r.h,12,modsFocus) elseif hovered then D.roundRect(m,'line',r.x+.5,r.y+.5,r.w-1,r.h-1,12,modsFocus,1) end
        if row.kind=='mod' then
          D.clipText(runtime,m,row.label,r.x+16,r.y+12,r.w-150,16,colors.text,{weight='semibold'})
          local staged=screen:isStaged(row.mod);D.text(runtime,m,staged and 'STAGED · RESTART REQUIRED' or (row.mod.enabled and 'INSTALLED' or 'DISABLED'),r.x+16,r.y+38,10,staged and colors.warning or colors.textSecondary,{weight='bold'})
          local tr={x=r.x+r.w-70,y=r.y+14,w=64,h=34};runtime.modToggleRects[i]=tr;D.toggle(m,tr.x,tr.y,row.mod.enabled==true,colors,false)
        elseif row.kind=='option' then
          D.text(runtime,m,row.label,r.x+18,r.y+17,14,colors.text,{weight='semibold'});runtime.modControlRects[i]=drawModControl(runtime,m,colors,screen,row,r)
        elseif row.kind=='utility' then
          D.clipText(runtime,m,row.label,r.x+18,r.y+19,r.w-80,15,colors.text,{weight='semibold'});D.text(runtime,m,'›',r.x+r.w-42,r.y+16,18,colors.focus,{weight='bold'})
        else D.clipText(runtime,m,row.label,r.x+16,r.y+19,r.w-40,15,colors.text,{weight='semibold'}) end
      end
    end
  end
  if oldX then love.graphics.setScissor(oldX,oldY,oldW,oldH) else love.graphics.setScissor() end
  runtime.modScrollbar=nil;local maxScroll=math.max(0,total-view.h)
  if maxScroll>0 then
    local track={x=1272,y=view.y,w=8,h=692};local th=math.max(56,track.h*view.h/total);local travel=track.h-th;local ty=track.y+(screen.scrollY/maxScroll)*travel
    runtime.modScrollbar={track=track,thumb={x=track.x,y=ty,w=track.w,h=th},hit={x=1254,y=ty,w=44,h=math.max(44,th)},maxScroll=maxScroll,travel=travel,total=total};drawScrollbar(runtime,m,colors,runtime.modScrollbar)
  end
  if #rows==0 then D.text(runtime,m,'Nothing here.',view.x,view.y+10,14,colors.textSecondary,{}) end

  local ctx=screen:infoContext();local optionContext=ctx and (ctx.kind=='option' or ctx.kind=='utility')
  D.text(runtime,m,optionContext and 'OPTION DESCRIPTION' or 'INFO & PERMISSIONS',info.x+24,info.y+24,24,colors.text,{weight='bold'})
  D.text(runtime,m,optionContext and 'Details for the selected option.' or 'Manifest and runtime state for the selected mod.',info.x+24,info.y+62,14,colors.textSecondary,{})
  local infoLayoutOpts=nil
  local visualMod=ctx and ctx.mod and (tostring(ctx.mod.id)=='kanto_rework_suite' or tostring(ctx.mod.id)=='kanto_rework_graphics')
  local visualTheme=ctx and ctx.kind=='option' and ctx.mod and ctx.option and ((tostring(ctx.mod.id)=='kanto_rework_suite' and tostring(ctx.option.id)=='ui.ui_theme') or (tostring(ctx.mod.id)=='kanto_rework_ui' and tostring(ctx.option.id)=='ui_theme'))
  if visualMod or visualTheme then
    local pr={x=info.x+24,y=info.y+100,w=info.w-48,h=196};D.roundRect(m,'fill',pr.x,pr.y,pr.w,pr.h,12,colors.subtle)
    local path=visualTheme and runtime.assetPath('assets/menu/main/states/main_card_pokemon_hover.png') or runtime.assetPath('assets/battle/backgrounds/canonical/grass_day.png')
    local ok,img=pcall(runtime.assets.image,runtime.assets,path,visualTheme and 'linear' or 'linear')
    if ok and img then
      local iw,ih=img:getDimensions();local pad=visualTheme and 18 or 0;local aw,ah=pr.w-2*pad,pr.h-2*pad;local k=math.min(aw*m.scale/iw,ah*m.scale/ih);local dw,dh=iw*k/m.scale,ih*k/m.scale
      love.graphics.setColor(1,1,1,1);love.graphics.draw(img,m.ox+(pr.x+pad+(aw-dw)/2)*m.scale,m.oy+(pr.y+pad+(ah-dh)/2)*m.scale,0,k,k)
    end
    D.roundRect(m,'line',pr.x,pr.y,pr.w,pr.h,12,colors.border,1)
    local caption=visualTheme and ('THEME PREVIEW · '..tostring(ctx.value or ''):upper()) or ('VISUAL PREVIEW · '..tostring(ctx.label or 'GRAPHICS'):upper())
    D.panel(m,pr.x+10,pr.y+pr.h-31,pr.w-20,23,6,{colors.inverse[1],colors.inverse[2],colors.inverse[3],.86},nil)
    D.text(runtime,m,caption,pr.x+16,pr.y+pr.h-26,9,colors.textInverse,{weight='bold',width=pr.w-32})
    -- Keep preview + metadata in ONE outer layout. The card starts immediately
    -- below the preview and its height is capped by the real panel bottom.
    infoLayoutOpts={topInset=(pr.y+pr.h+16)-info.y}
  end
  drawResponsiveModInfo(runtime,m,colors,screen,info,ctx,infoLayoutOpts)
  if screen.notice then D.panel(m,center.x+360,center.y+810,500,34,9,colors.inverse,nil);D.text(runtime,m,screen.notice,center.x+370,center.y+819,11,colors.textInverse,{width=480,align='center'}) end
  local footerRegion=screen.region=='header' and 'header' or (screen.region=='info' and 'info' or (screen:restartRequired() and 'restart' or 'content'))
  runtime.Footer.menuDraw(runtime,m,D,colors,screen.game,'mods',footerRegion);drawOverlay(runtime,m,colors,screen)
end

local function drawExtensionDocument(runtime,m,colors,screen)
  local D=runtime.Draw;local hasChoice=screen:hasChoice()
  local panel={x=420,y=228,w=1404,h=hasChoice and 568 or 650}
  local view={x=456,y=260,w=1310,h=hasChoice and 474 or 556}
  local font=D.font(runtime,m,19,"regular");local lineH=31;local gap=22
  local layouts={};local contentH=0
  for i,block in ipairs((screen.document and screen.document.blocks) or {}) do
    local _,lines=font:getWrap(tostring(block.text or ""),view.w*m.scale)
    if type(lines)~="table" or #lines==0 then lines={""} end
    local h=#lines*lineH
    layouts[#layouts+1]={block=block,lines=lines,y=contentH,h=h}
    contentH=contentH+h+(i<#screen.document.blocks and gap or 0)
  end
  screen:setReaderMetrics(contentH,view.h)
  D.panel(m,panel.x,panel.y,panel.w,panel.h,18,colors.elevated,colors.border)
  runtime.extensionDocumentViewport=view;runtime.extensionVisibleBlocks={}
  local oldX,oldY,oldW,oldH=love.graphics.getScissor()
  love.graphics.setScissor(m.ox+view.x*m.scale,m.oy+view.y*m.scale,view.w*m.scale,view.h*m.scale)
  for i,layout in ipairs(layouts) do
    local y=view.y+layout.y-screen.readerScrollY
    if y+layout.h>=view.y and y<=view.y+view.h then
      runtime.extensionVisibleBlocks[#runtime.extensionVisibleBlocks+1]=i
      for lineIndex,line in ipairs(layout.lines) do
        D.text(runtime,m,line,view.x,y+(lineIndex-1)*lineH,19,colors.text,{weight="regular"})
      end
      if i<#layouts then D.line(m,view.x,y+layout.h+gap/2,view.x+view.w,y+layout.h+gap/2,colors.border,1) end
    end
  end
  if oldX then love.graphics.setScissor(oldX,oldY,oldW,oldH) else love.graphics.setScissor() end

  local rh=runtime.graphicsEditorPopupResizeHandle;D.line(m,rh.x+5,rh.y+17,rh.x+17,rh.y+5,colors.textSecondary,2);D.line(m,rh.x+10,rh.y+17,rh.x+17,rh.y+10,colors.textSecondary,2)

  local maxScroll=screen:readerMaxScroll();runtime.extensionScrollbar=nil
  if maxScroll>0 then
    local track={x=1790,y=view.y,w=10,h=view.h};local thumbH=math.max(56,track.h*view.h/math.max(contentH,1));local travel=math.max(0,track.h-thumbH)
    local thumb={x=track.x,y=track.y+(screen.readerScrollY/maxScroll)*travel,w=track.w,h=thumbH}
    runtime.extensionScrollbar={track=track,thumb=thumb,hit={x=1774,y=thumb.y,w=42,h=math.max(44,thumb.h)},maxScroll=maxScroll,travel=travel}
    drawScrollbar(runtime,m,colors,runtime.extensionScrollbar)
  end
  local blocks=screen.document and #screen.document.blocks or 0
  local pct=maxScroll<=0 and 100 or math.floor((screen.readerScrollY/maxScroll)*100+.5)
  D.text(runtime,m,("DOCUMENT VIEW  ·  %d SECTION%s"):format(blocks,blocks==1 and "" or "S"),456,panel.y+panel.h-28,10,colors.textSecondary,{weight="bold"})
  D.text(runtime,m,("%d%% READ"):format(pct),1650,panel.y+panel.h-28,10,colors.textSecondary,{weight="bold",width=116,align="right"})

  runtime.extensionChoiceRects={}
  if screen:choosing() then
    local yes={x=456,y=836,w=640,h=64};local no={x=1148,y=836,w=640,h=64};runtime.extensionChoiceRects={yes,no}
    for i,r in ipairs(runtime.extensionChoiceRects) do
      D.panel(m,r.x,r.y,r.w,r.h,12,screen.choiceIndex==i and colors.inverse or colors.panel,colors.border)
      D.text(runtime,m,i==1 and "YES" or "NO",r.x,r.y+20,16,screen.choiceIndex==i and colors.textInverse or colors.text,{weight="semibold",width=r.w,align="center"})
    end
  elseif hasChoice then
    D.text(runtime,m,"Continue to the end of the document to answer.",456,834,13,colors.textSecondary,{weight="medium",width=1332,align="center"})
  end
end

function Presenter.drawModExtension(runtime,m,colors,screen)
  local D=runtime.Draw;runtime.Header.draw(runtime,m,D,colors,screen.game,screen.title or "MOD FEATURE");D.roundRect(m,"fill",0,88,1920,928,0,colors.canvas)
  D.panel(m,64,120,300,856,16,colors.panel,colors.border);D.panel(m,388,120,1468,856,16,colors.panel,colors.border)
  D.text(runtime,m,"MOD",88,144,11,colors.textSecondary,{weight="bold"});D.text(runtime,m,(screen.source and screen.source.name) or "INSTALLED MOD",88,174,22,colors.text,{weight="bold",width=240})
  D.text(runtime,m,"KANTO UI",88,240,11,colors.focus,{weight="bold"});D.text(runtime,m,"The source mod owns these values and actions. Kanto Rework owns this presentation and navigation.",88,272,13,colors.textSecondary,{width=240})
  D.text(runtime,m,screen.title or "MOD FEATURE",420,144,28,colors.text,{weight="bold"});runtime.extensionRowRects={};runtime.extensionChoiceRects={}
  if screen.viewKind=="list" then
    D.text(runtime,m,"Select an entry to continue inside this mod's tree.",420,188,14,colors.textSecondary,{})
    local rows=screen:items();local first=(screen.scroll or 0)+1
    for slot=1,8 do local i=first+slot-1;local row=rows[i];if not row then break end
      local r={x=420,y=228+(slot-1)*82,w=1404,h=68};runtime.extensionRowRects[i]=r;local id="extension:"..i;local st=runtime.Focus.visual(screen.nav,id,id==screen:activeItemId() and id or nil,screen.hoverIndex and ("extension:"..screen.hoverIndex) or nil)
      D.panel(m,r.x,r.y,r.w,r.h,12,st=="hover" and colors.subtle or colors.panel,colors.border);if st=="focus" then D.focusBorder(m,r.x,r.y,r.w,r.h,12,colors.focus) elseif st=="hover" then D.roundRect(m,"line",r.x,r.y,r.w,r.h,12,colors.selected,2) end
      D.clipText(runtime,m,row.label or "MOD ACTION",r.x+22,r.y+22,1050,16,colors.text,{weight="semibold"});if row.right then D.clipText(runtime,m,row.right,r.x+1100,r.y+23,220,13,colors.textSecondary,{weight="bold",width=220,align="right"}) end;D.text(runtime,m,"›",r.x+r.w-48,r.y+17,22,colors.focus,{weight="semibold"})
    end
  else
    D.text(runtime,m,"ADAPTIVE READER",420,188,14,colors.textSecondary,{weight="bold"})
    drawExtensionDocument(runtime,m,colors,screen)
  end
  if screen.notice then D.text(runtime,m,screen.notice,420,920,12,colors.danger,{weight="bold",width=1404}) end
  runtime.Footer.menuDraw(runtime,m,D,colors,screen.game,"mod_extension")
end

-- FIELD ACTIONS POPUP -------------------------------------------------------
function Presenter.drawFieldActions(runtime,m,colors,screen)
  local D=runtime.Draw;local rows=screen.rows or {};local pitch,rowH=76,64
  local listH=#rows*pitch
  local popupH=math.max(160, 72 + listH)
  local x,y,w=96,math.floor((1080-popupH)/2),448
  D.roundRect(m,"fill",0,0,1920,1080,0,{colors.letterbox[1],colors.letterbox[2],colors.letterbox[3],.58})
  D.panel(m,x,y,w,popupH,20,colors.panel,colors.border)
  D.roundRect(m,"fill",x,y,w,4,2,colors.selected)
  local isDark = (colors.themeId == "dark" or colors.themeId == "purplenight")
  local titleColor = isDark and {0.85, 0.85, 0.85, 1} or {0.25, 0.22, 0.20, 1}
  D.text(runtime,m,"ACCIONES DE CAMPO",x+24,y+20,14,titleColor,{weight="bold"})
  runtime.fieldActionRects={}
  for i,row in ipairs(rows) do
    local r={x=x+24,y=y+56+(i-1)*pitch,w=w-48,h=rowH}
    runtime.fieldActionRects[i]=r
    local id="field:"..tostring(row.id)
    local st=runtime.Focus.visual(screen.nav,id,screen:activeItemId(),screen.hoverIndex and ("field:"..tostring(rows[screen.hoverIndex].id)) or nil)
    local isHover=(st=="hover") or (screen.index==i)
    local fill=isHover and colors.subtle or colors.panel
    D.panel(m,r.x,r.y,r.w,r.h,12,fill,colors.border)
    if isHover then
      D.roundRect(m,"line",r.x,r.y,r.w,r.h,12,colors.selected,2)
    end
    D.roundRect(m,"fill",r.x+12,r.y+8,48,48,8,colors.selected)
    local badgeLabel = (row.id=="kanto.free_fly" and "3D") or "MO"
    D.text(runtime,m,badgeLabel,r.x+12,r.y+23,13,colors.textInverse,{weight="semibold",width=48,align="center"})
    local itemTextColor = isDark and {0.98, 0.98, 0.98, 1} or {0.10, 0.08, 0.08, 1}
    D.clipText(runtime,m,row.label,r.x+72,r.y+21,r.w-80,18,itemTextColor,{weight="bold"})
  end
end

-- MAP / FLY ----------------------------------------------------------------
local function drawNativePlayerSprite(m,screen,cx,cy)
  local image,quad,flip=screen:playerSprite();if not(image and quad) then return end
  -- The live 16x16 ROM frame is intentionally presented at exactly 2x with
  -- integer nearest-neighbour scaling. It is drawn after every location box,
  -- so the player always remains on the top visual layer.
  local px=m.ox+cx*m.scale-16;local py=m.oy+cy*m.scale-16
  love.graphics.setColor(1,1,1,1)
  if flip then love.graphics.draw(image,quad,px+32,py,0,-2,2)
  else love.graphics.draw(image,quad,px,py,0,2,2) end
end
local FLY_REASON={
  hm_required="SE REQUIERE MO02 VUELO",badge_required="SE REQUIERE LA MEDALLA TRUENO",
  outside_required="VUELO REQUIERE ESTAR AL AIRE LIBRE",
  no_overworld="VUELO NO DISPONIBLE",engine_unavailable="VUELO NO DISPONIBLE",
}
function Presenter.drawMap(runtime,m,colors,screen)
  local D=runtime.Draw;local inner=screen.inner;local view=screen:mapViewport();runtime.mapViewport=view
  local oldX,oldY,oldW,oldH=love.graphics.getScissor()
  love.graphics.setScissor(m.ox+view.x*m.scale,m.oy+view.y*m.scale,view.w*m.scale,view.h*m.scale)
  if screen.mapImage then
    local iw,ih=screen.mapImage:getDimensions();love.graphics.setColor(1,1,1,1)
    local bx,by=screen:imageBaseScale();love.graphics.draw(screen.mapImage,m.ox+screen.panX*m.scale,m.oy+screen.panY*m.scale,0,bx*m.scale*screen.mapScale,by*m.scale*screen.mapScale)
  else
    D.roundRect(m,"fill",view.x,view.y,view.w,view.h,0,colors.canvas)
    D.text(runtime,m,"MAPA DE KANTO NO DISPONIBLE",48,48,18,colors.text,{weight="bold"})
  end
  runtime.mapPoiRects={}
  -- Major cities/towns keep their authored labels on the map at all times.
  -- Routes and dungeon/landmark entries are still real map POIs and remain
  -- fully named in the navigation sheet; on the artwork they use a compact
  -- marker until selected or hovered, then reveal the same label component.
  -- This prevents the complete 60+ TownMap dataset from covering the map.
  for _,loc in ipairs(screen:allMapLocations()) do
    local i=screen:destinationIndex(loc);local anchor=screen:anchor(loc)
    if anchor then
      local poiX,poiY=screen:mapPoint(anchor.x,anchor.y)
      local id=i and ("map:"..i) or nil
      local hoverId=screen.hoverIndex and ("map:"..screen.hoverIndex) or nil
      local st=id and runtime.Focus.visual(screen.nav,id,screen:activeItemId(),hoverId) or "default"
      local major=screen.isMajorMapLabel and screen:isMajorMapLabel(loc) or false
      local reveal=major or (i and i==inner.sel) or st=="hover" or loc==inner.playerLoc
      if reveal then
        local labelX,labelY=screen:mapPoint(anchor.labelX,anchor.labelY)
        local font=D.font(runtime,m,13,"semibold");local measured=font.getWidth and font:getWidth(tostring(loc.name or "KANTO"))/m.scale or 128
        local r={x=labelX,y=labelY,w=math.max(146,math.min(216,measured+32)),h=44}
        local visible=r.x+r.w>=view.x and r.x<=view.x+view.w and r.y+r.h>=view.y and r.y<=view.y+view.h
        if visible and i then runtime.mapPoiRects[i]=r end
        if visible then
          local edgeX=poiX<r.x and r.x or (poiX>r.x+r.w and r.x+r.w or poiX)
          local edgeY=math.max(r.y+8,math.min(r.y+r.h-8,poiY))
          if math.abs(poiX-edgeX)+math.abs(poiY-edgeY)>18 then
            D.line(m,edgeX,edgeY,poiX,poiY,{colors.border[1],colors.border[2],colors.border[3],.90},2)
          end
          D.panel(m,r.x,r.y,r.w,r.h,10,st=="hover" and {colors.subtle[1],colors.subtle[2],colors.subtle[3],.96} or {colors.panel[1],colors.panel[2],colors.panel[3],.92},colors.border)
          if i and i==inner.sel and st~="hover" then D.focusBorder(m,r.x,r.y,r.w,r.h,10,colors.focus)
          elseif st=="hover" then D.roundRect(m,"line",r.x,r.y,r.w,r.h,10,colors.selected,2) end
          D.clipText(runtime,m,loc.name or "KANTO",r.x+16,r.y+14,r.w-32,13,colors.text,{weight="semibold"})
        end
      else
        local r={x=poiX-12,y=poiY-12,w=24,h=24}
        local visible=r.x+r.w>=view.x and r.x<=view.x+view.w and r.y+r.h>=view.y and r.y<=view.y+view.h
        if visible then
          if i then runtime.mapPoiRects[i]=r end
          D.roundRect(m,"fill",poiX-5,poiY-5,10,10,5,{colors.panel[1],colors.panel[2],colors.panel[3],.94})
          D.roundRect(m,"line",poiX-5,poiY-5,10,10,5,colors.border,2)
        end
      end
    end
  end
  local playerAnchor=screen:anchor(inner.playerLoc)
  if playerAnchor then
    local px,py=screen:mapPoint(playerAnchor.x,playerAnchor.y)
    drawNativePlayerSprite(m,screen,px,py)
  end
  if oldX then love.graphics.setScissor(oldX,oldY,oldW,oldH) else love.graphics.setScissor() end

  local rh=runtime.graphicsEditorPopupResizeHandle;D.line(m,rh.x+5,rh.y+17,rh.x+17,rh.y+5,colors.textSecondary,2);D.line(m,rh.x+10,rh.y+17,rh.x+17,rh.y+10,colors.textSecondary,2)

  -- Full-height paper sheet: the map remains visible beneath it, while the
  -- previous black gutters around the floating panel are eliminated.
  local panel={x=1520,y=0,w=400,h=1080}
  D.roundRect(m,"fill",panel.x,panel.y,panel.w,panel.h,0,{colors.canvas[1],colors.canvas[2],colors.canvas[3],.96})
  D.line(m,panel.x,panel.y,panel.x,panel.y+panel.h,colors.border,2)
  D.text(runtime,m,"LUGARES DE KANTO",panel.x+28,panel.y+28,11,colors.textSecondary,{weight="bold"})
  local flyStatus=screen:flyStatus();local flyAvailable=flyStatus.available==true
  D.text(runtime,m,"Explorar Kanto",panel.x+28,panel.y+58,20,colors.text,{weight="bold",width=panel.w-56})
  if not flyAvailable then
    D.text(runtime,m,FLY_REASON[flyStatus.reason] or "VUELO BLOQUEADO",panel.x+28,panel.y+90,10,colors.warning,{weight="bold",width=panel.w-56})
  end
  runtime.mapDestinationRects={};local listView=screen:listMetrics();local first,last=screen:visibleWindow()
  local listOldX,listOldY,listOldW,listOldH=love.graphics.getScissor()
  love.graphics.setScissor(m.ox+listView.x*m.scale,m.oy+listView.y*m.scale,listView.w*m.scale,listView.h*m.scale)
  for i=first,last do
    local loc=inner.locs[i];local r=screen:listRowRect(i);runtime.mapDestinationRects[i]=r
    local id="map:"..i;local st=runtime.Focus.visual(screen.nav,id,screen:activeItemId(),screen.hoverIndex and ("map:"..screen.hoverIndex) or nil);local selected=i==inner.sel
    local rowAvailable=screen:rowFlyAvailable(i)
    local fill=st=="hover" and colors.subtle or colors.panel
    D.panel(m,r.x,r.y,r.w,r.h,12,fill,colors.border)
    if selected and st~="hover" then D.focusBorder(m,r.x,r.y,r.w,r.h,12,colors.focus)
    elseif st=="hover" then D.roundRect(m,"line",r.x,r.y,r.w,r.h,12,colors.selected,2) end
    local textX=r.x+16
    local stateLabel=loc==inner.playerLoc and "ACTUAL" or (rowAvailable and "VOLAR" or "LUGAR")
    D.clipText(runtime,m,loc.name or "KANTO",textX,r.y+11,r.w-132,14,colors.text,{weight="semibold"})
    D.text(runtime,m,stateLabel,r.x+r.w-104,r.y+12,9,rowAvailable and colors.success or colors.textSecondary,{weight="bold",width=88,align="right"})
    local detail=loc==inner.playerLoc and "Ubicación actual" or (rowAvailable and "Confirmar para volar" or "Lugar en el mapa")
    D.clipText(runtime,m,detail,textX,r.y+36,r.w-32,10,colors.textSecondary,{weight="regular"})
  end
  if listOldX then love.graphics.setScissor(listOldX,listOldY,listOldW,listOldH) else love.graphics.setScissor() end
  runtime.mapScrollbar=screen:scrollbar();drawScrollbar(runtime,m,colors,runtime.mapScrollbar)
  D.text(runtime,m,"ARRASTRAR RATÓN  MOVER    ↑/↓  SELECCIONAR LUGAR",panel.x+28,panel.y+panel.h-60,10,colors.textSecondary,{weight="bold"})
  D.text(runtime,m,"A / CLIC  ABRIR   ·   B / CLIC DER.  VOLVER",panel.x+28,panel.y+panel.h-36,10,colors.textSecondary,{weight="semibold",width=panel.w-56})
end


-- PC STORAGE ---------------------------------------------------------------
local function pcMonName(runtime,game,mon)
  local def=mon and game.data.pokemon and game.data.pokemon[mon.species]
  return mon and runtime.PokemonName(mon.nickname or (def and def.name) or mon.species,mon.species,def,mon.nickname~=nil) or 'POKéMON'
end
local function pcPartyIcon(runtime,m,game,mon,x,y,size)
  if not mon then return false end
  -- Stored/Party slots are compact representations. Use the shared two-frame
  -- menu icon context; battle Real Size and Live animation speed never enter
  -- this path. Graphics.draw also isolates theme tint and slices the strip.
  if runtime.Graphics and type(runtime.Graphics.draw)=='function' then
    local ok,drawn=pcall(runtime.Graphics.draw,runtime.Graphics,'pc.icon',game,mon,
      m.ox+x*m.scale,m.oy+y*m.scale,size*m.scale,size*m.scale)
    if ok and drawn==true then return true end
  end
  local okParty,PartyMenu=pcall(require,'src.ui.PartyMenu');if not(okParty and PartyMenu and type(PartyMenu.drawIcon)=='function') then return false end
  love.graphics.push('all');love.graphics.translate(m.ox+x*m.scale,m.oy+y*m.scale);love.graphics.scale((size/16)*m.scale,(size/16)*m.scale)
  love.graphics.setColor(1,1,1,1);local worked=pcall(PartyMenu.drawIcon,game,mon,0,0,false,0,false);love.graphics.pop();return worked
end

local function pcFocusOutline(runtime,m,r,color) runtime.Draw.roundRect(m,'line',r.x+1,r.y+1,r.w-2,r.h-2,8,color,3) end
local function pcDashedRect(runtime,m,x,y,w,h,color) local D=runtime.Draw;local dash,gap=10,6;for xx=x+8,x+w-8,dash+gap do D.line(m,xx,y+1,math.min(xx+dash,x+w-8),y+1,color,2);D.line(m,xx,y+h-1,math.min(xx+dash,x+w-8),y+h-1,color,2) end;for yy=y+8,y+h-8,dash+gap do D.line(m,x+1,yy,x+1,math.min(yy+dash,y+h-8),color,2);D.line(m,x+w-1,yy,x+w-1,math.min(yy+dash,y+h-8),color,2) end end
local function pcTypeKey(value) local typ=tostring(value or 'NORMAL'):upper();if typ=='PSYCH_TYPE' or typ=='PSYCHIC_TYPE' or typ=='PSYCH' then return 'PSYCHIC' end;return typ:gsub('_TYPE$','') end
local function pcSearchIcon(runtime)
  if runtime.pcSearchIcon~=nil then return runtime.pcSearchIcon or nil end
  local path=runtime.assetPath and runtime.assetPath('assets/ui/search.png') or 'assets/ui/search.png'
  local ok,img=pcall(runtime.assets.image,runtime.assets,path,'nearest')
  runtime.pcSearchIcon=ok and img or false
  return runtime.pcSearchIcon or nil
end
function Presenter.drawPcStorage(runtime,m,colors,screen)
  local D=runtime.Draw;local Boxes=require('src.pokemon.Boxes')
  if runtime.Header.drawGeneric then runtime.Header.drawGeneric(runtime,m,D,colors,screen.game,'MENÚ PRINCIPAL',"PC DE BILL") else runtime.Header.draw(runtime,m,D,colors,screen.game,"PC DE BILL") end
  D.roundRect(m,'fill',0,88,1920,928,0,colors.canvas)
  local boxes=Boxes.ensure(screen.game.save);local current=screen.game.save.currentBox or 1;local box=boxes[current] or {};local entries=screen:displayEntries();local party=screen.game.save.party or {}
  local total=0;for i=1,Boxes.COUNT do total=total+#(boxes[i] or {}) end

  -- Canonical PC redesign (Figma 1425:49837): 1792 x 856 workspace at
  -- x=64/y=120; Search is centred over Stored Pokémon (centre x=1040).
  local cx,cy=64,120
  D.text(runtime,m,'SISTEMA DE ALMACENAMIENTO POKÉMON',cx,cy+22,11,colors.textSecondary,{weight='semibold'})
  D.text(runtime,m,('%d CAJAS  •  %s / %s'):format(Boxes.COUNT,tostring(total),tostring(Boxes.COUNT*Boxes.CAPACITY)),cx,cy+46,10,colors.textSecondary,{weight='semibold'})
  runtime.pcSortRect={x=677,y=162,w=110,h=28}
  runtime.pcSearchRect={x=890,y=162,w=300,h=28}
  D.text(runtime,m,'Ordenar:',runtime.pcSortRect.x,runtime.pcSortRect.y+7,10,colors.textSecondary,{weight='medium'})
  D.text(runtime,m,screen:sortLabel(),runtime.pcSortRect.x+50,runtime.pcSortRect.y+7,10,colors.text,{weight='bold',width=60,align='left'})
  D.roundRect(m,'fill',runtime.pcSearchRect.x,runtime.pcSearchRect.y,runtime.pcSearchRect.w,runtime.pcSearchRect.h,6,colors.pcSearch or colors.panel)
  D.roundRect(m,'line',runtime.pcSearchRect.x+.5,runtime.pcSearchRect.y+.5,runtime.pcSearchRect.w-1,runtime.pcSearchRect.h-1,6,colors.pcSearchBorder or colors.border,1)
  if screen.searchActive then pcFocusOutline(runtime,m,runtime.pcSearchRect,colors.focus) end
  local searchText=screen.searchQuery~='' and screen.searchQuery or 'Buscar Pokémon...'
  local searchIcon=pcSearchIcon(runtime)
  if searchIcon then drawScaledImage(m,searchIcon,runtime.pcSearchRect.x+10,runtime.pcSearchRect.y+7,14,14) end
  D.text(runtime,m,searchText,runtime.pcSearchRect.x+32,runtime.pcSearchRect.y+7,11,screen.searchQuery~='' and colors.text or colors.disabled,{weight='medium',width=256})

  -- BOX BANK: Figma intentionally has no enclosing stroke.
  local bx,by,bw,bh=64,202,568,768
  D.roundRect(m,'fill',bx,by,bw,bh,8,colors.pcBank or colors.panel)
  D.text(runtime,m,'CAJAS',bx+24,by+22,22,colors.text,{weight='bold'})
  D.text(runtime,m,('ACTUAL %s  •  %d / %d'):format(screen:boxName(current),#box,Boxes.CAPACITY),bx+24,by+60,10,colors.textSecondary,{weight='semibold',width=350})
  runtime.pcRenameBoxRect={x=bx+bw-142,y=by+48,w=118,h=28}
  D.roundRect(m,'fill',runtime.pcRenameBoxRect.x,runtime.pcRenameBoxRect.y,runtime.pcRenameBoxRect.w,runtime.pcRenameBoxRect.h,6,colors.subtle)
  D.roundRect(m,'line',runtime.pcRenameBoxRect.x+.5,runtime.pcRenameBoxRect.y+.5,runtime.pcRenameBoxRect.w-1,runtime.pcRenameBoxRect.h-1,6,colors.border,1)
  D.text(runtime,m,'RENOMBRAR',runtime.pcRenameBoxRect.x,runtime.pcRenameBoxRect.y+8,10,colors.text,{weight='semibold',width=runtime.pcRenameBoxRect.w,align='center'})
  D.line(m,bx+24,by+86,bx+bw-24,by+86,colors.pcSearchBorder or colors.border,1)
  runtime.pcBoxRects={};local rowW=253;local colStep=267;local rowStart=by+103
  for i=1,Boxes.COUNT do
    local col=(i-1)%2;local row=math.floor((i-1)/2);local r={x=bx+24+col*colStep,y=rowStart+row*64,w=rowW,h=48};runtime.pcBoxRects[i]=r
    local enabled=screen:boxSelectable(i);local active=i==current and enabled;local keyboardFocus=enabled and screen.area=='boxes' and i==screen.boxIndex
    local hover=enabled and screen.hover and screen.hover.kind=='box' and screen.hover.value==i
    local fill=active and (colors.pcSelectedFill or colors.inverse) or colors.subtle
    local stroke=active and (colors.pcSelectedStroke or colors.inverse) or colors.border
    if not enabled then
      fill={fill[1],fill[2],fill[3],.30};stroke={stroke[1],stroke[2],stroke[3],.35}
    end
    D.roundRect(m,'fill',r.x,r.y,r.w,r.h,8,fill)
    D.roundRect(m,'line',r.x+.5,r.y+.5,r.w-1,r.h-1,8,stroke,1)
    if keyboardFocus then pcFocusOutline(runtime,m,r,colors.focus)
    elseif hover and not active then D.roundRect(m,'line',r.x+1,r.y+1,r.w-2,r.h-2,8,colors.focus,1) end
    if active then D.roundRect(m,'fill',r.x+9,r.y+12,4,24,0,colors.pcSelectedRail or colors.textSecondary) end
    local textColor=enabled and (active and colors.textInverse or colors.text) or colors.disabled
    local secondary=enabled and (active and colors.textInverse or colors.textSecondary) or colors.disabled
    D.clipText(runtime,m,screen:boxName(i),r.x+21,r.y+16,142,13,textColor,{weight='semibold'})
    local n=#(boxes[i] or {});local cap=Boxes.CAPACITY
    -- Completion glyph bars were removed by design: numeric occupancy is the sole status.
    if enabled then
      D.text(runtime,m,('%d / %d'):format(n,cap),r.x+168,r.y+16,10,secondary,{width=72,align='right'})
    else
      -- Text makes the search-disabled state accessible without relying on
      -- opacity/color alone, while the box remains in its canonical position.
      D.text(runtime,m,'SIN COINCIDENCIAS',r.x+164,r.y+16,9,colors.disabled,{weight='semibold',width=76,align='right'})
    end
  end

  -- STORED POKÉMON: exact 720-wide centered column, 24 px horizontal inset,
  -- 4 columns x 156 px, 8 px horizontal gap, 12 px vertical gap.
  local sx,sy,sw,sh=680,202,720,768;runtime.pcStoredRect={x=sx,y=sy,w=sw,h=sh}
  D.roundRect(m,'fill',sx,sy,sw,sh,8,colors.pcSurface or colors.panel)
  D.roundRect(m,'line',sx+.5,sy+.5,sw-1,sh-1,8,colors.pcBorder or colors.border,1)
  D.text(runtime,m,'POKÉMON ALMACENADOS',sx+25,sy+13,22,colors.text,{weight='bold'})
  D.text(runtime,m,('ACTUAL %s'):format(screen:boxName(current)),sx+25,sy+43,10,colors.textSecondary,{weight='semibold',width=260})
  D.text(runtime,m,('%d / %d  •  %d LIBRES'):format(#box,Boxes.CAPACITY,Boxes.CAPACITY-#box),sx+448,sy+41,10,colors.textSecondary,{weight='semibold',width=247,align='right'})
  D.line(m,sx+25,sy+73,sx+sw-25,sy+73,colors.pcSearchBorder or colors.pcBorder or colors.border,1)
  runtime.pcMonRects={};local cols,visible=4,20;local visibleRows=5;local totalSlots=math.max(1,#entries+1);local totalRows=math.ceil(totalSlots/cols);local startRow=math.max(0,math.min(math.max(0,totalRows-visibleRows),tonumber(screen.storageStartRow) or 0));local first=startRow*cols+1
  local maxDraw=math.min(first+visible-1,totalSlots)
  for i=first,maxDraw do
    local slot=i-first;local col=slot%cols;local row=math.floor(slot/cols);local r={x=sx+25+col*164,y=sy+90+row*128,w=156,h=116};runtime.pcMonRects[i]=r;local entry=entries[i];local mon=entry and entry.mon
    local keyboardFocus=screen.area=='stored' and i==screen.monIndex;local hover=screen.hover and screen.hover.kind=='stored' and screen.hover.value==i
    local sel=entry and screen.selected and screen.selected.where=='box' and (screen.selected.boxIndex or current)==current and screen.selected.index==entry.sourceIndex
    D.roundRect(m,'fill',r.x,r.y,r.w,r.h,8,colors.subtle)
    if keyboardFocus then pcFocusOutline(runtime,m,r,colors.focus)
    elseif hover then D.roundRect(m,'line',r.x+.5,r.y+.5,r.w-1,r.h-1,8,colors.focus,1) end
    if sel then pcDashedRect(runtime,m,r.x,r.y,r.w,r.h,colors.focus) end
    if mon then
      local dex=tonumber(entry.def and entry.def.dex) or entry.sourceIndex;D.text(runtime,m,('%03d'):format(dex),r.x+8,r.y+7,9,colors.textSecondary,{weight='medium'})
      pcPartyIcon(runtime,m,screen.game,mon,r.x+54,r.y+12,48)
      local def=screen.game.data.pokemon and screen.game.data.pokemon[mon.species];local types=def and def.types or {}
      for ti=1,math.min(2,#types) do local typ=pcTypeKey(types[ti]);local tx=ti==1 and r.x+8 or r.x+r.w-40;local tc=colors.typeColors and colors.typeColors[typ] or colors.focus;if runtime.TypeIcon then runtime.TypeIcon.draw(typ,m.ox+(tx+16)*m.scale,m.oy+(r.y+45)*m.scale,32*m.scale,tc,1) end end
      D.clipText(runtime,m,pcMonName(runtime,screen.game,mon),r.x+8,r.y+77,r.w-16,14,colors.text,{weight='bold',align='center'})
      D.text(runtime,m,'Nv. '..tostring(mon.level or '—'),r.x,r.y+98,11,colors.textSecondary,{weight='medium',width=r.w,align='center'})
    else D.text(runtime,m,'COLOCAR',r.x,r.y+51,10,colors.textSecondary,{weight='semibold',width=r.w,align='center'}) end
  end
  runtime.pcStorageScrollbar=nil
  if totalRows>visibleRows then
    local track={x=sx+700,y=sy+76,w=8,h=676};local maxStart=math.max(1,totalRows-visibleRows);local ratio=startRow/maxStart;local th=math.max(88,track.h*visibleRows/totalRows);local ty=track.y+ratio*(track.h-th);runtime.pcStorageScrollbar={track=track,thumb={x=track.x,y=ty,w=track.w,h=th}}
    D.roundRect(m,'fill',track.x,track.y,track.w,track.h,4,colors.pcScrollbarTrack or colors.border);D.roundRect(m,'fill',track.x,ty,track.w,th,4,colors.pcScrollbarThumb or colors.focus)
  end

  -- ACTIVE PARTY / context panel.
  local rx,ry,rw,rh=1448,202,408,768;runtime.pcPartyPanelRect={x=rx,y=ry,w=rw,h=rh}
  D.roundRect(m,'fill',rx,ry,rw,rh,8,colors.pcSurface or colors.panel);D.roundRect(m,'line',rx+.5,ry+.5,rw-1,rh-1,8,colors.pcBorder or colors.border,1)
  D.text(runtime,m,'EQUIPO ACTUAL',rx+21,ry+22,10,colors.textSecondary,{weight='bold'})
  runtime.pcPartyRects={};local slotW=116
  for i=1,math.min(6,#party+1) do
    if i>#party and #party>=6 then break end
    local mon=party[i];local col=(i-1)%3;local row=math.floor((i-1)/3);local r={x=rx+20+col*(slotW+8),y=ry+42+row*104,w=slotW,h=96};runtime.pcPartyRects[i]=r
    local keyboardFocus=screen.area=='party' and i==screen.partyIndex;local hover=screen.hover and screen.hover.kind=='party' and screen.hover.value==i;local sel=screen.selected and screen.selected.where=='party' and screen.selected.index==i
    D.roundRect(m,'fill',r.x,r.y,r.w,r.h,8,colors.subtle)
    if keyboardFocus then pcFocusOutline(runtime,m,r,colors.focus) elseif hover then D.roundRect(m,'line',r.x+.5,r.y+.5,r.w-1,r.h-1,8,colors.focus,1) end
    if sel then pcDashedRect(runtime,m,r.x,r.y,r.w,r.h,colors.focus) end
    if mon then pcPartyIcon(runtime,m,screen.game,mon,r.x+34,r.y+7,48);D.clipText(runtime,m,pcMonName(runtime,screen.game,mon),r.x+4,r.y+60,r.w-8,10,colors.text,{weight='bold',align='center'});D.text(runtime,m,'Nv. '..tostring(mon.level or '—'),r.x,r.y+77,9,colors.textSecondary,{width=r.w,align='center'}) else D.text(runtime,m,'DEPOSITAR',r.x,r.y+42,9,colors.textSecondary,{weight='semibold',width=r.w,align='center'}) end
  end
  D.line(m,rx+21,ry+254,rx+rw-21,ry+254,colors.pcBorder or colors.border,1)
  local selected=screen:contextMon();if selected then
    local model=nil;if runtime.PartyAdapter and type(runtime.PartyAdapter.pokemon)=='function' then local ok,v=pcall(runtime.PartyAdapter.pokemon,screen.game,selected);if ok then model=v end end
    local contentY=ry+267
    D.text(runtime,m,'SELECCIONADO',rx+21,contentY,9,colors.textSecondary,{weight='bold'});pcPartyIcon(runtime,m,screen.game,selected,rx+21,contentY+24,64)
    local name=pcMonName(runtime,screen.game,selected);D.text(runtime,m,name,rx+101,contentY+28,18,colors.text,{weight='bold',width=250});local detailTypes=table.concat(screen:typeNames(selected),' / ');D.text(runtime,m,'Nv. '..tostring(selected.level or '—')..(detailTypes~='' and ' · '..detailTypes or ''),rx+101,contentY+56,11,colors.textSecondary,{weight='semibold',width=250})
    local hp=tonumber((model and model.hp) or selected.hp) or 0;local max=tonumber(model and model.stats and model.stats.hp or selected.stats and selected.stats.hp) or hp
    local hpRatio=max>0 and math.max(0,math.min(1,hp/max)) or 0;local hpColor=hpRatio<=.2 and colors.danger or hpRatio<=.5 and colors.warning or colors.success;D.text(runtime,m,'PS',rx+21,contentY+100,10,colors.textSecondary,{weight='bold'});D.text(runtime,m,max>0 and (('%d / %d'):format(hp,max)) or '—',rx+285,contentY+100,10,colors.text,{weight='semibold',width=92,align='right'});D.roundRect(m,'fill',rx+21,contentY+122,rw-42,10,5,colors.subtle);if hpRatio>0 then D.roundRect(m,'fill',rx+21,contentY+122,(rw-42)*hpRatio,10,5,hpColor) end
    D.text(runtime,m,'EXP',rx+21,contentY+148,10,colors.textSecondary,{weight='bold'});local ratio=tonumber(model and model.expRatio) or 0;D.text(runtime,m,model and model.toNextLevel and (tostring(model.toNextLevel)..' PARA SUBIR') or '—',rx+241,contentY+148,10,colors.textSecondary,{weight='semibold',width=136,align='right'});D.roundRect(m,'fill',rx+21,contentY+170,rw-42,10,5,colors.subtle);if ratio>0 then D.roundRect(m,'fill',rx+21,contentY+170,(rw-42)*math.min(1,ratio),10,5,colors.exp) end
    D.text(runtime,m,'MOVIMIENTOS',rx+21,contentY+196,9,colors.textSecondary,{weight='bold'});local moves=screen:contextMoves()
    for i=1,4 do local move=moves[i];local my=contentY+219+(i-1)*56;D.roundRect(m,'fill',rx+21,my,rw-42,44,8,colors.subtle);if move then local typ=pcTypeKey(move.type);local tc=colors.typeColors and colors.typeColors[typ] or colors.focus;if runtime.TypeIcon then runtime.TypeIcon.draw(typ,m.ox+(rx+39)*m.scale,m.oy+(my+22)*m.scale,26*m.scale,tc,1) end;D.clipText(runtime,m,tostring(move.name or move.id or 'DESCONOCIDO'):upper(),rx+59,my+13,rw-198,11,colors.text,{weight='semibold'});local pp=move.pp~=nil and tostring(move.pp) or '—';local maxpp=move.maxPP~=nil and tostring(move.maxPP) or '—';D.text(runtime,m,pp..' / '..maxpp..' PP',rx+rw-135,my+13,9,colors.textSecondary,{weight='semibold',width=94,align='right'}) else D.text(runtime,m,'—',rx+59,my+13,11,colors.textSecondary,{weight='semibold'}) end end
    D.line(m,rx+21,contentY+443,rx+rw-21,contentY+443,colors.pcBorder or colors.border,1)
    runtime.pcReleaseRect={x=rx+21,y=contentY+456,w=rw-42,h=34};if screen.area=='stored' then D.roundRect(m,'fill',runtime.pcReleaseRect.x,runtime.pcReleaseRect.y,runtime.pcReleaseRect.w,runtime.pcReleaseRect.h,6,colors.danger);D.text(runtime,m,'LIBERAR A '..name,runtime.pcReleaseRect.x,runtime.pcReleaseRect.y+10,10,colors.textInverse,{weight='bold',width=runtime.pcReleaseRect.w,align='center'}) end
  end

  local drag=screen.drag;if drag and drag.active and drag.x and drag.y and screen.selected and screen.selected.mon then local mon=screen.selected.mon;local r={x=drag.x-78,y=drag.y-58,w=156,h=116};local panelColor={colors.panel[1],colors.panel[2],colors.panel[3],.82};local borderColor={colors.focus[1],colors.focus[2],colors.focus[3],.9};D.roundRect(m,'fill',r.x,r.y,r.w,r.h,8,panelColor);pcDashedRect(runtime,m,r.x,r.y,r.w,r.h,borderColor);pcPartyIcon(runtime,m,screen.game,mon,r.x+54,r.y+10,48);D.clipText(runtime,m,pcMonName(runtime,screen.game,mon),r.x+8,r.y+77,r.w-16,12,colors.text,{weight='bold',align='center'});D.text(runtime,m,'Nv. '..tostring(mon.level or '—'),r.x,r.y+98,9,colors.textSecondary,{weight='medium',width=r.w,align='center'}) end

  if screen.releaseConfirm then
    D.roundRect(m,'fill',0,88,1920,928,0,{0,0,0,.42});local x,y,w,h=766,404,388,220;D.panel(m,x,y,w,h,12,colors.panel,colors.borderStrong);D.text(runtime,m,'¿LIBERAR POKéMON?',x+24,y+24,17,colors.danger,{weight='bold',width=w-48,align='center'});D.text(runtime,m,'Esta acción no se puede deshacer.',x+24,y+62,12,colors.textSecondary,{width=w-48,align='center'});runtime.pcReleaseChoiceRects={cancel={x=x+30,y=y+142,w=144,h=48},release={x=x+214,y=y+142,w=144,h=48}};for _,id in ipairs({'cancel','release'}) do local r=runtime.pcReleaseChoiceRects[id];local f=screen.releaseChoice==id;local label=id=='release' and 'LIBERAR' or 'CANCELAR';D.panel(m,r.x,r.y,r.w,r.h,8,id=='release' and (f and colors.danger or colors.subtle) or colors.subtle,f and colors.focus or colors.border);D.text(runtime,m,label,r.x,r.y+15,11,id=='release' and f and colors.textInverse or colors.text,{weight='bold',width=r.w,align='center'}) end
  end
  runtime.pcSortChoiceRects={}
  if screen.sortOpen then
    D.roundRect(m,'fill',0,88,1920,928,0,{0,0,0,.42})
    local x,y,w,h=831,443,258,218;D.panel(m,x,y,w,h,10,colors.panel,colors.borderStrong)
    D.text(runtime,m,'ORDENAR POR',x+16,y+16,10,colors.textSecondary,{weight='bold'});D.line(m,x+16,y+37,x+w-16,y+37,colors.border,1)
    local labels={'POKÉDEX','TIPO','NIVEL'}
    for i,label in ipairs(labels) do
      local r={x=x+16,y=y+45+(i-1)*37,w=226,h=33};runtime.pcSortChoiceRects[i]=r
      local selected=(screen.sortFocus or 1)==i
      if selected then D.roundRect(m,'fill',r.x,r.y,r.w,r.h,6,colors.subtle);pcFocusOutline(runtime,m,r,colors.focus) end
      D.roundRect(m,'line',r.x+4,r.y+8.5,16,16,8,selected and colors.focus or colors.border,1)
      if selected then D.roundRect(m,'fill',r.x+8,r.y+12.5,8,8,4,colors.focus) end
      D.text(runtime,m,label,r.x+30,r.y+8,11,colors.text,{weight='semibold'})
    end
    D.roundRect(m,'fill',x+16,y+160,226,4,2,colors.border)
    D.text(runtime,m,'↑/↓  SELECCIONAR    ENTER  APLICAR    A  VOLVER',x+16,y+172,8,colors.textSecondary,{weight='semibold',width=226,align='center'})
  end
  D.roundRect(m,'fill',0,1016,1920,64,0,colors.inverse)
  local _,device=runtime.Footer.resolve(screen.game,{})
  local renameKey='N'
  if device=='TÁCTIL' then renameKey='TOCAR' elseif device~='TECLADO + RATÓN' then
    local rp=runtime.Footer.resolve(screen.game,{{action='select',label='RENOMBRAR CAJA'}});renameKey=(rp[1] and rp[1].key) or 'SELECT'
  end
  local prompts={{'FLECHAS','NAVEGAR'},{'ENTER','ABRIR'},{renameKey,'RENOMBRAR CAJA'},{'ARRASTRAR','MOVER'},{'A','VOLVER'}};local px=32
  for _,pp in ipairs(prompts) do D.text(runtime,m,pp[1],px,1037,12,colors.textInverse,{weight='bold'});D.text(runtime,m,pp[2],px+70,1038,11,colors.textInverse,{alpha=.72});px=px+230 end
  D.text(runtime,m,device,1640,1038,12,colors.textInverse,{weight='semibold',width=248,align='right'})
end


-- GRAPHICS LIVE EDITOR -----------------------------------------------------
function Presenter.drawGraphicsEditor(runtime,m,colors,screen)
  local D=runtime.Draw
  local preview,previewErr=runtime.BattlePresenter.drawGraphicsPreview(screen.game,runtime.viewport,{
    background=screen.background,phase=screen.phase,playerSpecies=screen.playerSpecies,opponentSpecies=screen.opponentSpecies,config=screen.working,uiLayout=screen.uiWorking,uiTarget=screen.uiTarget,trainerPhase=screen.trainerPreviewPhase,grid=screen.gridEnabled==true,battle=screen.liveBattle and screen.battle or nil,
  })
  runtime.graphicsEditorPreviewBounds=preview and preview.bounds or {}
  runtime.graphicsEditorPerformance=preview and preview.performance or nil
  runtime.graphicsEditorUiBounds=preview and preview.uiBounds or {}
  runtime.graphicsEditorSceneAnchors=preview and preview.sceneAnchors or {}
  runtime.graphicsEditorPreviewResult=preview

  -- Exact renderer bounds: the same box returned by BattlePresenter after its
  -- authored-cell fit. Violet is debug-only and never part of normal combat.
  if screen.positionRole then
    local r=runtime.graphicsEditorPreviewBounds and runtime.graphicsEditorPreviewBounds[screen.positionRole]
    if r then D.roundRect(m,'line',r.x,r.y,r.w,r.h,2,{0.647,0.38,0.773,1},3);D.text(runtime,m,screen.positionRole:upper()..' BOUNDS',r.x,r.y-22,10,{0.647,0.38,0.773,1},{weight='bold'}) end
  end
  local uiSelected=screen.positionRole and screen.positionRole:match('^ui:(.+)$');if uiSelected then local r=runtime.graphicsEditorUiBounds and runtime.graphicsEditorUiBounds[uiSelected];if r then D.roundRect(m,'line',r.x,r.y,r.w,r.h,4,{0.647,0.38,0.773,1},3);D.text(runtime,m,uiSelected:upper()..' · LIVE COMPONENT',r.x,r.y-22,10,{0.647,0.38,0.773,1},{weight='bold'}) end end

  local x,y,w,h=screen.popupX or 48,screen.popupY or 108,screen.popupW or 610,screen.popupH or 860
  D.roundRect(m,'fill',x+6,y+8,w,h,16,{0,0,0,.28})
  D.panel(m,x,y,w,h,16,{colors.panel[1],colors.panel[2],colors.panel[3],.97},colors.borderStrong or colors.border)
  runtime.graphicsEditorPopupHeader={x=x,y=y,w=w,h=66}
  runtime.graphicsEditorPopupResizeHandle={x=x+w-28,y=y+h-28,w=22,h=22}
  D.text(runtime,m,'LIVE GRAPHICS EDITOR',x+22,y+18,20,colors.text,{weight='bold'})
  D.text(runtime,m,screen.liveBattle and 'LIVE BATTLE · INPUT LOCKED' or 'SAME KRS BATTLE PIPELINE',x+22,y+44,9,colors.textSecondary,{weight='bold'})
  D.text(runtime,m,'DRAG',x+w-66,y+26,9,colors.textSecondary,{weight='bold',width=44,align='right'})

  -- Global / Local segmented choice. Shape + label reinforce selection.
  local sx,sy=x+22,y+74;local sw=(w-44-8)/2;runtime.graphicsEditorScopeRects={}
  for i,v in ipairs({'GLOBAL','LOCAL'}) do
    local scope=v:lower();local active=(screen.scope==scope);local hovered=screen.scopeHover==scope;local pressed=screen.scopePressed==scope;local r={x=sx+(i-1)*(sw+8),y=sy,w=sw,h=42};runtime.graphicsEditorScopeRects[scope]=r
    local fill=pressed and (colors.inverseRaised or colors.inverse) or active and colors.inverse or hovered and colors.subtle or colors.subtle
    D.roundRect(m,'fill',r.x,r.y,r.w,r.h,9,fill)
    D.roundRect(m,'line',r.x,r.y,r.w,r.h,9,(active or hovered) and colors.focus or colors.border,active and 2 or 1)
    D.text(runtime,m,(active and '✓  ' or '')..v,r.x,r.y+12,12,active and colors.textInverse or colors.text,{weight='bold',width=r.w,align='center'})
  end

  local rows=screen:rows();runtime.graphicsEditorRowRects={};runtime.graphicsEditorSliderTracks={}
  local list={x=x+18,y=y+128,w=w-36,h=h-206};local rowH=50;local cy=list.y-(screen.scrollY or 0)
  local oldX,oldY,oldW,oldH=love.graphics.getScissor();love.graphics.setScissor(m.ox+list.x*m.scale,m.oy+list.y*m.scale,list.w*m.scale,list.h*m.scale)
  for i,row in ipairs(rows) do
    local hh=row.kind=='header' and 30 or rowH;local r={x=list.x,y=cy,w=list.w,h=hh};runtime.graphicsEditorRowRects[i]=r
    if cy+hh>=list.y and cy<=list.y+list.h then
      if row.kind=='header' then
        D.text(runtime,m,row.label,r.x+6,r.y+10,9,colors.textSecondary,{weight='bold'});D.line(m,r.x+104,r.y+15,r.x+r.w-6,r.y+15,colors.border,1)
      else
        local st=runtime.Focus.visual(screen.nav,'graphics:'..i,screen:activeId(),nil)
        local focused=st=='focus';local hovered=st=='hover';local pressed=screen.pressedRow==i or (screen.sliderDrag and screen.sliderDrag.index==i)
        local selected=(screen.positionRole and row.kind=='position' and screen.positionRole==row.role) or (row.kind=='background_position' and screen.positionRole=='background') or (row.kind=='ui_position' and screen.positionRole==('ui:'..tostring(row.target)))
        local fill=pressed and (colors.inverseRaised or colors.inverse) or selected and colors.subtle or hovered and colors.subtle or focused and colors.subtle or {colors.panel[1],colors.panel[2],colors.panel[3],.74}
        D.roundRect(m,'fill',r.x,r.y+2,r.w,r.h-4,9,fill)
        if focused then D.roundRect(m,'line',r.x+1,r.y+3,r.w-2,r.h-6,8,colors.focus,3);D.roundRect(m,'fill',r.x+7,r.y+12,4,r.h-24,2,colors.focus) end
        if hovered and not focused then D.roundRect(m,'line',r.x+2,r.y+4,r.w-4,r.h-8,7,colors.focus,1) end
        if selected then D.roundRect(m,'line',r.x+4,r.y+6,r.w-8,r.h-12,6,colors.focus,2);D.text(runtime,m,'SELECTED',r.x+r.w-160,r.y+29,8,colors.textSecondary,{weight='bold',width=146,align='right'}) end
        if pressed then D.text(runtime,m,'PRESSED',r.x+r.w-160,r.y+29,8,colors.textInverse,{weight='bold',width=146,align='right'}) end
        if row.disabled then D.text(runtime,m,'DISABLED',r.x+r.w-118,r.y+18,9,colors.textSecondary,{weight='bold',width=106,align='right'}) end
        local labelW=math.max(142,math.min(206,r.w*.38));local valueW=78;local controlX=r.x+labelW+24
        D.text(runtime,m,row.label,r.x+12,r.y+10,10,row.disabled and colors.textSecondary or colors.text,{weight='semibold',width=labelW-14})
        if row.kind=='slider' then
          local trackW=math.max(72,r.x+r.w-14-valueW-12-controlX);local tr={x=controlX,y=r.y+20,w=trackW,h=8};runtime.graphicsEditorSliderTracks[i]=tr
          D.roundRect(m,'fill',tr.x,tr.y,tr.w,tr.h,4,colors.border)
          local lo,hi=tonumber(row.min) or 0,tonumber(row.max) or 100;local pct=math.max(0,math.min(1,((tonumber(row.value) or lo)-lo)/math.max(1,hi-lo)));D.roundRect(m,'fill',tr.x,tr.y,tr.w*pct,tr.h,4,colors.focus)
          D.roundRect(m,'fill',tr.x+tr.w*pct-7,tr.y-3,14,14,7,colors.panel);D.roundRect(m,'line',tr.x+tr.w*pct-7,tr.y-3,14,14,7,colors.focus,2)
          local value=tostring(math.floor((row.value or 0)+.5))..(row.suffix or '')
          D.text(runtime,m,value,r.x+r.w-valueW-10,r.y+12,12,colors.text,{weight='bold',width=valueW,align='right'})
        else
          local valueX=controlX;local avail=math.max(70,r.x+r.w-valueX-12)
          D.text(runtime,m,tostring(row.value or (row.kind=='action' and 'OPEN') or ''),valueX,r.y+11,11,row.disabled and colors.textSecondary or colors.text,{weight='semibold',width=avail,align='right'})
          if (row.kind=='position' and screen.positionRole==row.role) or (row.kind=='background_position' and screen.positionRole=='background') or (row.kind=='ui_position' and screen.positionRole==('ui:'..tostring(row.target))) then D.text(runtime,m,'EDITING · D-PAD/DRAG',valueX,r.y+28,8,{0.647,0.38,0.773,1},{weight='bold',width=avail,align='right'}) end
        end
      end
    end
    cy=cy+hh
  end
  if oldX then love.graphics.setScissor(oldX,oldY,oldW,oldH) else love.graphics.setScissor() end

  local rh=runtime.graphicsEditorPopupResizeHandle;D.line(m,rh.x+5,rh.y+17,rh.x+17,rh.y+5,colors.textSecondary,2);D.line(m,rh.x+10,rh.y+17,rh.x+17,rh.y+10,colors.textSecondary,2)

  local footerY=y+h-70;D.line(m,x+18,footerY,x+w-18,footerY,colors.border,1)
  local perf=runtime.graphicsEditorPerformance
  if perf then
    local perfText=('FPS %s  ·  DRAW %s  ·  %.2f ms  ·  Δ %.1f KB'):format(tostring(perf.fps or '—'),tostring(perf.drawCalls or '—'),tonumber(perf.renderMs) or 0,tonumber(perf.allocationKb) or 0)
    D.text(runtime,m,perfText,x+22,footerY+12,9,colors.textSecondary,{weight='semibold',width=w-44})
  elseif previewErr then D.text(runtime,m,'PREVIEW ERROR · '..tostring(previewErr),x+22,footerY+12,9,colors.warning,{weight='bold',width=w-44}) end
  D.text(runtime,m,screen.notice or 'LIVE PREVIEW · VALUES COMMIT AT END OF INTERACTION',x+22,footerY+32,9,colors.textSecondary,{weight='bold',width=w-44})

  -- A compact footer keeps the scene visible. It uses the same semantic
  -- binding/device source as the rest of KRS; controller/keyboard switches
  -- therefore update immediately without reopening the editor.
  D.roundRect(m,'fill',0,1016,1920,64,0,colors.inverse)
  local semantic=screen.positionRole and {
    {navigation=true,label='MOVE'},
    {action='select',label='FINE'},
    {action='a',label='FINISH'},
    {action='b',label='FINISH / BACK'},
  } or {
    {navigation=true,label='CONTROL / ADJUST'},
    {action='a',label='EDIT / OPEN'},
    {action='b',label='BACK'},
  }
  local prompts,device=runtime.Footer.resolve(screen.game,semantic);local px=32
  for _,pp in ipairs(prompts) do D.text(runtime,m,pp.key,px,1037,11,colors.textInverse,{weight='bold'});local f=D.font(runtime,m,11,'bold');local kw=f:getWidth(pp.key)/m.scale;D.text(runtime,m,pp.label,px+kw+9,1038,10,colors.textInverse,{alpha=.72});px=px+math.max(210,kw+135) end
  D.text(runtime,m,device,1640,1038,12,colors.textInverse,{weight='semibold',width=248,align='right'})
end


function Presenter.draw(runtime,game,viewport)
  if not (love and love.graphics and runtime.Layout.isWide(viewport)) then return false end
  local top=game and game.stack and game.stack.top and game.stack:top()
  if not top or not top.kind then return false end
  if top.isWide and not top:isWide() then return false end
  local supported={krs_title=true,main=true,options=true,mods=true,mod_extension=true,controls=true,field_actions_popup=true,krs_map=true,save_slots=true,bag_register=true,pc_storage=true,graphics_editor=true}
  if not supported[top.kind] then return false end
  local m=runtime.Layout.metrics(viewport)
  local colors=runtime.Theme.resolveAll(runtime,game)
  love.graphics.push("all");love.graphics.origin()
  love.graphics.setShader()
  love.graphics.setBlendMode("alpha")
  love.graphics.setColor(1,1,1,1)
  pcall(love.graphics.setDepthMode,"always",false)
  pcall(love.graphics.setScissor)
  local ok,err=pcall(function()
    if top.kind=="krs_title" then Presenter.drawTitle(runtime,m,colors,top)
    elseif top.kind=="main" then Presenter.drawMain(runtime,m,colors,top)
    elseif top.kind=="options" then Presenter.drawOptions(runtime,m,colors,top)
    elseif top.kind=="mods" then Presenter.drawMods(runtime,m,colors,top)
    elseif top.kind=="mod_extension" then Presenter.drawModExtension(runtime,m,colors,top)
    elseif top.kind=="controls" then Presenter.drawControls(runtime,m,colors,top)
    elseif top.kind=="field_actions_popup" then Presenter.drawFieldActions(runtime,m,colors,top)
    elseif top.kind=="krs_map" then Presenter.drawMap(runtime,m,colors,top)
    elseif top.kind=="save_slots" then Presenter.drawSaveSlots(runtime,m,colors,top)
    elseif top.kind=="bag_register" then Presenter.drawBagRegister(runtime,m,colors,top)
    elseif top.kind=="pc_storage" then Presenter.drawPcStorage(runtime,m,colors,top)
    elseif top.kind=="graphics_editor" then Presenter.drawGraphicsEditor(runtime,m,colors,top) end
  end)
  love.graphics.pop()
  if not ok then return nil,err end
  return true
end
return Presenter
