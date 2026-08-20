-- KRS / Icon / Type Glyph + KRS / Feedback / Type Icon
-- Canonical Figma sources:
--   glyph set 625:2266 : transparent 20x20 canvas, white vector geometry
--   icon set  618:2641 : 32x32 semantic circle + centred 20x20 glyph
--
-- Runtime PNGs are generated from the canonical SVGs. The complete SVG canvas
-- is always scaled, never the visual trace bbox, so Figma's optical padding is
-- preserved exactly across every type.
return function(deps)
  local Assets=assert(deps.Assets)
  local mod=assert(deps.mod)
  local cache={}
  local TypeIcon={}
  local WHITE={1,1,1,1}
  local GLYPH_TO_ICON=20/32

  local function entry(kind)
    local key=tostring(kind or "UNKNOWN"):upper()
    if key=='PSYCH_TYPE' or key=='PSYCHIC_TYPE' or key=='PSYCH' then key='PSYCHIC' else key=key:gsub('_TYPE$','') end
    return Assets.typeGlyphs[key]
  end

  local function choose(kind,drawSize)
    local spec=entry(kind)
    if type(spec)~="table" or type(spec.runtime)~="table" then return nil,nil end
    drawSize=math.max(1,tonumber(drawSize) or spec.canvas.width or 20)
    -- Keep at least ~2 source pixels per destination pixel when a density is
    -- available. At the validated 1280..2560 Wide targets this always
    -- downsamples a vector-derived raster and never upscales a small PNG.
    local target=drawSize*2
    local chosen=spec.runtime[#spec.runtime]
    for _,variant in ipairs(spec.runtime) do
      if variant.pixels>=target then chosen=variant;break end
    end
    return spec,chosen
  end

  local function load(kind,drawSize)
    local spec,chosen=choose(kind,drawSize)
    if not chosen then return spec,nil,nil end
    local key=chosen.path
    if cache[key]~=nil then return spec,cache[key] or nil,chosen end
    local ok,img=pcall(function()
      if mod.assets and mod.assets.image then return mod.assets:image(chosen.path) end
      return love.graphics.newImage(mod.assets:path(chosen.path))
    end)
    if not ok or not img then cache[key]=false return spec,nil,chosen end
    if img.setFilter then img:setFilter("linear","linear") end
    cache[key]=img
    return spec,img,chosen
  end

  local function setColor(c,alpha)
    c=c or WHITE
    love.graphics.setColor(c[1] or 1,c[2] or 1,c[3] or 1,(c[4] or 1)*(alpha or 1))
  end

  -- Draw the complete canonical 20x20 glyph canvas at `size` physical pixels.
  -- `size` is NOT the visual trace size; internal Figma padding is retained.
  function TypeIcon.drawGlyph(kind,cx,cy,size,color,alpha)
    size=math.max(1,tonumber(size) or 20)
    local spec,img=load(kind,size)
    if not spec or not img then return false end
    local okDim,iw,ih=pcall(img.getDimensions,img)
    if not (okDim and tonumber(iw) and iw>0 and tonumber(ih) and ih>0) then return false end
    local sx=size/iw;local sy=size/ih
    setColor(color or WHITE,alpha)
    local ok=pcall(love.graphics.draw,img,cx-size/2,cy-size/2,0,sx,sy)
    return ok
  end

  -- Canonical compact Type Icon: 32x32 container, 20x20 glyph.
  function TypeIcon.draw(kind,cx,cy,size,typeColor,alpha)
    size=math.max(1,tonumber(size) or 32)
    setColor(typeColor,alpha)
    pcall(love.graphics.circle,"fill",cx,cy,size/2)
    return TypeIcon.drawGlyph(kind,cx,cy,size*GLYPH_TO_ICON,WHITE,alpha)
  end

  function TypeIcon.loaded(kind,size) local _,img=load(kind,size or 20);return img~=nil end
  function TypeIcon.variant(kind,size) local _,v=choose(kind,size or 20);return v and v.path or nil end
  function TypeIcon.spec(kind) return entry(kind) end
  TypeIcon.WHITE=WHITE
  TypeIcon.FIGMA={glyphSet="625:2266",glyphCanvas=20,iconSet="618:2641",icon=32,iconGlyph=20}
  return TypeIcon
end
