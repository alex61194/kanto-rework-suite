-- Kanto Journal battle presentation for Wide 16:9.
-- BattleState keeps combat rules, queues, callbacks and turn ownership.
-- KRS owns the Wide presentation, Figma geometry and pointer semantics only.
return function(runtime)
  local BattleState=require('src.battle.BattleState')
  local Growth=require('src.pokemon.Growth')
  local Stats=require('src.pokemon.Stats')
  local NativeFont=require('src.render.Font')
  local ChoiceBox=require('src.ui.ChoiceBox')
  local BattleBackgrounds=assert(runtime.BattleBackgrounds,'battle background resolver required')
  local P={}
  local barAnim=setmetatable({},{__mode='k'})
  local hudFlow=setmetatable({},{__mode='k'})
  local BATTLE_ART_SLOT=380
  local POKEMON_BATTLE_SIZE=BATTLE_ART_SLOT
  -- Terminal fallback only. Canonical KRS backgrounds now expose their own
  -- 1920x950 ground-contact anchors through BattleBackgrounds.groundAnchors().
  -- Pokémon are bottom-centred on those authored circle centres; Voxel-owned
  -- or unknown backgrounds retain the previous global contact points.
  local FALLBACK_PLAYER_GROUND={x=630,y=790}
  local FALLBACK_ENEMY_GROUND={x=1400,y=570}

  local function isBattle(s) return s and getmetatable(s)==BattleState end
  local function isStatBox(s) return s and BattleState.StatBox and getmetatable(s)==BattleState.StatBox end
  local function isChoiceBox(s) return s and getmetatable(s)==ChoiceBox end
  local function battleContext(game)
    local stack=game and game.stack
    local states=stack and stack.states or {}
    local top=stack and type(stack.top)=='function' and stack:top() or states[#states]
    local battle,battleIndex
    for i=#states,1,-1 do
      if isBattle(states[i]) then battle,battleIndex=states[i],i;break end
    end
    if not battle and isBattle(top) then battle,battleIndex=top,#states end
    if not battle then return nil,top,nil,nil end
    -- Only an overlay pushed DIRECTLY by BattleState belongs to this surface.
    -- A ChoiceBox inside Party/PC/etc may still have a battle deeper in the
    -- stack and must remain owned by that intervening screen.
    local direct=states[battleIndex+1]
    local stat=(top==direct and isStatBox(top)) and top or nil
    local choice=(top==direct and isChoiceBox(top)) and top or nil
    return battle,top,stat,choice
  end
  local function presentationActive(game) local b=select(1,battleContext(game));return b~=nil end
  local function interactive(game)
    local b,top,stat,choice=battleContext(game)
    if not b then return false end
    return stat~=nil or choice~=nil or b.phase=='menu' or b.phase=='moveSelect'
  end
  local function rgba(a,b,c,d) return {a,b,c,d or 1} end
  local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
  local function circleLogical(m,mode,x,y,r,color,width)
    local g=love.graphics;g.setColor(color);if width then g.setLineWidth(math.max(1,width*m.scale)) end
    g.circle(mode,m.ox+x*m.scale,m.oy+y*m.scale,r*m.scale)
  end
  local function fitImageScale(m,img,cx,cy,scale)
    if not img then return end
    if img.setFilter then pcall(img.setFilter,img,'nearest','nearest') end
    local iw,ih=img:getDimensions();if not iw or iw<=0 or not ih or ih<=0 then return end
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(img,m.ox+cx*m.scale-iw*scale/2,m.oy+cy*m.scale-ih*scale/2,0,scale,scale)
  end
  local function compatExports()
    local h=runtime.mod and runtime.mod.find and runtime.mod.find('compatibility') or nil
    return h and h.exports or nil
  end
  local function visualsExports()
    local h=runtime.mod and runtime.mod.find and runtime.mod.find('graphics') or nil
    return h and h.exports or nil
  end
  local function battleArtMetrics(img)
    local ex=compatExports()
    if ex and type(ex.battleArtMetrics)=='function' then
      local ok,value=pcall(ex.battleArtMetrics,img)
      if ok and type(value)=='table' then return value end
    end
  end
  local function battlePresentation(game)
    -- Graphics is the first-party authority for battle-only scale/Real Size.
    -- Compatibility's Voxel presentation contract remains a legacy fallback
    -- for older package mixes, never the primary setting source.
    local vx=visualsExports()
    if vx and type(vx.battlePresentation)=='function' then
      local ok,value=pcall(vx.battlePresentation,game)
      if ok and type(value)=='table' then value._owner='krs_graphics';return value end
    end
    local ex=compatExports()
    if ex and type(ex.voxelBattleArtPresentation)=='function' then
      local ok,value=pcall(ex.voxelBattleArtPresentation,game)
      if ok and type(value)=='table' then value._owner='legacy_voxel';return value end
    end
    return {upscale='default',pixelScale=1,realSize='auto',nativePixels=true,_owner='none'}
  end
  local function battleBackgroundsEnabled()
    local vx=visualsExports()
    if vx and type(vx.battleBackgroundsEnabled)=='function' then
      local ok,value=pcall(vx.battleBackgroundsEnabled)
      if ok then return value~=false end
    end
    return true
  end
  local function fitImageBox(m,img,x,y,w,h,metric,offsetY,clip,alpha,visualScale,frameAnchor,mirrorX)
    if not img then return end
    if img.setFilter then pcall(img.setFilter,img,'nearest','nearest') end
    local iw,ih=img:getDimensions();if not iw or iw<=0 or not ih or ih<=0 then return end
    metric=metric or battleArtMetrics(img)
    local x0=clamp(tonumber(metric and metric.x0) or 0,0,iw-1)
    local x1=clamp(tonumber(metric and metric.x1) or (iw-1),x0,iw-1)
    local y0=clamp(tonumber(metric and metric.y0) or 0,0,ih-1)
    local y1=clamp(tonumber(metric and metric.y1) or (ih-1),y0,ih-1)
    -- Animated Battle Art frames have intentionally different opaque bounds.
    -- Scaling each frame from x0/x1/y0/y1 makes a breathing/flapping sprite
    -- visibly pump in size. The authored cell canvas is stable for the whole
    -- sequence; use that for scale, then use Voxel's shared center/y1 anchor
    -- only for placement. This preserves authored motion while front/back both
    -- live in the same 380x380 KRS slot.
    local canvasW=math.max(1,tonumber(metric and metric.w) or iw)
    local canvasH=math.max(1,tonumber(metric and metric.h) or ih)
    -- `visualScale` is a bounded species-size correction layered on top of
    -- the provider's authored-cell fit. It never changes the source art or
    -- animation metrics; bottom-centre anchoring below keeps feet/body contact
    -- fixed on the battle circle while only the perceived body size changes.
    local k=math.min(w*m.scale/canvasW,h*m.scale/canvasH)*(tonumber(visualScale) or 1)
    -- Pokémon are grounded by the bottom-centre of the authored FRAME/CELL,
    -- not by the last opaque pixel. That makes the placement independent from
    -- transparent padding and keeps every animation frame tied to one stable
    -- battle-circle contact point. Non-Pokémon art retains Voxel's own opaque
    -- anchor semantics.
    local center=frameAnchor and (canvasW/2) or (tonumber(metric and metric.center) or (canvasW/2))
    local bottom=frameAnchor and canvasH or (y1+1)
    local px=m.ox+(x+w/2)*m.scale-center*k
    local py=m.oy+(y+h)*m.scale-bottom*k+(tonumber(offsetY) or 0)*m.scale
    if clip and love.graphics.setScissor then
      love.graphics.setScissor(m.ox+x*m.scale,m.oy+y*m.scale,w*m.scale,h*m.scale)
    end
    love.graphics.setColor(1,1,1,tonumber(alpha) or 1)
    if mirrorX then love.graphics.draw(img,px+iw*k,py,0,-k,k) else love.graphics.draw(img,px,py,0,k,k) end
    if clip and love.graphics.setScissor then love.graphics.setScissor() end
    return k,canvasW,canvasH
  end
  local function normalizeType(value)
    local tt=tostring(value or 'NORMAL'):upper()
    if tt=='PSYCH_TYPE' or tt=='PSYCHIC_TYPE' or tt=='PSYCH' then return 'PSYCHIC' end
    tt=tt:gsub('_TYPE$','')
    if tt=='PSYCH' then tt='PSYCHIC' end
    return tt~='' and tt or 'NORMAL'
  end
  local function typeColor(c,t)
    local tt=normalizeType(t)
    return c.typeColors and c.typeColors[tt] or c.focus
  end
  local function pill(D,m,c,label,x,y,w,fill)
    D.roundRect(m,'fill',x,y,w,24,12,fill or c.inverse)
    D.text(runtime,m,tostring(label or '—'):upper(),x,y+4,12,c.textInverse,{weight='semibold',width=w,align='center'})
  end
  local function statusIcon(m,c,b,cx,cy)
    local mon=b and b.mon;if not mon then return false end
    -- shownStatus follows the battle's Gen 1 reveal/synchronisation timing.
    -- Falling back to the party status only covers non-standard battlers.
    local status=b.shownStatus or mon.status
    if not status then return false end
    return runtime.StatusToken and runtime.StatusToken.drawIcon(status,mon.hp,
      m.ox+cx*m.scale,m.oy+cy*m.scale,32*m.scale,c,1) or false
  end
  local function typeIcon(m,c,typ,cx,cy,size)
    if runtime.TypeIcon then
      return runtime.TypeIcon.draw(normalizeType(typ),m.ox+cx*m.scale,m.oy+cy*m.scale,(size or 32)*m.scale,typeColor(c,typ),1)
    end
  end
  local function shownHp(b)
    local mon=b and b.mon
    local hp=tonumber(b and b.shownHP)
    if hp==nil then hp=tonumber(mon and mon.hp) or 0 end
    local max=tonumber(b and b.curStats and b.curStats.hp or mon and mon.stats and mon.stats.hp) or math.max(1,hp)
    return math.max(0,hp),math.max(1,max)
  end
  local smoothRatio
  local function battleLogicSpeed(game)
    if game and type(game.logicSpeed)=='function' then
      local ok,value=pcall(game.logicSpeed,game)
      value=ok and tonumber(value) or nil
      if value and value==value and value>0 then return clamp(value,.1,100) end
    end
    return 1
  end
  local function rightText(D,m,text,right,y,size,color,weight)
    local font=D.font(runtime,m,size,weight)
    local width=(font and font.getWidth and font:getWidth(tostring(text or '')) or 0)/(m.scale>0 and m.scale or 1)
    D.text(runtime,m,text,right-width,y,size,color,{weight=weight})
  end
  local function hpBar(D,m,c,game,b,x,y,w,standard)
    local hp,max=shownHp(b);local target=clamp(hp/max,0,1);local r=smoothRatio(b,'hp',target,battleLogicSpeed(game))
    local labelSize=standard and 15 or 13;local valueSize=standard and 14 or 12
    -- Exact Figma component geometry: Standard track y=36/h=16; Compact
    -- track y=20/h=12. Keep value text single-line instead of printf-wrap.
    local trackY=standard and 36 or 20;local trackH=standard and 16 or 12
    D.text(runtime,m,'PS',x,y,labelSize,c.text,{weight='semibold'})
    rightText(D,m,('%d / %d'):format(hp,max),x+w,y,valueSize,c.text,'semibold')
    D.roundRect(m,'fill',x,y+trackY,w,trackH,trackH/2,c.subtle);D.roundRect(m,'line',x,y+trackY,w,trackH,trackH/2,c.border,1)
    local fill=target<=.2 and c.danger or target<.55 and c.warning or c.success
    if r>0 then D.roundRect(m,'fill',x,y+trackY,math.max(2,w*r),trackH,trackH/2,fill) end
  end
  local function expMetrics(game,b)
    local mon=b and b.mon;if not mon then return 0,0 end
    local def=game and game.data and game.data.pokemon and game.data.pokemon[mon.species]
    if not def then return 0,0 end
    local cap=game.data.constants and game.data.constants.levelCap or 100
    if (tonumber(mon.level) or 1)>=cap then return 1,0 end
    local base=Growth.expForLevel(def.growthRate,mon.level,game.data.growth_rates)
    local nextExp=Growth.expForLevel(def.growthRate,mon.level+1,game.data.growth_rates)
    local span=math.max(1,nextExp-base);local value=tonumber(mon.exp) or base
    return clamp((value-base)/span,0,1),math.max(0,nextExp-value)
  end
  smoothRatio=function(owner,key,target,speed)
    if not owner then return target end
    local bucket=barAnim[owner];if not bucket then bucket={};barAnim[owner]=bucket end
    local now=(love.timer and love.timer.getTime and love.timer.getTime()) or 0
    local rec=bucket[key]
    if not rec then rec={value=target,target=target,from=target,start=now};bucket[key]=rec;return target end
    if math.abs((rec.target or target)-target)>0.0001 then
      rec.from=rec.value or rec.target or target;rec.target=target;rec.start=now
    end
    local t=clamp(((now-(rec.start or now))*(tonumber(speed) or 1))/.42,0,1);local e=t*t*(3-2*t)
    rec.value=(rec.from or target)+((rec.target or target)-(rec.from or target))*e
    if t>=1 then rec.value=target end
    return rec.value
  end
  local TYPE_COLORS = {
    NORMAL = {0.66, 0.65, 0.58, 1}, FIRE = {0.94, 0.40, 0.18, 1}, WATER = {0.26, 0.53, 0.96, 1},
    GRASS = {0.43, 0.75, 0.30, 1}, ELECTRIC = {0.97, 0.78, 0.15, 1}, ICE = {0.45, 0.82, 0.82, 1},
    FIGHTING = {0.75, 0.20, 0.16, 1}, POISON = {0.64, 0.24, 0.63, 1}, GROUND = {0.87, 0.74, 0.39, 1},
    FLYING = {0.65, 0.56, 0.94, 1}, PSYCHIC = {0.96, 0.33, 0.53, 1}, BUG = {0.65, 0.73, 0.12, 1},
    ROCK = {0.72, 0.62, 0.22, 1}, GHOST = {0.44, 0.34, 0.59, 1}, DRAGON = {0.43, 0.21, 0.98, 1},
    STEEL = {0.71, 0.71, 0.81, 1}, DARK = {0.44, 0.34, 0.27, 1}, FAIRY = {0.92, 0.52, 0.64, 1},
  }
  local TYPE_NAMES_ES = {
    NORMAL = "NORMAL", FIRE = "FUEGO", WATER = "AGUA", GRASS = "PLANTA", ELECTRIC = "ELÉCTRICO",
    ICE = "HIELO", FIGHTING = "LUCHA", POISON = "VENENO", GROUND = "TIERRA", FLYING = "VOLADOR",
    PSYCHIC = "PSÍQUICO", BUG = "BICHO", ROCK = "ROCA", GHOST = "FANTASMA", DRAGON = "DRAGÓN",
    STEEL = "ACERO", DARK = "SINIESTRO", FAIRY = "HADA",
  }
  local function isPokemonCaught(game, b)
    local species = b and b.mon and b.mon.species
    if not species then return false end
    local pokedex = game and game.save and game.save.pokedex
    return pokedex and pokedex.owned and (pokedex.owned[species] == true)
  end
  local function drawPixelBallIcon(D, m, x, y, size)
    local s = size or 16
    local cy = y + s / 2
    D.roundRect(m, 'fill', x, y, s, s/2, 2, {0.92, 0.15, 0.20, 1})
    D.roundRect(m, 'fill', x, y + s/2, s, s/2, 2, {1, 1, 1, 1})
    D.roundRect(m, 'line', x, y, s, s, 3, {0.12, 0.08, 0.10, 1}, 1)
    D.line(m, x, cy, x + s, cy, {0.12, 0.08, 0.10, 1}, 1)
    D.roundRect(m, 'fill', x + s/2 - 2, cy - 2, 4, 4, 2, {1, 1, 1, 1})
    D.roundRect(m, 'line', x + s/2 - 2, cy - 2, 4, 4, 2, {0.12, 0.08, 0.10, 1}, 1)
  end
  local function hud(D,m,c,game,b,x,y,w,h,enemy)
    local cardW = 380
    local cardH = enemy and 86 or 108
    local cx = x + (w - cardW) / 2
    local cy = y + (h - cardH) / 2
    
    local name = tostring(b and b.name or 'POKéMON'):upper()
    local lv = tonumber(b and b.mon and b.mon.level) or 0
    local hp, max = shownHp(b)
    local target = clamp(hp / max, 0, 1)
    local r = smoothRatio(b, 'hp', target, battleLogicSpeed(game))
    local caught = enemy and isPokemonCaught(game, b)
    
    -- Fondo pixel art cálido con doble borde biselado estilo GBA Rojo Fuego
    local bgCol = {0.98, 0.98, 0.96, 0.98}
    local borderCol = {0.12, 0.08, 0.10, 1.0}
    local innerHighlight = {1.0, 1.0, 1.0, 0.9}
    
    -- Tarjeta principal con esquinas pixel art de 6px
    D.roundRect(m, 'fill', cx, cy, cardW, cardH, 6, bgCol)
    D.roundRect(m, 'line', cx, cy, cardW, cardH, 6, borderCol, 2)
    D.roundRect(m, 'line', cx + 2, cy + 2, cardW - 4, cardH - 4, 4, innerHighlight, 1)
    
    -- Puntero de bocadillo pixelado apuntando hacia abajo al Pokémon
    local tailX = enemy and (cx + 50) or (cx + cardW - 60)
    local tailY = cy + cardH
    local tailW = 18
    local tailH = 10
    local tailDir = enemy and 1 or -1
    love.graphics.setColor(bgCol[1], bgCol[2], bgCol[3], bgCol[4] or 1)
    love.graphics.polygon('fill',
      m.ox + (tailX - tailW/2) * m.scale, m.oy + tailY * m.scale,
      m.ox + (tailX + tailW/2) * m.scale, m.oy + tailY * m.scale,
      m.ox + (tailX + 8 * tailDir) * m.scale, m.oy + (tailY + tailH) * m.scale
    )
    love.graphics.setColor(borderCol[1], borderCol[2], borderCol[3], borderCol[4] or 1)
    love.graphics.setLineWidth(2 * m.scale)
    love.graphics.line(
      m.ox + (tailX - tailW/2) * m.scale, m.oy + tailY * m.scale,
      m.ox + (tailX + 8 * tailDir) * m.scale, m.oy + (tailY + tailH) * m.scale,
      m.ox + (tailX + tailW/2) * m.scale, m.oy + tailY * m.scale
    )
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Fila Superior: Icono Capturado + Género + Nombre + Insignia Nivel Rojo Fuego
    local curX = cx + 12
    if caught then
      drawPixelBallIcon(D, m, curX, cy + 11, 16)
      curX = curX + 22
    end
    
    local gender = b and b.mon and b.mon.gender or (b and b.mon and ((b.mon.dvs and (b.mon.dvs.atk or 0) >= 8) and 'm' or 'f')) or 'm'
    local genderCol = (gender == 'f') and {0.92, 0.25, 0.45, 1} or {0.12, 0.50, 0.90, 1}
    local genderGlyph = (gender == 'f') and '♀' or '♂'
    D.roundRect(m, 'fill', curX, cy + 9, 20, 20, 4, genderCol)
    D.text(runtime, m, genderGlyph, curX, cy + 9, 13, {1, 1, 1, 1}, {weight = 'bold', width = 20, align = 'center'})
    curX = curX + 26
    
    D.clipText(runtime, m, name, curX, cy + 9, 160, 18, {0.10, 0.08, 0.10, 1}, {weight = 'bold'})
    
    -- Insignia Nivel estilo Rojo Fuego
    local lvText = 'Nv.' .. lv
    local lvW = 54
    local lvX = cx + cardW - lvW - 12
    D.roundRect(m, 'fill', lvX, cy + 9, lvW, 20, 4, {0.95, 0.45, 0.05, 1})
    D.roundRect(m, 'line', lvX, cy + 9, lvW, 20, 4, {0.75, 0.30, 0.00, 1}, 1)
    D.text(runtime, m, lvText, lvX, cy + 9, 13, {1, 1, 1, 1}, {weight = 'bold', width = lvW, align = 'center'})
    
    -- Fila Intermedia: Pastillas de Tipo (NORMAL, VOLADOR, etc.) + Estado alterado
    local typeY = cy + 34
    local types = b and b.curTypes or (b and b.mon and b.mon.species and game and game.data and game.data.pokemon and game.data.pokemon[b.mon.species] and game.data.pokemon[b.mon.species].types) or {'NORMAL'}
    local typeX = cx + 12
    for i = 1, math.min(2, #types) do
      local typ = normalizeType(types[i])
      local col = TYPE_COLORS[typ] or {0.5, 0.5, 0.5, 1}
      local label = TYPE_NAMES_ES[typ] or typ
      local pillW = 72
      D.roundRect(m, 'fill', typeX, typeY, pillW, 16, 3, col)
      D.roundRect(m, 'line', typeX, typeY, pillW, 16, 3, {col[1]*0.7, col[2]*0.7, col[3]*0.7, 1}, 1)
      D.text(runtime, m, label, typeX, typeY - 1, 10, {1, 1, 1, 1}, {weight = 'bold', width = pillW, align = 'center'})
      typeX = typeX + pillW + 6
    end
    statusIcon(m, c, b, cx + cardW - 40, typeY + 8)
    
    -- Fila Inferior: Etiqueta PS + Barra de Vida + Números
    local barX = cx + 42
    local barY = cy + 56
    local barW = cardW - 54
    local barH = 11
    
    D.text(runtime, m, 'PS', cx + 12, barY - 2, 13, {0.95, 0.35, 0.10, 1}, {weight = 'bold'})
    D.roundRect(m, 'fill', barX, barY, barW, barH, 3, {0.86, 0.88, 0.90, 1})
    D.roundRect(m, 'line', barX, barY, barW, barH, 3, {0.45, 0.48, 0.52, 1}, 1)
    local fill = target <= 0.2 and {0.95, 0.20, 0.20, 1} or target < 0.55 and {0.98, 0.70, 0.10, 1} or {0.0, 0.85, 0.40, 1}
    if r > 0 then
      D.roundRect(m, 'fill', barX, barY, math.max(3, barW * r), barH, 3, fill)
    end
    
    if not enemy then
      D.text(runtime, m, ('%d / %d'):format(hp, max), barX, barY + 13, 12, {0.15, 0.12, 0.15, 1}, {weight = 'bold', width = barW, align = 'right'})
      -- Barra de EXP estilo Rojo Fuego
      local ratio, toNext = expMetrics(game, b)
      ratio = smoothRatio(b, 'exp', ratio, battleLogicSpeed(game))
      local expY = cy + 86
      D.text(runtime, m, 'EXP', cx + 12, expY - 3, 10, {0.05, 0.60, 0.85, 1}, {weight = 'bold'})
      D.roundRect(m, 'fill', barX, expY, barW, 5, 2, {0.86, 0.88, 0.90, 1})
      if ratio > 0 then
        D.roundRect(m, 'fill', barX, expY, math.max(2, barW * ratio), 5, 2, {0.0, 0.85, 1.0, 1})
      end
    end
  end
  local PHYSICAL={NORMAL=true,FIGHTING=true,FLYING=true,POISON=true,GROUND=true,ROCK=true,BUG=true,GHOST=true}
  local function resolveText(game,v)
    if type(v)~='string' or v=='' then return nil end
    if game and game.data and game.data.text and game.data.text[v] then return tostring(game.data.text[v]) end
    return v
  end
  local function moveModel(game,mv)
    if not mv then return nil end
    local def=game and game.data and game.data.moves and game.data.moves[mv.id] or {}
    local typ=normalizeType(def.type or mv.type or 'NORMAL')
    local power=tonumber(def.power or mv.power) or 0
    local acc=tonumber(def.accuracy or mv.accuracy)
    local base=tonumber(def.pp) or tonumber(mv.maxPP) or tonumber(mv.pp)
    local ups=math.max(0,tonumber(mv.ppUps) or 0)
    local maxpp=base and (base+ups*math.floor(base/5)) or tonumber(mv.maxPP) or tonumber(mv.pp)
    local explicit=tostring(def.category or def.damageClass or ''):upper()
    local cat
    if explicit~='' then cat=explicit elseif power<=0 then cat='STATUS' else cat=PHYSICAL[typ] and 'PHYSICAL' or 'SPECIAL' end
    local desc
    for _,k in ipairs({'description','desc','summary','effectText','text'}) do desc=resolveText(game,def[k]);if desc and desc~='' then break end end
    if (not desc or desc=='') and runtime.Core and type(runtime.Core.moveDescription)=='function' then
      local ok,v=pcall(runtime.Core.moveDescription,def,mv.id);if ok and type(v)=='string' and v~='' then desc=v end
    end
    desc=desc or 'No move description is exposed by the active data source.'
    return {id=mv.id,name=tostring(def.name or mv.name or mv.id or '—'),type=typ,category=cat,
      power=power,accuracy=acc,pp=tonumber(mv.pp),maxPP=maxpp,description=desc}
  end
  local function compatPolicy(game,battle)
    local ex=compatExports()
    -- Compatibility owns the independent animation clock when Voxel 3D-BTL
    -- is off; passing 0 means "derive real frame delta" rather than freeze.
    if ex and type(ex.prepareBattleArt)=='function' then pcall(ex.prepareBattleArt,battle,0) end
    if ex and type(ex.battleVisualPolicy)=='function' then
      local ok,v=pcall(ex.battleVisualPolicy,game,battle);if ok and type(v)=='table' then return v end
    end
    return {backgroundOwner='krs'}
  end
  local function backdropKind(game,s) return BattleBackgrounds.resolve(game,s) end
  local function normalizedBackdropTransform(config)
    config=type(config)=='table' and config or {}
    local scale=clamp(tonumber(config.scale) or 100,100,140)/100
    return {scale=scale,offsetX=clamp(tonumber(config.offsetX) or 0,-320,320),offsetY=clamp(tonumber(config.offsetY) or 0,-180,180)}
  end
  local function transformBackdropPoint(point,config)
    if not point then return nil end
    local t=normalizedBackdropTransform(config);local ox=(1920-1920*t.scale)/2+t.offsetX;local oy=(950-950*t.scale)/2+t.offsetY
    return {x=ox+(point.x or point[1] or 0)*t.scale,y=oy+(point.y or point[2] or 0)*t.scale}
  end
  local function drawBackdrop(D,m,c,backdrop,config)
    backdrop=type(backdrop)=='table' and backdrop or {kind=tostring(backdrop or 'field')}
    local t=normalizedBackdropTransform(config);local dw,dh=1920*t.scale,950*t.scale;local dx=(1920-dw)/2+t.offsetX;local dy=(950-dh)/2+t.offsetY
    if backdrop.file then
      local path=runtime.assetPath and runtime.assetPath('assets/battle/backgrounds/canonical/'..backdrop.file..'.png')
      local image=path and runtime.assets:image(path,'nearest')
      if image then
        local iw,ih=image:getDimensions();love.graphics.setColor(1,1,1,1)
        -- Canonical Figma assets are 1920×950. The final 20 px intentionally
        -- continue under the 64 px footer instead of being vertically crushed.
        love.graphics.setScissor(m.ox,m.oy+86*m.scale,1920*m.scale,950*m.scale);love.graphics.draw(image,m.ox+dx*m.scale,m.oy+(86+dy)*m.scale,0,(dw/iw)*m.scale,(dh/ih)*m.scale);love.graphics.setScissor()
        return
      end
    end
    local kind=backdrop.kind or 'field'
    local background={
      field='grass',grass='grass',forest='forest',cave='cave',water='water',
      oak_lab='oak_lab',route='route',city='city',
      gym_pewter='gym_pewter',gym_cerulean='gym_cerulean',gym_vermilion='gym_vermilion',
      gym_celadon='gym_celadon',gym_fuchsia='gym_fuchsia',gym_saffron='gym_saffron',
      gym_cinnabar='gym_cinnabar',gym_viridian='gym_viridian',
    }
    if background[kind] then
      local path=runtime.assetPath and runtime.assetPath('assets/battle/backgrounds/'..background[kind]..'.png')
      local image=path and runtime.assets:image(path,'nearest')
      if image then
        local iw,ih=image:getDimensions();love.graphics.setColor(1,1,1,1)
        love.graphics.setScissor(m.ox,m.oy+86*m.scale,1920*m.scale,950*m.scale);love.graphics.draw(image,m.ox+dx*m.scale,m.oy+(86+dy)*m.scale,0,(dw/iw)*m.scale,(dh/ih)*m.scale);love.graphics.setScissor()
        return
      end
    end
    local top,bottom
    if kind=='grass' then top=rgba(.38,.63,.31);bottom=rgba(.57,.47,.27)
    elseif kind=='water' then top=rgba(.30,.62,.70);bottom=rgba(.20,.48,.61)
    elseif kind=='cave' then top=rgba(.30,.31,.30);bottom=rgba(.40,.34,.28)
    elseif kind=='indoor' then top=rgba(.84,.79,.66);bottom=rgba(.49,.42,.34)
    else top=rgba(.42,.64,.34);bottom=rgba(.59,.49,.29) end
    D.roundRect(m,'fill',0,86,1920,930,0,top);D.roundRect(m,'fill',0,610,1920,406,0,bottom)
  end
  local partyBallCache
  local function partyBallImage(state)
    partyBallCache=partyBallCache or {}
    if partyBallCache[state]~=nil then return partyBallCache[state] or nil end
    local path=runtime.assetPath and runtime.assetPath('assets/runtime/party_balls/'..state..'.png')
    local image=path and runtime.assets:image(path,'nearest') or nil;partyBallCache[state]=image or false;return image
  end
  local function ball(m,c,px,py,mon)
    if mon then
      local state=(tonumber(mon.hp) or 0)<=0 and 'ko' or mon.status and 'status' or 'normal'
      local image=partyBallImage(state)
      if image then local iw,ih=image:getDimensions();local k=20*m.scale/math.max(iw,ih);love.graphics.setColor(1,1,1,1);love.graphics.draw(image,m.ox+px*m.scale-10*m.scale,m.oy+py*m.scale-10*m.scale,0,k,k);return end
    end
    circleLogical(m,'line',px,py,10,c.faint,1.5)
  end
  local function fittingTextSize(D,m,text,maxWidth,startSize,minSize,weight)
    text=tostring(text or '')
    for size=startSize,minSize,-1 do
      local font=D.font(runtime,m,size,weight or 'bold')
      local ok,w=pcall(font.getWidth,font,text)
      if ok and (tonumber(w) or math.huge)<=maxWidth*m.scale then return size end
    end
    return minSize
  end
  local function teamRow(m,c,label,party,x,y,labelAfter)
    local D=runtime.Draw;label=tostring(label or ''):upper()
    if labelAfter then
      for i=1,6 do ball(m,c,x+10+(i-1)*24,y,party and party[i] or nil) end
      -- The opponent identity owns the complete span between party balls and the
      -- right-side location block. Never hide a legal trainer class/name behind
      -- an ellipsis: use the real width first, then reduce typography within a
      -- controlled 18→12 px range. A two-line fallback remains inside the 86 px
      -- global header if an extension supplies a still longer label.
      local tx,maxW=x+156,math.max(160,1548-(x+156))
      local size=fittingTextSize(D,m,label,maxW,18,12,'bold')
      local font=D.font(runtime,m,size,'bold');local ok,w=pcall(font.getWidth,font,label)
      if ok and (tonumber(w) or 0)<=maxW*m.scale then
        D.text(runtime,m,label,tx,y-size*.62,size,c.textInverse,{weight='bold',width=maxW})
      else
        D.text(runtime,m,label,tx,12,size,c.textInverse,{weight='bold',width=maxW})
      end
    else
      local maxW=90;local size=fittingTextSize(D,m,label,maxW,18,12,'bold')
      D.text(runtime,m,label,x,y-size*.62,size,c.textInverse,{weight='bold',width=maxW})
      for i=1,6 do ball(m,c,x+97+(i-1)*24,y,party and party[i] or nil) end
    end
  end
  local function opponentName(game,s)
    if runtime.CharacterNames and type(runtime.CharacterNames.battleOpponent)=='function' then
      local ok,value=pcall(runtime.CharacterNames.battleOpponent,game,s)
      if ok and type(value)=='string' and value~='' then return value end
    end
    if s and s.kind=='trainer' and s.trainer and s.trainer.name then return s.trainer.name end
    return s and s.enemy and (s.enemy.name or (s.enemy.mon and s.enemy.mon.nickname)) or 'POKéMON'
  end
  local function playerName(game)
    return game and game.save and game.save.player and game.save.player.name or 'PLAYER'
  end
  local function shell(D,m,c,game,s)
    D.roundRect(m,'fill',0,0,1920,86,0,c.inverse)
    D.text(runtime,m,'KANTO JOURNAL',32,16,24,c.textInverse,{weight='bold'})
    local jc=runtime.Core.journalContext and runtime.Core.journalContext() or {}
    D.text(runtime,m,tostring(jc.location or 'KANTO'):gsub('_',' '):upper(),1570,16,14,c.textInverse,{weight='semibold',width=318,align='right'})
    local world=tostring(jc.worldTime or jc.time or '')
    if world=='' then local bg=backdropKind(game,s);world=tostring(bg.mapId~='' and bg.mapId or bg.kind):gsub('_',' '):upper() end
    D.text(runtime,m,world,1570,48,12,c.faint,{weight='medium',width=318,align='right'})
    if s.kind=='trainer' or s.kind=='link' then
      local opp=s.enemyParty or {s.enemy and s.enemy.mon or nil}
      teamRow(m,c,opponentName(game,s),opp,832,43,true)
    else
      -- Wild encounters have no trainer party. Keep the opponent identity but
      -- deliberately omit the six team balls instead of inventing a party.
      local wild=tostring(opponentName(game,s)):upper();local maxW=716
      local size=fittingTextSize(D,m,wild,maxW,18,12,'bold')
      D.text(runtime,m,wild,832,32,size,c.textInverse,{weight='bold',width=maxW,align='center'})
    end
  end
  local function footer(game,m,c,prompts)
    local D=runtime.Draw;D.roundRect(m,'fill',0,1016,1920,64,0,c.inverse)
    local resolved,label=runtime.Footer.resolve(game,prompts)
    local keyboard=(label=='KEYBOARD + MOUSE')
    if keyboard then
      local keyX={36,199,337,504};local labelX={107,253,373,540}
      for i,p in ipairs(resolved) do if keyX[i] then D.text(runtime,m,p.key,keyX[i],1038,12,c.textInverse,{weight='bold'});D.text(runtime,m,p.label,labelX[i],1038,11,c.faint,{weight='medium'}) end end
    else
      local x=32
      for _,p in ipairs(resolved) do D.text(runtime,m,p.key,x,1037,12,c.textInverse,{weight='bold'});local f=D.font(runtime,m,12,'bold');local kw=f:getWidth(p.key)/m.scale;D.text(runtime,m,p.label,x+kw+9,1038,11,c.faint,{weight='medium'});x=x+math.max(150,kw+110) end
    end
    teamRow(m,c,playerName(game),game and game.save and game.save.party or {},847,1048,false)
    D.text(runtime,m,label,1660,1038,12,c.textInverse,{weight='semibold',width=228,align='right'})
  end
  local commandIconCache={}
  local function commandIcon(m,c,kind,x,y,size,focused)
    local image=commandIconCache[kind]
    if image==nil then
      local path=runtime.assetPath and runtime.assetPath('assets/runtime/battle_actions/'..tostring(kind)..'.png')
      image=path and runtime.assets:image(path,'linear') or nil;commandIconCache[kind]=image or false
    elseif image==false then image=nil end
    if not image then return false end
    local iw,ih=image:getDimensions();local k=math.min(size*m.scale/iw,size*m.scale/ih)
    local col=focused and c.text or c.textInverse
    love.graphics.setColor(col[1],col[2],col[3],col[4] or 1)
    love.graphics.draw(image,m.ox+x*m.scale+(size*m.scale-iw*k)/2,m.oy+y*m.scale+(size*m.scale-ih*k)/2,0,k,k)
    love.graphics.setColor(1,1,1,1);return true
  end
  local COMMAND_THEME_COLORS = {
    fight = { bg = { 0.82, 0.15, 0.20, 0.98 }, hover = { 0.96, 0.22, 0.28, 1.00 }, highlight = { 1.0, 0.45, 0.50, 1 }, shadow = { 0.55, 0.08, 0.12, 1 } },
    pokemon = { bg = { 0.12, 0.62, 0.28, 0.98 }, hover = { 0.16, 0.80, 0.38, 1.00 }, highlight = { 0.40, 0.95, 0.55, 1 }, shadow = { 0.06, 0.40, 0.16, 1 } },
    bag = { bg = { 0.92, 0.48, 0.08, 0.98 }, hover = { 1.00, 0.62, 0.14, 1.00 }, highlight = { 1.00, 0.80, 0.35, 1 }, shadow = { 0.60, 0.28, 0.02, 1 } },
    run = { bg = { 0.12, 0.48, 0.84, 0.98 }, hover = { 0.18, 0.68, 0.98, 1.00 }, highlight = { 0.45, 0.85, 1.00, 1 }, shadow = { 0.06, 0.30, 0.58, 1 } },
  }
  local function commandCard(D,m,c,label,sub,x,y,w,h,focused,icon)
    local themeCol = COMMAND_THEME_COLORS[icon or 'fight']
    local fill = themeCol and (focused and themeCol.hover or themeCol.bg) or (focused and c.subtle or c.inverse)
    local borderCol = { 0.12, 0.08, 0.10, 1.0 }
    
    -- Botón con esquinas pixel art de 6px
    D.roundRect(m, 'fill', x, y, w, h, 6, fill)
    D.roundRect(m, 'line', x, y, w, h, 6, borderCol, 2)
    
    -- Bisel interior 3D pixel art estilo GBA
    if themeCol then
      D.roundRect(m, 'line', x + 2, y + 2, w - 4, h - 4, 4, themeCol.highlight, 1)
    end
    
    if focused then
      D.roundRect(m, 'line', x, y, w, h, 6, { 1, 1, 1, 0.95 }, 3)
    end
    
    if not commandIcon(m,c,icon or 'fight',x+16,y+16,28,focused) then
      D.icon(runtime,m,icon or 'fight',x+16,y+16,28,{text={1,1,1,1},textSecondary={1,1,1,0.85},subtle=c.subtle,border=c.border})
    end
    D.text(runtime,m,label,x+56,y+11,18,{1,1,1,1},{weight='bold',width=w-72})
    D.text(runtime,m,sub,x+56,y+35,11,{1,1,1,0.85},{weight='medium',width=w-72})
  end
  local function moveRow(D,m,c,mv,x,y,w,h,focused,disabled,index)
    local fill=focused and c.inverse or c.panel;D.panel(m,x,y,w,h,8,fill,focused and c.focus or c.border);if focused then D.focusBorder(m,x,y,w,h,8,c.focus) end
    local alpha=disabled and .42 or 1;local primary=focused and c.textInverse or c.text;local secondary=focused and (c.selectionGold or c.faint) or c.textSecondary
    D.text(runtime,m,tostring(index),x+12,y+8,12,focused and c.focus or c.textSecondary,{weight='bold',alpha=alpha,width=20,align='center'})
    typeIcon(m,c,mv and mv.type,x+56,y+18,32)
    -- The move name owns the complete gap between the type glyph and the PP
    -- column.  The old focused-state width was only 104 px, which made long
    -- but perfectly valid Gen 1 names such as THUNDERSHOCK wrap onto a second
    -- line despite more than 300 px being available in the canonical row.
    -- clipText guarantees a single line; no Gen 1 name needs truncation at
    -- this 300 px budget with the canonical 12 px typeface.
    D.clipText(runtime,m,tostring(mv and mv.name or '—'),x+80,y+8,300,12,disabled and c.disabled or primary,{weight='bold',alpha=alpha})
    local pp=mv and mv.pp~=nil and (tostring(mv.pp)..' / '..tostring(mv.maxPP or mv.pp)) or '—'
    D.text(runtime,m,pp,x+w-76,y+8,10,secondary,{weight='semibold',width=64,align='right',alpha=alpha})
  end
  local function effectiveMoveValues(s,mv)
    if not mv then return nil end
    local basePower=tonumber(mv.power) or 0;local baseAcc=tonumber(mv.accuracy)
    local power,acc=basePower,baseAcc;local pdir,adir=0,0
    if basePower>0 and s.player then
      local stat=mv.category=='SPECIAL' and 'special' or 'attack';local stage=s.player.stages and tonumber(s.player.stages[stat]) or 0
      local baseStat=tonumber(s.player.curStats and s.player.curStats[stat]) or 0
      if baseStat>0 then
        local staged=Stats.applyStage(baseStat,stage)
        power=math.max(1,math.floor(basePower*(staged/baseStat)))
      end
      pdir=power>basePower and 1 or power<basePower and -1 or 0
    end
    if baseAcc and s.player and s.enemy then
      local byte=math.floor(baseAcc*255/100);byte=math.min(255,Stats.applyStage(byte,s.player.stages and s.player.stages.accuracy or 0));byte=math.min(255,Stats.applyStage(byte,-(s.enemy.stages and s.enemy.stages.evasion or 0)))
      acc=clamp(math.floor(byte*100/255+.5),1,100);adir=acc>baseAcc and 1 or acc<baseAcc and -1 or 0
    end
    return power,acc,pdir,adir
  end
  local function influencedColor(c,dir) return dir>0 and c.success or dir<0 and c.danger or (c.selectionGold or c.textInverse) end
  local function moveDock(D,m,c,game,s,offset)
    local ox,oy=tonumber(offset and offset.x) or 0,tonumber(offset and offset.y) or 0
    local scale=clamp(tonumber(offset and offset.scale) or 100,50,150);local factor=scale/100
    local baseX,baseY=720+ox,780+oy
    if math.abs(factor-1)>0.0001 then
      local source=m;local transformed={};for k,v in pairs(source) do transformed[k]=v end
      transformed.scale=source.scale*factor
      transformed.ox=source.ox+baseX*source.scale*(1-factor)
      transformed.oy=source.oy+baseY*source.scale*(1-factor)
      m=transformed
    end
    local dock={x=baseX,y=baseY,w=1140,h=228};D.panel(m,dock.x,dock.y,dock.w,dock.h,16,c.panel,c.border)
    local moves=s.player and s.player.curMoves or {};local sel=moveModel(game,moves[s.moveIndex]);local leftX,leftY=736+ox,796+oy
    D.text(runtime,m,'MOVIMIENTO SELECCIONADO',748+ox,804+oy,12,c.textSecondary,{weight='bold'})
    if sel then
      D.text(runtime,m,sel.name,748+ox,828+oy,24,c.text,{weight='bold',width=556});pill(D,m,c,sel.type,748+ox,864+oy,100,typeColor(c,sel.type));pill(D,m,c,'◆ '..sel.category,856+ox,864+oy,100,c.inverse)
      D.text(runtime,m,sel.description,748+ox,896+oy,16,c.textSecondary,{width=556})
      local power,acc,pdir,adir=effectiveMoveValues(s,sel)
      local function centeredMetric(x,w,label,value,valueColor,border)
        D.panel(m,x,949+oy,w,30,8,c.inverse,border)
        local labelFont=D.font(runtime,m,16,'medium');local valueFont=D.font(runtime,m,16,'medium')
        local labelText=tostring(label);local valueText=tostring(value)
        local lw=(labelFont and labelFont.getWidth and labelFont:getWidth(labelText)/m.scale) or (#labelText*8)
        local vw=(valueFont and valueFont.getWidth and valueFont:getWidth(valueText)/m.scale) or (#valueText*8)
        local gap=14;local start=x+(w-(lw+gap+vw))/2
        D.text(runtime,m,labelText,start,956+oy,16,c.textInverse,{weight='medium'})
        D.text(runtime,m,valueText,start+lw+gap,956+oy,16,valueColor,{weight='medium'})
      end
      centeredMetric(748+ox,174,'POTENCIA',power>0 and tostring(power) or '—',influencedColor(c,pdir),c.border)
      centeredMetric(930+ox,174,'PRECISIÓN',acc and tostring(acc) or '—',influencedColor(c,adir),nil)
    else D.text(runtime,m,'SIN DATOS',748+ox,828+oy,15,c.textSecondary,{weight='semibold'}) end
    D.line(m,1328+ox,796+oy,1328+ox,992+oy,c.border,4);D.text(runtime,m,'ELIGE UN MOVIMIENTO',1360+ox,800+oy,12,c.textSecondary,{weight='bold'})
    runtime.battleRects={}
    for i=1,4 do
      local mv=moveModel(game,moves[i]);local r={x=1360+ox,y=832+oy+(i-1)*40,w=472,h=36}
      runtime.battleRects[i]={x=baseX+(r.x-baseX)*factor,y=baseY+(r.y-baseY)*factor,w=r.w*factor,h=r.h*factor}
      moveRow(D,m,c,mv,r.x,r.y,r.w,r.h,i==s.moveIndex,s.player and s.player.disabledSlot==i,i)
    end
    return {x=baseX,y=baseY,w=dock.w*factor,h=dock.h*factor,scale=scale}
  end
  local function stageText(stage) stage=tonumber(stage) or 0;return stage>0 and ('+'..stage) or tostring(stage) end
  local function battleInfoPanel(D,m,c,s)
    if not runtime.battleInfoOpen then return end
    D.roundRect(m,'fill',0,0,1920,1080,0,{0,0,0,.70});local x,y,w,h=600,290,720,500
    D.panel(m,x,y,w,h,20,c.panel,c.borderStrong)
    D.text(runtime,m,'ESTADÍSTICAS DE COMBATE',x,y+24,24,c.text,{weight='bold',width=w,align='center'})
    D.text(runtime,m,'MODIFICADORES DE NIVEL',x,y+60,11,c.textSecondary,{weight='bold',width=w,align='center'})
    local rows={{'ATQ','Ataque','attack'},{'DEF','Defensa','defense'},
      {'ATE','Atq. Esp.','special'},{'DFE','Def. Esp.','special'},
      {'VEL','Velocidad','speed'},{'PRE','Precisión','accuracy'},{'EVA','Evasión','evasion'}}
    local function side(b,sx)
      D.text(runtime,m,tostring(b and b.name or 'POKéMON'),sx,y+100,18,c.text,{weight='bold',width=220})
      D.text(runtime,m,'Nv. '..tostring(b and b.mon and b.mon.level or '—'),sx+210,y+103,14,c.textSecondary,{weight='semibold',width=70,align='right'})
      D.line(m,sx,y+128,sx+280,y+128,c.borderStrong,2)
      for i,r in ipairs(rows) do
        local yy=y+154+(i-1)*35;local st=b and b.stages and tonumber(b.stages[r[3]]) or 0
        D.text(runtime,m,r[1],sx+12,yy,13,c.text,{weight='bold'})
        D.text(runtime,m,r[2],sx+54,yy,13,c.textSecondary,{weight='medium'})
        local col=st>0 and c.success or st<0 and c.danger or c.textSecondary
        D.text(runtime,m,stageText(st)..(st>0 and ' ▲' or st<0 and ' ▼' or ''),sx+232,yy,14,col,{weight='bold',width=48,align='right'})
        D.line(m,sx+12,yy+24,sx+280,yy+24,c.subtle,1)
      end
    end
    side(s.player,x+32);D.line(m,x+360,y+108,x+360,y+426,c.border,2);side(s.enemy,x+392)
    D.panel(m,x+296,y+h-48,128,24,6,c.inverse,nil);D.text(runtime,m,'TAB',x+304,y+h-43,14,c.textInverse,{weight='bold'});D.text(runtime,m,'CERRAR',x+350,y+h-43,13,c.faint,{weight='medium'})
  end
  local function previousLevelStats(game,statBox)
    if statBox then
      for _,key in ipairs({'_krsPreviousStats','previousStats','oldStats','statsBefore'}) do if type(statBox[key])=='table' then return statBox[key] end end
    end
    local mon=statBox and statBox.mon
    local level=mon and tonumber(mon.level)
    local def=mon and game and game.data and game.data.pokemon and game.data.pokemon[mon.species]
    if not(def and level and level>1) then return nil end
    local ok,Stats=pcall(require,'src.pokemon.Stats');if not ok or type(Stats.calc)~='function' then return nil end
    local okCalc,value=pcall(Stats.calc,def,level-1,mon.dvs,mon.statExp)
    return okCalc and type(value)=='table' and value or nil
  end
  local function levelUpPanel(game,D,m,c,statBox)
    if not statBox then return end
    local mon=statBox.mon or {};local s=mon.stats or {};local previous=previousLevelStats(game,statBox);local x,y,w,h=650,322,620,436
    D.roundRect(m,'fill',0,0,1920,1080,0,{0,0,0,.56});D.panel(m,x,y,w,h,20,c.panel,c.borderStrong)
    D.text(runtime,m,'¡SUBIÓ DE NIVEL!',x,y+28,24,c.text,{weight='bold',width=w,align='center'});D.text(runtime,m,tostring(mon.nickname or mon.species or 'POKéMON'):upper()..'  ·  Nv. '..tostring(mon.level or '—'),x,y+68,14,c.textSecondary,{weight='semibold',width=w,align='center'})
    local rows={{'PS','hp'},{'ATAQUE','attack'},{'DEFENSA','defense'},{'VELOCIDAD','speed'},{'ESPECIAL','special'}}
    for i,r in ipairs(rows) do
      local yy=y+118+(i-1)*48;local value=s[r[2]];local old=previous and previous[r[2]];local gain=(tonumber(value) and tonumber(old)) and math.max(0,tonumber(value)-tonumber(old)) or nil
      D.text(runtime,m,r[1],x+56,yy,14,c.textSecondary,{weight='semibold'})
      if gain then D.text(runtime,m,'+'..tostring(gain),x+w-206,yy+2,14,c.success,{weight='bold',width=70,align='right'}) end
      D.text(runtime,m,tostring(value or '—'),x+w-116,yy,18,c.text,{weight='bold',width=60,align='right'});D.line(m,x+56,yy+30,x+w-56,yy+30,c.subtle,1)
    end
    D.panel(m,x+226,y+h-52,168,28,7,c.inverse,nil);D.text(runtime,m,'ENTER / ESC',x+238,y+h-46,13,c.textInverse,{weight='bold'});D.text(runtime,m,'CERRAR',x+332,y+h-46,12,c.faint,{weight='medium'})
  end
  local function sourceMessageChunks(text)
    local out={};local pos=1
    while true do
      local npos=text:find('[\n\v]',pos)
      out[#out+1]=npos and text:sub(pos,npos-1) or text:sub(pos)
      if not npos then break end;pos=npos+1
    end
    return out
  end
  local function visibleMessageLines(s)
    local raw=s.current and s.current.text
    if type(raw)~='string' or raw=='' then return {} end
    -- BattleState keeps only a rolling two-line Game Boy window in `shown`.
    -- Wide dialogue must not inherit that destructive presentation window: it
    -- should retain everything already revealed in the current semantic
    -- message and let the KRS box perform its own wrapping. `charIndex` is the
    -- engine's authoritative glyph count across the whole message.
    local remaining=math.max(0,tonumber(s.charIndex) or 0);local out={}
    for _,src in ipairs(sourceMessageChunks(raw)) do
      if remaining<=0 then break end
      local spans=NativeFont.split(src);local n=math.min(remaining,#spans)
      if n>0 then out[#out+1]=src:sub(1,spans[n].to) end
      remaining=remaining-n
    end
    return out
  end
  local function cleanBattleText(lines)
    local parts={}
    for _,line in ipairs(lines or {}) do
      local v=tostring(line or ''):gsub('[\v\f]',' '):gsub('%s+',' '):gsub('^%s+',''):gsub('%s+$','')
      if v~='' then parts[#parts+1]=v end
    end
    return table.concat(parts,' '):gsub('%s+([!%?%.,;:])','%1')
  end
  local function battleChoiceFallback(s)
    if s and s.kind=='wild' and s.player and s.player.fainted then return '¿Usar el siguiente POKéMON?' end
    return 'Elige una opción.'
  end
  local function battleMessage(D,m,c,s,choice)
    local lines=visibleMessageLines(s)
    local text=cleanBattleText(lines)
    if text=='' and not choice and not s.current then return nil end
    if text=='' and choice then text=battleChoiceFallback(s) end
    if runtime.DialoguePanel and type(runtime.DialoguePanel.draw)=='function' then
      local model={text=text,bottomMargin=88}
      if choice then
        local labels=s.current and s.current._krsChoiceLabels or {'SÍ','NO'}
        model.choice={labels=labels,count=2,index=choice.index or 1,align='right'}
      end
      return runtime.DialoguePanel.draw(runtime,m,c,model)
    end
    local r={x=400,y=860,w=1120,h=132};D.panel(m,r.x,r.y,r.w,r.h,18,c.panel,c.borderStrong or c.border)
    D.text(runtime,m,text,r.x+32,r.y+28,18,c.text,{weight='semibold',width=r.w-64})
    return r
  end
  local function currentAnimSprites(s)
    if s.animPlaying and s.animPlayer then local step=s.animPlayer.steps and s.animPlayer.steps[s.animPlayer.stepIndex];return step and step.sprites end
    if s.lockedBall and s.animPlayer then return s.lockedBall end
  end
  local function visualAnchor(box,mode)
    if not box then return nil end
    if mode=='top' then return {x=box.x+box.w/2,y=box.y} end
    if mode=='feet' or mode=='base' or mode=='ground' then return {x=box.groundX or (box.x+box.w/2),y=box.groundY or (box.y+box.h)} end
    return {x=box.x+box.w/2,y=box.y+box.h/2}
  end
  local function decorateAnimationAnchors(s,bounds)
    bounds=bounds or {}
    local attackerIsPlayer=s and s.animAttackerIsPlayer==true
    bounds.attacker=attackerIsPlayer and bounds.player or bounds.opponent
    bounds.source=bounds.attacker
    bounds.self=bounds.attacker
    bounds.defender=attackerIsPlayer and bounds.opponent or bounds.player
    bounds.target=bounds.defender
    bounds.opponent=bounds.opponent
    bounds.player=bounds.player
    bounds.sides={player=bounds.player,opponent=bounds.opponent}
    bounds.field={x=0,y=86,w=1920,h=930,groundX=960,groundY=1016,
      top={x=960,y=86},center={x=960,y=551},feet={x=960,y=1016}}
    bounds.allCombatants={bounds.player,bounds.opponent}
    return bounds
  end
  local function animationTargetBoxes(s,bounds,kind,side)
    bounds=decorateAnimationAnchors(s,bounds)
    kind=tostring(kind or 'target'):lower()
    if kind=='attacker' or kind=='source' or kind=='self' or kind=='user' then return {bounds.attacker} end
    if kind=='defender' or kind=='target' or kind=='opponent' or kind=='enemy' then return {bounds.defender} end
    if kind=='side' then
      side=tostring(side or ''):lower()
      if side=='source' or side=='attacker' or side=='self' then return {bounds.attacker} end
      if side=='target' or side=='defender' or side=='opponent' then return {bounds.defender} end
      if side=='player' or side=='ally' then return {bounds.player} end
      if side=='enemy' then return {bounds.opponent} end
      return {}
    end
    if kind=='field' or kind=='terrain' or kind=='fullscreen' then return {bounds.field} end
    if kind=='all' or kind=='all_combatants' or kind=='combatants' then return bounds.allCombatants end
    return {}
  end
  local function roleAnchors(s,bounds,mode)
    local users=animationTargetBoxes(s,bounds,'attacker')
    local targets=animationTargetBoxes(s,bounds,'defender')
    return visualAnchor(users[1],mode),visualAnchor(targets[1],mode)
  end
  local function mapAuthoredPoint(px,py,user,target,scale)
    if not (user and target) then return nil,nil end
    -- Native Gen1 animation coordinates use 40,80 for the user and 120,32 for
    -- the target. Project the whole authored plane onto the CURRENT visual line
    -- connecting those two battlers. This keeps projectiles continuous while
    -- self/target effects and Live-Editor moves follow the rendered instances.
    local ux,uy,tx,ty=40,80,120,32
    local dx,dy=tx-ux,ty-uy;local len2=dx*dx+dy*dy
    local qx,qy=(px or ux)-ux,(py or uy)-uy
    local t=(qx*dx+qy*dy)/len2
    local perp=(qx*(-dy)+qy*dx)/math.sqrt(len2)
    local adx,ady=target.x-user.x,target.y-user.y;local alen=math.sqrt(adx*adx+ady*ady)
    local nx,ny=0,0;if alen>0 then nx,ny=-ady/alen,adx/alen end
    local k=tonumber(scale) or 6
    return user.x+adx*t+nx*perp*k,user.y+ady*t+ny*perp*k
  end
  local function drawAttackAnimation(m,s,bounds)
    local sprites=currentAnimSprites(s);if not sprites or #sprites==0 or not s.drawAnimLayer then return end
    local minX,maxX,minY,maxY=math.huge,-math.huge,math.huge,-math.huge
    for _,sp in ipairs(sprites) do minX=math.min(minX,(sp.x or 0)-8);maxX=math.max(maxX,sp.x or 0);minY=math.min(minY,(sp.y or 0)-16);maxY=math.max(maxY,sp.y or 0) end
    local cx=(minX+maxX)/2;local cy=(minY+maxY)/2
    local user,target=roleAnchors(s,bounds,'center')
    local tx,ty=mapAuthoredPoint(cx,cy,user,target,6)
    if not tx then
      -- Unsupported/native fallback remains deterministic, but only when exact
      -- current battler bounds were unavailable for this frame.
      local t=clamp((cx-40)/80,0,1);tx=522+(1438-522)*t;ty=650+(470-650)*t
    end
    local k=6*m.scale
    love.graphics.push('all');love.graphics.setScissor(m.ox,m.oy+86*m.scale,1920*m.scale,930*m.scale);love.graphics.translate(m.ox+tx*m.scale-cx*k,m.oy+ty*m.scale-cy*k);love.graphics.scale(k,k);pcall(s.drawAnimLayer,s,false);love.graphics.pop()
  end
  local function externalBattleAnimLayer(game,m,layer,bounds)
    local h=runtime.mod and runtime.mod.find and runtime.mod.find('battle_animations') or nil
    local exports=h and h.exports or nil
    if not (type(exports)=='table' and type(exports.drawKrsWideLayer)=='function') then return false end
    local transform={x=m.ox,y=m.oy+86*m.scale,r=0,sx=m.scale,sy=m.scale,ox=0,oy=0,kx=0,ky=0}
    local ok,value=pcall(exports.drawKrsWideLayer,layer,transform,bounds)
    return ok and value==true
  end
  local function providerPicEffect(s,b)
    local pf=s and s.picFx and b and s.picFx[b] or nil
    if not pf then return {visible=true,alpha=1,xscale=1,ox=0,oy=0} end
    local effect={visible=not pf.hidden,alpha=tonumber(pf.fade) or 1,xscale=1,
      ox=(tonumber(pf.ox) or 0)*6,oy=(tonumber(pf.oy) or 0)*6,kind=pf.kind,t=tonumber(pf.t) or 0}
    local k,t=effect.kind,effect.t
    if k=='slideOff' then
      local dir=b.isPlayer and -1 or 1;effect.ox=effect.ox+dir*8*math.min(8,math.floor(t/3)+1)*6
    elseif k=='slideHalf' then
      local dir=b.isPlayer and -1 or 1;effect.ox=effect.ox+dir*8*math.min(4,math.floor(t/4)+1)*6
    elseif k=='slideDown' then effect.oy=effect.oy+8*math.min(7,math.floor(t/3)+1)*6;effect.clip=true
    elseif k=='slideDownHide' then effect.oy=effect.oy+16*(math.floor(t/8)+1)*6;effect.clip=true
    elseif k=='bounce' then effect.oy=effect.oy+8*math.min(7,math.floor((t%21)/3)+1)*6;effect.clip=true
    elseif k=='shakeBF' then effect.ox=effect.ox+((math.floor(t/3)%2==0) and -8 or 8)*6
    elseif k=='squish' then effect.xscale=math.max(0,7-2*(math.floor(t/6)+1))/7
    elseif k=='blink' and math.floor(t/5)%2==0 then effect.visible=false
    elseif k=='slideUp' then effect.reveal=clamp(math.min(7,math.floor((t-1)/2)+1)/7,0,1) end
    if pf.minimized then effect.minimized=true;effect.visible=false end
    return effect
  end
  local function pokemonArt(game,b,side,isPlayer,backdrop,editorConfig)
    local mon=b and b.mon
    if not (runtime.PokemonArt and mon and mon.species) then return nil end
    local ok,art=pcall(runtime.PokemonArt.image,runtime.PokemonArt,game,mon.species,side,{
      kind='battle',mon=mon,battler=b,player=isPlayer==true,game=game,
      backgroundKey=backdrop and (backdrop.kind or backdrop.file) or nil,
      backgroundPhase=backdrop and (backdrop.period or 'default') or nil,
      editorRole=isPlayer and 'player' or 'opponent',editorConfig=editorConfig,
    })
    if ok and type(art)=='table' and art.image then return art end
  end
  local function krsPlayerTrainerArt(game,s)
    if not runtime.PokemonArt then return nil end
    local gx=visualsExports()
    if not (type(gx)=='table' and type(gx.playerArt)=='function') then return nil end
    local ok,value=pcall(gx.playerArt)
    if not (ok and type(value)=='table' and value.path) then return nil end
    local art={path=value.path,nativePath=value.path,trueColor=true,source='krs_graphics.player'}
    if value.animated and type(value.atlas)=='table' then
      local atlas={};for k,v in pairs(value.atlas) do atlas[k]=v end
      -- The authored player strip contains five poses. Pose one is the held
      -- battle-intro stance; poses two through five play once while the
      -- trainer slides offscreen to send the Pokémon out. Drive that sequence
      -- from BattleState.picOffset instead of a wall clock so pausing/menuing
      -- cannot desynchronise the pose from the native battle transaction.
      local offset=type(s.picOffset)=='function' and tonumber(s:picOffset('back')) or 0
      local count=math.max(1,tonumber(atlas.frameCount) or 5)
      local frame=1
      if offset and math.abs(offset)>0 and count>1 then
        local progress=clamp(math.abs(offset)/72,0,1)
        frame=math.min(count,2+math.floor(progress*math.max(1,count-1)))
      end
      atlas.frameIndex=frame;art.atlas=atlas
    end
    local made=runtime.PokemonArt:materialize(art)
    return made and made.image or nil,made
  end

  local function trainerPresentation(game,s,layout)
    if not (s and (s.kind=='trainer' or s.kind=='link')) then return nil,nil,nil,false end
    local phase=s.krsTrainerPreviewPhase or (runtime.TrainerScene and runtime.TrainerScene.phase and runtime.TrainerScene.phase(s)) or (s.showEnemyTrainer and 'intro' or 'battle')
    local gx=visualsExports();local keep=false
    if gx and type(gx.trainerArt)=='table' and type(gx.trainerArt.keepVisible)=='function' then
      local ok,v=pcall(gx.trainerArt.keepVisible);keep=ok and v==true
    end
    local shouldDraw=s.krsTrainerForcePreview==true or s.showEnemyTrainer==true or (runtime.TrainerScene and runtime.TrainerScene.showPersistent and runtime.TrainerScene.showPersistent(s,keep))
    if not shouldDraw then return nil,nil,phase,keep end
    local request={oppClass=s.oppClass,partyIndex=s.partyIndex,trainer=s.trainer,kind='battle',phase=phase}
    local art=runtime.Graphics and runtime.Graphics.resolve and runtime.Graphics:resolve('battle.trainer',game,nil,request) or nil
    local image
    if type(art)=='table' and art.path then
      if type(art.atlas)=='table' and runtime.PokemonArt and runtime.PokemonArt.materialize then
        local atlas={};for k,v in pairs(art.atlas) do atlas[k]=v end
        local style=type(layout)=='table' and layout.trainer_style or nil
        atlas.speedPercent=tonumber(style and style.animationSpeed) or 100;art.atlas=atlas
        local made=runtime.PokemonArt:materialize(art);if made then image=made.image;art=made end
      elseif runtime.Graphics and runtime.Graphics.image then
        local made=runtime.Graphics:image('battle.trainer',game,nil,request);image=made and made.image;art=made or art
      end
    end
    if not image and s.showEnemyTrainer then image=s.trainerPic;art=nil end
    return image,art,phase,keep
  end
  local function trainerTransform(layout,phase)
    local key=phase=='post' and 'trainer_post' or phase=='battle' and 'trainer_battle' or 'trainer_intro'
    local pos=type(layout)=='table' and layout[key] or nil;local style=type(layout)=='table' and layout.trainer_style or nil
    return tonumber(pos and pos.x) or (phase=='battle' and 1580 or 1248),tonumber(pos and pos.y) or (phase=='battle' and 350 or 280),clamp(tonumber(style and style.scale) or 100,25,200)
  end

  local function tutorialTrainerImage(oakDemo)
    runtime.tutorialTrainerImages=runtime.tutorialTrainerImages or {}
    local key=oakDemo and 'oak' or 'old_man'
    if runtime.tutorialTrainerImages[key]~=nil then return runtime.tutorialTrainerImages[key] or nil end
    local relative=oakDemo and 'assets/intro/prof_oak_demo.png' or 'assets/intro/old_man.png'
    local img=runtime.assets:image(runtime.assetPath(relative),'nearest')
    runtime.tutorialTrainerImages[key]=img or false
    return img
  end
  local function spriteImages(game,s,backdrop,layout)
    local enemyArt,playerArt
    local enemy,player
    if s.showEnemyTrainer then
      local trainerImage,trainerMeta=trainerPresentation(game,s,layout)
      enemy=trainerImage or s.trainerPic;enemyArt=trainerMeta
    elseif s.enemy then
      -- The provider remains authoritative through the complete battle turn.
      -- Native picFx changes geometry/visibility, not sprite ownership.  The
      -- previous fallback to battler.sprite during shake/blink/slide effects
      -- is what made Voxel fronts suddenly reappear at their engine scale.
      enemyArt=pokemonArt(game,s.enemy,'front',false,backdrop);enemy=enemyArt and enemyArt.image or s.enemy.sprite
    end
    if s.showPlayerBack then
      -- Scripted catching tutorials keep their dedicated characters. Normal
      -- battles may use the KRS Graphics player-art choice; animated five-pose
      -- strips are phase-locked to the native trainer slide transaction.
      if s.demo then
        player=tutorialTrainerImage(s.oakDemo==true) or s.playerBackPic
      else
        player,playerArt=krsPlayerTrainerArt(game,s)
        player=player or s.playerBackPic
      end
    elseif s.player then
      playerArt=pokemonArt(game,s.player,'back',true,backdrop);player=playerArt and playerArt.image or s.player.sprite
    end
    return enemy,player,enemyArt,playerArt
  end
  local function faintOffset(s,b)
    if not (b and b.fainted and type(s.fxFaintActive)=='function' and s:fxFaintActive(b)) then return 0,false end
    local px=type(s.fxFaintOffset)=='function' and tonumber(s:fxFaintOffset(b,1)) or 0
    return clamp((px or 0)/56,0,1)*POKEMON_BATTLE_SIZE,true
  end
  local function battlerVisible(s,b,base)
    if not base or not b then return base end
    if b.fainted then return type(s.fxFaintActive)=='function' and s:fxFaintActive(b) end
    return true
  end
  local function pokedexHeightMetres(game,b)
    local mon=b and b.mon;local species=mon and mon.species
    local def=game and game.data and game.data.pokemon and species and game.data.pokemon[species]
    local dex=def and def.dexEntry
    local ft=tonumber(dex and dex.heightFt);local inch=tonumber(dex and dex.heightIn)
    if ft==nil or inch==nil then return nil end
    local totalIn=ft*12+inch;if totalIn<=0 then return nil end
    return totalIn*0.0254
  end

  local function autoBattlePixelScale(game,b,side,img,metric,presentation)
    -- AUTO is the only non-literal scale mode. It derives a continuous pixel
    -- multiplier from the active provider's authored frame/cell, the selected
    -- Real Size policy and perspective. DEFAULT/X0.5/X2/X3 remain literal.
    local iw,ih=img:getDimensions()
    local canvasW=math.max(1,tonumber(metric and metric.w) or iw)
    local canvasH=math.max(1,tonumber(metric and metric.h) or ih)
    local isBack=side=='back'
    local target=160
    local mode=tostring(presentation and presentation.realSize or 'auto'):lower()
    local metres=pokedexHeightMetres(game,b)
    if metres and mode~='no' then
      -- YES follows canonical height more strongly. AUTO deliberately tempers
      -- the physical ratio because literal metres would make extreme species
      -- unusable in a 16:9 battle composition.
      local exponent=mode=='yes' and 0.38 or 0.24
      target=target*(metres^exponent)
    end
    -- The player/back side is closer to the camera and therefore gets a small
    -- perspective lift in AUTO only. Literal multipliers remain literal.
    if isBack then target=target*1.10 end
    local minH=isBack and 96 or 88
    local maxH=isBack and 352 or 320
    target=clamp(target,minH,maxH)
    local scale=target/canvasH
    -- Wide sprites must remain composable even when their canonical height is
    -- modest. This is a visual safety ceiling, not a fit-to-slot normalizer.
    local maxW=isBack and 420 or 380
    scale=math.min(scale,maxW/canvasW)
    return clamp(scale,0.25,3.0)
  end


  local function drawSprites(game,m,s,groundAnchors,backdrop,layout)
    local bounds={}
    local enemyImg,playerImg,enemyArt,playerArt=spriteImages(game,s,backdrop,layout)
    local persistentTrainerImg,persistentTrainerArt,trainerPhase=trainerPresentation(game,s,layout)
    local playerBase=s.showPlayerBack or (s.player and not s.sendingOut and not (s.fxHidden and s:fxHidden(s.player)))
    local enemyBase=s.showEnemyTrainer or (s.enemy and not s.enemyHidden and not s.enemySendingOut and not (s.fxHidden and s:fxHidden(s.enemy)))
    local playerVisible=s.showPlayerBack or battlerVisible(s,s.player,playerBase)
    local enemyVisible=s.showEnemyTrainer or battlerVisible(s,s.enemy,enemyBase)
    local intro=(tonumber(s.introSlide) or 0)*2*6
    local foeOff=(type(s.picOffset)=='function' and tonumber(s:picOffset('foe')) or 0)*6
    local backOff=(type(s.picOffset)=='function' and tonumber(s:picOffset('back')) or 0)*6
    local sx=((s.fx and tonumber(s.fx.shakeX)) or 0)*6
    local sy=((s.fx and tonumber(s.fx.shakeY)) or 0)*6
    local enemyFaint,enemyClip=faintOffset(s,s.enemy)
    local playerFaint,playerClip=faintOffset(s,s.player)
    local presentation=battlePresentation(game)
    local playerGround=groundAnchors and groundAnchors.player
      and {x=groundAnchors.player.x,y=86+groundAnchors.player.y} or FALLBACK_PLAYER_GROUND
    local enemyGround=groundAnchors and groundAnchors.enemy
      and {x=groundAnchors.enemy.x,y=86+groundAnchors.enemy.y} or FALLBACK_ENEMY_GROUND
    if playerArt and type(playerArt.editorPosition)=='table' then
      playerGround={x=tonumber(playerArt.editorPosition.x) or playerGround.x,y=tonumber(playerArt.editorPosition.y) or playerGround.y}
    end
    if enemyArt and type(enemyArt.editorPosition)=='table' then
      enemyGround={x=tonumber(enemyArt.editorPosition.x) or enemyGround.x,y=tonumber(enemyArt.editorPosition.y) or enemyGround.y}
    end

    -- For Pokémon x/y are GROUND CONTACT coordinates. Trainer intro pictures
    -- retain the historical top-left slot coordinates. KRS DEFAULT is now
    -- strict native x1: one authored cell pixel equals one KRS logical pixel.
    -- Fixed multipliers are equally literal; only AUTO derives a per-Pokémon
    -- multiplier from native frame dimensions, Pokédex policy and side depth.
    local function drawBattler(img,art,b,x,y,faint,clip,isPokemon,pokemonSide,trainerScalePercent)
      if not img then return end
      local effect=providerPicEffect(s,b)
      if not effect.visible then return end
      local ox,oy=art and effect.ox or 0,art and effect.oy or 0
      local alpha=art and effect.alpha or 1
      local xscale=art and effect.xscale or 1
      local metric=art and art.metrics or battleArtMetrics(img)
      local baseW,baseH=BATTLE_ART_SLOT,BATTLE_ART_SLOT
      if not isPokemon and trainerScalePercent then local f=clamp(tonumber(trainerScalePercent) or 100,25,200)/100;baseW,baseH=baseW*f,baseH*f end
      local providerScaled=isPokemon and art~=nil and (presentation._owner=='krs_graphics')
      local rawPixelScale=providerScaled and tonumber(presentation.pixelScale) or nil
      local visualScale=1
      if providerScaled then
        local iw,ih=img:getDimensions()
        local canvasW=math.max(1,tonumber(metric and metric.w) or iw)
        local canvasH=math.max(1,tonumber(metric and metric.h) or ih)
        if art and art.editorSizePercent~=nil then
          local pct=clamp(tonumber(art.editorSizePercent) or 0,0,100)/100
          rawPixelScale=1+4*pct
          local maxW=(pokemonSide=='back') and 420 or 380
          local maxH=(pokemonSide=='back') and 352 or 320
          rawPixelScale=math.min(rawPixelScale,maxW/canvasW,maxH/canvasH)
        elseif not rawPixelScale then
          rawPixelScale=autoBattlePixelScale(game,b,pokemonSide or 'front',img,metric,presentation)
        end
        baseW,baseH=canvasW*rawPixelScale,canvasH*rawPixelScale
      end
      local drawFaint=faint
      if providerScaled and tonumber(faint) and POKEMON_BATTLE_SIZE>0 then
        drawFaint=(faint/POKEMON_BATTLE_SIZE)*baseH
      end
      local slotX,slotY
      if isPokemon then
        slotX=x-baseW/2+ox;slotY=y-baseH+oy
      else
        slotX=x+ox;slotY=y+oy
      end
      if isPokemon then
        local role=b and b.isPlayer and 'player' or 'opponent'
        local actualW=(xscale>0 and xscale<.999) and baseW*xscale or baseW
        local actualX=slotX+((baseW-actualW)/2)
        bounds[role]={x=actualX,y=slotY,w=actualW,h=math.max(0,baseH-(tonumber(drawFaint) or 0)),
          groundX=x,groundY=y,top={x=actualX+actualW/2,y=slotY},
          center={x=actualX+actualW/2,y=slotY+baseH/2},feet={x=x,y=y},battler=b}
      end
      love.graphics.push('all')
      if xscale<.999 and xscale>0 then
        local contracted=baseW*xscale;slotX=slotX+(baseW-contracted)/2
        fitImageBox(m,img,slotX,slotY,contracted,baseH,metric,drawFaint,clip or effect.clip,alpha,visualScale,isPokemon,art and art.mirrorX==true)
      elseif xscale>0 then
        if effect.reveal and love.graphics.setScissor then
          local revealH=baseH*effect.reveal
          love.graphics.setScissor(m.ox+slotX*m.scale,m.oy+(slotY+baseH-revealH)*m.scale,baseW*m.scale,revealH*m.scale)
          fitImageBox(m,img,slotX,slotY,baseW,baseH,metric,drawFaint,false,alpha,visualScale,isPokemon,art and art.mirrorX==true)
        else
          fitImageBox(m,img,slotX,slotY,baseW,baseH,metric,drawFaint,clip or effect.clip,alpha,visualScale,isPokemon,art and art.mirrorX==true)
        end
      end
      love.graphics.pop()
    end
    local trainerX,trainerY,trainerScale=trainerTransform(layout,trainerPhase)
    if persistentTrainerImg and trainerPhase=='battle' and not s.showEnemyTrainer then
      -- Persistent trainer is an additional KRS presentation layer behind the
      -- active opponent Pokémon. Engine showEnemyTrainer stays untouched.
      drawBattler(persistentTrainerImg,persistentTrainerArt,nil,trainerX+sx,trainerY+sy,0,false,false,nil,trainerScale)
    end
    if enemyVisible then
      if s.showEnemyTrainer then
        drawBattler(enemyImg,enemyArt,s.enemy,trainerX-intro+foeOff+sx,trainerY+sy,enemyFaint,enemyClip,false,nil,trainerScale)
      else
        drawBattler(enemyImg,enemyArt,s.enemy,enemyGround.x-intro+foeOff+sx,enemyGround.y+sy,enemyFaint,enemyClip,true,'front')
      end
    end
    if playerVisible then
      if s.showPlayerBack then
        drawBattler(playerImg,playerArt,s.player,332+intro+backOff+sx,476+sy,playerFaint,playerClip,false)
      else
        drawBattler(playerImg,playerArt,s.player,playerGround.x+intro+backOff+sx,playerGround.y+sy,playerFaint,playerClip,true,'back')
      end
    end
    return bounds
  end
  local function moveAnimationActive(game,s)
    if not (s and s.animPlaying and type(s.animName)=='string') then return false end
    return game and game.data and game.data.moves and game.data.moves[s.animName]~=nil or false
  end
  local function hudVisibility(game,s)
    local rec=hudFlow[s]
    if not rec then rec={lastPhase=s.phase,hidePlayer=false,awaiting=false,sawAnim=false};hudFlow[s]=rec end
    local moveAnim=moveAnimationActive(game,s)
    if s.phase=='moveSelect' then
      rec.hidePlayer=true;rec.awaiting=false;rec.sawAnim=false
    elseif rec.lastPhase=='moveSelect' then
      if s.phase=='menu' then rec.hidePlayer=false;rec.awaiting=false;rec.sawAnim=false
      else rec.hidePlayer=true;rec.awaiting=true;rec.sawAnim=false end
    end
    if rec.awaiting and moveAnim then rec.sawAnim=true end
    if rec.awaiting and rec.sawAnim and not moveAnim then
      rec.hidePlayer=false;rec.awaiting=false;rec.sawAnim=false
    elseif rec.awaiting and not rec.sawAnim and s.phase=='menu' then
      -- Invalid/no-PP moves and animation-disabled turns eventually come back
      -- to the command menu; that is the safe restoration point.
      rec.hidePlayer=false;rec.awaiting=false
    end
    rec.lastPhase=s.phase
    return not moveAnim,not(moveAnim or rec.hidePlayer),moveAnim
  end
  local function battleLayout(game,override)
    if type(override)=='table' then return override end
    local api=runtime.BattleLayoutConfig
    return api and api.resolve and api.resolve(game) or {}
  end
  local function offsetOf(layout,id)
    local o=type(layout)=='table' and layout[id] or nil
    return tonumber(o and o.x) or 0,tonumber(o and o.y) or 0
  end
  local function transformOf(layout,id)
    local o=type(layout)=='table' and layout[id] or nil
    return tonumber(o and o.x) or 0,tonumber(o and o.y) or 0,clamp(tonumber(o and o.scale) or 100,50,150)
  end
  local function scaledMetrics(m,pivotX,pivotY,scalePercent)
    local factor=clamp(tonumber(scalePercent) or 100,50,150)/100
    if math.abs(factor-1)<0.0001 then return m,factor end
    local out={};for k,v in pairs(m) do out[k]=v end
    out.scale=m.scale*factor
    out.ox=m.ox+(tonumber(pivotX) or 0)*m.scale*(1-factor)
    out.oy=m.oy+(tonumber(pivotY) or 0)*m.scale*(1-factor)
    return out,factor
  end
  local function hudWithLayout(D,m,c,game,b,layout,id,baseX,baseY,w,h,enemy)
    local ox,oy,scale=transformOf(layout,id);local x,y=baseX+ox,baseY+oy
    -- Enemy HUD is semantically right-anchored, Player HUD left-anchored.
    -- Scaling pivots on that real edge, so changing scale never reintroduces
    -- the residual margin this pass removes at the source layout.
    local pivotX=enemy and (x+w) or x;local pivotY=y
    local tm,factor=scaledMetrics(m,pivotX,pivotY,scale)
    hud(D,tm,c,game,b,x,y,w,h,enemy)
    local bx=enemy and (pivotX-w*factor) or pivotX
    return {x=bx,y=pivotY,w=w*factor,h=h*factor,scale=scale,pivotX=pivotX,pivotY=pivotY}
  end
  local function commandBlock(D,m,c,defs,selected,layout)
    local ox,oy,scale=transformOf(layout,'command_list')
    local factor=clamp(tonumber(scale) or 100,50,150)/100
    local rects={};local boundsByTarget={}
    local w,h = 264, 62
    
    local gridPos = {
      { col = 0, row = 0 }, -- 1: FIGHT / LUCHA (Top-Left)
      { col = 1, row = 0 }, -- 2: PKMN / POKÉMON (Top-Right)
      { col = 0, row = 1 }, -- 3: BAG / MOCHILA (Bottom-Left)
      { col = 1, row = 1 }, -- 4: RUN / HUIR (Bottom-Right)
    }
    
    local startX = 1350 + ox
    local startY = 860 + oy
    local gapX = 14
    local gapY = 12
    
    local minX,minY,maxX,maxY
    for i,d in ipairs(defs or {}) do
      local pos = gridPos[i] or { col = i-1, row = 0 }
      local semantic=tostring(d[3] or ''):lower();local target='command_'..semantic
      local child=type(layout)=='table' and layout[target] or nil
      local cx,cy=tonumber(child and child.x) or 0,tonumber(child and child.y) or 0
      local x = startX + pos.col * (w + gapX) * factor + cx
      local yy = startY + pos.row * (h + gapY) * factor + cy
      local tm=select(1,scaledMetrics(m,x,yy,scale))
      commandCard(D,tm,c,d[1],d[2],x,yy,w,h,i==(selected or 1),d[3])
      local r={x=x,y=yy,w=w*factor,h=h*factor,target=target};rects[i]=r;boundsByTarget[target]=r
      minX=minX and math.min(minX,r.x) or r.x;minY=minY and math.min(minY,r.y) or r.y
      maxX=maxX and math.max(maxX,r.x+r.w) or (r.x+r.w);maxY=maxY and math.max(maxY,r.y+r.h) or (r.y+r.h)
    end
    
    -- Nodo central hexagonal oscuro estilo Gamma Emerald
    local hubX = startX + w * factor + (gapX * factor) / 2
    local hubY = startY + h * factor + (gapY * factor) / 2
    D.roundRect(m, "fill", hubX - 18 * factor, hubY - 18 * factor, 36 * factor, 36 * factor, 8 * factor, {0.14, 0.16, 0.20, 0.98})
    D.roundRect(m, "line", hubX - 18 * factor, hubY - 18 * factor, 36 * factor, 36 * factor, 8 * factor, {0.35, 0.40, 0.48, 1}, 2)
    
    local group={x=minX or startX,y=minY or startY,w=(maxX and minX) and (maxX-minX) or 0,h=(maxY and minY) and (maxY-minY) or 0,scale=scale}
    return group,rects,boundsByTarget
  end
  local function resolvedGraphicsEditorConfig(game,backdrop)
    local gx=visualsExports();local api=gx and gx.graphicsEditor
    if api and type(api.resolve)=='function' then
      local key=backdrop and (backdrop.kind or backdrop.file) or 'grass';local phase=backdrop and (backdrop.period or 'default') or 'default'
      local ok,value=pcall(api.resolve,game,key,phase);if ok and type(value)=='table' then return value end
    end
    return nil
  end
  -- Live Graphics editor preview. This deliberately reuses the battle
  -- background resolver, PokémonArt provider, authored ground anchors,
  -- battle-art metrics and the same fitImageBox primitive as real combat.
  -- It is not a parallel renderer; only battle transactions/HUD state are
  -- omitted from this editor-facing entry point.
  function P.drawGraphicsPreview(game,viewport,spec)
    spec=type(spec)=='table' and spec or {}
    if not runtime.Layout.isWide(viewport) then return nil,'wide_required' end
    local m=runtime.Layout.metrics(viewport);local c=runtime.Theme.resolveAll(runtime,game);local D=runtime.Draw
    local liveBattle=spec.battle
    local backdrop=liveBattle and backdropKind(game,liveBattle) or (type(BattleBackgrounds.previewBackdrop)=='function'
      and BattleBackgrounds.previewBackdrop(spec.background or 'grass',spec.phase or 'day')
      or {file='grass_day',kind='grass',period='day'})
    local anchors=type(BattleBackgrounds.groundAnchors)=='function' and BattleBackgrounds.groundAnchors(backdrop) or nil
    local t0=love.timer and love.timer.getTime and love.timer.getTime() or os.clock()
    local mem0=collectgarbage and collectgarbage('count') or 0
    local stats0=love.graphics.getStats and love.graphics.getStats() or {}
    local sceneConfig=type(spec.config)=='table' and spec.config or resolvedGraphicsEditorConfig(game,backdrop) or {}
    love.graphics.push('all');love.graphics.origin();drawBackdrop(D,m,c,backdrop,sceneConfig.background)
    local bounds={}
    local function one(role,species,side,fallbackGround)
      local mon={species=species};local b={mon=mon,isPlayer=role=='player'}
      local art=pokemonArt(game,b,side,role=='player',backdrop,spec.config)
      if not (art and art.image) then return nil end
      local img=art.image;local metric=art.metrics or battleArtMetrics(img);local iw,ih=img:getDimensions()
      local canvasW=math.max(1,tonumber(metric and metric.w) or iw);local canvasH=math.max(1,tonumber(metric and metric.h) or ih)
      local pct=clamp(tonumber(art.editorSizePercent) or 0,0,100)/100
      local pixelScale=1+4*pct
      local maxW=(role=='player') and 420 or 380;local maxH=(role=='player') and 352 or 320
      pixelScale=math.min(pixelScale,maxW/canvasW,maxH/canvasH)
      local w,h=canvasW*pixelScale,canvasH*pixelScale
      local pos=type(art.editorPosition)=='table' and art.editorPosition or nil
      local gx=tonumber(pos and pos.x) or fallbackGround.x;local gy=tonumber(pos and pos.y) or fallbackGround.y
      local x,y=gx-w/2,gy-h
      fitImageBox(m,img,x,y,w,h,metric,0,true,1,1,true,art.mirrorX==true)
      bounds[role]={x=x,y=y,w=w,h=h,groundX=gx,groundY=gy,mirrorX=art.mirrorX==true,
        top={x=gx,y=y},center={x=gx,y=y+h/2},feet={x=gx,y=gy},
        source=art.source,generation=art.generation,animated=art.animated==true,frame=art.metrics and art.metrics.frame or nil}
      return art
    end
    local pg0=anchors and anchors.player and transformBackdropPoint(anchors.player,sceneConfig.background) or nil
    local eg0=anchors and anchors.enemy and transformBackdropPoint(anchors.enemy,sceneConfig.background) or nil
    local pg=pg0 and {x=pg0.x,y=86+pg0.y} or FALLBACK_PLAYER_GROUND
    local eg=eg0 and {x=eg0.x,y=86+eg0.y} or FALLBACK_ENEMY_GROUND
    local opponentSpecies=(liveBattle and liveBattle.enemy and liveBattle.enemy.mon and liveBattle.enemy.mon.species) or spec.opponentSpecies or 'PIKACHU'
    local playerSpecies=(liveBattle and liveBattle.player and liveBattle.player.mon and liveBattle.player.mon.species) or spec.playerSpecies or 'PIKACHU'
    local opponentArt=one('opponent',opponentSpecies,'front',eg)
    local playerArt=one('player',playerSpecies,'back',pg)
    local uiLayout=battleLayout(game,spec.uiLayout);local uiBounds={}
    local previewTrainerPhase=spec.trainerPhase=='intro' and 'intro' or spec.trainerPhase=='post' and 'post' or 'battle'
    local trainerShell=liveBattle
    if not trainerShell then
      local oppClass='OPP_BROCK';local trainer=game and game.data and game.data.trainers and game.data.trainers[oppClass]
      local nativePic=nil
      if trainer then local ok,v=pcall(BattleState.trainerSprite,game.data,trainer,oppClass,1);if ok then nativePic=v end end
      trainerShell={kind='trainer',phase=previewTrainerPhase=='intro' and 'intro' or 'menu',oppClass=oppClass,partyIndex=1,trainer=trainer or {name='BROCK'},trainerPic=nativePic,
        showEnemyTrainer=previewTrainerPhase~='battle',krsTrainerPreviewPhase=previewTrainerPhase,krsTrainerForcePreview=true,enemy={isPlayer=false,mon={species=opponentSpecies}}}
    else
      -- Live battle preview can inspect any semantic transform without changing
      -- the BattleState flags/phase that own real combat.
      trainerShell=setmetatable({krsTrainerPreviewPhase=previewTrainerPhase,krsTrainerForcePreview=true},{__index=liveBattle})
    end
    local trainerImg,trainerArt,trainerPhase=trainerPresentation(game,trainerShell,uiLayout)
    if trainerImg then
      local tx,ty,ts=trainerTransform(uiLayout,trainerPhase);local metric=trainerArt and trainerArt.metrics or battleArtMetrics(trainerImg)
      local slot=BATTLE_ART_SLOT*(ts/100);fitImageBox(m,trainerImg,tx,ty,slot,slot,metric,0,true,1,1,false,false)
      uiBounds['trainer_'..trainerPhase]={x=tx,y=ty,w=slot,h=slot,scale=ts}
    end
    local enemyBattler=liveBattle and liveBattle.enemy or {name='OPPONENT',mon={species=opponentSpecies,level=50,hp=100},hp=100,maxHp=100,curTypes={'NORMAL'}}
    uiBounds.opponent_frame=hudWithLayout(D,m,c,game,enemyBattler,uiLayout,'opponent_frame',1300,140,620,180,true)
    local playerBattler=liveBattle and liveBattle.player or {name='PLAYER',mon={species=playerSpecies,level=50,hp=100,exp=0},hp=100,maxHp=100,curTypes={'NORMAL'}}
    local playerBaseY=(liveBattle and liveBattle.phase=='menu') and 700 or 626
    uiBounds.player_frame=hudWithLayout(D,m,c,game,playerBattler,uiLayout,'player_frame',0,playerBaseY,620,180,false)
    -- A battle shows either its command menu or its move dock, never both.
    -- The editor mirrors that real phase: command choices stay visible by
    -- default while editing background/HUD/Pokémon, and focusing Move Menu
    -- switches the preview to moveSelect.
    if spec.uiTarget~='move_menu' then
      local defs=liveBattle and liveBattle.safari and {
        {'BALL','Safari Balls · '..tostring(liveBattle.safari.balls or 0),'bag'},
        {'BAIT','Make the Pokémon less likely to flee','pokemon'},
        {'THROW ROCK','Make the Pokémon easier to catch','fight'},
        {'RUN','Leave this encounter','run'},
      } or {{'FIGHT','Damage and status moves','fight'},{'POKéMON','Switch active partner','pokemon'},{'BAG','Use an item','bag'},{'RUN','Attempt escape','run'}}
      local commandGroup,_,commandTargets=commandBlock(D,m,c,defs,liveBattle and liveBattle.menuIndex or 1,uiLayout);uiBounds.command_list=commandGroup;for target,r in pairs(commandTargets or {}) do uiBounds[target]=r end
    end
    if spec.uiTarget=='move_menu' then
      local moveState=liveBattle or {moveIndex=1,player={name='PLAYER',mon={species=playerSpecies,level=50},curMoves={
        {id='TACKLE',name='TACKLE',type='NORMAL',power=40,accuracy=100,pp=35,maxPP=35,description='A physical attack in which the user charges and slams into the target.'},
        {id='GROWL',name='GROWL',type='NORMAL',power=0,accuracy=100,pp=40,maxPP=40,description='The user growls in an endearing way, making opposing Pokémon less wary.'},
      },stages={},curStats={attack=50,special=50}},enemy={stages={}}}
      local dock=moveDock(D,m,c,game,moveState,uiLayout.move_menu);uiBounds.move_menu={x=dock.x,y=dock.y,w=dock.w,h=dock.h}
    end
    if spec.grid then
      -- X/Y are the exact logical coordinates consumed by battler placement.
      -- There is no independent positional Z in the current renderer; depth is
      -- render-order only and is therefore deliberately not exposed as a fake axis.
      local grid={0.95,0.95,1,0.22};local axis={0.95,0.95,1,0.58}
      for x=100,1900,100 do D.line(m,x,86,x,1016,x==100 and axis or grid,x%500==0 and 2 or 1) end
      for y=100,1000,100 do D.line(m,0,y,1920,y,y==100 and axis or grid,y%500==0 and 2 or 1) end
      D.text(runtime,m,'X → 0 … 1920',112,96,10,c.textInverse,{weight='bold'})
      D.text(runtime,m,'Y ↓ 86 … 1016',112,116,10,c.textInverse,{weight='bold'})
      D.text(runtime,m,'Z · N/A (RENDER ORDER ONLY)',112,136,10,c.faint,{weight='bold'})
      for role,b in pairs(bounds) do
        if b.feet then D.roundRect(m,'fill',b.feet.x-4,b.feet.y-4,8,8,4,c.focus);D.text(runtime,m,role:upper()..('  X %d  Y %d'):format(b.feet.x,b.feet.y),b.feet.x+8,b.feet.y-8,9,c.textInverse,{weight='bold'}) end
      end
    end
    -- Reuse the real BattlePresenter header component, after all scene content,
    -- so the editor shows the protected top chrome and clipping boundary.
    local previewEnemy={mon={species=opponentSpecies},name=liveBattle and tostring(liveBattle.enemy and liveBattle.enemy.name or 'OPPONENT') or 'PREVIEW OPPONENT'}
    local shellBattle=liveBattle or {kind='trainer',enemy=previewEnemy,enemyParty={previewEnemy.mon},trainer={name='PREVIEW TRAINER'}}
    shell(D,m,c,game,shellBattle)
    love.graphics.pop()
    local stats1=love.graphics.getStats and love.graphics.getStats() or {}
    local elapsed=((love.timer and love.timer.getTime and love.timer.getTime() or os.clock())-t0)*1000
    local mem1=collectgarbage and collectgarbage('count') or mem0
    return {bounds=bounds,uiBounds=uiBounds,sceneAnchors={player=pg,opponent=eg},backdrop=backdrop,playerArt=playerArt,opponentArt=opponentArt,
      performance={renderMs=elapsed,fps=love.timer and love.timer.getFPS and love.timer.getFPS() or nil,
        drawCalls=(tonumber(stats1.drawcalls) or 0)-(tonumber(stats0.drawcalls) or 0),
        canvasSwitches=(tonumber(stats1.canvasswitches) or 0)-(tonumber(stats0.canvasswitches) or 0),
        allocationKb=mem1-mem0,textureMemory=stats1.texturememory},
      pipeline='battle_presenter.shared',editorContract=P.liveEditorContract and P.liveEditorContract() or nil}
  end

  -- Future Live Battle UI editing contract. Targets point at the exact renderer
  -- functions used by BattlePresenter today; the editor must parameterize these
  -- layouts rather than create visual copies. `movable=false` documents that
  -- UI editing is architectural preparation only in this pass.
  local LIVE_EDITOR_TARGETS={
    {id='opponent_frame',component='battle.hud.opponent',renderer=hud,movable=true},
    {id='player_frame',component='battle.hud.player',renderer=hud,movable=true},
    {id='command_list',component='battle.commands',renderer=commandCard,movable=true},
    {id='move_menu',component='battle.moves',renderer=moveDock,movable=true},
    {id='trainer_intro',component='battle.trainer.intro',renderer='trainerPresentation',movable=true},
    {id='trainer_battle',component='battle.trainer.battle',renderer='trainerPresentation',movable=true},
    {id='trainer_post',component='battle.trainer.post',renderer='trainerPresentation',movable=true},
  }
  function P.liveEditorContract()
    local targets={}
    for i,v in ipairs(LIVE_EDITOR_TARGETS) do targets[i]={id=v.id,component=v.component,renderer=v.renderer,movable=v.movable} end
    return {version=1,owner='kanto_rework_ui.BattlePresenter',sharedPipeline=true,targets=targets}
  end

  function P.handles(game) return presentationActive(game) and runtime.Layout.isWide(runtime.viewport) end
  function P.interactive(game) return interactive(game) and runtime.Layout.isWide(runtime.viewport) end
  function P.ownsChoice(game,state)
    if not runtime.Layout.isWide(runtime.viewport) then return false end
    local b,top,stat,choice=battleContext(game)
    return b~=nil and choice~=nil and choice==state and top==state
  end
  function P.draw(game,viewport)
    local s,top,stat,choice=battleContext(game);if not s or not runtime.Layout.isWide(viewport) then return false end
    local m=runtime.Layout.metrics(viewport);local c=runtime.Theme.resolveAll(runtime,game);local D=runtime.Draw;local policy=compatPolicy(game,s)
    love.graphics.push('all');love.graphics.origin()
    local bgMode=s.bgMode and s:bgMode() or 'white'
    local backdrop=backdropKind(game,s)
    local groundAnchors=nil
    local sceneConfig=resolvedGraphicsEditorConfig(game,backdrop) or {}
    if policy.backgroundOwner~='voxel' and bgMode~='world' and battleBackgroundsEnabled() then
      drawBackdrop(D,m,c,backdrop,sceneConfig.background)
      if type(BattleBackgrounds.groundAnchors)=='function' then
        local raw=BattleBackgrounds.groundAnchors(backdrop)
        if raw then groundAnchors={player=transformBackdropPoint(raw.player,sceneConfig.background),enemy=transformBackdropPoint(raw.enemy,sceneConfig.background),profile=raw.profile} end
      end
    end
    local uiLayout=battleLayout(game)
    local visualBounds=drawSprites(game,m,s,groundAnchors,backdrop,uiLayout)
    visualBounds=decorateAnimationAnchors(s,visualBounds)
    runtime.battleVisualAnchors=visualBounds
    local gx=visualsExports()
    if gx and gx.battleVisuals and type(gx.battleVisuals.update)=='function' then
      pcall(gx.battleVisuals.update,visualBounds,{x=m.ox,y=m.oy+86*m.scale,w=1920*m.scale,h=930*m.scale,logical={x=0,y=86,w=1920,h=930}})
    end
    -- All move/buff/debuff/status visuals are composed after battlers but before
    -- Battle HUD and global KRS chrome. Both authored sub-layers consume the same
    -- CURRENT per-frame bounds, so self/target/projectile effects follow moved
    -- sprites rather than inheriting static battle-background coordinates.
    externalBattleAnimLayer(game,m,'back',visualBounds)
    externalBattleAnimLayer(game,m,'front',visualBounds)
    drawAttackAnimation(m,s,visualBounds)
    runtime.battleRects={};runtime.battleChoiceRects=nil
    if not choice and not stat and s.phase=='moveSelect' then moveDock(D,m,c,game,s,uiLayout.move_menu) end
    local showEnemyHud,showPlayerHud=hudVisibility(game,s)
    if showEnemyHud then hudWithLayout(D,m,c,game,s.enemy,uiLayout,'opponent_frame',1100,220,400,100,true) end
    if showPlayerHud and s.player then
      hudWithLayout(D,m,c,game,s.player,uiLayout,'player_frame',280,480,400,120,false)
    end
    local prompts={{navigation=true,label='SELECCIONAR'},{action='a',label=choice and 'CONFIRMAR' or 'ABRIR'},{action='BATTLE_INFO',label='INFO COMBATE'},{action='LIVE_BATTLE_EDITOR',label='EDITAR UI'}}
    if runtime.battleInfoOpen then prompts[#prompts+1]={action='b',label='VOLVER'} end
    if runtime.suppressBattleMessage then
      -- A higher KRS-owned semantic overlay (e.g. MoveLearn TextBox) owns the
      -- dialogue surface while BattleState remains the world/HUD source.
    elseif choice then
      local layout=battleMessage(D,m,c,s,choice);runtime.battleChoiceRects=layout and layout.choiceRects or nil
    elseif not stat and s.phase=='menu' then
      local defs=s.safari and {
        {'SAFARI BALL','Safari Balls · '..tostring(s.safari.balls or 0),'bag'},
        {'CEBO','Hace menos probable que huya','pokemon'},
        {'ROCA','Más fácil de capturar','fight'},
        {'HUIR','Salir de la Zona Safari','run'},
      } or {{'LUCHA','Movimientos de ataque y estado','fight'},{'POKÉMON','Cambiar de Pokémon','pokemon'},{'MOCHILA','Usar un objeto de la bolsa','bag'},{'HUIR','Intentar escapar del combate','run'}}
      local _,rects=commandBlock(D,m,c,defs,s.menuIndex,uiLayout);runtime.battleRects=rects
    elseif not stat and s.phase~='moveSelect' then battleMessage(D,m,c,s,nil) end
    battleInfoPanel(D,m,c,s);levelUpPanel(game,D,m,c,stat)
    -- Global KRS chrome is final by contract: nothing in the battle scene may
    -- paint over the 0..86 header or 1016..1080 footer.
    shell(D,m,c,game,s);footer(game,m,c,prompts);love.graphics.pop();return true
  end
  function P.keypressed(game,key)
    local s,top,stat,choice=battleContext(game)
    if not s then return false end
    local actions=runtime.Core and runtime.Core.inputActions
    local function bound(action)
      return actions and type(actions.binding)=='function' and tostring(actions.binding(action,'key') or '')==tostring(key)
    end
    -- Consume the physical key so Gen1Recomp's native battle input cannot act
    -- on the same press. The semantic action itself executes from input.step.
    if bound('LIVE_BATTLE_EDITOR') or bound('BATTLE_INFO') then return true end
    if not interactive(game) then return false end
    if stat or choice then return false end
    if runtime.battleInfoOpen and (key=='escape' or key=='backspace') then runtime.battleInfoOpen=false;return true end
    return false
  end
  function P.pointer(game,event,lx,ly)
    local s,top,stat,choice=battleContext(game);if not s then return false end
    -- The whole KRS battle surface owns the physical mouse. During non-menu
    -- message/animation phases a click maps to the same native A/B actions,
    -- so the cursor does not disappear between command selections.
    if not interactive(game) then
      if event.phase=='pressed' then
        if event.source=='mouse' and event.button==2 then runtime.mod.input:tap(game,'b')
        elseif event.source=='touch' or event.button==1 then runtime.mod.input:tap(game,'a') end
      end
      return true
    end
    if stat then if event.phase=='pressed' and (event.source=='touch' or event.button==1 or event.button==2) then runtime.mod.input:tap(game,'a') end;return true end
    if choice then
      if event.phase=='moved' then
        for i,r in ipairs(runtime.battleChoiceRects or {}) do if runtime.Layout.contains(lx,ly,r) then choice.index=i;break end end
        return true
      end
      if event.phase=='pressed' then
        if event.source=='mouse' and event.button==2 then runtime.mod.input:tap(game,'b');return true end
        if event.source=='touch' or event.button==1 then
          for i,r in ipairs(runtime.battleChoiceRects or {}) do if runtime.Layout.contains(lx,ly,r) then choice.index=i;runtime.mod.input:tap(game,'a');return true end end
        end
      end
      return true
    end
    if runtime.battleInfoOpen then if event.phase=='pressed' and event.button==2 then runtime.battleInfoOpen=false end;return true end
    if event.phase=='moved' then for i,r in pairs(runtime.battleRects or {}) do if runtime.Layout.contains(lx,ly,r) then if s.phase=='menu' then s.menuIndex=i else s.moveIndex=i end;return true end end;return true end
    if event.phase=='pressed' then
      if event.source=='mouse' and event.button==2 then runtime.mod.input:tap(game,'b');return true end
      if event.source=='touch' or event.button==1 then for i,r in pairs(runtime.battleRects or {}) do if runtime.Layout.contains(lx,ly,r) then if s.phase=='menu' then s.menuIndex=i else s.moveIndex=i end;runtime.mod.input:tap(game,'a');return true end end end
    end
    return event.phase=='released' or event.phase=='cancelled'
  end
  P.isStatBox=isStatBox
  return P
end
