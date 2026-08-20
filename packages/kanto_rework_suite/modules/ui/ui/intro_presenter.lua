-- Kanto Journal presentation for Gen1Recomp's official OakSpeech state.
-- The engine owns the complete intro state machine, naming callbacks, cries,
-- music and save mutations. KRS replaces pixels only on Wide 16:9 surfaces.
return function(runtime)
  local OakSpeech=require('src.ui.OakSpeech')
  local TextBox=require('src.render.TextBox')
  local GameVersion=require('src.core.GameVersion')
  local P={}

  local function isOak(s) return type(s)=='table' and getmetatable(s)==OakSpeech end
  local function isText(s) return type(s)=='table' and getmetatable(s)==TextBox end
  local function states(game) return game and game.stack and game.stack.states or {} end
  local function context(game)
    local ss=states(game);local top=ss[#ss]
    if isOak(top) then return top,top,nil end
    if isText(top) and isOak(ss[#ss-1]) then return ss[#ss-1],top,top end
    return nil,top,nil
  end
  function P.handles(game,viewport)
    local speech=select(1,context(game))
    return speech~=nil and runtime.Layout.isWide(viewport or runtime.viewport)
  end
  function P.ownsText(game,state,viewport)
    if not runtime.Layout.isWide(viewport or runtime.viewport) then return false end
    local ss=states(game)
    return isText(state) and ss[#ss]==state and isOak(ss[#ss-1])
  end

  local function load(relative,filter)
    runtime.introImages=runtime.introImages or {}
    if runtime.introImages[relative]~=nil then return runtime.introImages[relative] or nil end
    local img=runtime.assets:image(runtime.assetPath(relative),filter or 'nearest')
    runtime.introImages[relative]=img or false;return img
  end
  local function graphicsAsset(context,request)
    local graphics=runtime.Core and runtime.Core.graphics
    if not (graphics and type(graphics.resolve)=='function') then return nil end
    request=type(request)=='table' and request or {}
    local ok,value=pcall(graphics.resolve,context,request,nil)
    return ok and type(value)=='table' and value or nil
  end
  local function loadResolved(asset,defaultFilter)
    if not (asset and asset.path) then return nil end
    return runtime.assets:image(asset.path,asset.filter or defaultFilter or 'nearest')
  end

  local function drawCover(m,img)
    if not img then return end
    local iw,ih=img:getDimensions();local scale=math.max(1920/iw,1080/ih)*m.scale
    local dw,dh=iw*scale,ih*scale
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(img,m.ox+(1920*m.scale-dw)/2,m.oy+(1080*m.scale-dh)/2,0,scale,scale)
  end
  local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end

  -- Full-resolution character artwork is authored independently from the
  -- 1920x1080 scene. Fit it proportionally (fractional down-scaling allowed)
  -- instead of the integer-only pixel helper used by the older 64px assets.
  -- `crop` only discards transparent canvas margin; it never stretches,
  -- recolours or rewrites the supplied pixels.
  local function drawArt(m,img,cx,bottom,maxW,maxH,opts)
    if not img then return end
    opts=opts or {}
    if img.setFilter then pcall(img.setFilter,img,opts.filter or 'nearest',opts.filter or 'nearest') end
    local iw,ih=img:getDimensions();if iw<=0 or ih<=0 then return end
    local crop=opts.crop
    local sx,sy,sw,sh=0,0,iw,ih
    if type(crop)=='table' then
      sx,sy=tonumber(crop[1]) or 0,tonumber(crop[2]) or 0
      sw,sh=tonumber(crop[3]) or iw,tonumber(crop[4]) or ih
    end
    local baseFit
    if tonumber(opts.presentationScale) then
      baseFit=tonumber(opts.presentationScale)
    else
      baseFit=math.min(maxW/sw,maxH/sh)
      if opts.integerScale then baseFit=math.max(1,math.floor(baseFit)) end
    end
    if opts.noUpscale then baseFit=math.min(1,baseFit) end
    local fit=baseFit*(tonumber(opts.scale) or 1)
    if fit<=0 then return end
    local scale=fit*m.scale
    local dw,dh=sw*scale,sh*scale
    local x=m.ox+cx*m.scale-dw/2
    local y=m.oy+bottom*m.scale-dh
    local progress=clamp(tonumber(opts.reveal) or 1,0,1)
    local alpha=clamp(tonumber(opts.alpha) or 1,0,1)
    if opts.revealKind=='fade' then alpha=alpha*progress end
    love.graphics.setColor(1,1,1,alpha)
    local clipped=false
    if opts.revealKind=='wipe' and progress<1 and love.graphics.setScissor then
      local rw=dw*progress
      love.graphics.setScissor(x+dw-rw,y,rw,dh);clipped=true
    end
    if crop and love.graphics.newQuad then
      local ok,quad=pcall(love.graphics.newQuad,sx,sy,sw,sh,iw,ih)
      if ok and quad then love.graphics.draw(img,quad,x,y,0,scale,scale)
      else love.graphics.draw(img,x,y,0,scale,scale) end
    else
      love.graphics.draw(img,x,y,0,scale,scale)
    end
    if clipped then love.graphics.setScissor() end
  end
  local function currentVisual(speech)
    local step=speech.steps and speech.steps[speech.step] or nil
    local id=step and step.id or ''
    if id=='demo_mon' or id=='world_spiel' then return 'pokemon' end
    if id=='ask_rival_name' or id=='name_rival' or id=='confirm_rival_name' then return 'rival' end
    if id=='ask_player_name' or id=='name_player' or id=='confirm_player_name' or id=='legend' or id=='shrink' then return 'player' end
    return 'oak'
  end
  local function pokemonImage(game,speech)
    local species=tostring(speech.demoSpecies or 'NIDORINO'):upper()
    local asset=graphicsAsset('intro.pokemon',{species=species,data=game and game.data})
    if asset and runtime.PokemonArt and type(runtime.PokemonArt.materialize)=='function' then
      local art=runtime.PokemonArt:materialize(asset)
      if art and art.image then
        return art.image,{asset=art,crop=nil,animated=art.metrics and (tonumber(art.metrics.frameCount) or 1)>1,integerScale=asset.integerScale}
      end
    elseif asset then
      local image=loadResolved(asset,'nearest');if image then return image,{asset=asset,crop=nil,animated=false,integerScale=asset.integerScale} end
    end
    -- Missing KRS assets degrade locally to the engine's already-resolved
    -- demo picture; no Battle Real Size or third-party menu scale is queried.
    return speech.demoPic,{asset=nil,crop=nil,animated=false}
  end


  local function revealState(speech)
    local r=speech and speech.picReveal
    if type(r)~='table' then return nil,1 end
    local dur=math.max(1,tonumber(r.dur) or 1)
    return tostring(r.kind or ''),clamp((tonumber(r.t) or 0)/dur,0,1)
  end

  local function shrinkScale(speech)
    local shrink=speech and speech.shrink
    if type(shrink)~='table' then return 1 end
    local frame=tonumber(shrink.frame) or 0
    if frame<=4 then return 1 end
    if frame<=28 then
      local t=clamp((frame-5)/23,0,1)
      return 1-(0.84*t)
    end
    return 0.12
  end
  local function speakerFor(speech)
    -- The prose in the canonical Oak speech is Professor Oak's narration,
    -- including the beats where the rival/player portrait is being introduced.
    return 'PROFESOR OAK'
  end

  function P.draw(game,viewport)
    local speech,top,text=context(game)
    if not speech or not runtime.Layout.isWide(viewport) then return false end
    local m=runtime.Layout.metrics(viewport);local c=runtime.Theme.resolveAll(runtime,game)
    love.graphics.push('all');love.graphics.origin()
    local ok, res = pcall(function()
      local scene=graphicsAsset('intro.scene',{id='oak_lab',data=game and game.data})
      drawCover(m,loadResolved(scene,'linear') or load('assets/intro/oak_lab_presentation.png','linear'))
      local kind=currentVisual(speech)
      local revealKind,reveal=revealState(speech)
      if kind=='oak' then
        local trainer=graphicsAsset('intro.trainer',{id='oak',data=game and game.data})
        drawArt(m,loadResolved(trainer,'linear') or load('assets/intro/prof_oak_intro.png','linear'),960,970,560,680,{
          crop={750,13,527,1331},revealKind=revealKind,reveal=reveal,
        })
      elseif kind=='rival' then
        local trainer=graphicsAsset('intro.trainer',{id='blue',data=game and game.data})
        drawArt(m,loadResolved(trainer,'nearest') or load('assets/intro/rival.png','nearest'),960,970,560,680,{
          presentationScale=trainer and trainer.presentationScale or 1,noUpscale=true,filter='nearest',revealKind=revealKind,reveal=reveal,
        })
      elseif kind=='pokemon' then
        local mon,meta=pokemonImage(game,speech)
        drawArt(m,mon,960,930,420,420,{
          filter='nearest',integerScale=meta and meta.integerScale,crop=meta and meta.crop or nil,revealKind=revealKind,reveal=reveal,
        })
      else
        local trainer=graphicsAsset('intro.trainer',{id='red',data=game and game.data})
        drawArt(m,loadResolved(trainer,'nearest') or load('assets/intro/player_red.png','nearest'),960,970,560,680,{
          presentationScale=trainer and trainer.presentationScale or 1,noUpscale=true,filter='nearest',revealKind=revealKind,reveal=reveal,
        })
      end
      local fade=tonumber(speech.fadeLevel) or 0
      if fade>0 then
        local a=clamp(fade/3,0,1)
        love.graphics.setColor(1,1,1,a)
        love.graphics.rectangle('fill',m.ox,m.oy,1920*m.scale,1080*m.scale)
      end
      if text then
        local model=runtime.DialogueAdapter.model(text,nil,game)
        model.speaker=speakerFor(speech)
        runtime.DialoguePanel.draw(runtime,m,c,model)
      end
      return true
    end)
    love.graphics.pop()
    if not ok then return nil, res end
    return res == true
  end
  return P
end
