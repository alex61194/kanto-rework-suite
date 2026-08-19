-- Consumer for KRS' neutral context-scoped Graphics registry. Concrete assets
-- remain owned by kanto_rework_graphics; UI only asks for a context and draws
-- the returned image/frame without applying theme colour or battle scaling.
return function(deps)
  local Core=assert(deps.Core,'Core exports are required')
  local service={images={}}

  local function requestFor(game,mon,extra)
    extra=type(extra)=='table' and extra or {}
    local out={}
    for k,v in pairs(extra) do out[k]=v end
    if mon then
      out.mon=mon;out.species=out.species or mon.species;out.gender=out.gender or mon.gender
      out.form=out.form or mon.form;out.shiny=out.shiny==nil and mon.shiny or out.shiny
    end
    out.data=out.data or (game and game.data)
    return out
  end

  function service:resolve(context,game,mon,extra)
    if not (Core.graphics and type(Core.graphics.resolve)=='function') then return nil end
    local ok,value=pcall(Core.graphics.resolve,context,requestFor(game,mon,extra))
    return ok and type(value)=='table' and value or nil
  end

  function service:image(context,game,mon,extra)
    local asset=self:resolve(context,game,mon,extra);if not asset or not asset.path then return nil end
    local cached=self.images[asset.path]
    if cached==false then return nil end
    if not cached then
      local ok,img=pcall(love.graphics.newImage,asset.path)
      if not(ok and img) then self.images[asset.path]=false;return nil end
      local filter=asset.filter=='linear' and 'linear' or 'nearest'
      if img.setFilter then pcall(img.setFilter,img,filter,filter) end
      self.images[asset.path]=img;cached=img
    end
    asset.image=cached
    return asset
  end

  function service:frame(asset)
    if not(asset and asset.image) then return nil,nil,nil end
    local count=math.max(1,tonumber(asset.frameCount) or 1)
    if count<=1 then local w,h=asset.image:getDimensions();return nil,w,h end
    local fw=tonumber(asset.frameWidth);local fh=tonumber(asset.frameHeight)
    local iw,ih=asset.image:getDimensions();fw=fw or math.floor(iw/count);fh=fh or ih
    local duration=math.max(.01,tonumber(asset.frameDuration) or .25)
    local now=(love and love.timer and love.timer.getTime and love.timer.getTime()) or os.clock()
    local index=math.floor(now/duration)%count
    return love.graphics.newQuad(index*fw,0,fw,fh,iw,ih),fw,fh
  end

  function service:draw(context,game,mon,x,y,w,h,extra)
    local asset=self:image(context,game,mon,extra);if not asset then return false end
    local quad,fw,fh=self:frame(asset);local iw,ih=fw,fh
    if not iw then iw,ih=asset.image:getDimensions() end
    local sx,sy=(w or iw)/iw,(h or ih)/ih
    love.graphics.push('all');love.graphics.setColor(1,1,1,1)
    if quad then love.graphics.draw(asset.image,quad,x,y,0,sx,sy) else love.graphics.draw(asset.image,x,y,0,sx,sy) end
    love.graphics.pop()
    if asset.trueColor then
      local ok,PaletteFX=pcall(require,'src.render.PaletteFX')
      if ok and PaletteFX and type(PaletteFX.markTrueColor)=='function' then pcall(PaletteFX.markTrueColor,x,y,w or iw,h or ih) end
    end
    return true,asset
  end

  function service:invalidate() self.images={} end
  return service
end
