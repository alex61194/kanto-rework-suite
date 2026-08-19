-- One live art path for every KRS menu surface. Core resolves the engine
-- hook first, then Compatibility may replace it with an active third-party
-- provider. Images are cached by final path, never merely by species, so an
-- in-session option change cannot leave a mixed Gen-I/Crystal menu cache.
return function(deps)
  local Core=assert(deps.Core,"Core exports are required")
  local internalMod=assert(deps.mod,"internal UI mod facade is required")
  local PaletteFX=require("src.render.PaletteFX")
  -- Keep the GPU frame cache intentionally small. Long imported animation atlases can
  -- contain hundreds of cells; the live Graphics editor and menu presenters only
  -- need a short rolling window, not one Canvas allocation per authored frame.
  local service={images={},atlasFrames={},atlasFrameOrder={},atlasFrameLimit=32}

  local function compatExports(game)
    local handle=internalMod.find and internalMod.find("compatibility")
    return handle and handle.exports or nil
  end

  function service:resolve(game,species,side,opts)
    opts=type(opts)=="table" and opts or {}
    -- Core owns visual arbitration. KRS Graphics is resolved there first; the
    -- official pokemon.sprite seam then supplies optional external/native
    -- fallbacks. UI never selects Voxel or another provider directly.
    local path,trueColor,source,meta
    if type(Core.resolvePokemonArt)=="function" then
      local ok,p,tc,provider,details=pcall(Core.resolvePokemonArt,game,species,side,opts)
      if ok then path,trueColor,source,meta=p,tc==true,provider,details end
    end
    if path or (type(meta)=="table" and (meta.image or meta.frames)) then
      local out=type(meta)=="table" and meta or {}
      out.path=out.path or path;out.trueColor=trueColor==true
      out.source=out.source or source or "krs-visual-service"
      return out
    end
    -- Compatibility remains a temporary legacy bridge for providers that have
    -- not yet moved onto the engine hook. It is never the first-party owner.
    local cx=compatExports(game)
    if not cx and deps.mod and type(deps.mod.find)=="function" then
      local h=deps.mod.find("compatibility");cx=h and h.exports or nil
    end
    if cx and type(cx.resolvePokemonArt)=="function" then
      local ok,value=pcall(cx.resolvePokemonArt,game,species,side,opts)
      if ok and type(value)=="table" and (value.image or value.path or value.frames) then
        value.trueColor=value.trueColor==true;value.source=value.source or "compatibility-legacy"
        return value
      end
    end
    return nil
  end


  local function atlasImage(service,path)
    local cached=service.images[path]
    if cached==false then return nil end
    if not cached then
      local ok,img=pcall(love.graphics.newImage,path)
      if not (ok and img) then service.images[path]=false;return nil end
      if img.setFilter then pcall(img.setFilter,img,"nearest","nearest") end
      service.images[path]=img;cached=img
    end
    return cached
  end

  local function atlasFrame(service,art)
    local atlas=art and art.atlas
    if type(atlas)~="table" then return nil end
    local path=atlas.path or art.path
    local fw=math.max(1,math.floor(tonumber(atlas.frameWidth) or 0))
    local fh=math.max(1,math.floor(tonumber(atlas.frameHeight) or 0))
    local cols=math.max(1,math.floor(tonumber(atlas.columns) or 1))
    local count=math.max(1,math.floor(tonumber(atlas.frameCount) or 1))
    if not path or fw<=0 or fh<=0 then return nil end
    local forced=tonumber(atlas.frameIndex)
    local index
    if forced then
      index=math.max(1,math.min(count,math.floor(forced)))
    else
      local now=love and love.timer and love.timer.getTime and love.timer.getTime() or os.clock()
      local durations=type(atlas.durationsMs)=='table' and atlas.durationsMs or nil
      if durations and #durations>=count then
        local speed=math.max(1,tonumber(atlas.speedPercent) or 100)/100
        local total=0;local scaled={}
        for i=1,count do scaled[i]=math.max(1,(tonumber(durations[i]) or 1)/speed);total=total+scaled[i] end
        local elapsed=(now*1000)%math.max(1,total);index=count
        for i=1,count do elapsed=elapsed-scaled[i];if elapsed<0 then index=i;break end end
      else
        local ms=math.max(1,tonumber(atlas.frameDurationMs) or 80)
        index=math.floor((now*1000)/ms)%count+1
      end
    end
    local variantRows=math.max(1,math.floor(tonumber(atlas.variantRows) or 1))
    local variantIndex=math.max(1,math.min(variantRows,math.floor(tonumber(atlas.variantIndex) or 1)))
    local renderH=math.max(1,math.floor(fh/variantRows))
    local key=path.."#"..tostring(index).."#v"..tostring(variantRows)..":"..tostring(variantIndex)
    local hit=service.atlasFrames[key]
    if hit then return hit,{w=fw,h=renderH,frame=index,frameCount=count,variantIndex=variantIndex,variantRows=variantRows} end
    local image=atlasImage(service,path);if not image then return nil end
    local iw,ih=image:getDimensions()
    local col=(index-1)%cols;local row=math.floor((index-1)/cols)
    -- Cell stride remains the authored frameHeight. A gender track is a crop
    -- INSIDE that cell, not an extra animation row in the atlas.
    local qx,qy=col*fw,row*fh+(variantIndex-1)*renderH
    if qx+fw>iw or qy+renderH>ih then return nil end
    local ok,canvas=pcall(love.graphics.newCanvas,fw,renderH,{dpiscale=1})
    if not(ok and canvas) then return nil end
    if canvas.setFilter then pcall(canvas.setFilter,canvas,"nearest","nearest") end
    local g=love.graphics
    local prevCanvas=g.getCanvas and g.getCanvas() or nil
    local prevBlend,prevAlpha=g.getBlendMode();local pr,pg,pb,pa=g.getColor()
    local prevShader=g.getShader and g.getShader() or nil
    local sx,sy,sw,sh=g.getScissor and g.getScissor() or nil
    local worked=pcall(function()
      g.setCanvas(canvas);g.clear(0,0,0,0);if g.setShader then g.setShader() end;if g.setScissor then g.setScissor() end
      g.setBlendMode("replace","premultiplied");g.setColor(1,1,1,1)
      local quad=love.graphics.newQuad(qx,qy,fw,renderH,iw,ih)
      g.draw(image,quad,0,0)
    end)
    if prevCanvas then g.setCanvas(prevCanvas) else g.setCanvas() end
    if prevAlpha~=nil then g.setBlendMode(prevBlend or "alpha",prevAlpha) else g.setBlendMode(prevBlend or "alpha") end
    g.setColor(pr or 1,pg or 1,pb or 1,pa or 1)
    if g.setScissor then if sx then g.setScissor(sx,sy,sw,sh) else g.setScissor() end end
    if g.setShader then g.setShader(prevShader) end
    if not worked then if canvas.release then pcall(canvas.release,canvas) end;return nil end
    service.atlasFrames[key]=canvas;service.atlasFrameOrder[#service.atlasFrameOrder+1]=key
    while #service.atlasFrameOrder>service.atlasFrameLimit do
      local old=table.remove(service.atlasFrameOrder,1)
      -- Drop only our cache ownership. A drawable returned earlier in this
      -- same BattlePresenter frame may still be held by a local renderer
      -- reference; Canvas:release() here invalidates that live reference and
      -- produces "Cannot use object after it has been released". LÖVE/LuaJIT
      -- will reclaim the Canvas once no renderer/cache reference remains.
      service.atlasFrames[old]=nil
    end
    return canvas,{w=fw,h=renderH,frame=index,frameCount=count,variantIndex=variantIndex,variantRows=variantRows}
  end

  local function animatedPath(art)
    local animation=art and art.animation
    if not(type(animation)=="table" and type(animation.frames)=="table"
        and type(animation.durations)=="table" and #animation.frames>1) then return art.path end
    local total=0;for i=1,#animation.frames do total=total+math.max(1,tonumber(animation.durations[i]) or 100) end
    if total<=0 then return art.path end
    local now=love and love.timer and love.timer.getTime and love.timer.getTime() or os.clock()
    local elapsed=(now*1000)%total
    for i,path in ipairs(animation.frames) do
      elapsed=elapsed-math.max(1,tonumber(animation.durations[i]) or 100)
      if elapsed<0 then return path end
    end
    return animation.frames[1] or art.path
  end

  local function animatedImage(art)
    local frames=art and art.frames;local durations=art and art.durations
    if not(type(frames)=="table" and #frames>1 and type(durations)=="table") then return art and art.image end
    local total=0;for i=1,#frames do total=total+math.max(1,tonumber(durations[i]) or 100) end
    if total<=0 then return art.image or frames[1] end
    local now=love and love.timer and love.timer.getTime and love.timer.getTime() or os.clock()
    local elapsed=(now*1000)%total
    for i,image in ipairs(frames) do
      elapsed=elapsed-math.max(1,tonumber(durations[i]) or 100)
      if elapsed<0 then return image end
    end
    return frames[1] or art.image
  end

  function service:materialize(art)
    if type(art)~='table' then return nil end
    local okAtlas,drawable,metric=pcall(atlasFrame,self,art)
    if okAtlas and drawable then
      art.image=drawable;art.metrics=metric;art.trueColor=true
      return art
    end
    local path=art.nativePath or art.fallbackPath or art.path
    if type(path)~='string' or path=='' then return nil end
    local image=atlasImage(self,path);if not image then return nil end
    art.image=image;art.trueColor=art.trueColor~=false
    return art
  end

  function service:image(game,species,side,opts)
    local art=self:resolve(game,species,side,opts)
    if not art then return nil end
    local okAtlas,atlasDrawable,atlasMetric=pcall(atlasFrame,self,art)
    if okAtlas and atlasDrawable then
      art.image=atlasDrawable;art.metrics=atlasMetric;art.trueColor=true
      return art
    end
    local direct=animatedImage(art) or art.image
    if direct then
      if direct.setFilter then pcall(direct.setFilter,direct,"nearest","nearest") end
      art.image=direct
      -- Animated atlases expose per-frame metrics. Keep the selected
      -- frame and its authored anchor together: carrying frame-one metrics
      -- onto a later atlas cell is enough to make the opponent appear to
      -- jump back to a different size/anchor after a native battle effect.
      local cx=compatExports(game)
      if cx and type(cx.battleArtMetrics)=="function" then
        local ok,metric=pcall(cx.battleArtMetrics,direct)
        if ok and type(metric)=="table" then art.metrics=metric end
      end
      return art
    end
    local staticPath=art.nativePath or art.fallbackPath or art.path
    if type(art.atlas)=="table" then art.path=staticPath end
    art.path=animatedPath(art)
    local cached=self.images[art.path]
    if cached==false and art.path~=staticPath then art.path=staticPath;cached=self.images[staticPath] end
    if cached==false then return nil end
    if not cached then
      local ok,image=pcall(love.graphics.newImage,art.path)
      if not (ok and image) then
        self.images[art.path]=false
        if art.path~=staticPath then
          art.path=staticPath;ok,image=pcall(love.graphics.newImage,staticPath)
        end
      end
      if not (ok and image) then self.images[art.path]=false;return nil end
      if image.setFilter then pcall(image.setFilter,image,"nearest","nearest") end
      self.images[art.path]=image;cached=image
    end
    art.image=cached
    return art
  end

  function service.mark(art,x,y,w,h)
    if art and art.trueColor and tonumber(x) and tonumber(y) and tonumber(w) and tonumber(h)
        and PaletteFX and PaletteFX.markTrueColor then
      PaletteFX.markTrueColor(x,y,w,h)
    end
  end

  function service:invalidate()
    for _,c in pairs(self.atlasFrames or {}) do if c and c.release then pcall(c.release,c) end end
    self.images={};self.atlasFrames={};self.atlasFrameOrder={}
  end
  return service
end
