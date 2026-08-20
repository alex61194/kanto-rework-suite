-- KRS / Feedback / Status Icon + Status Token
-- Canonical Figma sources:
--   glyph set  627:2304 : transparent 32x32 white-vector glyphs
--   compact set 405:3994 : 32x32 semantic container + canonical glyph
--   full set    149:116  : 188x40 badge containing the compact icon
--
-- Glyph geometry is never reconstructed in Lua. Only semantic containers,
-- borders and the Badly Poisoned marker background are runtime geometry.
return function(deps)
  local C=assert(deps.C)
  local Assets=assert(deps.Assets)
  local mod=assert(deps.mod)
  local runtime=deps.runtime or {}
  local Status={}
  local imageCache={}
  local fontCache={}
  local PURE_WHITE={1,1,1,1}

  local defs={
    PSN={semantic="POISONED",label="ENVENENADO",node="149:74",iconNode="618:2529",glyph="POISONED",glyphNode="627:2272"},
    TOX={semantic="BADLY_POISONED",label="GRAV. ENVENENADO",node="149:80",iconNode="618:2535",glyph="BADLY_POISONED",glyphNode="627:2278",severe=true},
    BRN={semantic="BURNED",label="QUEMADO",node="149:86",iconNode="618:2553",glyph="BURNED",glyphNode="627:2285"},
    PAR={semantic="PARALYZED",label="PARALIZADO",node="149:92",iconNode="618:2520",glyph="PARALYZED",glyphNode="627:2287"},
    SLP={semantic="ASLEEP",label="DORMIDO",node="149:98",iconNode="618:2557",glyph="ASLEEP",glyphNode="627:2289"},
    FRZ={semantic="FROZEN",label="CONGELADO",node="149:104",iconNode="618:2524",glyph="FROZEN",glyphNode="627:2295"},
    FNT={semantic="FAINTED",label="DEBILITADO",node="149:110",iconNode="177:101",glyph="FAINTED",glyphNode="627:2300"},
  }

  local aliases={
    POISONED="PSN",POISON="PSN",PSN="PSN",ENVENENADO="PSN",ENV="PSN",
    TOXIC="TOX",TOX="TOX",["BADLY POISONED"]="TOX",BADLY_POISONED="TOX",BADLYPOISONED="TOX",["GRAVEMENTE ENVENENADO"]="TOX",GRAVEMENTE_ENVENENADO="TOX",
    BURNED="BRN",BURN="BRN",BRN="BRN",QUEMADO="BRN",QUE="BRN",
    PARALYZED="PAR",PARALYSED="PAR",PAR="PAR",PARALIZADO="PAR",
    ASLEEP="SLP",SLEEP="SLP",SLP="SLP",DORMIDO="SLP",DOR="SLP",
    FROZEN="FRZ",FREEZE="FRZ",FRZ="FRZ",CONGELADO="FRZ",CON="FRZ",
    FAINTED="FNT",FAINT="FNT",FNT="FNT",KO="FNT",DEBILITADO="FNT",DEB="FNT",
  }

  -- Exact default values resolved from the Figma Status Token / Status Icon
  -- components. Accessibility profiles may replace these semantic roles.
  local standard={
    POISONED={outline={153/255,46/255,235/255,1},icon={147/255,84/255,203/255,1}},
    BADLY_POISONED={outline={99/255,20/255,173/255,1},icon={147/255,84/255,203/255,1},marker={99/255,20/255,173/255,1}},
    BURNED={outline={255/255,110/255,46/255,1},icon={228/255,97/255,62/255,1}},
    PARALYZED={outline={245/255,194/255,46/255,1},icon={223/255,188/255,40/255,1}},
    ASLEEP={outline={87/255,87/255,92/255,1},icon={87/255,87/255,92/255,1}},
    FROZEN={outline={71/255,200/255,200/255,1},icon={71/255,200/255,200/255,1}},
    FAINTED={outline={71/255,71/255,79/255,1},icon={71/255,71/255,79/255,1}},
  }

  local function canonical(status,hp)
    if tonumber(hp) and tonumber(hp)<=0 then return "FNT" end
    if status==nil then return nil end
    local raw=tostring(status):upper():gsub("-"," ")
    if raw=="" or raw=="OK" or raw=="NONE" or raw=="HEALTHY" then return nil end
    return aliases[raw] or aliases[raw:gsub(" ","_")]
  end

  local function setColor(c,alpha)
    c=c or PURE_WHITE
    love.graphics.setColor(c[1] or 1,c[2] or 1,c[3] or 1,(c[4] or 1)*(alpha or 1))
  end

  local function semanticColors(def,theme)
    local profile=theme and theme.statusColors
    return (profile and profile[def.semantic]) or standard[def.semantic]
  end

  local function font(px,weight)
    px=math.max(8,math.floor((tonumber(px) or 12)+.5));weight=weight or "regular"
    local family=runtime.fontFamily
    if runtime.Theme and type(runtime.Theme.fontFamily)=="function" then local ok,v=pcall(runtime.Theme.fontFamily);if ok and v then family=v end end
    local key=tostring(family or "default")..":"..tostring(px)..":"..tostring(weight)
    if fontCache[key] then return fontCache[key] end
    local f
    local typography=runtime.Core and runtime.Core.typography
    if not f and typography and family and type(typography.font)=="function" then local ok,v=pcall(typography.font,family,weight,px);if ok and v then f=v end end
    local paths=typography and family and type(typography.paths)=="function" and typography.paths(family) or runtime.fontPaths
    local path=paths and (paths[weight] or paths.regular)
    if not f and path then local ok,v=pcall(love.graphics.newFont,path,px);if ok then f=v end end
    if not f then local ok,v=pcall(love.graphics.newFont,px);if ok then f=v end end
    f=f or love.graphics.getFont()
    if f and family=="kanto_rework.pixelify_sans" and type(f.setFilter)=="function" then pcall(f.setFilter,f,"nearest","nearest",1) end
    fontCache[key]=f;return f
  end

  local function choose(def,drawSize)
    local spec=Assets.statusGlyphs[def.glyph]
    if not spec or type(spec.runtime)~="table" then return nil,nil end
    drawSize=math.max(1,tonumber(drawSize) or 32)
    local target=drawSize*2
    local chosen=spec.runtime[#spec.runtime]
    for _,variant in ipairs(spec.runtime) do if variant.pixels>=target then chosen=variant;break end end
    return spec,chosen
  end

  local function loadGlyph(def,drawSize)
    local spec,chosen=choose(def,drawSize)
    if not chosen then return spec,nil,nil end
    if imageCache[chosen.path]~=nil then return spec,imageCache[chosen.path] or nil,chosen end
    local ok,img=pcall(function()
      if mod.assets and mod.assets.image then return mod.assets:image(chosen.path) end
      return love.graphics.newImage(mod.assets:path(chosen.path))
    end)
    if not ok or not img then imageCache[chosen.path]=false return spec,nil,chosen end
    if img.setFilter then img:setFilter("linear","linear") end
    imageCache[chosen.path]=img
    return spec,img,chosen
  end

  local function drawGlyph(def,cx,cy,size,alpha)
    local spec,img=loadGlyph(def,size);if not spec or not img then return false end
    local okDim,iw,ih=pcall(img.getDimensions,img)
    if not (okDim and tonumber(iw) and iw>0 and tonumber(ih) and ih>0) then return false end
    setColor(PURE_WHITE,alpha)
    return pcall(love.graphics.draw,img,cx-size/2,cy-size/2,0,size/iw,size/ih)
  end

  local function drawAtomic(def,cx,cy,size,theme,alpha)
    local sem=semanticColors(def,theme)
    setColor(sem.icon,alpha)
    pcall(love.graphics.circle,"fill",cx,cy,size/2)
    if def.severe then
      local markerSize=size*(12/32)
      local mx=cx+size*(10/32);local my=cy-size*(10/32)
      setColor(sem.marker or sem.outline,alpha)
      pcall(love.graphics.circle,"fill",mx,my,markerSize/2)
      setColor(PURE_WHITE,alpha)
      pcall(love.graphics.setLineWidth,size/32)
      pcall(love.graphics.circle,"line",mx,my,math.max(0,markerSize/2-size/64))
    end
    return drawGlyph(def,cx,cy,size,alpha)
  end

  function Status.normalize(status,hp) return canonical(status,hp) end
  function Status.spec(status,hp) local key=canonical(status,hp);return key and defs[key] or nil end

  function Status.drawIcon(status,hp,cx,cy,size,theme,alpha)
    local def=Status.spec(status,hp);if not def then return false end
    return drawAtomic(def,cx,cy,tonumber(size) or 32,theme,alpha)
  end

  function Status.drawToken(status,hp,x,y,scale,theme,alpha)
    local def=Status.spec(status,hp);if not def then return false end
    scale=tonumber(scale) or 1
    local colors=(theme and theme.colors) or C.colors
    local sem=semanticColors(def,theme)
    local w,h=188*scale,40*scale
    local radius=12*scale
    local lw=math.max(1,2*scale)
    love.graphics.push("all")
    setColor(colors.panel or {1,1,1,1},alpha)
    love.graphics.rectangle("fill",x,y,w,h,radius,radius)
    setColor(sem.outline,alpha);love.graphics.setLineWidth(lw)
    love.graphics.rectangle("line",x+lw/2,y+lw/2,w-lw,h-lw,math.max(0,radius-lw/2),math.max(0,radius-lw/2))
    drawAtomic(def,x+20*scale,y+20*scale,32*scale,theme,alpha)
    local f=font(12*scale,"semibold");love.graphics.setFont(f)
    setColor(colors.text or colors.ink or C.colors.ink,alpha)
    local tx=x+46*scale;local ty=y+(h-f:getHeight())/2
    love.graphics.print(def.label,tx,ty)
    love.graphics.pop();return true
  end

  function Status.assetPath(status,hp,size)
    local def=Status.spec(status,hp);if not def then return nil end
    local _,chosen=choose(def,size or 32);return chosen and chosen.path or nil
  end

  function Status.glyphSpec(status,hp)
    local def=Status.spec(status,hp);return def and Assets.statusGlyphs[def.glyph] or nil
  end

  Status.FIGMA={
    glyphSet="627:2304",compactSet="405:3994",set="149:116",noneNode="393:3814",
    full={width=188,height=40,radius=12,border=2,paddingLeft=4,paddingRight=12,gap=10,icon=32,text=12},
    compact={width=32,height=32},severeMarker={x=20,y=0,width=12,height=12,border=1},
  }
  return Status
end
