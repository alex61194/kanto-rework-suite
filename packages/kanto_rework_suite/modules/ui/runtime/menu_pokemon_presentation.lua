-- Menu-only Pokémon presentation geometry.
-- Real Size is perceptible, but every UI owns a hard bounding box. Battle
-- multipliers are deliberately ignored here.
return function(deps)
  local internalMod=assert(deps.mod,"internal UI mod facade is required")
  local service={}
  local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
  local function graphicsExports(game)
    local handle=internalMod.find and internalMod.find("graphics")
    return handle and handle.exports or nil
  end
  local function policy(game)
    local gx=graphicsExports(game)
    if gx and type(gx.menuPresentation)=='function' then
      local ok,value=pcall(gx.menuPresentation)
      if ok and type(value)=='table' then return tostring(value.realSize or 'auto'):lower(),value end
    end
    return 'auto',{}
  end
  function service.heightMetres(game,mon)
    local species=mon and mon.species
    local def=game and game.data and game.data.pokemon and species and game.data.pokemon[species]
    local dex=def and def.dexEntry
    local ft=tonumber(dex and dex.heightFt);local inch=tonumber(dex and dex.heightIn)
    if ft==nil or inch==nil then return nil end
    local total=ft*12+inch;if total<=0 then return nil end
    return total*.0254
  end
  function service.sizeFactor(game,mon)
    local mode=policy(game)
    if mode=='no' then return 1 end
    local metres=service.heightMetres(game,mon)
    if not metres then return 1 end
    -- Menus use a much softer curve than battle Real Size. YES is stronger;
    -- AUTO retains recognisable hierarchy without making outliers dominate.
    local exponent=mode=='yes' and .34 or .26
    return clamp(metres^exponent,.58,1.55)
  end
  function service.geometry(game,mon,image,box,opts)
    if not (image and image.getDimensions and type(box)=='table') then return nil end
    opts=type(opts)=='table' and opts or {}
    local iw,ih=image:getDimensions();if iw<=0 or ih<=0 then return nil end
    local bw,bh=math.max(1,tonumber(box.w) or 1),math.max(1,tonumber(box.h) or 1)
    local base=tonumber(opts.baseFraction) or .68
    local ceiling=clamp(tonumber(opts.ceiling) or .92,.2,1)
    local floorFrac=clamp(tonumber(opts.floorFraction) or .34,.05,ceiling)
    local targetH=bh*base*service.sizeFactor(game,mon)
    targetH=clamp(targetH,bh*floorFrac,bh*ceiling)
    local scale=targetH/ih
    scale=math.min(scale,(bw*ceiling)/iw)
    local dw,dh=iw*scale,ih*scale
    return {
      x=(tonumber(box.x) or 0)+(bw-dw)*.5,
      y=(tonumber(box.y) or 0)+(bh-dh)*.5,
      w=dw,h=dh,scale=scale,
      factor=service.sizeFactor(game,mon),realSize=policy(game),
    }
  end
  function service.status(game,mon)
    local mode,meta=policy(game)
    return {realSize=mode,heightMetres=service.heightMetres(game,mon),factor=service.sizeFactor(game,mon),battleScaleIgnored=true,source=meta.source or 'krs_graphics'}
  end
  return service
end
