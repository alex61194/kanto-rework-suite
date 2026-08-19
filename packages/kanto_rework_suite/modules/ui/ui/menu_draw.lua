local Draw = {}
local okUtf8, utf8lib = pcall(require, "utf8")
if not okUtf8 then utf8lib = nil end

local function setColor(c, alpha)
  if not (love and love.graphics) then return end
  love.graphics.setColor(c[1], c[2], c[3], alpha or c[4] or 1)
end

Draw.setColor = setColor

function Draw.roundRect(m, mode, x, y, w, h, radius, color, lineWidth)
  local g = love.graphics
  setColor(color)
  if lineWidth then g.setLineWidth(math.max(1, lineWidth * m.scale)) end
  g.rectangle(mode, m.ox + x*m.scale, m.oy + y*m.scale,
    w*m.scale, h*m.scale, radius*m.scale, radius*m.scale)
end

function Draw.line(m, x1, y1, x2, y2, color, width)
  local g = love.graphics
  setColor(color)
  g.setLineWidth(math.max(1, (width or 1) * m.scale))
  g.line(m.ox + x1*m.scale, m.oy + y1*m.scale,
    m.ox + x2*m.scale, m.oy + y2*m.scale)
end

function Draw.font(runtime, m, size, weight)
  local px = math.max(8, math.floor(size * m.scale + 0.5))
  local family=runtime.fontFamily
  if runtime.Theme and type(runtime.Theme.fontFamily)=="function" then
    local ok,value=pcall(runtime.Theme.fontFamily)
    if ok and type(value)=="string" and value~="" then family=value end
  end
  local key = tostring(family or "default") .. ":" .. tostring(px) .. ":" .. tostring(weight or "regular")
  runtime.fonts = runtime.fonts or {}
  if runtime.fonts[key] then return runtime.fonts[key] end

  local font
  local typography=runtime.Core and runtime.Core.typography
  if not font and typography and family and type(typography.font)=="function" then
    local ok,loaded=pcall(typography.font,family,weight or "regular",px)
    if ok and loaded then font=loaded end
  end
  local familyPaths=typography and family and type(typography.paths)=="function" and typography.paths(family) or nil
  local fallbackPaths=familyPaths or runtime.fontPaths
  if not font and fallbackPaths then
    local path = fallbackPaths[weight or "regular"] or fallbackPaths.regular
    if path then
      local ok, loaded = pcall(love.graphics.newFont, path, px)
      if ok then font = loaded end
    end
  end
  if not font then
    local ok, loaded = pcall(love.graphics.newFont, px)
    if ok then font = loaded else font = love.graphics.getFont() end
  end
  if font and type(font.setFallbacks)=="function" and runtime.fontFallbackPath then
    runtime.fallbackFonts=runtime.fallbackFonts or {}
    local fallback=runtime.fallbackFonts[px]
    if fallback==nil then
      local ok,loaded=pcall(love.graphics.newFont,runtime.fontFallbackPath,px)
      fallback=ok and loaded or false;runtime.fallbackFonts[px]=fallback
    end
    if fallback then pcall(font.setFallbacks,font,fallback) end
  end
  if font and family=="kanto_rework.pixelify_sans" and type(font.setFilter)=="function" then
    pcall(font.setFilter,font,"nearest","nearest",1)
  end
  runtime.fonts[key] = font
  return font
end

local SPECIAL={ ["♀"]="female", ["♂"]="male" }

local function glyphList(value)
  local out={}
  if utf8lib and utf8lib.codes and utf8lib.char then
    for _,code in utf8lib.codes(value) do out[#out+1]=utf8lib.char(code) end
  else
    local i=1
    while i<=#value do
      local b=value:byte(i);local n=(b and b>=240 and 4) or (b and b>=224 and 3) or (b and b>=192 and 2) or 1
      out[#out+1]=value:sub(i,i+n-1);i=i+n
    end
  end
  return out
end

local function customGlyphWidth(font,glyph)
  if SPECIAL[glyph] then return math.max(5,font:getHeight()*0.68) end
  return font:getWidth(glyph)
end

local function measureText(font,value,trackingPx)
  local glyphs=glyphList(value);local total=0
  for i,glyph in ipairs(glyphs) do
    total=total+customGlyphWidth(font,glyph)+(i<#glyphs and (trackingPx or 0) or 0)
  end
  return total,glyphs
end

local function drawGenderGlyph(g,font,glyph,x,y)
  local h=font:getHeight();local w=customGlyphWidth(font,glyph);local cx=x+w*0.43;local cy=y+h*0.40;local r=h*0.20
  local oldWidth=g.getLineWidth and g.getLineWidth() or 1
  g.setLineWidth(math.max(1,h*0.075))
  g.circle("line",cx,cy,r)
  if glyph=="♀" then
    local stemTop=cy+r;local stemBottom=y+h*0.84
    g.line(cx,stemTop,cx,stemBottom)
    g.line(cx-r*0.60,y+h*0.69,cx+r*0.60,y+h*0.69)
  else
    local sx,sy=cx+r*0.70,cy-r*0.70;local ex,ey=x+w*0.88,y+h*0.10
    g.line(sx,sy,ex,ey)
    g.line(ex,ey,ex-r*0.62,ey+r*0.08)
    g.line(ex,ey,ex-r*0.08,ey+r*0.62)
  end
  g.setLineWidth(oldWidth)
  return w
end

function Draw.text(runtime, m, text, x, y, size, color, opts)
  opts = opts or {}
  local g = love.graphics
  local font = Draw.font(runtime, m, size, opts.weight)
  g.setFont(font)
  setColor(color, opts.alpha)
  local px, py = m.ox + x*m.scale, m.oy + y*m.scale
  local tracking=(tonumber(opts.tracking) or 0)*m.scale
  local value=tostring(text or "")
  local hasSpecial=value:find("♀",1,true) or value:find("♂",1,true)
  if hasSpecial or (tracking~=0 and not value:find("\n",1,true)) then
    local total,glyphs=measureText(font,value,tracking)
    if opts.width and opts.align=="center" then px=px+(opts.width*m.scale-total)/2
    elseif opts.width and opts.align=="right" then px=px+opts.width*m.scale-total end
    for i,glyph in ipairs(glyphs) do
      local advance
      if SPECIAL[glyph] then advance=drawGenderGlyph(g,font,glyph,px,py)
      else g.print(glyph,px,py);advance=font:getWidth(glyph) end
      px=px+advance+(i<#glyphs and tracking or 0)
    end
  elseif opts.width then
    g.printf(value, px, py, opts.width*m.scale, opts.align or "left")
  else
    g.print(value, px, py)
  end
end

function Draw.clipText(runtime, m, text, x, y, width, size, color, opts)
  opts = opts or {}
  local font = Draw.font(runtime, m, size, opts.weight)
  love.graphics.setFont(font)
  local target = tostring(text or "")
  local maxPx = width * m.scale
  local tracking=(tonumber(opts.tracking) or 0)*m.scale
  local function widthOf(value) return measureText(font,value,tracking) end
  if widthOf(target) > maxPx then
    local suffix = "…"
    local function popUtf8(value)
      if value=="" then return "" end
      if utf8lib and utf8lib.offset then
        local last=utf8lib.offset(value,-1);if last then return value:sub(1,last-1) end
      end
      local i=#value
      while i>1 do local b=value:byte(i);if not b or b<128 or b>=192 then break end;i=i-1 end
      return value:sub(1,i-1)
    end
    while target~="" and widthOf(target .. suffix) > maxPx do target=popUtf8(target) end
    target=target..suffix
  end
  Draw.text(runtime,m,target,x,y,size,color,opts)
end

Draw.measureText=function(runtime,m,text,size,opts)
  opts=opts or {};local font=Draw.font(runtime,m,size,opts.weight)
  return measureText(font,tostring(text or ""),(tonumber(opts.tracking) or 0)*m.scale)
end

function Draw.panel(m, x, y, w, h, radius, fill, border)
  Draw.roundRect(m, "fill", x, y, w, h, radius, fill)
  if border then Draw.roundRect(m, "line", x, y, w, h, radius, border, 1) end
end

function Draw.dropShadow(m,x,y,w,h,radius,samples)
  for _,sample in ipairs(samples or {}) do
    local spread=tonumber(sample.spread) or 0
    Draw.roundRect(m,"fill",
      x+(tonumber(sample.offsetX) or 0)-spread,
      y+(tonumber(sample.offsetY) or 0)-spread,
      w+spread*2,h+spread*2,
      math.max(0,(radius or 0)+spread),
      sample.color or {0,0,0,0})
  end
end

-- Clip arbitrary card content to a real rounded rectangle. Images exported
-- from design tools often retain opaque canvas pixels in their square corners;
-- drawing a rounded outline over them does not hide those pixels. The stencil
-- makes the Lua frame authoritative and keeps images, overlays and future
-- animated content inside the same silhouette.
function Draw.withRoundedClip(m,x,y,w,h,radius,drawContent)
  if type(drawContent)~="function" then return false end
  local g=love and love.graphics
  if not (g and type(g.stencil)=="function" and type(g.setStencilTest)=="function") then
    drawContent()
    return false
  end

  local px=m.ox+x*m.scale
  local py=m.oy+y*m.scale
  local pw=w*m.scale
  local ph=h*m.scale
  local pr=math.max(0,(radius or 0)*m.scale)
  local oldCompare,oldValue
  if type(g.getStencilTest)=="function" then oldCompare,oldValue=g.getStencilTest() end

  g.stencil(function()
    g.rectangle("fill",px,py,pw,ph,pr,pr)
  end,"replace",1,false)
  g.setStencilTest("greater",0)
  local ok,err=xpcall(drawContent,tostring)
  if oldCompare then g.setStencilTest(oldCompare,oldValue) else g.setStencilTest() end
  if not ok then error(err,0) end
  return true
end

function Draw.focusBorder(m, x, y, w, h, radius, color)
  Draw.roundRect(m, "line", x, y, w, h, radius, color, 3)
  Draw.roundRect(m, "fill", x + 10, y + h/2 - 12, 4, 24, 2, color)
end

function Draw.toggle(m, x, y, on, colors, disabled)
  local track = on and colors.selected or colors.subtle
  Draw.roundRect(m, "fill", x, y, 64, 34, 17, track)
  Draw.roundRect(m, "line", x, y, 64, 34, 17, disabled and colors.disabled or colors.border, 1)
  local tx = on and (x + 34) or (x + 4)
  Draw.roundRect(m, "fill", tx, y + 4, 26, 26, 13, on and colors.textInverse or colors.text)
  -- Geometry marker makes state readable without relying on hue.
  if on then
    Draw.line(m, x + 12, y + 17, x + 17, y + 22, colors.textInverse, 2)
    Draw.line(m, x + 17, y + 22, x + 25, y + 12, colors.textInverse, 2)
  else
    Draw.line(m, x + 42, y + 11, x + 53, y + 22, colors.textSecondary, 2)
    Draw.line(m, x + 53, y + 11, x + 42, y + 22, colors.textSecondary, 2)
  end
end

function Draw.selector(runtime, m, x, y, w, value, colors)
  Draw.roundRect(m, "fill", x, y, w, 40, 8, colors.panel)
  Draw.roundRect(m, "line", x, y, w, 40, 8, colors.border, 1)
  Draw.text(runtime, m, "‹", x + 14, y + 7, 18, colors.textSecondary, {weight="semibold", width=28, align="center"})
  Draw.clipText(runtime, m, value, x + 48, y + 10, w - 96, 14, colors.text, {weight="medium", width=w-96, align="center"})
  Draw.text(runtime, m, "›", x + w - 42, y + 7, 18, colors.textSecondary, {weight="semibold", width=28, align="center"})
end

function Draw.stepper(runtime, m, x, y, w, value, colors)
  Draw.roundRect(m, "fill", x, y, w, 40, 8, colors.panel)
  Draw.roundRect(m, "line", x, y, w, 40, 8, colors.border, 1)
  Draw.text(runtime, m, "−", x + 10, y + 8, 18, colors.textSecondary, {weight="semibold", width=32, align="center"})
  Draw.clipText(runtime, m, value, x + 48, y + 10, w - 96, 14, colors.text, {weight="medium", width=w-96, align="center"})
  Draw.text(runtime, m, "+", x + w - 42, y + 8, 18, colors.textSecondary, {weight="semibold", width=32, align="center"})
end

function Draw.chevron(runtime, m, x, y, colors)
  Draw.roundRect(m, "fill", x, y, 40, 40, 8, colors.subtle)
  Draw.roundRect(m, "line", x, y, 40, 40, 8, colors.border, 1)
  Draw.text(runtime, m, "›", x, y + 6, 20, colors.textSecondary, {weight="semibold", width=40, align="center"})
end

function Draw.icon(runtime, m, kind, x, y, size, colors)
  local g = love.graphics
  local c = colors.text
  setColor(c)
  g.setLineWidth(math.max(1, 2*m.scale))
  local X, Y, S = m.ox+x*m.scale, m.oy+y*m.scale, size*m.scale
  local function rect(mode, rx, ry, rw, rh, r)
    g.rectangle(mode, X+rx*S, Y+ry*S, rw*S, rh*S, (r or 0)*S, (r or 0)*S)
  end
  if kind == "pokemon" then
    g.circle("line", X+S/2, Y+S/2, S*0.34)
    g.line(X+S*0.16,Y+S/2,X+S*0.84,Y+S/2)
    g.circle("fill", X+S/2,Y+S/2,S*0.08)
  elseif kind == "pokedex" then
    rect("line",.2,.18,.6,.66,.05); g.line(X+S*.5,Y+S*.18,X+S*.5,Y+S*.84)
  elseif kind == "bag" then
    rect("line",.22,.35,.56,.48,.08); g.arc("line","open",X+S*.5,Y+S*.36,S*.18,math.pi,2*math.pi)
  elseif kind == "fight" then
    -- Compact fist silhouette matching the functional Figma battle glyph.
    rect("fill",.23,.40,.48,.34,.08);rect("fill",.24,.25,.12,.24,.04);rect("fill",.38,.20,.12,.28,.04);rect("fill",.52,.22,.12,.27,.04);rect("fill",.66,.29,.10,.24,.04)
  elseif kind == "run" then
    g.circle("fill",X+S*.62,Y+S*.20,S*.09)
    g.line(X+S*.58,Y+S*.30,X+S*.46,Y+S*.50);g.line(X+S*.46,Y+S*.50,X+S*.26,Y+S*.46);g.line(X+S*.46,Y+S*.50,X+S*.66,Y+S*.64);g.line(X+S*.66,Y+S*.64,X+S*.80,Y+S*.86);g.line(X+S*.47,Y+S*.49,X+S*.34,Y+S*.78);g.line(X+S*.34,Y+S*.78,X+S*.17,Y+S*.87)
  elseif kind == "pc" then
    rect("line",.16,.2,.68,.5,.04); g.line(X+S*.4,Y+S*.78,X+S*.6,Y+S*.78); g.line(X+S*.5,Y+S*.7,X+S*.5,Y+S*.82)
  elseif kind == "link" then
    g.arc("line","open",X+S*.38,Y+S*.5,S*.24,-1.0,1.0); g.arc("line","open",X+S*.62,Y+S*.5,S*.24,2.14,4.14)
  elseif kind == "save" then
    rect("line",.18,.14,.64,.72,.03); rect("line",.3,.2,.4,.22,.01); rect("line",.3,.58,.4,.2,.01)
  elseif kind == "options" then
    g.circle("line",X+S*.5,Y+S*.5,S*.2); for i=0,7 do local a=i*math.pi/4; g.line(X+S*(.5+.27*math.cos(a)),Y+S*(.5+.27*math.sin(a)),X+S*(.5+.38*math.cos(a)),Y+S*(.5+.38*math.sin(a))) end
  elseif kind == "mods" then
    g.line(X+S*.22,Y+S*.75,X+S*.73,Y+S*.24); g.circle("line",X+S*.7,Y+S*.27,S*.15); g.circle("fill",X+S*.29,Y+S*.68,S*.07)
  elseif kind == "close" then
    g.line(X+S*.25,Y+S*.25,X+S*.75,Y+S*.75); g.line(X+S*.75,Y+S*.25,X+S*.25,Y+S*.75)
  else
    g.circle("fill",X+S/2,Y+S/2,S*.12)
  end
end

function Draw.mapPin(m, x, y, size, color)
  -- Small vector map pin used where the runtime font lacks the Figma glyph.
  local g=love.graphics
  setColor(color)
  local S=(size or 14)*m.scale
  local X=m.ox+x*m.scale;local Y=m.oy+y*m.scale
  g.setLineWidth(math.max(1,1.5*m.scale))
  g.circle("line",X,Y-S*.16,S*.27)
  g.circle("fill",X,Y-S*.16,S*.07)
  g.line(X-S*.19,Y+S*.02,X,Y+S*.42)
  g.line(X+S*.19,Y+S*.02,X,Y+S*.42)
end

function Draw.star(m, x, y, outerRadius, color, innerRadius)
  -- Vector five-point star: avoid depending on Unicode font coverage.
  local g = love.graphics
  setColor(color)
  local ro = (outerRadius or 8) * m.scale
  local ri = (innerRadius or ((outerRadius or 8) * 0.45)) * m.scale
  local cx = m.ox + x*m.scale
  local cy = m.oy + y*m.scale
  local pts = {}
  for i = 0, 9 do
    local r = (i % 2 == 0) and ro or ri
    local a = -math.pi/2 + i*math.pi/5
    pts[#pts+1] = cx + math.cos(a)*r
    pts[#pts+1] = cy + math.sin(a)*r
  end
  g.polygon("fill", pts)
end

function Draw.pokedollar(m, x, y, size, color)
  -- Dedicated vector glyph: avoids relying on Unicode coverage in the runtime font.
  local g = love.graphics
  setColor(color)
  local S = size * m.scale
  local X, Y = m.ox + x*m.scale, m.oy + y*m.scale
  g.setLineWidth(math.max(1, 1.6*m.scale))
  -- Stylised Pokémon currency P with the canonical double crossbar cue.
  g.line(X + S*.28, Y + S*.08, X + S*.28, Y + S*.92)
  g.arc("line", "open", X + S*.47, Y + S*.30, S*.22, -math.pi/2, math.pi/2)
  g.line(X + S*.28, Y + S*.08, X + S*.47, Y + S*.08)
  g.line(X + S*.28, Y + S*.52, X + S*.47, Y + S*.52)
  g.line(X + S*.10, Y + S*.60, X + S*.60, Y + S*.60)
  g.line(X + S*.10, Y + S*.72, X + S*.53, Y + S*.72)
end

return Draw
