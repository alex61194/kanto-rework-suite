return function(options)
  local C=assert(options.C); local Layout=assert(options.Layout)
  local Adapter=assert(options.Adapter); local runtime=assert(options.runtime)
  local TypeIcon=assert(options.TypeIcon)
  local TypeChip=assert(options.TypeChip)
  local StatusToken=assert(options.StatusToken)
  local Footer=assert(options.Footer)
  local Palette=assert(options.Palette)
  local Core=assert(options.Core)
  local P={}; local fonts={}; local partyBalls=nil
  local theme={colors=C.colors,typeColors=C.typeColors,profile="standard",colorMode="unknown"}
  local drawT={scale=1,offsetX=0,offsetY=0,screenWidth=C.DESIGN_WIDTH,screenHeight=C.DESIGN_HEIGHT,viewportWidth=C.DESIGN_WIDTH,viewportHeight=C.DESIGN_HEIGHT}
  local opacity=1

  local function round(v) return math.floor(v+.5) end
  local function sx(v) return round(drawT.offsetX+(tonumber(v) or 0)*drawT.scale) end
  local function sy(v) return round(drawT.offsetY+(tonumber(v) or 0)*drawT.scale) end
  local function sl(v,minimum) return math.max(minimum or 1,round((tonumber(v) or 0)*drawT.scale)) end
  local function stroke(v) return sl(v,(tonumber(v) or 0)>=2 and 2 or 1) end
  local function rectPhysical(x,y,w,h)
    local x1,y1=sx(x),sy(y);local x2,y2=sx(x+w),sy(y+h)
    return x1,y1,math.max(1,x2-x1),math.max(1,y2-y1)
  end
  local function color(c,a) love.graphics.setColor(c[1],c[2],c[3],(a or c[4] or 1)*opacity) end
  local function minimumFont(size)
    if size<=11 then return C.MIN_FONT_PX or 10 end
    if size<=13 then return 11 end
    if size<=15 then return 12 end
    if size<=18 then return 13 end
    if size<=20 then return 14 end
    if size<=24 then return 16 end
    if size<=28 then return 18 end
    return 20
  end
  local function font(size,weight)
    local actual=math.max(minimumFont(size),round(size*drawT.scale))
    weight=weight or "regular"
    local family=runtime.fontFamily
    if runtime.Theme and type(runtime.Theme.fontFamily)=="function" then
      local ok,value=pcall(runtime.Theme.fontFamily);if ok and type(value)=="string" and value~="" then family=value end
    end
    local key=tostring(family or "default")..":"..tostring(actual)..":"..weight
    if not fonts[key] then
      local typography=Core and Core.typography
      if not fonts[key] and typography and family and type(typography.font)=="function" then
        local ok,loaded=pcall(typography.font,family,weight,actual)
        if ok and loaded then fonts[key]=loaded end
      end
      local familyPaths=typography and family and type(typography.paths)=="function" and typography.paths(family) or nil
      local fallbackPaths=familyPaths or runtime.fontPaths
      if not fonts[key] and fallbackPaths then
        local path=fallbackPaths[weight] or fallbackPaths.regular
        if path then local ok,loaded=pcall(love.graphics.newFont,path,actual);if ok then fonts[key]=loaded end end
      end
      if not fonts[key] then fonts[key]=love.graphics.newFont(actual) end
      if fonts[key] and type(fonts[key].setFallbacks)=="function" and runtime.fontFallbackPath then
        local ok,fallback=pcall(love.graphics.newFont,runtime.fontFallbackPath,actual)
        if ok and fallback then pcall(fonts[key].setFallbacks,fonts[key],fallback) end
      end
      if fonts[key] and family=="kanto_rework.pixelify_sans" and type(fonts[key].setFilter)=="function" then
        pcall(fonts[key].setFilter,fonts[key],"nearest","nearest",1)
      end
    end
    return fonts[key]
  end
  local function text(value,x,y,size,c,align,width,weight)
    love.graphics.setFont(font(size,weight)); color(c or theme.colors.ink)
    local px,py=sx(x),sy(y)
    if width then love.graphics.printf(tostring(value or ""),px,py,sl(width),align or "left")
    else love.graphics.print(tostring(value or ""),px,py) end
  end
  local function textWidth(value,size,weight)
    local face=font(size,weight)
    if face and type(face.getWidth)=="function" then
      local ok,width=pcall(face.getWidth,face,tostring(value or ""))
      if ok and type(width)=="number" then return width/math.max(drawT.scale,0.0001) end
    end
    return #tostring(value or "")*(tonumber(size) or 12)*.56
  end
  local function rect(mode,x,y,w,h,r,c,lw)
    local px,py,pw,ph=rectPhysical(x,y,w,h);color(c)
    if lw then love.graphics.setLineWidth(stroke(lw)) end
    local pr=math.max(0,sl(r or 0,0))
    love.graphics.rectangle(mode,px,py,pw,ph,pr,pr)
  end
  local function segment(x1,y1,x2,y2,c,lw)
    color(c or theme.colors.ink);love.graphics.setLineWidth(stroke(lw or 1))
    love.graphics.line(sx(x1),sy(y1),sx(x2),sy(y2))
  end
  local function circle(mode,x,y,r,c,lw)
    color(c or theme.colors.ink);if lw then love.graphics.setLineWidth(stroke(lw)) end
    love.graphics.circle(mode,sx(x),sy(y),sl(r))
  end
  local function polygonLine(points,c,lw)
    local out={};for i=1,#points,2 do out[#out+1]=sx(points[i]);out[#out+1]=sy(points[i+1]) end
    color(c or theme.colors.ink);love.graphics.setLineWidth(stroke(lw or 1));love.graphics.polygon("line",out)
  end
  local function line(x,y,w,c) rect("fill",x,y,w,math.max(1/drawT.scale,1),0,c or theme.colors.border) end
  local function panel(r,tone)
    rect("fill",r.x,r.y,r.w,r.h,16,tone or theme.colors.panel)
    rect("line",r.x+.5,r.y+.5,r.w-1,r.h-1,16,theme.colors.border,1)
  end
  local function addRegion(state,kind,id,index,x,y,w,h)
    state.regions[#state.regions+1]={kind=kind,id=id,index=index,x=x,y=y,w=w,h=h}
  end
  local function roundedClip(x,y,w,h,r,draw)
    local px,py,pw,ph=rectPhysical(x,y,w,h);local pr=sl(r,0)
    love.graphics.stencil(function() love.graphics.rectangle("fill",px,py,pw,ph,pr,pr) end,"replace",1)
    love.graphics.setStencilTest("greater",0);draw();love.graphics.setStencilTest()
  end
  local function selectedRail(x,y,w,h,r)
    roundedClip(x,y,w,h,r,function() rect("fill",x,y,14,h,0,theme.colors.focus) end)
  end
  local function dashedRect(x,y,w,h,c)
    local dash,gap=10,6
    for xx=x+8,x+w-8,dash+gap do segment(xx,y+1,math.min(xx+dash,x+w-8),y+1,c,2);segment(xx,y+h-1,math.min(xx+dash,x+w-8),y+h-1,c,2) end
    for yy=y+8,y+h-8,dash+gap do segment(x+1,yy,x+1,math.min(yy+dash,y+h-8),c,2);segment(x+w-1,yy,x+w-1,math.min(yy+dash,y+h-8),c,2) end
  end
  local function frameState(state,x,y,w,h,r)
    rect("fill",x,y,w,h,r,theme.colors.panel)
    if state=="Focused" then rect("line",x+1.5,y+1.5,w-3,h-3,r,theme.colors.focus,3)
    elseif state=="Hover" then rect("line",x+1,y+1,w-2,h-2,r,theme.colors.selected,2)
    elseif state=="Dragging" then
      local dash,gap=10,6
      for xx=x+10,x+w-10,dash+gap do segment(xx,y+1.5,math.min(xx+dash,x+w-10),y+1.5,theme.colors.focus,3);segment(xx,y+h-1.5,math.min(xx+dash,x+w-10),y+h-1.5,theme.colors.focus,3) end
      for yy=y+10,y+h-10,dash+gap do segment(x+1.5,yy,x+1.5,math.min(yy+dash,y+h-10),theme.colors.focus,3);segment(x+w-1.5,yy,x+w-1.5,math.min(yy+dash,y+h-10),theme.colors.focus,3) end
    else rect("line",x+.5,y+.5,w-1,h-1,r,theme.colors.border,1) end
    if state=="Selected" then selectedRail(x,y,w,h,r) end
  end
  local function withOpacity(alpha,fn) local previous=opacity;opacity=previous*(alpha or 1);local ok,err=pcall(fn);opacity=previous;if not ok then error(err,0) end end

  local function badge(label,x,y,w)
    w=w or 74
    rect("fill",x,y,w,18,4,theme.colors.infoSoft or theme.colors.subtle)
    text(label,x,y+4,9,theme.colors.info,"center",w,"bold")
  end

  local function comma(value)
    local s=tostring(math.floor(tonumber(value) or 0))
    repeat local nextValue,n=s:gsub("^(-?%d+)(%d%d%d)","%1,%2");s=nextValue until n==0
    return s
  end

  local function typeBadge(type,x,y)
    -- Exact Figma Type Token (618:2865): 148x36, 20x20 canonical glyph.
    TypeChip.draw(type,sx(x),sy(y),drawT.scale,theme,opacity)
  end
  -- Status presentation is the canonical Figma Feedback component:
  -- atomic 32x32 icon on party cards; 188x40 bordered token in the active
  -- Pokémon detail panel. Fainted derives from HP, not from a persistent
  -- status code.
  local function statusIcon(status,hp,x,y)
    StatusToken.drawIcon(status,hp,sx(x+16),sy(y+16),sl(32),theme,opacity)
  end
  local function statusToken(status,hp,x,y)
    StatusToken.drawToken(status,hp,sx(x),sy(y),drawT.scale,theme,opacity)
  end
  local function progress(label,current,maximum,ratio,x,y,w,kind,valueText)
    local standard=(w>=280 and kind=="exp" and label=="PROGRESS")
    local trackY=standard and 36 or 28
    local trackH=standard and 16 or 12
    text(label,x,y,standard and 15 or 13,theme.colors.ink,nil,nil,"bold")
    text(valueText or ((current or 0).." / "..(maximum or 0)),
      x+(standard and 106 or 92),y,standard and 14 or 12,theme.colors.ink,
      "right",standard and 174 or 128,"medium")
    rect("fill",x,y+trackY,w,trackH,trackH/2,theme.colors.subtle)
    rect("line",x+.5,y+trackY+.5,w-1,trackH-1,trackH/2,theme.colors.border,1)
    ratio=math.max(0,math.min(1,tonumber(ratio) or 0))
    local fill=theme.colors.exp
    if kind=="hp" then fill=ratio<=.2 and theme.colors.hpCritical or ratio<.55 and theme.colors.hpMid or theme.colors.hpFull end
    if ratio>0 then rect("fill",x,y+trackY,math.max(2,w*ratio),trackH,trackH/2,fill) end
  end
  local function moveRow(move,x,y,w,h,disabled)
    local alpha=disabled and .48 or 1
    withOpacity(alpha,function()
    if move then
      local kind=tostring(move.type or "UNKNOWN"):upper();TypeIcon.draw(kind,sx(x+26),sy(y+h/2),sl(32),theme.typeColors[kind] or theme.colors.faint)
      text(move.name,x+48,y+(h-22)/2,15,theme.colors.ink,nil,nil,"semibold")
      local pp=move.pp and move.maxPP and ("%d / %d PP"):format(move.pp,move.maxPP) or "—"
      text(pp,x+w-102,y+(h-22)/2,14,theme.colors.muted,"right",90,"medium")
    else text("—",x+16,y+(h-22)/2,15,theme.colors.muted) end
    end)
  end
  local function moveSlot(state,move,x,y,w,h)
    local disabled=state=="Disabled"
    withOpacity(disabled and .48 or 1,function()
      rect("fill",x,y,w,h,10,theme.colors.subtle)
      if state=="Focused" then rect("line",x+1,y+1,w-2,h-2,10,theme.colors.focus,2)
      elseif state=="Hover" then rect("line",x+1,y+1,w-2,h-2,10,theme.colors.selected,2)
      elseif state=="Dragging" then dashedRect(x,y,w,h,theme.colors.focus)
      else rect("line",x+.5,y+.5,w-1,h-1,10,theme.colors.border,1) end
      if state=="Selected" then selectedRail(x,y,w,h,10) end
      moveRow(move,x+8,y+8,w-8,h-16,false)
    end)
  end
  local function frontSprite(game,p,x,y,size,maxArt)
    local inset=size*.06;local available=math.min(size*.88,maxArt or size*.88)
    local okResolve,image,_,art=pcall(Adapter.frontSprite,game,p.source)
    local drawn=false
    if okResolve and image then
      local okDraw=pcall(function()
        local box={x=sx(x+inset),y=sy(y+inset),w=sl(available),h=sl(available)}
        local geometry=runtime.MenuPokemonPresentation and runtime.MenuPokemonPresentation.geometry(
          game,p.source,image,box,{baseFraction=.72,ceiling=.94,floorFraction=.30})
        local iw,ih=image:getDimensions()
        if not geometry then
          local k=math.min(box.w/iw,box.h/ih);geometry={x=box.x+(box.w-iw*k)/2,y=box.y+(box.h-ih*k)/2,w=iw*k,h=ih*k,scale=k}
        end
        love.graphics.setColor(1,1,1,opacity)
        love.graphics.draw(image,round(geometry.x),round(geometry.y),0,geometry.scale,geometry.scale)
        if runtime.PokemonArt then runtime.PokemonArt.mark(art,geometry.x,geometry.y,geometry.w,geometry.h) end
      end)
      drawn=okDraw==true
    end
    if not drawn then
      rect("fill",x+inset,y+inset,available,available,12,theme.colors.subtle)
      text((p.name or "P"):sub(1,1),x+inset,y+inset+available*.28,available*.34,theme.colors.faint,"center",available)
    end
  end
  local function partyIcon(game,p,x,y,size)
    -- Compact Party/Moves surfaces own menu icons, never battle/front art.
    -- Keep the authored 32px two-frame sprite crisp and bounded inside the
    -- component wrapper; Graphics owns its fixed menu cadence.
    local visual=math.min(size*.67,128)
    local dx=x+(size-visual)/2;local dy=y+(size-visual)/2
    local ok,drawn=pcall(Adapter.drawPartyIcon,game,p.source,sx(dx),sy(dy),sl(visual))
    if ok and drawn==true then return true end
    rect("fill",dx,dy,visual,visual,10,theme.colors.subtle)
    text((p.name or "P"):sub(1,1),dx,dy+visual*.28,visual*.34,theme.colors.faint,"center",visual)
    return false
  end


  local function loadPartyBalls()
    if partyBalls~=nil then return partyBalls or nil end
    local value={}
    for _,state in ipairs({"normal","status","ko"}) do
      local ok,image=pcall(love.graphics.newImage,"assets/runtime/party_balls/"..state..".png")
      if not ok or not image then partyBalls=false;return nil end
      if type(image.setFilter)=="function" then image:setFilter("nearest","nearest") end
      value[state]=image
    end
    partyBalls=value;return value
  end
  local function partyBallRow(game,party,x,y)
    local balls=loadPartyBalls();if not balls then return end
    for i=1,6 do
      local mon=party[i]
      if mon then
        local model=Adapter.pokemon(game,mon)
        local state=(tonumber(model.hp) or 0)<=0 and "ko" or (StatusToken.normalize and StatusToken.normalize(model.status,model.hp)) and "status" or "normal"
        love.graphics.setColor(1,1,1,opacity)
        love.graphics.draw(balls[state],sx(x+(i-1)*48),sy(y),0,drawT.scale,drawT.scale)
      end
    end
  end

  local function headerContext(game)
    local ctx=type(Core.journalContext)=="function" and Core.journalContext() or {location="KANTO",playTime=0}
    local sec=math.max(0,math.floor(tonumber(ctx.playTime) or 0))
    local clock=("%02d:%02d"):format(math.floor(sec/3600),math.floor(sec/60)%60)
    local phase=runtime.worldPhase and runtime.worldPhase(game) or "day"
    return tostring(ctx.location or "KANTO"):gsub("_"," "):upper(),clock,tostring(phase):upper()
  end
  local function drawHeader(game,state)
    rect("fill",0,0,1920,88,0,theme.colors.header)
    text("KANTO JOURNAL",32,18,24,theme.colors.white,nil,nil,"bold"); withOpacity(.72,function() text("POKÉMON",32,55,11,theme.colors.white,nil,nil,"bold") end)
    local map,clock,phase=headerContext(game); text(map,1570,18,14,theme.colors.white,"right",318,"semibold"); withOpacity(.76,function() text(clock.."  •  "..phase,1570,48,12,theme.colors.white,"right",318,"medium") end)
    local tabs=Layout.headerTabs();local accent=theme.colors.headerAccent or theme.colors.focus;local headerFocus=theme.colors.headerFocus or theme.colors.white
    local child=state.mode~="PartyBrowse"
    local active=state.mode=="MovesActive" and "moves" or state.mode=="SummaryActive" and "summary" or state.mode=="SubmenuBrowse" and (state.submenuFocus or "summary") or "party"
    local pr=tabs.party
    local parentHovered=runtime.Focus.isPointer(runtime.partyNav) and runtime.hoveredRegion=="party"
    local parentFocused=(not runtime.Focus.isPointer(runtime.partyNav)) and state.mode=="PartyBrowse" and runtime.headerPartyFocused==true
    if parentFocused then rect("line",pr.x+1,pr.y+1,pr.w-2,pr.h-2,8,headerFocus,2) end
    local parentLabel=child and "← EQUIPO" or "EQUIPO"
    text(parentLabel,pr.x,pr.y+10,14,theme.colors.white,"center",pr.w,"semibold")
    if active=="party" then rect("fill",pr.x+14,pr.y+37,112,3,1.5,accent) elseif parentHovered then rect("fill",pr.x+14,pr.y+39,112,1,.5,accent) end
    rect("fill",901.5,32,1,24,0,theme.colors.white)
    addRegion(state,"header_tab","party",nil,pr.x,pr.y,pr.w,pr.h)
    local tabLabels={summary="DATOS",moves="ATAQUES"}
    for _,id in ipairs({"summary","moves"}) do
      local r=tabs[id];local selected=id==active;local hovered=runtime.Focus.isPointer(runtime.partyNav) and runtime.hoveredRegion==id
      local focused=state.mode=="SubmenuBrowse" and (not runtime.Focus.isPointer(runtime.partyNav)) and id==state.submenuFocus
      local tabTitle=tabLabels[id] or id:upper()
      if focused then rect("line",r.x+1,r.y+1,r.w-2,r.h-2,8,headerFocus,2) end
      if selected then text(tabTitle,r.x,r.y+10,13,theme.colors.white,"center",r.w,"semibold") else withOpacity(.72,function() text(tabTitle,r.x,r.y+10,13,theme.colors.white,"center",r.w,"semibold") end) end
      if selected then rect("fill",r.x+14,r.y+37,96,3,1.5,accent) elseif hovered then rect("fill",r.x+14,r.y+39,96,1,.5,accent) end
      addRegion(state,"header_tab",id,nil,r.x,r.y,r.w,r.h)
    end
  end
  local function drawFooter(game,state,prompts)
    if not state.battleMode then
      prompts=prompts or {};prompts[#prompts+1]={action='UI_SUBMENU_PREV',label='PESTAÑA ANTERIOR'};prompts[#prompts+1]={action='UI_SUBMENU_NEXT',label='SIGUIENTE PESTAÑA'}
    end
    Footer.draw(game,prompts,nil,{key=font(14),label=font(13),device=font(13)},{x=sx,y=sy,len=sl},theme.colors)
  end

  local function detailMoveRows(p,x,y,w)
    for i=1,4 do
      rect("fill",x,y+(i-1)*58,w,52,10,theme.colors.subtle); rect("line",x+.5,y+(i-1)*58+.5,w-1,51,10,theme.colors.border,1)
      moveRow(p.moves[i],x,y+(i-1)*58,w,52,false)
    end
  end
  local function drawPartyDetail(game,p)
    local r=Layout.partyDetail(); panel(r)
    -- Figma 1248:25996 / Active Pokémon dossier.
    text("POKÉMON ACTIVO",r.x+24,r.y+24,11,theme.colors.muted,nil,nil,"bold")
    frontSprite(game,p,r.x+150,r.y+60,200)
    text(p.name,r.x+24,r.y+300,32,theme.colors.ink,nil,nil,"bold")
    statusToken(p.status,p.hp,r.x+222,r.y+300)
    text(("Nv. %d"):format(p.level),r.x+396,r.y+308,18,theme.colors.muted,"right",80,"semibold")
    local tx=r.x+24; for _,t in ipairs(p.types) do typeBadge(t,tx,r.y+360); tx=tx+156 end
    line(r.x+24,r.y+416,452,theme.colors.border)
    text("ATAQUES ACTUALES",r.x+24,r.y+437,11,theme.colors.muted,nil,nil,"bold")
    local slots=Layout.activeMoveSlots()
    for i=1,4 do
      local y=slots[i].y
      rect("fill",r.x+24,y,452,68,10,theme.colors.subtle);rect("line",r.x+24.5,y+.5,451,67,10,theme.colors.border,1)
      moveRow(p.moves[i],r.x+24,y,452,68,false)
    end
    line(r.x+24,r.y+775,452,theme.colors.border)
    text("POSICIÓN EN EQUIPO",r.x+24,r.y+796,10,theme.colors.muted,nil,nil,"bold")
    text("EXPERIENCIA",r.x+296,r.y+796,10,theme.colors.muted,"right",180,"bold")
    text(("Ranura %d de %d"):format(p.partyIndex or 1,p.partyCount or 6),r.x+24,r.y+820,14,theme.colors.ink,nil,nil,"semibold")
    text(("%s / %s"):format(comma(p.exp or 0),comma((p.exp or 0)+(p.toNextLevel or 0))),r.x+224,r.y+820,14,theme.colors.ink,"right",252,"semibold")
  end
  local function drawPartyCard(game,state,p,index,r,visual)
    local alpha=visual=="Disabled" and .48 or 1
    withOpacity(alpha,function()
    frameState(visual,r.x,r.y,r.w,r.h,16)
    partyIcon(game,p,r.x+20,r.y+70,96)
    local contentX=r.x+136
    text(p.name,contentX,r.y+22,24,theme.colors.ink,nil,nil,"bold"); text(("Nv. %d"):format(p.level),contentX+168,r.y+27,16,theme.colors.muted,"right",60,"semibold")
    statusIcon(p.status,p.hp,contentX+236,r.y+24)
    local tx=contentX; for _,t in ipairs(p.types) do typeBadge(t,tx,r.y+68); tx=tx+156 end
    local hpMax=tonumber(p.stats.hp) or 0; local hpRatio=hpMax>0 and p.hp/hpMax or 0
    progress("PS",p.hp,hpMax,hpRatio,contentX,r.y+112,220,"hp")
    progress("EXP",nil,nil,p.expRatio,contentX,r.y+168,220,"exp",p.toNextLevel and (("%s PARA SUBIR"):format(tostring(p.toNextLevel))) or C.notAvailable)
    end)
    addRegion(state,"party_card","party."..index,index,r.x,r.y,r.w,r.h)
  end
  local function drawParty(game,state)
    drawHeader(game,state)
    local detail=Adapter.pokemon(game,state.party[state.selectedParty or state.partyFocus]);detail.partyIndex=state.selectedParty or state.partyFocus;detail.partyCount=#state.party
    drawPartyDetail(game,detail)
    text("EQUIPO ACTIVO",620,144,11,theme.colors.muted,nil,nil,"bold")
    text("FORMACIÓN DEL EQUIPO",620,164,32,theme.colors.ink,nil,nil,"black")
    partyBallRow(game,state.party,1540,144)
    local cards=Layout.partyCards(#state.party)
    for i,mon in ipairs(state.party) do
      local visual="Default"
      if state.mode=="PartyBrowse" then
        if runtime.Focus.isPointer(runtime.partyNav) then if runtime.hoveredRegion=="party."..i then visual="Hover" end
        elseif i==state.partyFocus then visual="Focused" end
      end
      if (state.mode=="SubmenuBrowse" or state.mode=="BattleAction") and i==state.selectedParty then visual="Selected" end
      if state.drag and state.drag.kind=="party" then
        if i==state.drag.source then visual="Dragging" elseif i==state.drag.target then visual="Focused" end
      end
      local model=Adapter.pokemon(game,mon);model.partyIndex=i;model.partyCount=#state.party
      drawPartyCard(game,state,model,i,cards[i],visual)
    end
    if state.drag and state.drag.kind=="party" and state.drag.x then
      local p=Adapter.pokemon(game,state.party[state.drag.source]); local r={x=state.drag.x-302,y=state.drag.y-118,w=604,h=236}
      withOpacity(.9,function() drawPartyCard(game,{regions={}},p,0,r,"Dragging") end)
    end
    if state.mode=="BattleAction" then
      -- Battle actions are one unified modal, not controls leaking out of the
      -- active-Pokémon dossier at the bottom-left. The party remains visible
      -- as context while the modal owns the decision.
      local labels={"CAMBIO","DATOS","CANCELAR"};local ids={"switch","stats","cancel"}
      rect("fill",0,88,1920,928,0,{0,0,0,.55})
      local px,py,pw,ph=600,442,720,196;panel({x=px,y=py,w=pw,h=ph})
      text("ACCIÓN EN COMBATE",px+28,py+24,11,theme.colors.muted,nil,nil,"bold")
      local w,h,gap=202,72,16;local x0=px+25;local y=py+88
      for i,label in ipairs(labels) do
        local x=x0+(i-1)*(w+gap);local focused=i==state.battleActionFocus
        rect("fill",x,y,w,h,10,focused and theme.colors.subtle or theme.colors.panel)
        rect("line",x+.5,y+.5,w-1,h-1,10,focused and theme.colors.focus or theme.colors.border,focused and 3 or 1)
        text(label,x,y+25,13,theme.colors.ink,"center",w,"bold")
        addRegion(state,"battle_action",ids[i],i,x,y,w,h)
      end
      drawFooter(game,state,{{key="IZQ / DER",label="ACCIÓN"},{action="a",label="ELEGIR"},{action="b",label="EQUIPO"}})
    elseif state.mode=="PartyBrowse" then
      if state.battleMode then
        drawFooter(game,state,{{navigation=true,label="NAVEGAR"},{action="a",label="SELECCIONAR"},{action="b",label="VOLVER"}})
      elseif state.drag and state.drag.kind=="party" and state.drag.input=="navigation" then
        drawFooter(game,state,{{navigation=true,label="MOVER"},{action="a",label="COLOCAR"},{action="b",label="CANCELAR"}})
      else
        drawFooter(game,state,{{navigation=true,label="NAVEGAR"},{action="a",label="SELECCIONAR"},{action="select",label="MOVER"},{key="RATÓN",label="ARRASTRAR",pointerOnly=true},{action="b",label="VOLVER"}})
      end
    else drawFooter(game,state,{{key="IZQ / DER",label="ELEGIR"},{action="a",label="ABRIR"},{action="b",label="VOLVER"}}) end
  end

  local function dataField(label,value,x,y,w,future)
    rect("fill",x,y,w,72,10,future and theme.colors.subtle or theme.colors.panel)
    if future then dashedRect(x,y,w,72,theme.colors.border)
    else rect("line",x+.5,y+.5,w-1,71,10,theme.colors.border,1) end
    text(label,x+14,y+10,11,theme.colors.muted)
    if future then text(C.future,x+w-138,y+10,12,theme.colors.info,"right",124); text(C.notAvailable,x+14,y+36,14,theme.colors.ink)
    else text(value or C.notAvailable,x+14,y+36,14,theme.colors.ink) end
  end
  local function renameIndicator(x,y)
    segment(x+2,y+13,x+12,y+3,theme.colors.info,2)
    segment(x+5,y+16,x+15,y+6,theme.colors.info,2)
    segment(x+2,y+13,x+1,y+18,theme.colors.info,2);segment(x+1,y+18,x+6,y+17,theme.colors.info,2)
  end
  local function statTab(state,id,label,x,y,w)
    w=w or 132
    local hover=runtime.Focus.isPointer(runtime.partyNav) and runtime.hoveredRegion==id
    local selected=state.statMode==id
    rect("fill",x,y,w,40,7,selected and theme.colors.header or (hover and theme.colors.subtle or theme.colors.subtle))
    rect("line",x+.5,y+.5,w-1,39,7,selected and theme.colors.header or (hover and theme.colors.selected or theme.colors.border),hover and 2 or 1)
    text(label,x,y+10,14,selected and theme.colors.white or theme.colors.ink,"center",w,"bold")
    addRegion(state,"stat_tab",id,nil,x,y,w,40)
  end
  local function drawSummary(game,state)
    drawHeader(game,state)
    local p=state.pokemon
    -- Latest Figma: Pokémon record / dossier / active-moves profile.
    local left={x=64,y=120,w=380,h=856};local dossier={x=468,y=120,w=884,h=856};local right={x=1376,y=120,w=480,h=856}
    panel(left);panel(dossier);panel(right)
    text("FICHA POKÉMON",left.x+24,left.y+28,11,theme.colors.muted,nil,nil,"bold")
    frontSprite(game,p,left.x+66,left.y+70,200)
    text(p.name,left.x+24,left.y+300,31,theme.colors.ink,nil,nil,"bold")
    local renameX=math.min(left.x+left.w-54,left.x+24+textWidth(p.name,31,"bold")+14)
    local renameHover=runtime.hoveredRegion=="rename"
    if renameHover then rect("fill",renameX-7,left.y+297,36,36,7,theme.colors.subtle);rect("line",renameX-6.5,left.y+297.5,35,35,7,theme.colors.selected,1) end
    renameIndicator(renameX,left.y+307);addRegion(state,"rename","rename",nil,renameX-7,left.y+297,36,36)
    text(("Nv. %d • ID %s"):format(p.level,p.otId and tostring(p.otId) or "—"),left.x+24,left.y+342,14,theme.colors.muted,nil,nil,"semibold")
    local tx=left.x+24;for _,t in ipairs(p.types) do typeBadge(t,tx,left.y+384);tx=tx+156 end
    line(left.x+24,left.y+440,left.w-48);text("ENTRENADOR ORIGINAL",left.x+24,left.y+461,10,theme.colors.muted,nil,nil,"bold");text(p.ot or C.notAvailable,left.x+24,left.y+481,14,theme.colors.ink,nil,nil,"semibold")
    text("ID ENTRENADOR",left.x+24,left.y+517,10,theme.colors.muted,nil,nil,"bold");text(p.otId and tostring(p.otId) or C.notAvailable,left.x+24,left.y+537,14,theme.colors.ink,nil,nil,"semibold")
    text("OBJETO EQUIPADO",left.x+24,left.y+573,10,theme.colors.muted,nil,nil,"bold");text(C.notAvailable,left.x+24,left.y+593,14,theme.colors.muted,nil,nil,"semibold");badge("MOD",left.x+156,left.y+591,42)

    text("INFORME POKÉMON",dossier.x+32,dossier.y+32,28,theme.colors.ink,nil,nil,"bold")
    statTab(state,"stats","ESTADÍSTICAS BASE",dossier.x+32,dossier.y+88,180)
    statTab(state,"iv","VALORES INDIVIDUALES (VI) ★",dossier.x+224,dossier.y+88,270)
    statTab(state,"ev","PUNTOS DE ESFUERZO (PE)",dossier.x+506,dossier.y+88,210)
    local keys={{"PS","hp"},{"ATAQUE","attack"},{"DEFENSA","defense"},{"VELOCIDAD","speed"},{"ESPECIAL","special"}}
    local function statValue(key)
      if state.statMode=="stats" then return p.stats and p.stats[key] or "—" end
      if state.statMode=="iv" then
        local d=p.dvs or {}; if key=="hp" then local a=tonumber(d.attack or d.atk or 0);local de=tonumber(d.defense or d.def or 0);local sp=tonumber(d.speed or 0);local s=tonumber(d.special or d.spc or 0);return ((a%2)*8+(de%2)*4+(sp%2)*2+(s%2)) end
        return d[key] or d[key=='attack' and 'atk' or key=='defense' and 'def' or key=='special' and 'spc' or key] or "—"
      end
      local e=p.statExp or {}; return e[key] or e[key=='attack' and 'atk' or key=='defense' and 'def' or key=='special' and 'spc' or key] or "—"
    end
    for i,k in ipairs(keys) do
      local y=dossier.y+148+(i-1)*52;local fill=i%2==0 and theme.colors.subtle or theme.colors.panel;rect("fill",dossier.x+32,y,dossier.w-64,52,0,fill)
      text(k[1],dossier.x+48,y+16,14,theme.colors.ink,nil,nil,"bold");local v=statValue(k[2]);local display=tostring(v)
      if state.statMode=="iv" then display=display.." / 15" elseif state.statMode=="ev" then display=comma(v).." / 65,535" end
      local perfect=state.statMode=="iv" and tonumber(v)==15
      local tableRight=dossier.x+dossier.w-32
      if perfect then
        text(display,tableRight-260,y+14,16,theme.colors.hpFull,"right",134,"bold")
        text("★ PERFECTO",tableRight-114,y+16,12,theme.colors.selectionGold,"right",98,"bold")
      else
        text(display,tableRight-260,y+14,16,theme.colors.ink,"right",244,"bold")
      end
    end
    rect("line",dossier.x+32,dossier.y+148,dossier.w-64,260,8,theme.colors.border,1)
    line(dossier.x+32,dossier.y+436,dossier.w-64,theme.colors.border)
    text("REGISTRO DE EXPERIENCIA",dossier.x+32,dossier.y+461,10,theme.colors.muted,nil,nil,"bold")
    text("EXP ACTUAL",dossier.x+32,dossier.y+491,10,theme.colors.muted,nil,nil,"bold");text(p.exp and comma(p.exp) or "—",dossier.x+32,dossier.y+513,20,theme.colors.ink,nil,nil,"semibold")
    text("SIGUIENTE NIVEL",dossier.x+192,dossier.y+491,10,theme.colors.muted,nil,nil,"bold");text(p.toNextLevel and comma(p.toNextLevel) or "—",dossier.x+192,dossier.y+513,20,theme.colors.ink,nil,nil,"semibold")
    progress("EXP",nil,nil,p.expRatio,dossier.x+32,dossier.y+581,dossier.w-64,"exp",p.toNextLevel and ((comma(p.toNextLevel)).." PARA SUBIR") or C.notAvailable)

    text("ATAQUES ACTIVOS",right.x+24,right.y+24,11,theme.colors.muted,nil,nil,"bold")
    -- Current canonical Summary mockup keeps this presentation region empty;
    -- move management lives on the dedicated MOVES tab.
    line(right.x+24,right.y+180,right.w-48,theme.colors.border)
    text("PERFIL DE COMBATE",right.x+24,right.y+201,10,theme.colors.muted,nil,nil,"bold")
    text("HABILIDAD POKÉMON",right.x+24,right.y+237,10,theme.colors.muted,nil,nil,"bold");text(C.notAvailable,right.x+24,right.y+257,14,theme.colors.muted,nil,nil,"semibold");badge("MOD FUTURO",right.x+164,right.y+255,80)
    text("ESTADO DE OBJETO",right.x+24,right.y+293,10,theme.colors.muted,nil,nil,"bold");text(C.notAvailable,right.x+24,right.y+313,14,theme.colors.muted,nil,nil,"semibold");badge("MOD FUTURO",right.x+164,right.y+311,80)
    drawFooter(game,state,{{navigation=true,label="SELECCIONAR"},{action="a",label="RENOMBRAR"},{action="select",label="MODO ESTADÍSTICAS"},{action="b",label="EQUIPO"}})
  end

  local function categoryBadge(category,x,y)
    local raw=tostring(category or "STATUS"):upper()
    local label="ESTADO"
    if raw=="ATTACK" or raw=="PHYSICAL" or raw=="FÍSICO" then label="FÍSICO"
    elseif raw=="SPECIAL" or raw=="ESPECIAL" then label="ESPECIAL" end
    rect("fill",x,y,116,32,16,theme.colors.header)
    rect("line",x+.5,y+.5,115,31,16,theme.colors.header,1)
    if label=="FÍSICO" then
      polygonLine({x+12,y+16,x+18,y+10,x+24,y+16,x+18,y+22},theme.colors.white,1.5)
    elseif label=="ESPECIAL" then
      local pts={sx(x+18),sy(y+9),sx(x+25),sy(y+16),sx(x+18),sy(y+23),sx(x+11),sy(y+16)}
      color(theme.colors.white);love.graphics.polygon("fill",pts)
    else
      circle("line",x+18,y+16,6,theme.colors.white,1.5)
    end
    text(label,x+30,y+9,12,theme.colors.white,nil,nil,"bold")
  end
  local function activeMoveHeaderLayout(name,work)
    -- The two longest official English move names contain 27 characters.
    -- MENACING MOONRAZE MAELSTROM is the wider one in Inter Bold. Keep the
    -- badges 8-16 px after the measured label and reduce only this headline,
    -- by at most 2 px, when the 27-character case needs the extra room.
    local nameX=work.x+60
    local rowRight=work.x+work.w-34
    local typeWidth,categoryWidth,badgeGap=148,116,16
    local size=28
    local width=textWidth(name,size,"bold")
    local nameGap=math.max(8,math.min(16,round(width*.03)))
    local maxNameWidth=rowRight-nameX-typeWidth-badgeGap-categoryWidth-nameGap
    while size>26 and width>maxNameWidth do
      size=size-1
      width=textWidth(name,size,"bold")
    end
    local typeX=nameX+width+nameGap
    local maxTypeX=rowRight-typeWidth-badgeGap-categoryWidth
    typeX=math.min(typeX,maxTypeX)
    return {nameX=nameX,nameY=work.y+158+(28-size)/2,nameSize=size,
      nameWidth=width,nameGap=nameGap,typeX=typeX,categoryX=typeX+typeWidth+badgeGap,
      rowRight=rowRight}
  end
  local function detailCard(move,x,y,w,h)
    rect("fill",x,y,w,h,14,theme.colors.panel);rect("line",x+.5,y+.5,w-1,h-1,14,theme.colors.border,1)
    if not move then text("ELIGE UN ATAQUE APRENDIDO",x+24,y+26,28,theme.colors.ink);line(x+24,y+74,w-48);text("Elige un ataque aprendido para compararlo con el ataque activo.",x+24,y+116,16,theme.colors.muted,"left",w-48);return end
    text(move.name,x+24,y+24,28,theme.colors.ink);typeBadge(move.type,x+24,y+72)
    categoryBadge(move.category,x+184,y+74)
    text(move.pp and move.maxPP and ("%d / %d PP"):format(move.pp,move.maxPP) or "PP —",x+24,y+126,14,theme.colors.ink);line(x+24,y+158,w-48);text("DESCRIPCIÓN",x+24,y+176,12,theme.colors.ink);text(move.description,x+24,y+208,16,theme.colors.muted,"left",w-48)
  end
  local function drawMoves(game,state)
    drawHeader(game,state);local p=state.pokemon
    local left={x=64,y=120,w=380,h=856};local work={x=468,y=120,w=884,h=856};local right={x=1376,y=120,w=480,h=856}
    panel(left);panel(work);panel(right)
    text("RESUMEN DE ATAQUES",left.x+24,left.y+24,11,theme.colors.muted,nil,nil,"bold");partyIcon(game,p,left.x+70,left.y+40,240)
    text(p.name,left.x+24,left.y+280,30,theme.colors.ink,nil,nil,"bold");text(("Nv. %d • ID %s"):format(p.level,p.otId and tostring(p.otId) or "—"),left.x+24,left.y+322,13,theme.colors.muted,nil,nil,"semibold")
    local tx=left.x+24;for _,t in ipairs(p.types) do typeBadge(t,tx,left.y+364);tx=tx+156 end
    line(left.x+24,left.y+420,left.w-48,theme.colors.border);text("SET DE ATAQUES ACTIVOS",left.x+24,left.y+441,10,theme.colors.muted,nil,nil,"bold");text(("%d / 4 ACTIVOS"):format(#(p.source and p.source.moves or {})),left.x+250,left.y+441,10,theme.colors.muted,"right",90,"bold")
    for i=1,4 do local y=left.y+477+(i-1)*66;local visual="Default";if runtime.Focus.isPointer(runtime.partyNav) then if runtime.hoveredRegion=="move."..i then visual="Hover" end elseif i==state.activeMoveFocus then visual="Focused" end;if state.selectedActive==i then visual="Selected" end;if state.drag and state.drag.kind=="move" then if i==state.drag.source then visual="Dragging" elseif i==state.drag.target then visual="Focused" end end;moveSlot(visual,p.moves[i],left.x+24,y,left.w-48,56);if p.moves[i] then addRegion(state,"active_move","move."..i,i,left.x+24,y,left.w-48,56) end end

    text("ESPACIO DE ATAQUES",work.x+32,work.y+32,28,theme.colors.ink,nil,nil,"bold");text("ATAQUES APRENDIDOS",work.x+work.w-194,work.y+40,13,theme.colors.focus,"right",160,"bold")
    local active=p.moves[state.activeMoveFocus]
    rect("fill",work.x+32,work.y+88,work.w-64,241,14,theme.colors.subtle);rect("line",work.x+32.5,work.y+88.5,work.w-65,240,14,theme.colors.border,1)
    text("ATAQUE ACTIVO • RANURA "..("%02d"):format(state.activeMoveFocus or 1),work.x+60,work.y+114,10,theme.colors.focus,nil,nil,"bold");if active then
      local header=activeMoveHeaderLayout(active.name,work)
      text(active.name,header.nameX,header.nameY,header.nameSize,theme.colors.ink,nil,nil,"bold");typeBadge(active.type,header.typeX,work.y+154);categoryBadge(active.category,header.categoryX,work.y+156)
      text(active.pp and active.maxPP and (active.pp.." / "..active.maxPP.." PP") or "PP —",work.x+work.w-170,work.y+116,12,theme.colors.muted,"right",116,"bold")
      text("POTENCIA",work.x+60,work.y+212,10,theme.colors.muted,nil,nil,"bold");text(tostring(active.power or "—"),work.x+60,work.y+235,16,theme.colors.ink,nil,nil,"semibold")
      text("PRECISIÓN",work.x+426,work.y+212,10,theme.colors.muted,nil,nil,"bold");text(active.accuracy and (tostring(active.accuracy).."%") or "—",work.x+426,work.y+235,16,theme.colors.ink,nil,nil,"semibold")
      text(active.description or "",work.x+60,work.y+276,12,theme.colors.text or theme.colors.ink,"left",work.w-120)
    end
    line(work.x+32,work.y+353,work.w-64,theme.colors.border)
    text("RESERVA DE ATAQUES",work.x+32,work.y+378,10,theme.colors.muted,nil,nil,"bold")
    local provider=state.learnedProvider or {};text(((#state.learned>0 and math.min(6,#state.learned) or 0).." MOSTRADOS / "..#state.learned.." APRENDIDOS"),work.x+work.w-284,work.y+378,10,theme.colors.muted,"right",250,"bold")
    if #state.learned==0 then state.learnedScrollbar=nil;text("SIN ATAQUES ADICIONALES",work.x+32,work.y+418,20,theme.colors.ink);text("Solo el set de ataques activos está disponible para este Pokémon.",work.x+32,work.y+454,12,theme.colors.muted)
    else
      local visible=6;local maxFirst=math.max(1,#state.learned-visible+1);local first=math.max(1,math.min(state.learnedFirst or 1,maxFirst));state.learnedFirst=first
      local count=math.min(visible,#state.learned-first+1);local cellW=390;local cellH=44
      for slot=1,count do local i=first+slot-1;local mv=state.learned[i];local col=(slot-1)%2;local row=math.floor((slot-1)/2);local r={x=work.x+32+col*(cellW+12),y=work.y+418+row*56,w=cellW,h=cellH};local visual=mv.disabled and "Disabled" or "Default";if runtime.Focus.isPointer(runtime.partyNav) and runtime.hoveredRegion=="learned."..i then visual="Hover" elseif state.learnedFocus==i and state.movePhase=="learned" then visual="Focused" end;moveSlot(visual,mv,r.x,r.y,r.w,r.h);addRegion(state,"learned_move","learned."..i,i,r.x,r.y,r.w,r.h) end
      if #state.learned>visible then local track={x=work.x+work.w-40,y=work.y+418,w=8,h=428};local thumbH=math.max(56,track.h*visible/#state.learned);local travel=track.h-thumbH;local thumb={x=track.x,y=track.y+(first-1)/math.max(1,maxFirst-1)*travel,w=track.w,h=thumbH};state.learnedScrollbar={track=track,thumb=thumb,hit={x=track.x-18,y=thumb.y,w=44,h=math.max(44,thumb.h)},travel=travel,maxFirst=maxFirst-1};rect("fill",track.x,track.y,track.w,track.h,4,theme.colors.subtle);rect("fill",thumb.x,thumb.y,thumb.w,thumb.h,4,theme.colors.focus) else state.learnedScrollbar=nil end
    end

    text("DETALLE DE ATAQUE APRENDIDO",right.x+24,right.y+24,11,theme.colors.muted,nil,nil,"bold")
    local chosen=state.learnedFocus and state.learned[state.learnedFocus] or nil
    if not chosen and active then
      for _,candidate in ipairs(state.learned or {}) do if candidate.id==active.id then chosen=candidate;break end end
    end
    if chosen then
      text(chosen.name,right.x+24,right.y+70,28,theme.colors.ink,nil,nil,"bold");typeBadge(chosen.type,right.x+24,right.y+126);categoryBadge(chosen.category,right.x+188,right.y+128)
      text("PUNTOS DE PODER",right.x+24,right.y+184,10,theme.colors.muted,nil,nil,"bold");text(chosen.pp and chosen.maxPP and (chosen.pp.." / "..chosen.maxPP.." PP") or "—",right.x+24,right.y+208,18,theme.colors.ink,nil,nil,"semibold")
      text("POTENCIA",right.x+24,right.y+238,10,theme.colors.muted);text(tostring(chosen.power or "—"),right.x+24,right.y+262,15,theme.colors.ink)
      text("PRECISIÓN",right.x+24,right.y+306,10,theme.colors.muted);text(chosen.accuracy and (tostring(chosen.accuracy).."%") or "—",right.x+24,right.y+330,15,theme.colors.ink)
      text("DESCRIPCIÓN DEL EFECTO",right.x+24,right.y+376,10,theme.colors.muted);text(chosen.description or "",right.x+24,right.y+404,13,theme.colors.ink,"left",right.w-48)
      line(right.x+24,right.y+434,right.w-48,theme.colors.border)
      rect("fill",right.x+24,right.y+456,right.w-48,142,12,theme.colors.subtle);rect("line",right.x+24.5,right.y+456.5,right.w-49,141,12,theme.colors.border,1)
      text("COMPARAR CON ACTIVO "..("%02d"):format(state.activeMoveFocus or 1).." • "..tostring(active and active.name or "—"),right.x+40,right.y+478,10,theme.colors.muted,nil,nil,"bold")
      text("TIPO",right.x+40,right.y+510,10,theme.colors.muted);text(tostring(active and active.type or "—").." → "..tostring(chosen.type or "—"),right.x+170,right.y+510,11,theme.colors.ink,nil,nil,"bold")
      text("CATEGORÍA",right.x+40,right.y+540,10,theme.colors.muted);text(tostring(active and active.category or "—").." → "..tostring(chosen.category or "—"),right.x+170,right.y+540,11,theme.colors.ink,nil,nil,"bold")
      text("PP MÁX",right.x+40,right.y+570,10,theme.colors.muted);text(tostring(active and active.maxPP or "—").." → "..tostring(chosen.maxPP or "—"),right.x+170,right.y+570,11,theme.colors.hpFull,nil,nil,"bold")
    else text("ELIGE UN ATAQUE APRENDIDO",right.x+24,right.y+70,20,theme.colors.ink);text("Elige un ataque aprendido para compararlo con el ataque activo.",right.x+24,right.y+112,13,theme.colors.muted,"left",right.w-48) end
    if state.drag and state.drag.kind=="move" and state.drag.input=="navigation" then drawFooter(game,state,{{navigation=true,label="MOVER"},{action="a",label="COLOCAR"},{action="b",label="CANCELAR"}})
    elseif state.movePhase=="learned" then drawFooter(game,state,{{navigation=true,label="SELECCIONAR"},{action="a",label="CONFIRMAR"},{action="b",label="CANCELAR"}})
    else drawFooter(game,state,{{navigation=true,label="SELECCIONAR"},{action="a",label="ELEGIR"},{key="RATÓN",label="DETALLES",pointerOnly=true},{action="b",label="EQUIPO"}}) end
  end

  local function debug(state,t)
    if not runtime.debugEnabled then return end
    rect("line",0,0,1920,1080,0,theme.colors.debug,2)
    for _,r in ipairs(state.regions or {}) do rect("line",r.x,r.y,r.w,r.h,0,theme.colors.debug,1);text(r.id or r.kind,r.x+3,r.y+3,9,theme.colors.debug) end
    local p=runtime.pointerLogical
    if p then text(("mouse %.1f, %.1f"):format(p.x or -1,p.y or -1),1500,980,12,theme.colors.debug);circle("line",p.x,p.y,8,theme.colors.debug,1) end
    text(("scale %.5f offset %.2f, %.2f"):format(t.scale,t.offsetX,t.offsetY),1400,998,11,theme.colors.debug)
  end

  function P:kind(game)
    local s=Adapter.topState(game);return type(s)=="table" and s.__kantoPartyUi and s.mode or nil
  end
  function P:isSupported(game,viewport) return self:kind(game)~=nil and Layout.supportsWide(viewport or runtime.viewport) end
  function P:drawState(game,viewport,state)
    if not (state and state.__kantoPartyUi) or not Layout.supportsWide(viewport) then return false end
    state.regions={};runtime.regions=state.regions;runtime.viewport=viewport
    local t=Layout.transform(viewport);drawT=t;opacity=1
    theme=Palette.resolve(game);runtime.visualProfile=theme.profile;runtime.colorMode=theme.colorMode
    love.graphics.push("all");love.graphics.origin()
    local ok, res = pcall(function()
      color(theme.colors.letterbox);love.graphics.rectangle("fill",0,0,t.screenWidth,t.screenHeight)
      love.graphics.setScissor(round(t.offsetX),round(t.offsetY),round(t.viewportWidth),round(t.viewportHeight))
      rect("fill",0,0,C.DESIGN_WIDTH,C.DESIGN_HEIGHT,0,theme.colors.canvas)
      if state.mode=="PartyBrowse" or state.mode=="SubmenuBrowse" or state.mode=="BattleAction" then drawParty(game,state)
      elseif state.mode=="SummaryActive" then drawSummary(game,state)
      elseif state.mode=="MovesActive" then drawMoves(game,state) end
      debug(state,t);love.graphics.setScissor()
      return true
    end)
    love.graphics.pop()
    if not ok then return nil, res end
    return res == true
  end
  function P:draw(game,viewport)
    local state=Adapter.topState(game);return self:drawState(game,viewport,state)
  end
  return P
end
