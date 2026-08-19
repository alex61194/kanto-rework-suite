-- Full-frame color-accessibility adapter for Gen1Recomp 0.1.75.
--
-- Palette-level correction cannot cover trueColor tilesets, imported battle
-- backgrounds, render-pipeline output or screen-space Kanto UI. This adapter
-- therefore owns one final color-correction shader and applies it at each of
-- the engine's three presentation layers:
--   1. render_pipelines.present: world + native UI + trueColor content;
--   2. render.hud: Kanto Wide UI and modular overlays;
--   3. TouchControls.draw: the mobile overlay drawn after render.hud.
-- Standard is an exact pass-through and allocates no full-frame canvas.
return function(deps)
  local mod=assert(deps and deps.mod,"game palette adapter needs mod")
  local runtime=assert(deps.runtime,"game palette adapter needs runtime")
  local Adapter={}
  local unpackValues=table.unpack or unpack
  local function packValues(...) return {n=select("#",...),...} end
  local PIPELINE_ID="kanto_rework_accessibility"
  local ORDER={"standard","protanopia","deuteranopia","tritanopia"}
  local LEVEL={standard=0,protanopia=1,deuteranopia=2,tritanopia=3}
  local shader=false
  local shaderAttempted=false
  local target=nil

  -- The same compensation model previously applied to four-color palette
  -- rows, now evaluated per final pixel. Inputs are converted from sRGB to
  -- linear RGB, the selected full-deficiency simulation error is redistributed
  -- into surviving channels, and the source luminance hierarchy is restored.
  local SHADER_SOURCE=[[
    extern number accessibilityMode;

    number srgbToLinear(number v) {
      v=clamp(v,0.0,1.0);
      return v<=0.04045 ? v/12.92 : pow((v+0.055)/1.055,2.4);
    }
    number linearToSrgb(number v) {
      v=clamp(v,0.0,1.0);
      return v<=0.0031308 ? v*12.92 : 1.055*pow(v,1.0/2.4)-0.055;
    }
    vec3 toLinear(vec3 c) {
      return vec3(srgbToLinear(c.r),srgbToLinear(c.g),srgbToLinear(c.b));
    }
    vec3 toSrgb(vec3 c) {
      return vec3(linearToSrgb(c.r),linearToSrgb(c.g),linearToSrgb(c.b));
    }
    number luma(vec3 c) { return dot(c,vec3(0.2126,0.7152,0.0722)); }

    vec3 simulated(vec3 c,number mode) {
      if (mode<1.5) {
        return vec3(
          0.152286*c.r+1.052583*c.g-0.204868*c.b,
          0.114503*c.r+0.786281*c.g+0.099216*c.b,
         -0.003882*c.r-0.048116*c.g+1.051998*c.b);
      }
      if (mode<2.5) {
        return vec3(
          0.367322*c.r+0.860646*c.g-0.227968*c.b,
          0.280085*c.r+0.672501*c.g+0.047413*c.b,
         -0.011820*c.r+0.042940*c.g+0.968881*c.b);
      }
      return vec3(
        1.255528*c.r-0.076749*c.g-0.178779*c.b,
       -0.078411*c.r+0.930809*c.g+0.147602*c.b,
        0.004733*c.r+0.691367*c.g+0.303900*c.b);
    }

    vec3 redistribute(vec3 e,number mode) {
      if (mode<1.5) return vec3(0.0,0.70*e.r+e.g,0.70*e.r+e.b);
      if (mode<2.5) return vec3(e.r+0.70*e.g,0.0,0.70*e.g+e.b);
      return vec3(e.r+0.70*e.b,e.g+0.70*e.b,0.0);
    }

    vec4 effect(vec4 color,Image tex,vec2 tc,vec2 sc) {
      vec4 src=Texel(tex,tc)*color;
      if (accessibilityMode<0.5 || src.a<=0.0) return src;
      vec3 original=toLinear(src.rgb);
      vec3 adjusted=original+redistribute(original-simulated(original,accessibilityMode),accessibilityMode);
      adjusted=clamp(adjusted+vec3(luma(original)-luma(adjusted)),0.0,1.0);
      return vec4(toSrgb(adjusted),src.a);
    }
  ]]

  local function normalize(value)
    value=tostring(value or "standard"):lower()
    return LEVEL[value]~=nil and value or "standard"
  end
  local function selected() return normalize(runtime.accessibility) end
  local function active() return selected()~="standard" end

  local function getShader()
    if shaderAttempted then return shader or nil end
    shaderAttempted=true
    if not (love and love.graphics and type(love.graphics.newShader)=="function") then
      runtime.gamePaletteError="love.graphics.newShader unavailable"
      return nil
    end
    local ok,value=pcall(love.graphics.newShader,SHADER_SOURCE)
    if not ok then
      runtime.gamePaletteError=tostring(value)
      mod.log:warn("Full-frame color accessibility unavailable: %s",tostring(value))
      return nil
    end
    shader=value
    runtime.gamePaletteError=nil
    return shader
  end

  local function sendMode(value)
    local sh=getShader();if not sh then return nil end
    sh:send("accessibilityMode",LEVEL[normalize(value)] or 0)
    return sh
  end

  local function ensureTarget(width,height)
    width=math.max(1,math.floor(tonumber(width) or 1))
    height=math.max(1,math.floor(tonumber(height) or 1))
    if target and target.getWidth and target:getWidth()==width and target:getHeight()==height then return target end
    if target and target.release then pcall(target.release,target) end
    target=love.graphics.newCanvas(width,height)
    if target and target.setFilter then target:setFilter("linear","linear") end
    return target
  end

  local function present(canvas,ctx)
    if not active() then return canvas end
    local sh=sendMode(selected());if not sh then return canvas end
    local width=ctx and ctx.width or (canvas and canvas.getWidth and canvas:getWidth())
    local height=ctx and ctx.height or (canvas and canvas.getHeight and canvas:getHeight())
    local out=ensureTarget(width,height)
    love.graphics.setCanvas(out)
    love.graphics.clear(0,0,0,0)
    love.graphics.setColor(1,1,1,1)
    love.graphics.setShader(sh)
    love.graphics.draw(canvas,0,0)
    love.graphics.setShader()
    love.graphics.setCanvas()
    return out
  end

  -- The public Gen1Recomp present-pipeline seam is the only renderer path
  -- that receives a single image containing every tileset and native screen.
  mod.content.render_pipelines:register(PIPELINE_ID,{
    label="COLOR ACCESSIBILITY",
    levels={"STANDARD","PROTANOPIA","DEUTERANOPIA","TRITANOPIA"},
    priority=1000,
    available=function() return getShader()~=nil end,
    gate=function() return true end,
    present=present,
    invalidate=function()
      if target and target.release then pcall(target.release,target) end
      target=nil
    end,
  })

  local function pipelineService()
    local ok,Pipelines=pcall(require,"src.render.Pipelines")
    return ok and type(Pipelines)=="table" and Pipelines or nil
  end
  local function pipelineLevel()
    local p=pipelineService()
    return p and p.get and p.get(PIPELINE_ID) and p.level(PIPELINE_ID) or nil
  end
  local function profileForLevel(level)
    level=math.max(0,math.min(3,math.floor(tonumber(level) or 0)))
    return ORDER[level+1]
  end

  local function writeOption(value,emit)
    local game=runtime.game
    if mod.options and type(mod.options.set)=="function" then
      mod.options:set("accessibility",value,{game=game,persist=true,emit=emit==true})
      return
    end
    local opts=game and game.save and game.save.options
    if opts then
      opts.modOptions=type(opts.modOptions)=="table" and opts.modOptions or {}
      opts.modOptions[mod.id]=type(opts.modOptions[mod.id])=="table" and opts.modOptions[mod.id] or {}
      opts.modOptions[mod.id].accessibility=value
    end
    local loader=game and game.mods
    if loader then
      loader.modOptions=type(loader.modOptions)=="table" and loader.modOptions or {}
      loader.modOptions[mod.id]=type(loader.modOptions[mod.id])=="table" and loader.modOptions[mod.id] or {}
      loader.modOptions[mod.id].accessibility=value
    end
    if opts and game and type(game.writeOptions)=="function" then pcall(game.writeOptions,game) end
    if emit and loader and loader.events then
      pcall(loader.events.emit,loader.events,"mod.options_changed",{mod=mod.id,key="accessibility",value=value})
    end
  end

  local function setPipeline(value)
    local p=pipelineService();if not (p and p.get and p.get(PIPELINE_ID)) then return false end
    p.setLevel(PIPELINE_ID,LEVEL[value] or 0)
    local game=runtime.game
    if game and game.save and game.save.options then p.syncOptions(game.save.options) end
    return true
  end

  function Adapter.set(value,opts)
    value=normalize(value)
    local changed=selected()~=value
    runtime.accessibility=value
    setPipeline(value)
    if not opts or opts.persist~=false then writeOption(value,opts and opts.emit==true) end
    return value,changed
  end

  function Adapter.attachGame(game)
    runtime.game=game or runtime.game
    Adapter.set(runtime.accessibility,{persist=true})
    Adapter.installTouchFilter()
    return true
  end

  -- Native Options exposes registered render pipelines. If that row changes
  -- the level, adopt it as the same Kanto preference instead of fighting it
  -- on the next fixed step.
  function Adapter.syncFromPipeline()
    local level=pipelineLevel();if level==nil then return false end
    local value=profileForLevel(level)
    if value==selected() then return false end
    runtime.accessibility=value
    writeOption(value,true)
    return true
  end

  function Adapter.cycle(dir)
    local index=(LEVEL[selected()] or 0)+1
    local delta=tonumber(dir) or 1
    index=((index-1+delta)%#ORDER)+1
    local value=Adapter.set(ORDER[index],{persist=true,emit=true})
    return value
  end

  -- Run one screen-space drawing block through the same shader. This covers
  -- render.hud, which executes after Renderer:endFrame's present pipeline.
  function Adapter.drawFiltered(fn,...)
    if not active() then return fn(...) end
    local sh=sendMode(selected());if not sh then return fn(...) end
    love.graphics.push("all")
    love.graphics.setShader(sh)
    local packed=packValues(pcall(fn,...))
    love.graphics.pop()
    if not packed[1] then error(packed[2],0) end
    return unpackValues(packed,2,packed.n)
  end

  function Adapter.installTouchFilter()
    local ok,TouchControls=pcall(require,"src.core.TouchControls")
    if not ok or type(TouchControls)~="table" or type(TouchControls.draw)~="function" then return false end
    local dispatcher=runtime.touchColorFilterPatch
    if type(dispatcher)~="table" or dispatcher.target~=TouchControls then
      dispatcher={target=TouchControls,original=TouchControls.draw,owner=nil}
      runtime.touchColorFilterPatch=dispatcher
      TouchControls.draw=function(self,...)
        local live=runtime.touchColorFilterPatch;local owner=live and live.owner
        if owner and type(owner.drawFiltered)=="function" then
          return owner.drawFiltered(function(...) return live.original(self,...) end,...)
        end
        return live.original(self,...)
      end
    end
    dispatcher.owner=Adapter
    return true
  end

  function Adapter.available() return getShader()~=nil end
  function Adapter.active() return active() and getShader()~=nil end
  function Adapter.profile() return selected() end
  function Adapter.invalidate()
    local p=pipelineService();if p and p.invalidate then p.invalidate() end
    return true
  end
  function Adapter.status()
    local okPalette,PaletteFX=pcall(require,"src.render.PaletteFX")
    return {
      available=getShader()~=nil,
      active=Adapter.active(),
      accessibility=selected(),
      colorsMode=okPalette and PaletteFX.mode or nil,
      advancedOnly=false,
      fullFrame=true,
      coversTrueColor=true,
      pipeline=PIPELINE_ID,
      pipelineLevel=pipelineLevel(),
      layers={present=true,hud=true,touch=true},
      error=runtime.gamePaletteError,
    }
  end

  runtime.gamePaletteAvailable=getShader()~=nil
  Adapter.installTouchFilter()
  return Adapter
end
