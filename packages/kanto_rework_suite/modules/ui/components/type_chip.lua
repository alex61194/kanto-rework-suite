-- KRS / Feedback / Type Token
-- Figma component set 618:2865: 148x36, semantic type background, 2px white
-- border, 6px horizontal padding, 8px gap, canonical 20x20 Type Glyph,
-- Inter Semi Bold 12/16 inverse label.
return function(deps)
  local TypeIcon=assert(deps.TypeIcon)
  local runtime=deps.runtime or {}
  local TypeChip={}
  local fonts={}
  local PURE_WHITE={1,1,1,1}

  local function setColor(c,alpha)
    c=c or PURE_WHITE
    love.graphics.setColor(c[1] or 1,c[2] or 1,c[3] or 1,(c[4] or 1)*(alpha or 1))
  end

  local function font(px)
    px=math.max(8,math.floor((tonumber(px) or 12)+.5))
    local family=runtime.fontFamily
    if runtime.Theme and type(runtime.Theme.fontFamily)=="function" then local ok,v=pcall(runtime.Theme.fontFamily);if ok and v then family=v end end
    local key=tostring(family or "default")..":"..tostring(px)
    if fonts[key] then return fonts[key] end
    local f
    local typography=runtime.Core and runtime.Core.typography
    if not f and typography and family and type(typography.font)=="function" then local ok,v=pcall(typography.font,family,"semibold",px);if ok and v then f=v end end
    local paths=typography and family and type(typography.paths)=="function" and typography.paths(family) or runtime.fontPaths
    local path=paths and (paths.semibold or paths.regular)
    if not f and path then local ok,v=pcall(love.graphics.newFont,path,px);if ok then f=v end end
    if not f then local ok,v=pcall(love.graphics.newFont,px);if ok then f=v end end
    f=f or love.graphics.getFont()
    if f and family=="kanto_rework.pixelify_sans" and type(f.setFilter)=="function" then pcall(f.setFilter,f,"nearest","nearest",1) end
    fonts[key]=f;return f
  end

  local TYPE_SPANISH={
    NORMAL="NORMAL",FIRE="FUEGO",WATER="AGUA",GRASS="PLANTA",ELECTRIC="ELÉCTRICO",
    ICE="HIELO",FIGHTING="LUCHA",POISON="VENENO",GROUND="TIERRA",FLYING="VOLADOR",
    PSYCHIC="PSÍQUICO",BUG="BICHO",ROCK="ROCA",GHOST="FANTASMA",DRAGON="DRAGÓN",
    STEEL="ACERO",DARK="SINIESTRO",FAIRY="HADA",UNKNOWN="DESCONOCIDO",
  }

  function TypeChip.draw(kind,x,y,scale,theme,alpha)
    local rawKind=tostring(kind or "UNKNOWN"):upper()
    scale=tonumber(scale) or 1
    local typeColors=theme and theme.typeColors or {}
    local colors=theme and theme.colors or {}
    local background=typeColors[rawKind] or colors.faint or {0.5,0.5,0.5,1}
    local labelColor=colors.textInverse or colors.white or {247/255,241/255,223/255,1}
    local w,h=148*scale,36*scale
    local radius=math.min(w,h)/2
    local lw=math.max(1,2*scale)

    love.graphics.push("all")
    setColor(background,alpha)
    love.graphics.rectangle("fill",x,y,w,h,radius,radius)
    setColor(PURE_WHITE,alpha)
    love.graphics.setLineWidth(lw)
    love.graphics.rectangle("line",x+lw/2,y+lw/2,w-lw,h-lw,math.max(0,radius-lw/2),math.max(0,radius-lw/2))

    -- Exact Figma layout: px=6, glyph=20, gap=8 => label starts at x+34.
    TypeIcon.drawGlyph(rawKind,x+16*scale,y+18*scale,20*scale,PURE_WHITE,alpha)
    local f=font(12*scale);love.graphics.setFont(f);setColor(labelColor,alpha)
    local tx=x+34*scale
    local ty=y+(h-f:getHeight())/2
    local label=TYPE_SPANISH[rawKind] or rawKind
    love.graphics.print(label,tx,ty)
    love.graphics.pop()
    return true
  end

  TypeChip.FIGMA={set="618:2865",width=148,height=36,border=2,radius=300,paddingX=6,paddingY=8,gap=8,glyph=20,text=12,lineHeight=16}
  return TypeChip
end
