return function(runtime)
  local P={}
  local Sprites=require("src.pokemon.Sprites")
  local Assets=require("src.render.Assets")
  local PaletteFX=require("src.render.PaletteFX")
  local Sound=require("src.core.Sound")
  local okDexEntry,DexEntryMenu=pcall(require,"src.ui.DexEntryMenu")
  -- Native DexEntryMenu redraws every frame. Keep one synthetic monster per
  -- native screen so animated art providers receive a stable identity and
  -- can advance their frame clock instead of rebuilding a preview battle.
  local nativeEntryCache=setmetatable({},{__mode="k"})

  local function clean(value)
    return tostring(value or ""):gsub("_"," "):gsub("[\v\f]"," "):gsub("%s+"," ")
  end

  local function statusLabel(value)
    if value=="caught" then return "ATRAPADO" end
    if value=="seen" then return "VISTO" end
    return "NO VISTO"
  end

  local function marker(m,x,y,r,mode,color,width)
    love.graphics.setColor(color)
    love.graphics.setLineWidth(math.max(1,(width or 1.5)*m.scale))
    love.graphics.circle(mode,m.ox+x*m.scale,m.oy+y*m.scale,r*m.scale)
  end

  local function drawKnowledge(m,c,value,x,y,w,selected)
    local D=runtime.Draw
    local color=selected and c.textSecondary or c.faint
    if value=="caught" then marker(m,x+4,y+8,3,"fill",color)
    elseif value=="seen" then marker(m,x+4,y+8,3,"line",color)
    else D.line(m,x,y+8,x+8,y+8,color,1.5) end
    D.text(runtime,m,statusLabel(value),x+16,y,11,color,{weight="semibold",tracking=.4,width=(w or 112)-16})
  end

  local function sprite(game,species,mon,kind)
    if not species then return nil end
    return runtime.PokemonArt:image(game,species,"front",{kind=kind or "pokedex",mon=mon})
  end

  local function drawSprite(m,art,x,y,w,h,maxLogical)
    if not (art and art.image) then return false end
    local iw,ih=art.image:getDimensions()
    local limit=math.min(w,h,maxLogical or math.min(w,h))*m.scale
    local scale=math.max(1,math.floor(math.min(limit/iw,limit/ih)))
    local dw,dh=iw*scale,ih*scale
    local dx=m.ox+x*m.scale+(w*m.scale-dw)/2
    local dy=m.oy+y*m.scale+(h*m.scale-dh)/2
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(art.image,dx,dy,0,scale,scale)
    if art.trueColor then PaletteFX.markTrueColor(dx,dy,dw,dh) end
    return true
  end

  local function icon(game,species)
    local data=game.data;local def=data.pokemon and data.pokemon[species];local icons=data.icons
    if not (def and icons) then return nil end
    local mon={species=species,hp=1,stats={hp=1}}
    local entry=(icons.bySpecies and icons.bySpecies[species]) or def.icon
    local name,vanilla
    if type(entry)=="string" then name=entry;vanilla=icons.icons and icons.icons[entry]
    elseif type(entry)=="table" then vanilla=entry.image end
    if not vanilla then name=def.dex and icons.byDex and icons.byDex[def.dex];vanilla=name and icons.icons and icons.icons[name] end
    local path=Sprites.iconPath(data,mon,vanilla,{name=name})
    if not path then return nil end
    runtime.dexIcons=runtime.dexIcons or {}
    local key=species..":"..path
    if runtime.dexIcons[key]~=nil then return runtime.dexIcons[key] or nil end
    local ok,resolved=pcall(Assets.resolve,path);resolved=ok and resolved or path
    local loaded,image=pcall(love.graphics.newImage,resolved)
    if not loaded or not image then runtime.dexIcons[key]=false;return nil end
    if image.setFilter then image:setFilter("nearest","nearest") end
    local value={image=image,trueColor=(path~=vanilla or type(entry)=="table"),path=path}
    runtime.dexIcons[key]=value
    return value
  end

  local function drawIcon(m,value,cx,cy,size)
    if not (value and value.image) then return false end
    local iw,ih=value.image:getDimensions();local side=math.min(iw,ih)
    local qx,qy=0,0
    if iw>ih then side=ih elseif ih>iw then side=iw end
    local quad=love.graphics.newQuad(qx,qy,side,side,iw,ih)
    local scale=(size*m.scale)/side
    local x=m.ox+(cx-size/2)*m.scale;local y=m.oy+(cy-size/2)*m.scale
    love.graphics.setColor(1,1,1,1);love.graphics.draw(value.image,quad,x,y,0,scale,scale)
    if value.trueColor then PaletteFX.markTrueColor(x,y,size*m.scale,size*m.scale) end
    return true
  end

  local function typeToken(m,c,kind,x,y)
    runtime.TypeChip.draw(tostring(kind or "UNKNOWN"):upper(),m.ox+x*m.scale,m.oy+y*m.scale,m.scale,{typeColors=c.typeColors,colors=c})
  end

  local function worldContext(game,m,c)
    local D=runtime.Draw
    local jc=type(runtime.Core.journalContext)=="function" and runtime.Core.journalContext() or {}
    D.text(runtime,m,clean(jc.location or "KANTO"):upper(),1570,18,14,c.textInverse,{weight="semibold",tracking=.3,width=318,align="right"})
    local sec=math.floor(tonumber(jc.playTime) or 0)
    local timeLabel=(runtime.worldTimeLabel and runtime.worldTimeLabel(game,sec)) or ("%02d:%02d • DÍA"):format(math.floor(sec/3600),math.floor(sec/60)%60)
    D.text(runtime,m,timeLabel,1570,45,12,c.faint,{weight="medium",tracking=.4,width=318,align="right"})
  end

  local function shell(game,m,c,view,status)
    local D=runtime.Draw
    D.roundRect(m,"fill",0,0,1920,1080,0,c.canvas)
    D.roundRect(m,"fill",0,0,1920,88,0,c.inverse)
    D.text(runtime,m,"KANTO JOURNAL",32,18,24,c.textInverse,{weight="bold",tracking=-.25})
    D.text(runtime,m,"POKÉDEX",32,52,11,c.textInverse,{weight="bold",tracking=1,alpha=.72})
    -- Each view owns different hit targets. Clear the previous view's rows so
    -- stale INDEX rectangles cannot intercept AREA map drags.
    runtime.pokedexRowRects={};runtime.pokedexAreaRects={}
    runtime.pokedexTabRects={}
    local tabs={{id="index",label="ÍNDICE"},{id="data",label="DATOS"},{id="area",label="HÁBITAT"}}
    local x=758
    for _,tab in ipairs(tabs) do
      local r={x=x,y=20,w=124,h=48};runtime.pokedexTabRects[tab.id]=r
      local unavailable=status=="unseen" and tab.id~="index"
      local active=tab.id==view
      D.text(runtime,m,tab.label,r.x,r.y+12,14,unavailable and c.disabled or (active and c.textInverse or c.faint),{weight="semibold",tracking=.3,width=r.w,align="center"})
      if active then D.roundRect(m,"fill",r.x+14,62,96,3,1.5,c.focus) end
      x=x+132
    end
    worldContext(game,m,c)
    D.roundRect(m,"fill",0,1016,1920,64,0,c.inverse)
  end

  local function footer(m,c,view,status,modal)
    local D=runtime.Draw
    if modal then D.roundRect(m,"fill",0,1016,1920,64,0,c.inverse) end
    local prompts
    if modal then prompts={{id="close",key="ENTER",label="CERRAR"},{id="cancel",key="A",label="CANCELAR"}}
    elseif view=="index" then prompts={
      {key="↑↓",label="BUSCAR"},{key="←→",label="PÁGINA"},{id="views",key="TAB",label="VISTAS"},
      {id="cry",key="C",label="GRITO",requiresSeen=true},
      {id="back",key="A",label="VOLVER"},{id="oak",key="O",label="EVALUACIÓN OAK"},
    }
    elseif view=="area" then prompts={
      {key="ARRASTRAR",label="MOVER MAPA",labelOffset=84},{key="FLECHAS",label="HÁBITATS",labelOffset=72},{id="views",key="TAB",label="VISTAS"},
      {id="cry",key="C",label="GRITO"},{id="back",key="A",label="VOLVER"},{id="oak",key="O",label="EVALUACIÓN OAK"},
    }
    else prompts={
      {key="←→",label="VISTAS"},{id="cry",key="C",label="GRITO"},{id="back",key="A",label="VOLVER"},{id="oak",key="O",label="EVALUACIÓN OAK"},
    } end
    runtime.pokedexFooterRects={}
    local x=32
    for _,prompt in ipairs(prompts) do
      local disabled=prompt.requiresSeen and status=="unseen"
      local width=modal and 160 or 148
      if prompt.id then runtime.pokedexFooterRects[prompt.id]={x=x,y=1016,w=width,h=64,disabled=disabled} end
      D.text(runtime,m,prompt.key,x,1037,13,disabled and c.disabled or c.textInverse,{weight="bold"})
      D.text(runtime,m,prompt.label,x+(prompt.labelOffset or 44),1038,12,disabled and c.disabled or c.faint,{weight="medium",tracking=.4})
      x=x+width+(modal and 0 or 20)
    end
    local label=runtime.Footer and runtime.Footer.deviceLabel and runtime.Footer.deviceLabel() or "TECLADO + RATÓN"
    D.text(runtime,m,label,1640,1037,13,c.textInverse,{weight="semibold",width=248,align="right"})
  end

  local function statusChip(m,c,value,x,y)
    runtime.Draw.panel(m,x,y,132,36,18,c.elevated,c.borderStrong)
    drawKnowledge(m,c,value,x+14,y+10,112,true)
  end

  local function entryDef(screen,n)
    local entry=screen.dex[n];return entry and entry.def,entry and entry.id
  end

  local function entryStatus(game,id)
    local dex=game.save.pokedex or {}
    if id and dex.owned and dex.owned[id] then return "caught" end
    if id and dex.seen and dex.seen[id] then return "seen" end
    return "unseen"
  end

  local function drawLedger(game,m,c,s)
    local D=runtime.Draw;local x,y,w,h=64,120,620,856
    D.panel(m,x,y,w,h,16,c.inverse,nil)
    D.text(runtime,m,"POKÉDEX DE KANTO",x+24,y+20,11,c.faint,{weight="bold",tracking=1})
    D.text(runtime,m,"ÍNDICE DE ESPECIES",x+24,y+44,24,c.textInverse,{weight="bold",tracking=-.25})
    D.text(runtime,m,("ORDEN NACIONAL  •  %d ESPECIES"):format(s.max),x+24,y+78,14,c.faint,{weight="semibold",tracking=.3})
    D.text(runtime,m,"REGISTRO DE CAMPO",x+48,y+106,11,c.textInverse,{weight="bold",tracking=1})
    D.text(runtime,m,"VISTOS",x+48,y+132,14,c.faint,{weight="semibold",tracking=.3})
    D.text(runtime,m,("%03d / %03d"):format(s.seen,s.max),x+48,y+158,32,c.textInverse,{weight="bold",tracking=-.5})
    D.line(m,x+336,y+159,x+336,y+215,c.borderStrong,1)
    D.text(runtime,m,"ATRAPADOS",x+362,y+132,14,c.faint,{weight="semibold",tracking=.3})
    D.text(runtime,m,("%03d / %03d"):format(s.caught,s.max),x+362,y+158,32,c.textInverse,{weight="bold",tracking=-.5})
    local first=math.max(1,s.index-5);first=math.min(first,math.max(1,s.max-10))
    D.text(runtime,m,("ENTRADAS %03d—%03d"):format(first,math.min(s.max,first+10)),x+24,y+226,11,c.faint,{weight="bold",tracking=1})
    runtime.pokedexRowRects={}
    local rowY=y+250
    for slot=1,11 do
      local n=first+slot-1;if n>s.max then break end
      local def,id=entryDef(s,n);local state=entryStatus(game,id);local selected=n==s.index
      local row={x=x+24,y=rowY,w=572,h=48};runtime.pokedexRowRects[n]=row
      if selected then D.roundRect(m,"line",row.x,row.y,row.w,row.h,10,c.focus,3) end
      local color=selected and c.textInverse or c.textInverse
      D.text(runtime,m,("#%03d"):format(n),row.x+18,row.y+14,18,color,{weight="semibold",tracking=.1,width=72})
      local name=state=="unseen" and "ENTRADA DESCONOCIDA" or clean(runtime.PokemonName(def and def.name or "UNKNOWN",id,def,false)):upper()
      D.clipText(runtime,m,name,row.x+108,row.y+14,300,18,state=="unseen" and c.faint or color,{weight="semibold",tracking=.1})
      drawKnowledge(m,c,state,row.x+486,row.y+16,84,false)
      rowY=rowY+52
    end
    local track={x=x+w-16,y=y+250,w=4,h=568};runtime.pokedexScrollbar={track=track}
    D.roundRect(m,"fill",track.x,track.y,track.w,track.h,2,c.borderStrong)
    local visible=11;local thumbH=math.max(72,track.h*(visible/s.max));local travel=track.h-thumbH
    local thumbY=track.y+travel*((first-1)/math.max(1,s.max-visible))
    runtime.pokedexScrollbar.thumb={x=track.x,y=thumbY,w=track.w,h=thumbH}
    D.roundRect(m,"fill",track.x,thumbY,track.w,thumbH,2,c.textInverse)
  end

  local function drawHero(game,m,c,s,x,y,w,h)
    local D=runtime.Draw;local def=s.entry and s.entry.def
    D.text(runtime,m,("№ %03d"):format(s.index),x+16,y,72,c.text,{weight="bold",tracking=-1})
    statusChip(m,c,s.status,x+w-148,y+18)
    if s.status=="unseen" or not def then
      D.text(runtime,m,"REGISTRO DE ESPECIE",x+120,y+256,11,c.textSecondary,{weight="bold",tracking=1,width=w-240,align="center"})
      D.text(runtime,m,"ESPECIE DESCONOCIDA",x+80,y+288,48,c.textSecondary,{weight="bold",tracking=-1,width=w-160,align="center"})
      local ix=x+186
      D.text(runtime,m,"IDENTIDAD",ix,y+352,16,c.textSecondary,{weight="semibold"});D.text(runtime,m,"— NO REGISTRADO",ix+128,y+352,16,c.textSecondary,{weight="semibold"})
      D.text(runtime,m,"DATOS",ix,y+380,16,c.textSecondary,{weight="semibold"});D.text(runtime,m,"— BLOQUEADO",ix+128,y+380,16,c.textSecondary,{weight="semibold"})
      D.text(runtime,m,"HÁBITAT",ix,y+408,16,c.textSecondary,{weight="semibold"});D.text(runtime,m,"— BLOQUEADO",ix+128,y+408,16,c.textSecondary,{weight="semibold"})
      D.line(m,x+140,y+456,x+w-140,y+456,c.border,1)
      D.text(runtime,m,"SE REQUIERE HABER VISTO ESTA ESPECIE PARA ACCEDER A LA ENTRADA",x+80,y+472,14,c.textSecondary,{weight="semibold",tracking=.3,width=w-160,align="center"})
      return
    end
    drawSprite(m,sprite(game,s.species,s.mon,s.artKind),x+140,y+104,w-280,360,256)
    local entry=def.dexEntry or {};local kind=clean(entry.kind or entry.classification):upper()
    D.text(runtime,m,"REGISTRO DE ESPECIE",x+120,y+498,11,c.textSecondary,{weight="bold",tracking=1,width=w-240,align="center"})
    D.text(runtime,m,clean(runtime.PokemonName(def.name,s.species,def,false)):upper(),x+120,y+530,48,c.text,{weight="bold",tracking=-1,width=w-240,align="center"})
    local types=def.types or {};local tokenCount=#types;local kindW=kind~="" and 212 or 0
    local total=tokenCount*148+math.max(0,tokenCount-1)*12+(tokenCount>0 and kindW>0 and 20 or 0)+kindW
    local tx=x+(w-total)/2
    for _,value in ipairs(types) do typeToken(m,c,value,tx,y+594);tx=tx+160 end
    if kind~="" then D.text(runtime,m,kind.." POKÉMON",tx+(tokenCount>0 and 8 or 0),y+602,16,c.textSecondary,{weight="medium",tracking=.1,width=kindW}) end
    D.line(m,x+120,y+646,x+w-120,y+646,c.border,1)
    local record=s.status=="caught" and "REGISTRO COMPLETO  •  DATOS Y HÁBITAT DISPONIBLES" or "AVISTADO  •  CAPTURA REQUERIDA PARA DATOS COMPLETOS"
    D.text(runtime,m,record,x+120,y+662,14,c.textSecondary,{weight="semibold",tracking=.3,width=w-240,align="center"})
  end

  local function drawIndex(game,m,c,s)
    shell(game,m,c,"index",s.status)
    drawLedger(game,m,c,s)
    drawHero(game,m,c,s,858,174,760,680)
    footer(m,c,"index",s.status,false)
  end

  local function dexEntryText(game,entry)
    if type(entry)~="table" then return nil end
    local value=entry.text or entry.description or entry.entry
    if type(value)=="string" and game.data and game.data.text and game.data.text[value] then value=game.data.text[value] end
    if type(value)~="string" then return nil end
    return clean(value)
  end

  local function measurement(entry,kind)
    if not entry then return "—" end
    if kind=="height" then
      local feet=tonumber(entry.heightFt);local inches=tonumber(entry.heightIn) or 0;local meters=tonumber(entry.heightM)
      if not meters and feet then meters=(feet*12+inches)*0.0254 end
      if feet then return ("%d' %02d\"  /  %.1f m"):format(feet,inches,meters or 0) end
      if meters then return ("%.1f m"):format(meters) end
    else
      local pounds,kg
      if tonumber(entry.weightKg) then kg=tonumber(entry.weightKg);pounds=kg*2.2046226218
      elseif tonumber(entry.weight) then pounds=tonumber(entry.weight)/10;kg=pounds*0.45359237 end
      if pounds then return ("%.1f lb  /  %.1f kg"):format(pounds,kg) end
    end
    return "—"
  end

  local function starterFooter(m,c)
    local D=runtime.Draw
    D.roundRect(m,"fill",0,1016,1920,64,0,c.inverse)
    D.text(runtime,m,"A",32,1037,13,c.textInverse,{weight="bold"})
    D.text(runtime,m,"CONTINUAR",60,1038,12,c.faint,{weight="medium",tracking=.4})
    D.text(runtime,m,"B",180,1037,13,c.textInverse,{weight="bold"})
    D.text(runtime,m,"CERRAR",208,1038,12,c.faint,{weight="medium",tracking=.4})
    D.text(runtime,m,"POKÉMON INICIAL",1640,1037,13,c.textInverse,{weight="semibold",width=248,align="right"})
  end

  local function drawData(game,m,c,s,starterPreview)
    shell(game,m,c,"data",s.status)
    local def=s.entry and s.entry.def;if not def then return end
    drawHero(game,m,c,s,48,170,760,680)
    local D=runtime.Draw;local e=def.dexEntry or {};local owned=s.status=="caught";local types=def.types or {}
    local kind=clean(e.kind or e.classification):upper();local x,y,w,h=824,136,1032,760
    D.panel(m,x,y,w,h,16,c.panel,c.borderStrong)
    D.text(runtime,m,("REGISTRO DE CAMPO  •  ENTRADA Nº %03d"):format(s.index),x+40,y+31,11,c.textSecondary,{weight="bold",tracking=1})
    if owned then marker(m,x+w-84,y+78,5,"fill",c.textSecondary);D.text(runtime,m,"REGISTRO COMPLETO",x+w-200,y+69,14,c.textSecondary,{weight="semibold",tracking=.3,width=160,align="right"}) end
    D.text(runtime,m,"DATOS DE LA ESPECIE",x+40,y+59,32,c.text,{weight="bold",tracking=-.5})
    local primary=tostring(types[1] or ""):upper();D.roundRect(m,"fill",x+40,y+114,140,4,2,(c.typeColors and c.typeColors[primary]) or c.focus)
    D.text(runtime,m,"CATEGORÍA",x+40,y+151,11,c.textSecondary,{weight="bold",tracking=1})
    D.text(runtime,m,(kind~="" and kind or "POKÉMON").." POKÉMON",x+40,y+179,20,c.text,{weight="semibold",tracking=.1})
    D.line(m,x+40,y+224,x+w-40,y+224,c.border,1)
    D.text(runtime,m,"MEDIDAS",x+40,y+251,11,c.text,{weight="bold",tracking=1})
    D.text(runtime,m,"ALTURA",x+40,y+279,11,c.textSecondary,{weight="bold",tracking=1})
    D.text(runtime,m,owned and measurement(e,"height") or "— NO REGISTRADO",x+40,y+307,20,c.text,{weight="semibold",tracking=.1,width=440})
    D.line(m,x+40,y+348,x+480,y+348,c.border,1)
    D.text(runtime,m,"PESO",x+552,y+279,11,c.textSecondary,{weight="bold",tracking=1})
    D.text(runtime,m,owned and measurement(e,"weight") or "— NO REGISTRADO",x+552,y+307,20,c.text,{weight="semibold",tracking=.1,width=440})
    D.line(m,x+552,y+348,x+992,y+348,c.border,1)
    D.text(runtime,m,"DESCRIPCIÓN",x+40,y+395,11,c.text,{weight="bold",tracking=1})
    D.text(runtime,m,"ENTRADA DE LA POKÉDEX",x+40,y+423,20,c.text,{weight="semibold",tracking=.1})
    local note=owned and dexEntryText(game,e) or nil
    if note then D.text(runtime,m,note,x+40,y+467,16,c.text,{weight="medium",tracking=.1,width=880})
    else D.text(runtime,m,"— NO REGISTRADO",x+40,y+467,16,c.textSecondary,{weight="semibold"});D.text(runtime,m,"Captura esta especie para desbloquear la descripción y medidas completas.",x+40,y+503,14,c.textSecondary,{width=880}) end
    D.line(m,x+40,y+580,x+w-40,y+580,c.border,1)
    if starterPreview then starterFooter(m,c) else footer(m,c,"data",s.status,false) end
  end

  local mapImage
  local function map()
    if mapImage~=nil then return mapImage or nil end
    local ok,value=pcall(love.graphics.newImage,runtime.assetPath("assets/map/kanto_fullscreen_16x9.png"))
    mapImage=ok and value or false;if mapImage and mapImage.setFilter then mapImage:setFilter("linear","linear") end
    return mapImage or nil
  end

  local AREA_ANCHORS={
    ["VIRIDIAN FOREST"]={366,394},["POWER PLANT"]={1074,326},["PEWTER CITY"]={350,336},
    ["CERULEAN CITY"]={830,282},["LAVENDER TOWN"]={1034,552},["CELADON CITY"]={652,590},
    ["SAFFRON CITY"]={960,520},["VERMILION CITY"]={1130,710},["FUCHSIA CITY"]={930,820},
    ["VIRIDIAN CITY"]={540,650},["PALLET TOWN"]={470,805},["CINNABAR ISLAND"]={340,900},["INDIGO PLATEAU"]={410,150},
  }
  local function areaPoint(location)
    local name=clean(location and (location.name or location.mapId) or "KANTO"):upper();local point=AREA_ANCHORS[name]
    if point then return point[1],point[2] end
    if location and tonumber(location.x) and tonumber(location.y) then return 170+tonumber(location.x)*62,150+tonumber(location.y)*47 end
  end

  local CITY_POIS={
    {name="CIUDAD PLATEADA",x=210,y=306,symbol="◆"},{name="CIUDAD CELESTE",x=690,y=252,symbol="●",focused=true},
    {name="PUEBLO LAVANDA",x=894,y=522,symbol="◇"},{name="CIUDAD AZULONA",x=512,y=560,symbol="■"},
  }
  local function drawCityPois(m,c,s)
    local D=runtime.Draw
    for _,poi in ipairs(CITY_POIS) do
      local px,py=s:areaMapPoint(poi.x,poi.y)
      D.panel(m,px,py,280,60,10,c.panel,poi.focused and c.focus or c.border)
      if poi.focused then D.roundRect(m,"line",px,py,280,60,10,c.focus,3) end
      D.roundRect(m,"fill",px+12,py+10,40,40,8,{205/255,31/255,25/255,1})
      D.text(runtime,m,poi.symbol,px+12,py+18,18,c.textInverse,{weight="bold",width=40,align="center"})
      D.text(runtime,m,poi.name,px+64,py+20,14,c.text,{weight="semibold",tracking=.3})
    end
  end

  local function drawArea(game,m,c,s)
    local D=runtime.Draw
    shell(game,m,c,"area",s.status)
    local image=map();if image then
      local iw,ih=image:getDimensions();local ox,oy,ow,oh=love.graphics.getScissor()
      local view=s:areaViewport()
      love.graphics.setScissor(m.ox+view.x*m.scale,m.oy+view.y*m.scale,view.w*m.scale,view.h*m.scale)
      love.graphics.setColor(1,1,1,1);love.graphics.draw(image,m.ox+s.areaPanX*m.scale,m.oy+s.areaPanY*m.scale,0,1920*m.scale/iw*s.areaScale,1080*m.scale/ih*s.areaScale)
      drawCityPois(m,c,s)
      local nests=s.area and s.area.nests or {};local selected=math.max(1,math.min(#nests,tonumber(s.areaIndex) or 1))
      local dexIcon=icon(game,s.species)
      for i,location in ipairs(nests) do
        local ax,ay=areaPoint(location);local px,py
        if ax then px,py=s:areaMapPoint(ax,ay) end
        if px and py then
          D.roundRect(m,"fill",px-22,py-22,44,44,22,c.inverse);D.roundRect(m,"line",px-22,py-22,44,44,22,i==selected and c.focus or c.inverse,3)
          if not drawIcon(m,dexIcon,px,py,30) then marker(m,px,py,7,"fill",c.focus) end
        end
      end
      if ox then love.graphics.setScissor(ox,oy,ow,oh) else love.graphics.setScissor() end
    end
    local nests=s.area and s.area.nests or {};local selected=math.max(1,math.min(#nests,tonumber(s.areaIndex) or 1))
    local dexIcon=icon(game,s.species)
    -- The information card owns the complete right column between the shared
    -- header and footer. Keep the map viewport unchanged on the left.
    local x,y,w,h=1312,88,608,928
    -- It is flush with the shared header, footer and right edge. An outer
    -- radius exposes the map through its left corners, so only the nested
    -- information cards keep rounded corners.
    D.panel(m,x,y,w,h,0,c.panel,c.borderStrong)
    D.panel(m,x+32,y+32,544,132,14,c.panel,c.border)
    D.roundRect(m,"fill",x+32,y+32,120,132,14,c.inverse)
    D.roundRect(m,"fill",x+142,y+32,20,132,0,c.panel)
    D.text(runtime,m,("№ %03d"):format(s.index),x+32,y+82,24,c.textInverse,{weight="bold",tracking=-.25,width=120,align="center"})
    drawIcon(m,dexIcon,x+190,y+98,48)
    local def=s.entry and s.entry.def;local types=def and def.types or {}
    D.text(runtime,m,def and clean(runtime.PokemonName(def.name,s.species,def,false)):upper() or "DESCONOCIDO",x+238,y+52,18,c.text,{weight="semibold",tracking=.1})
    local primary=tostring(types[1] or "UNKNOWN"):upper();runtime.TypeIcon.draw(primary,m.ox+(x+254)*m.scale,m.oy+(y+100)*m.scale,32*m.scale,(c.typeColors and c.typeColors[primary]) or c.focus)
    drawKnowledge(m,c,s.status,x+282,y+89,130,true)
    D.text(runtime,m,"UBICACIÓN DE LA ESPECIE",x+32,y+188,11,c.textSecondary,{weight="bold",tracking=1})
    D.text(runtime,m,"HÁBITATS CONOCIDOS",x+32,y+216,24,c.text,{weight="bold",tracking=-.25})
    D.text(runtime,m,("%d ZONAS REGISTRADAS"):format(#nests),x+32,y+254,14,c.textSecondary,{weight="semibold",tracking=.3})
    runtime.pokedexAreaRects={}
    if #nests==0 then D.text(runtime,m,"HÁBITAT DESCONOCIDO",x+32,y+310,16,c.textSecondary,{weight="semibold"}) end
    for i,location in ipairs(nests) do
      if i>6 then break end
      local row={x=x+32,y=y+298+(i-1)*84,w=512,h=68};runtime.pokedexAreaRects[i]=row
      D.panel(m,row.x,row.y,row.w,row.h,10,c.panel,i==selected and c.focus or c.border)
      if i==selected then D.roundRect(m,"line",row.x,row.y,row.w,row.h,10,c.focus,3) end
      D.text(runtime,m,clean(location.name or location.mapId or "KANTO"):upper(),row.x+16,row.y+12,18,c.text,{weight="semibold",tracking=.1})
      D.text(runtime,m,"HÁBITAT CONOCIDO",row.x+16,row.y+40,14,c.textSecondary,{weight="semibold",tracking=.3})
    end
    footer(m,c,"area",s.status,false)
  end

  local function drawOakModal(m,c,s)
    local D=runtime.Draw
    D.roundRect(m,"fill",0,88,1920,928,0,{0,0,0,.4})
    D.roundRect(m,"fill",594,274,732,532,12,{0,0,0,.24})
    local x,y,w,h=600,280,720,520
    D.panel(m,x,y,w,h,8,c.elevated or c.panel,c.text)
    D.roundRect(m,"line",x,y,w,h,8,c.text,2)
    D.text(runtime,m,"EVALUACIÓN DE LA POKÉDEX",x+42,y+32,11,c.textSecondary,{weight="bold",tracking=1})
    D.text(runtime,m,"EVALUACIÓN DEL PROF. OAK",x+42,y+64,28,c.text,{weight="black",tracking=-.5})
    D.line(m,x+42,y+120,x+w-42,y+120,c.border,1)
    D.text(runtime,m,("%03d / %03d"):format(s.seen,s.max),x+42,y+140,32,c.text,{weight="black",tracking=-.5})
    D.text(runtime,m,"POKÉMON VISTOS",x+42,y+184,11,c.textSecondary,{weight="bold",tracking=1})
    D.text(runtime,m,("%03d / %03d"):format(s.caught,s.max),x+266,y+140,32,c.text,{weight="black",tracking=-.5})
    D.text(runtime,m,"POKÉMON ATRAPADOS",x+266,y+184,11,c.textSecondary,{weight="bold",tracking=1})
    D.line(m,x+42,y+232,x+w-42,y+232,c.border,1)
    D.text(runtime,m,"VALORACIÓN DEL PROF. OAK:",x+42,y+252,11,c.textSecondary,{weight="bold",tracking=1})
    D.text(runtime,m,"¡SIGUE ASÍ!",x+42,y+288,36,c.text,{weight="black",tracking=-.5})
    D.text(runtime,m,clean(s.oakText or "¡Tu POKÉDEX va progresando muy bien! ¡Sigue con el buen trabajo!"),x+42,y+350,14,c.textSecondary,{weight="regular",width=w-84})
    D.line(m,x+42,y+400,x+w-42,y+400,c.border,1)
    D.text(runtime,m,"Pulsa ENTER para cerrar o A para volver.",x+42,y+420,12,c.textSecondary,{weight="regular",tracking=.4})
    footer(m,c,s.view,s.status,true)
  end

  local function isNativeEntry(state)
    return okDexEntry and DexEntryMenu and state and getmetatable(state)==DexEntryMenu and type(state.def)=="table"
  end

  local function nativeEntryState(game,state)
    local def=state.def;local species=def.id or def.species
    local status=state.forceOwned and "caught" or entryStatus(game,species)
    local value=nativeEntryCache[state]
    if not value or value.species~=species then
      value={kind="krs_native_dex_entry",view="data",mon={species=species},artKind="starter_preview"}
      nativeEntryCache[state]=value
    end
    value.index=tonumber(def.dex) or 0
    value.species=species;value.status=status;value.entry={id=species,def=def}
    return value
  end

  function P.handles(game,state)
    return state and (state.kind=="krs_pokedex" or isNativeEntry(state)) or false
  end

  function P.draw(game,viewport)
    local s=game and game.stack and game.stack:top()
    if not (P.handles(game,s) and runtime.Layout.isWide(viewport)) then return false end
    local m=runtime.Layout.metrics(viewport);local c=runtime.Theme.resolveAll(runtime,game)
    love.graphics.push("all");love.graphics.origin()
    local ok,err=pcall(function()
      if isNativeEntry(s) then drawData(game,m,c,nativeEntryState(game,s),true)
      elseif s.view=="index" then drawIndex(game,m,c,s)
      elseif s.view=="data" then drawData(game,m,c,s)
      else drawArea(game,m,c,s) end
      if s.oakOpen then drawOakModal(m,c,s) end
    end)
    love.graphics.pop()
    if not ok then return nil,err end
    return true
  end

  -- Private regression seam: verifies stable preview identity without
  -- exposing or replacing native DexEntryMenu lifecycle ownership.
  P._nativeEntryState=nativeEntryState

  return P
end
