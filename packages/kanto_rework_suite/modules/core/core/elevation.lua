-- Presentation-agnostic elevation profiles.
-- Core resolves reusable shadow geometry; product UIs remain responsible for drawing it.
return function()
  local api={}

  local function clamp(value,lo,hi)
    value=tonumber(value) or 0
    if value<lo then return lo end
    if value>hi then return hi end
    return value
  end

  function api.shadowSamples(definition)
    definition=type(definition)=="table" and definition or {}
    local blur=clamp(definition.blur or 0,0,64)
    local spread=clamp(definition.spread or 0,-64,64)
    local offsetX=clamp(definition.offsetX or 0,-128,128)
    local offsetY=clamp(definition.offsetY or 0,-128,128)
    local color=type(definition.color)=="table" and definition.color or {0,0,0,.4}
    local totalAlpha=clamp(color[4] or .4,0,1)
    if totalAlpha<=0 then return {} end

    local count=math.max(1,math.ceil(blur)+1)
    local sampleAlpha=1-math.pow(1-totalAlpha,1/count)
    local samples={}
    for index=count,1,-1 do
      local t=(index-1)/math.max(1,count-1)
      samples[#samples+1]={
        offsetX=offsetX,offsetY=offsetY,
        spread=spread+blur*t,
        color={clamp(color[1],0,1),clamp(color[2],0,1),clamp(color[3],0,1),sampleAlpha},
      }
    end
    return samples
  end

  function api.cardShadow()
    return {offsetX=0,offsetY=4,blur=4,spread=0,color={0,0,0,.4}}
  end

  return api
end
