-- KRS modular overlays: only area catch completion and capture odds remain.
-- The window is never a clipping viewport. Every retained widget recomputes
-- its typography, sprites, cards, columns and spacing from the current width
-- AND height so resizing changes the content itself.
return function(deps)
  local Core=assert(deps.Core,"Core exports are required")
  local Palette=assert(deps.Palette,"Palette is required")
  local Models=assert(deps.Models,"overlay models are required")
  local mod=assert(deps.mod,"mod is required")
  local runtime=deps.runtime or {}
  local Overlay={}
  local IDS={"encounters","capture"}
  local TITLES={encounters="LISTA DE CAPTURA DE ZONA",capture="PROBABILIDAD DE CAPTURA"}
  local TAB_LABELS={encounters="CAPTURA",capture="PROB."}
  local MODES={{id="overworld",label="MAPA"},{id="battle",label="COMBATE"},{id="both",label="AMBOS"},{id="none",label="NINGUNO"}}
  local BASE={encounters={w=640,h=500},capture={w=560,h=390}}
  local fonts={};local collapsedIcon=nil

  local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
  local function option(key,fallback)
    local o=mod and mod.options
    if o and type(o.get)=="function" then local ok,v=pcall(o.get,o,key);if ok and v~=nil then return v end end
    return fallback
  end
  local function font(size,weight)
    size=math.max(5,math.floor((tonumber(size) or 12)+.5));weight=weight or "regular"
    local family=runtime.fontFamily
    if runtime.Theme and type(runtime.Theme.fontFamily)=="function" then
      local ok,v=pcall(runtime.Theme.fontFamily);if ok and v then family=v end
    end
    local key=tostring(family or "default")..":"..tostring(size)..":"..weight
    if fonts[key] then return fonts[key] end
    if runtime.Draw and type(runtime.Draw.font)=="function" then fonts[key]=runtime.Draw.font(runtime,{scale=1},size,weight) end
    if not fonts[key] then fonts[key]=love.graphics.newFont(size) end
    return fonts[key]
  end
  local function set(c,a)
    c=c or {1,1,1,1};love.graphics.setColor(c[1] or 1,c[2] or 1,c[3] or 1,a or c[4] or 1)
  end
  local function requestedScale() return clamp((tonumber(option("overlay_scale",100)) or 100)/100,.5,1) end
  local function glass() return option("overlay_style","paper")=="glass" end
  local function overlayStyle(colors,scale)
    local id=tostring(colors and colors.themeId or "cream")
    if id=="retro" then return {radius=10*scale,innerRadius=5*scale,border=math.max(2,2*scale)} end
    if id=="graphite" then return {radius=14*scale,innerRadius=8*scale,border=math.max(1.5,1.5*scale)} end
    if id=="purplenight" then return {radius=18*scale,innerRadius=10*scale,border=math.max(1.5,1.5*scale)} end
    if id=="emerald" then return {radius=20*scale,innerRadius=12*scale,border=math.max(2,2*scale)} end
    if id=="firered" then return {radius=18*scale,innerRadius=10*scale,border=math.max(2,2*scale)} end
    return {radius=16*scale,innerRadius=9*scale,border=math.max(1.5,1.5*scale)}
  end
  local function state()
    if type(Core.overlayState)=="function" then
      local ok,value=pcall(Core.overlayState);if ok and type(value)=="table" then return value end
    end
    return {visible=false,contextMode=false,editMode=false,locked=true,focused="encounters",widgets={}}
  end
  local function safe(viewport)
    local w=math.max(1,tonumber(viewport and viewport.width) or 1);local h=math.max(1,tonumber(viewport and viewport.height) or 1)
    local margin=math.max(12,math.min(36,math.floor(math.min(w,h)*.022)))
    return {x=margin,y=margin,w=w-margin*2,h=h-margin*2}
  end
  local function position(pos,viewport,w,h)
    local s=safe(viewport);local nx=clamp(tonumber(pos and pos.x) or 0,0,1);local ny=clamp(tonumber(pos and pos.y) or 0,0,1)
    return math.floor(s.x+nx*math.max(0,s.w-w)+.5),math.floor(s.y+ny*math.max(0,s.h-h)+.5)
  end
  local function context(game)
    local top=Models.context(game);local battle=top and (top.kind=="wild" or top.kind=="trainer" or top.kind=="link")
    return top,game and top==game.overworld,battle==true
  end
  local function modeAllows(mode,overworld,battle)
    return mode=="both" or (mode=="overworld" and overworld) or (mode=="battle" and battle)
  end
  local function buildModels(game) return {encounters=Models.encounters(game),capture=Models.capture(game)} end
  local function available(id,game,models)
    local _,overworld,battle=context(game);if not(overworld or battle) then return false end
    return models[id]~=nil
  end
  function Overlay.enabledIds() return {"encounters","capture"} end

  local function geometry(id,pos,viewport)
    local base=BASE[id];local area=safe(viewport)
    local responsive=math.min((viewport.width or 1920)/1920,(viewport.height or 1080)/1080)
    local globalScale=clamp(responsive*requestedScale(),.50,1.18)
    local wf=clamp(tonumber(pos.width) or tonumber(pos.scale) or 1,.6,1.6)
    local hf=clamp(tonumber(pos.height) or tonumber(pos.scale) or 1,.6,1.6)
    local widthUnit=base.w*globalScale;local heightUnit=base.h*globalScale
    local w=math.min(area.w,math.max(150,widthUnit*wf));local h=math.min(area.h,math.max(126,heightUnit*hf))
    return w,h,wf,hf,widthUnit,heightUnit
  end
  local function chromeScale(id,w,h)
    local b=BASE[id]
    -- Both dimensions matter: a short window shrinks chrome even when wide,
    -- while a larger window grows the actual content instead of revealing more.
    return clamp(math.sqrt((w/b.w)*(h/b.h)),.42,1.55)
  end
  local function selectorGrid(w,scale)
    local gap=4*scale;local total=w-24*scale;local four=(total-gap*3)/4
    if four>=64*scale then return 4,1,four end
    return 2,2,(total-gap)/2
  end
  local function contextHeaderHeight(w,scale)
    local _,rows=selectorGrid(w,scale);return (rows==1 and 76 or 108)*scale
  end
  local function normalHeaderHeight(scale) return math.max(40,58*scale) end
  local function modeSelector(x,y,w,scale,current,colors)
    local style=overlayStyle(colors,scale);local rects={};local gap=4*scale
    local columns,rows,cell=selectorGrid(w,scale);local py=y+40*scale
    for i,item in ipairs(MODES) do
      local col=(i-1)%columns;local row=math.floor((i-1)/columns)
      local r={x=x+12*scale+col*(cell+gap),y=py+row*(25*scale+gap),w=cell,h=25*scale,mode=item.id};rects[#rects+1]=r
      local selected=current==item.id
      set(selected and (colors.navSelectedFill or colors.focus) or (colors.inverseRaised or colors.subtle),selected and .96 or .88)
      love.graphics.rectangle("fill",r.x,r.y,r.w,r.h,style.innerRadius,style.innerRadius)
      set(selected and (colors.navSelectedStroke or colors.focus) or colors.borderStrong);love.graphics.setLineWidth(selected and math.max(2,2*scale) or 1)
      love.graphics.rectangle("line",r.x,r.y,r.w,r.h,style.innerRadius,style.innerRadius)
      love.graphics.setFont(font(9*scale,"semibold"));set(selected and (colors.navSelectedText or colors.text) or (colors.structureText or colors.textInverse))
      love.graphics.printf(item.label,r.x,r.y+7*scale,r.w,"center")
    end
    return rects,(rows==1 and 76 or 108)*scale
  end
  local function card(x,y,w,h,id,focused,scale,colors,contextMode,mode,layoutOperation)
    local style=overlayStyle(colors,scale);local headerH=contextMode and contextHeaderHeight(w,scale) or normalHeaderHeight(scale)
    set(colors.panel,colors.overlayGlass and .84 or 1);love.graphics.rectangle("fill",x,y,w,h,style.radius,style.radius)
    set(colors.inverse,colors.overlayGlass and .92 or 1);love.graphics.rectangle("fill",x,y,w,headerH,style.radius,style.radius)
    if headerH>style.radius then love.graphics.rectangle("fill",x,y+style.radius,w,headerH-style.radius) end
    set(colors.headerAccent or colors.focus);love.graphics.rectangle("fill",x,y,math.max(4,5*scale),headerH,style.radius,0)
    set(focused and colors.focus or colors.borderStrong);love.graphics.setLineWidth(focused and 3 or style.border)
    love.graphics.rectangle("line",x,y,w,h,style.radius,style.radius)
    love.graphics.setFont(font(13*scale,"bold"));set(colors.structureText or colors.textInverse)
    love.graphics.print(TITLES[id],x+14*scale,y+13*scale)
    if contextMode then local rects,resolved=modeSelector(x,y,w,scale,mode,colors);return rects,resolved,nil end
    local buttonSize=math.max(34,math.min(44,44*scale));local collapseRect={x=x+w-buttonSize-7*scale,y=y+7*scale,w=buttonSize,h=buttonSize}
    if focused and layoutOperation then
      love.graphics.setFont(font(9*scale));set(colors.focus)
      love.graphics.printf(tostring(layoutOperation):upper(),x+w-buttonSize-78*scale,y+18*scale,64*scale,"right")
    end
    set(colors.inverseRaised or colors.subtle,.96);love.graphics.rectangle("fill",collapseRect.x,collapseRect.y,collapseRect.w,collapseRect.h,style.innerRadius,style.innerRadius)
    set(colors.headerAccent or colors.focus);love.graphics.setLineWidth(math.max(2,2*scale));local inset=math.max(9,12*scale);local cy=collapseRect.y+collapseRect.h/2
    love.graphics.line(collapseRect.x+inset,cy,collapseRect.x+collapseRect.w-inset,cy)
    return {},headerH,collapseRect
  end
  local function resizeHandle(x,y,w,h,scale,colors)
    local gap=math.max(3,5*scale);local inset=math.max(7,10*scale);set(colors.focus);love.graphics.setLineWidth(math.max(2,2*scale))
    for i=0,2 do local d=inset+i*gap;love.graphics.line(x+w-d,y+h-3,x+w-3,y+h-d) end
  end
  local function placeholder(x,y,w,h,headerH,scale,colors,text)
    love.graphics.setFont(font(12*scale,"semibold"));set(colors.textSecondary)
    love.graphics.printf(text or "NO DISPONIBLE EN EL ESTADO ACTUAL",x+12*scale,y+headerH+math.max(12,(h-headerH)/2-8*scale),w-24*scale,"center")
  end

  -- Responsive editorial grid. Rows are top-aligned instead of being centred
  -- inside a clipping viewport: resizing changes the card dimensions, column
  -- count, typography and sprite scale, but never hides a species/ball row.
  local function fitGrid(count,area,baseW,baseH,baseGap,maxCols,maxScale)
    if count<=0 then return {scale=1,cols=1,rows=0,cardW=0,cardH=0,gap=0,x=area.x,y=area.y} end
    local best=nil;maxCols=math.max(1,math.min(count,maxCols or count));maxScale=maxScale or 1.65
    for cols=1,maxCols do
      local rows=math.ceil(count/cols)
      local sx=area.w/(cols*baseW+math.max(0,cols-1)*baseGap)
      local sy=area.h/(rows*baseH+math.max(0,rows-1)*baseGap)
      local sc=math.min(sx,sy,maxScale)
      -- Prefer the largest readable cards. On an exact tie, fewer columns keep
      -- the list easier to scan and avoid a sparse final row.
      if not best or sc>best.scale+.001 or (math.abs(sc-best.scale)<.001 and cols<best.cols) then
        best={scale=sc,cols=cols,rows=rows}
      end
    end
    best.scale=math.max(.22,best.scale);best.gap=baseGap*best.scale
    best.cardW=baseW*best.scale;best.cardH=baseH*best.scale
    local totalW=best.cols*best.cardW+math.max(0,best.cols-1)*best.gap
    best.x=area.x+(area.w-totalW)/2;best.y=area.y
    return best
  end
  local function gridRect(layout,index)
    local col=(index-1)%layout.cols;local row=math.floor((index-1)/layout.cols)
    return layout.x+col*(layout.cardW+layout.gap),layout.y+row*(layout.cardH+layout.gap),layout.cardW,layout.cardH
  end
  local function frontImage(game,species,mon)
    if not(runtime.PokemonArt and type(runtime.PokemonArt.image)=="function") then return nil end
    local ok,art=pcall(runtime.PokemonArt.image,runtime.PokemonArt,game,species,"front",{kind="overlay",mon=mon})
    return ok and art or nil
  end
  local function drawFront(game,species,mon,x,y,size,alpha)
    local art=frontImage(game,species,mon);if not (art and art.image) then return false end
    local image=art.image;local iw,ih=image:getDimensions();if not(iw and ih and iw>0 and ih>0) then return false end
    if image.setFilter then pcall(image.setFilter,image,"nearest","nearest") end
    local metric=art.metrics
    local x0=clamp(tonumber(metric and metric.x0) or 0,0,iw-1)
    local x1=clamp(tonumber(metric and metric.x1) or (iw-1),x0,iw-1)
    local y0=clamp(tonumber(metric and metric.y0) or 0,0,ih-1)
    local y1=clamp(tonumber(metric and metric.y1) or (ih-1),y0,ih-1)
    local cw=math.max(1,tonumber(metric and metric.w) or iw);local ch=math.max(1,tonumber(metric and metric.h) or ih)
    local k=math.min(size/cw,size/ch);local center=tonumber(metric and metric.center) or cw/2
    local px=x+size/2-center*k;local py=y+size-(y1+1)*k
    love.graphics.setColor(1,1,1,alpha or 1);love.graphics.draw(image,px,py,0,k,k)
    if runtime.PokemonArt.mark then pcall(runtime.PokemonArt.mark,art,px,py,iw*k,ih*k) end
    return true
  end
  local function hpColor(colors,ratio) return ratio<=.2 and colors.danger or ratio<=.5 and colors.warning or colors.success end
  local function mapLabel(value) return tostring(value or "ZONA ACTUAL"):gsub("_"," "):upper() end
  local function surfaceBox(x,y,w,h,colors,scale,strong)
    local style=overlayStyle(colors,scale)
    set(strong and (colors.panel or colors.subtle) or colors.subtle,colors.overlayGlass and .82 or .98)
    love.graphics.rectangle("fill",x,y,w,h,style.innerRadius,style.innerRadius)
    set(strong and (colors.borderStrong or colors.border) or colors.border);love.graphics.setLineWidth(math.max(1,scale))
    love.graphics.rectangle("line",x,y,w,h,style.innerRadius,style.innerRadius)
  end
  local function badge(text,x,y,w,h,colors,scale,active)
    local style=overlayStyle(colors,scale);set(active and colors.focus or (colors.inverseRaised or colors.subtle),active and .98 or .92)
    love.graphics.rectangle("fill",x,y,w,h,style.innerRadius,style.innerRadius)
    love.graphics.setFont(font(8.5*scale,"bold"));set(active and (colors.navSelectedText or colors.textInverse) or colors.textSecondary)
    love.graphics.printf(text,x,y+h*.29,w,"center")
  end
  local function progressBar(x,y,w,h,ratio,colors)
    ratio=clamp(tonumber(ratio) or 0,0,1);set(colors.border);love.graphics.rectangle("fill",x,y,w,h,h/2,h/2)
    if ratio>0 then set(colors.focus);love.graphics.rectangle("fill",x,y,math.max(h,w*ratio),h,h/2,h/2) end
  end

  local function drawSpeciesCard(game,row,rx,ry,rw,rh,colors,s)
    surfaceBox(rx,ry,rw,rh,colors,s,false)
    local accentW=math.max(4,5*s);set(row.caught and colors.success or colors.focus)
    love.graphics.rectangle("fill",rx,ry,accentW,rh,math.max(2,3*s),0)

    local spriteBox=clamp(rh-18*s,34,86*s);local sx=rx+14*s;local sy=ry+(rh-spriteBox)/2
    set(colors.panel,colors.overlayGlass and .76 or 1);love.graphics.rectangle("fill",sx,sy,spriteBox,spriteBox,math.max(5,8*s),math.max(5,8*s))
    drawFront(game,row.species,nil,sx,sy,spriteBox,row.caught and .72 or 1)

    local tx=sx+spriteBox+14*s;local right=rx+rw-14*s
    local statusW=clamp(76*s,54,104);badge(row.caught and "ATRAPADO" or "POR ATRAPAR",right-statusW,ry+12*s,statusW,24*s,colors,s,row.caught)
    local nameW=math.max(40,right-statusW-10*s-tx)
    love.graphics.setFont(font(13*s,"bold"));set(row.caught and colors.textSecondary or colors.text)
    love.graphics.printf(tostring(row.name):upper(),tx,ry+12*s,nameW,"left")

    local lv=row.minLevel==row.maxLevel and ("NV "..row.minLevel) or ("NV "..row.minLevel.."–"..row.maxLevel)
    love.graphics.setFont(font(9.5*s,"medium"));set(colors.textSecondary);love.graphics.print(lv,tx,ry+42*s)
    love.graphics.setFont(font(14*s,"bold"));set(row.caught and colors.textSecondary or colors.focus)
    love.graphics.printf(("%.1f%%"):format(row.percent or 0),tx,ry+rh-28*s,math.max(45,right-tx),"right")
  end

  local function drawEncounterSection(game,group,area,colors,chrome)
    local s=clamp(math.min(area.w/620,area.h/380),.38,1.55)
    local headingH=clamp(42*s,26,58);local modeW=clamp(78*s,56,108)
    badge(group.label,area.x,area.y,modeW,26*s,colors,s,true)
    love.graphics.setFont(font(9*s,"semibold"));set(colors.textSecondary)
    love.graphics.print("PROBABILIDAD DE ENCUENTRO",area.x+modeW+10*s,area.y+2*s)
    love.graphics.setFont(font(12*s,"bold"));set(colors.text)
    love.graphics.print(("%.1f%% / PASO"):format(group.stepPercent or 0),area.x+modeW+10*s,area.y+17*s)

    local cards={x=area.x,y=area.y+headingH,w=area.w,h=math.max(1,area.h-headingH)}
    local maxCols=cards.w>=980 and 3 or cards.w>=760 and 2 or 1
    local layout=fitGrid(#group.rows,cards,330,96,10,maxCols,1.55)
    for i,row in ipairs(group.rows) do
      local rx,ry,rw,rh=gridRect(layout,i);drawSpeciesCard(game,row,rx,ry,rw,rh,colors,layout.scale)
    end
  end

  local function drawAreaSummary(model,area,colors,s)
    surfaceBox(area.x,area.y,area.w,area.h,colors,s,true)
    local pad=clamp(16*s,10,24);local right=area.x+area.w-pad
    love.graphics.setFont(font(8.5*s,"bold"));set(colors.textSecondary);love.graphics.print("REGISTRO DE ZONA",area.x+pad,area.y+pad)
    love.graphics.setFont(font(16*s,"bold"));set(colors.text);love.graphics.printf(mapLabel(model.mapId),area.x+pad,area.y+pad+18*s,area.w-pad*2,"left")
    local ratio=(model.total or 0)>0 and (model.caught or 0)/(model.total or 1) or 0
    local value=("%d / %d"):format(model.caught or 0,model.total or 0)
    love.graphics.setFont(font(15*s,"bold"));set(colors.focus);love.graphics.printf(value,area.x+pad,area.y+area.h-46*s,area.w-pad*2,"right")
    love.graphics.setFont(font(8.5*s,"semibold"));set(colors.textSecondary);love.graphics.print("ATRAPADOS",area.x+pad,area.y+area.h-43*s)
    progressBar(area.x+pad,area.y+area.h-18*s,area.w-pad*2,8*s,ratio,colors)
  end

  local function drawEncounters(game,model,x,y,w,h,headerH,chrome,colors)
    if not model then placeholder(x,y,w,h,headerH,chrome,colors,"SIN ENCUENTROS SALVAJES EN ESTA ZONA");return end
    local pad=clamp(16*chrome,8,24);local body={x=x+pad,y=y+headerH+pad,w=w-pad*2,h=h-headerH-pad*2}
    local groups=model.groups or {};if #groups==0 then return end
    local gap=clamp(14*chrome,7,22)

    -- Wide windows become an editorial two-column composition. Narrow/tall
    -- windows use a compact summary strip followed immediately by the species
    -- list. Both layouts consume the real window dimensions; no content is
    -- clipped or merely revealed by resizing.
    if body.w>=820 and body.w/body.h>=1.18 then
      local railW=clamp(body.w*.29,190,310);local summary={x=body.x,y=body.y,w=railW,h=body.h}
      drawAreaSummary(model,summary,colors,clamp(math.min(railW/250,body.h/400),.55,1.4))
      local content={x=body.x+railW+gap,y=body.y,w=body.w-railW-gap,h=body.h}
      if #groups==1 then drawEncounterSection(game,groups[1],content,colors,chrome)
      elseif content.w/content.h>=1.35 then
        local sw=(content.w-gap)/#groups
        for i,group in ipairs(groups) do drawEncounterSection(game,group,{x=content.x+(i-1)*(sw+gap),y=content.y,w=sw,h=content.h},colors,chrome) end
      else
        local sh=(content.h-gap*(#groups-1))/#groups
        for i,group in ipairs(groups) do drawEncounterSection(game,group,{x=content.x,y=content.y+(i-1)*(sh+gap),w=content.w,h=sh},colors,chrome) end
      end
      return
    end

    local summaryH=clamp(body.h*.18,76*chrome,118*chrome);drawAreaSummary(model,{x=body.x,y=body.y,w=body.w,h=summaryH},colors,clamp(summaryH/96,.55,1.35))
    local content={x=body.x,y=body.y+summaryH+gap,w=body.w,h=body.h-summaryH-gap}
    if #groups==1 then drawEncounterSection(game,groups[1],content,colors,chrome);return end
    local sh=(content.h-gap*(#groups-1))/#groups
    for i,group in ipairs(groups) do drawEncounterSection(game,group,{x=content.x,y=content.y+(i-1)*(sh+gap),w=content.w,h=sh},colors,chrome) end
  end

  local function drawTargetCard(game,model,area,colors,s)
    surfaceBox(area.x,area.y,area.w,area.h,colors,s,true)
    local pad=clamp(16*s,10,24);local sprite=clamp(math.min(area.h-2*pad,area.w*.34),48,120*s)
    local sx=area.x+pad;local sy=area.y+(area.h-sprite)/2
    set(colors.panel,colors.overlayGlass and .76 or 1);love.graphics.rectangle("fill",sx,sy,sprite,sprite,math.max(7,10*s),math.max(7,10*s))
    drawFront(game,model.species,model.mon,sx,sy,sprite,1)
    local tx=sx+sprite+14*s;local right=area.x+area.w-pad
    love.graphics.setFont(font(8.5*s,"bold"));set(colors.textSecondary);love.graphics.print("OBJETIVO SALVAJE",tx,area.y+pad)
    love.graphics.setFont(font(16*s,"bold"));set(colors.text);love.graphics.printf(tostring(model.name):upper(),tx,area.y+pad+18*s,math.max(30,right-tx),"left")
    local status=model.status and tostring(model.status):upper() or "SANO"
    love.graphics.setFont(font(9*s,"semibold"));set(colors.textSecondary);love.graphics.print(status,tx,area.y+pad+47*s)
    local ratio=clamp((model.hp or 0)/math.max(1,model.maxHp or 1),0,1);local by=area.y+area.h-pad-20*s;local bw=math.max(30,right-tx)
    progressBar(tx,by,bw,9*s,ratio,{border=colors.border,focus=hpColor(colors,ratio)})
    love.graphics.setFont(font(8.5*s,"semibold"));set(colors.textSecondary);love.graphics.printf(("%d / %d PS"):format(model.hp or 0,model.maxHp or 1),tx,by-20*s,bw,"right")
  end

  local function drawBallCard(row,rx,ry,rw,rh,colors,s,best)
    surfaceBox(rx,ry,rw,rh,colors,s,false);local accent=best and colors.focus or colors.borderStrong
    set(accent);love.graphics.rectangle("fill",rx,ry,math.max(4,5*s),rh,math.max(2,3*s),0)
    love.graphics.setFont(font(11*s,"bold"));set(colors.text);love.graphics.print(row.label,rx+14*s,ry+13*s)
    love.graphics.setFont(font(9*s,"semibold"));set(colors.textSecondary);love.graphics.print("×"..tostring(math.floor(row.quantity or 0)),rx+14*s,ry+39*s)
    love.graphics.setFont(font(20*s,"bold"));set(best and colors.focus or colors.text)
    love.graphics.printf(row.chance and (("%.1f%%"):format(row.chance)) or "ESPECIAL",rx+rw-112*s,ry+17*s,96*s,"right")
    if best then badge("MEJOR",rx+14*s,ry+rh-30*s,54*s,20*s,colors,s,true) end
  end

  local function drawCapture(game,model,x,y,w,h,headerH,chrome,colors)
    if not model then placeholder(x,y,w,h,headerH,chrome,colors,"DISPONIBLE EN COMBATES SALVAJES");return end
    local pad=clamp(16*chrome,8,24)
    local body={x=x+pad,y=y+headerH+pad,w=w-pad*2,h=h-headerH-pad*2}
    local rows=model.rows or {}
    love.graphics.setFont(font(9*chrome,"bold"));set(colors.textSecondary)
    love.graphics.print(model.safari and "SAFARI BALL · PROBABILIDAD ACTUAL" or "BALLS DISPONIBLES · PROBABILIDAD ACTUAL",body.x,body.y)
    body.y=body.y+26*chrome;body.h=math.max(1,body.h-26*chrome)
    if #rows==0 then
      love.graphics.setFont(font(11*chrome,"semibold"));set(colors.textSecondary)
      love.graphics.printf("SIN POKÉ BALLS DISPONIBLES",body.x,body.y+body.h*.42,body.w,"center")
      return
    end
    -- Capture mechanics remain model-owned. The overlay is now only the useful
    -- comparison surface: Ball + quantity + chance for the current battle.
    local maxCols=body.w>=620 and 2 or 1
    local layout=fitGrid(#rows,body,270,92,10,maxCols,1.5)
    local bestChance=tonumber(rows[1] and rows[1].chance)
    for i,row in ipairs(rows) do
      local rx,ry,rw,rh=gridRect(layout,i)
      drawBallCard(row,rx,ry,rw,rh,colors,layout.scale,bestChance and tonumber(row.chance)==bestChance)
    end
  end

  local function collapsedTabIcon()
    if collapsedIcon~=nil then return collapsedIcon or nil end;collapsedIcon=false
    if not(love and love.graphics and love.graphics.newImage) then return nil end
    local path="assets/generated/sprites/poke_ball.png"
    if type(Core.resolveAssetPath)=="function" then local ok,value=pcall(Core.resolveAssetPath,path);if ok and value then path=value end end
    local ok,image=pcall(love.graphics.newImage,path);if ok and image then if image.setFilter then image:setFilter("nearest","nearest") end;collapsedIcon=image end
    return collapsedIcon or nil
  end
  local function nearestEdge(x,y,w,h,viewport)
    local s=safe(viewport);local distances={{"left",x-s.x},{"right",s.x+s.w-(x+w)},{"top",y-s.y},{"bottom",s.y+s.h-(y+h)}}
    table.sort(distances,function(a,b) return a[2]<b[2] end);return distances[1][1]
  end
  local function overlaps(a,b,gap)
    gap=gap or 0;return a.x<b.x+b.w+gap and b.x<a.x+a.w+gap and a.y<b.y+b.h+gap and b.y<a.y+a.h+gap
  end
  local function tabRect(edge,pos,viewport,scale,occupied,blockers)
    local s=safe(viewport);local size=math.max(44,52*scale);local x,y;local explicit=pos.tabEdge==edge and tonumber(pos.tabPosition) or nil
    if edge=="left" or edge=="right" then x=edge=="left" and s.x or s.x+s.w-size;y=s.y+(explicit or tonumber(pos.y) or 0)*(s.h-size)
    else x=s.x+(explicit or tonumber(pos.x) or 0)*(s.w-size);y=edge=="top" and s.y or s.y+s.h-size end
    local r={x=math.floor(x+.5),y=math.floor(y+.5),w=size,h=size};occupied[edge]=occupied[edge] or {}
    local axis=(edge=="left" or edge=="right") and "y" or "x";local limit=axis=="y" and s.y+s.h-size or s.x+s.w-size;local start=axis=="y" and s.y or s.x
    local preferred=r[axis];local gap=math.max(6,6*scale);local step=size+gap
    local function free(candidate)
      for _,other in ipairs(occupied[edge]) do if overlaps(candidate,other,gap) then return false end end
      for _,other in ipairs(blockers or {}) do if overlaps(candidate,other,gap) then return false end end
      return true
    end
    if not free(r) then
      local slots=math.ceil(math.max(0,limit-start)/step)+2;local placed=false
      for distance=1,slots do for _,direction in ipairs({1,-1}) do
        local candidate={x=r.x,y=r.y,w=r.w,h=r.h};candidate[axis]=math.max(start,math.min(limit,preferred+direction*distance*step))
        if free(candidate) then r=candidate;placed=true;break end
      end;if placed then break end end
    end
    occupied[edge][#occupied[edge]+1]=r;return r
  end
  local function drawCollapsed(id,pos,viewport,scale,colors,expanded,occupied,blockers,order)
    local edge=pos.tabEdge;if edge~="left" and edge~="right" and edge~="top" and edge~="bottom" then edge=nearestEdge(expanded.x,expanded.y,expanded.w,expanded.h,viewport) end
    local r=tabRect(edge,pos,viewport,scale,occupied,blockers);local style=overlayStyle(colors,scale)
    set(colors.inverse,colors.overlayGlass and .90 or 1);love.graphics.rectangle("fill",r.x,r.y,r.w,r.h,style.radius,style.radius)
    set(colors.borderStrong);love.graphics.setLineWidth(style.border);love.graphics.rectangle("line",r.x,r.y,r.w,r.h,style.radius,style.radius)
    local icon=collapsedTabIcon();local iconSize=math.max(20,24*scale)
    if icon then local iw,ih=icon:getDimensions();local ratio=math.min(iconSize/iw,iconSize/ih);love.graphics.setColor(1,1,1,1);love.graphics.draw(icon,r.x+(r.w-iw*ratio)/2,r.y+6*scale,0,ratio,ratio) end
    love.graphics.setFont(font(8.5*scale,"bold"));set(colors.structureText or colors.textInverse);love.graphics.printf(TAB_LABELS[id],r.x,r.y+r.h-16*scale,r.w,"center")
    if type(Core.setOverlayRegion)=="function" then pcall(Core.setOverlayRegion,id,{x=r.x,y=r.y,w=r.w,h=r.h,collapsed=true,edge=edge,order=order}) end
  end
  local function clearRegions() if type(Core.setOverlayRegion)=="function" then for _,id in ipairs(IDS) do pcall(Core.setOverlayRegion,id,nil) end end end

  function Overlay.draw(game,viewport)
    if not(love and love.graphics and viewport) then return false end
    local st=state();local models=buildModels(game);if not st.visible then clearRegions();return false end
    local _,overworld,battle=context(game);local palette=Palette.resolve(game);local colors=palette.colors
    colors.typeColors=palette.typeColors;colors.overlayGlass=glass()
    clearRegions();love.graphics.push("all");love.graphics.origin();local order=0;local occupied={}
    local contextMode=st.contextMode==true or st.editMode==true;local layoutMode=runtime.overlayLayoutMode==true and not contextMode
    local drawIds={};for _,id in ipairs(IDS) do if st.focused~=id then drawIds[#drawIds+1]=id end end;if st.focused then drawIds[#drawIds+1]=st.focused end
    local expandedEntries,collapsedEntries,blockers={},{},{}
    for _,id in ipairs(drawIds) do
      local pos=(st.widgets or {})[id] or {};local mode=pos.mode or "none";local normalVisible=modeAllows(mode,overworld,battle) and available(id,game,models)
      if contextMode or normalVisible then
        local w,h,wf,hf,wu,hu=geometry(id,pos,viewport);local x,y=position(pos,viewport,w,h);local scale=chromeScale(id,w,h)
        local entry={id=id,pos=pos,mode=mode,scale=scale,w=w,h=h,x=x,y=y,focused=(contextMode or layoutMode) and st.focused==id,widthFactor=wf,heightFactor=hf,widthUnit=wu,heightUnit=hu}
        if pos.collapsed and not contextMode then collapsedEntries[#collapsedEntries+1]=entry else expandedEntries[#expandedEntries+1]=entry;blockers[#blockers+1]={x=x,y=y,w=w,h=h} end
      end
    end
    for _,entry in ipairs(expandedEntries) do
      order=order+1;local id=entry.id
      local modeRects,headerH,collapseRect=card(entry.x,entry.y,entry.w,entry.h,id,entry.focused,entry.scale,colors,contextMode,entry.mode,layoutMode and runtime.overlayLayoutOperation or nil)
      if contextMode and not available(id,game,models) then placeholder(entry.x,entry.y,entry.w,entry.h,headerH,entry.scale,colors)
      elseif id=="encounters" then drawEncounters(game,models.encounters,entry.x,entry.y,entry.w,entry.h,headerH,entry.scale,colors)
      else drawCapture(game,models.capture,entry.x,entry.y,entry.w,entry.h,headerH,entry.scale,colors) end
      if type(Core.setOverlayRegion)=="function" then pcall(Core.setOverlayRegion,id,{x=entry.x,y=entry.y,w=entry.w,h=entry.h,headerH=headerH,
        resizeSize=contextMode and 0 or math.max(36,44*entry.scale),widthScale=entry.widthFactor,heightScale=entry.heightFactor,
        widthUnit=entry.widthUnit,heightUnit=entry.heightUnit,minScale=.6,maxScale=1.6,modeRects=modeRects,collapseRect=collapseRect,order=order}) end
      if not contextMode then resizeHandle(entry.x,entry.y,entry.w,entry.h,entry.scale,colors) end
    end
    for _,entry in ipairs(collapsedEntries) do order=order+1;drawCollapsed(entry.id,entry.pos,viewport,entry.scale,colors,{x=entry.x,y=entry.y,w=entry.w,h=entry.h},occupied,blockers,order) end
    love.graphics.pop();return order>0
  end

  Overlay._themeStyle=overlayStyle
  Overlay._fitGrid=fitGrid
  return Overlay
end
