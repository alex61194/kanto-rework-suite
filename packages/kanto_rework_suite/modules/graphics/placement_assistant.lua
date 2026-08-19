-- Suggestion-only battle Pokémon size/placement assistant.
-- Inputs are explicit scene metadata + intrinsic Pokédex height + current
-- provider frame metrics. It never writes config and never maps species IDs to
-- fixed scales.
local M={}
local function clamp(v,a,b) v=tonumber(v) or a;return math.max(a,math.min(b,v)) end
local function intersects(a,b)
  return a and b and a.x < b.x+b.w and a.x+a.w > b.x and a.y < b.y+b.h and a.y+a.h > b.y
end
local function intrinsicFactor(heightM)
  local h=clamp(heightM or 1,0.15,20)
  -- Temper canonical size so spatial coherence/readability outrank literal metres.
  return clamp(h^0.22,.72,1.42)
end
local function projectionFactor(sideMeta)
  local depth=clamp(sideMeta and sideMeta.depth or .5,0,1)
  local strength=clamp(sideMeta and sideMeta.perspectiveStrength or .5,0,1)
  return clamp(1-strength*depth*.52,.60,1.05)
end
function M.suggest(req)
  req=type(req)=='table' and req or {}
  local role=req.role=='opponent' and 'opponent' or 'player'
  local scene=type(req.scene)=='table' and req.scene or {}
  local sideMeta=type(req.sideMeta)=='table' and req.sideMeta or {}
  sideMeta.perspectiveStrength=scene.perspectiveStrength
  local nativeW=math.max(1,tonumber(req.nativeWidth) or 96)
  local nativeH=math.max(1,tonumber(req.nativeHeight) or 96)
  local intrinsic=intrinsicFactor(req.heightM)
  local projection=projectionFactor(sideMeta)
  local circleFactor=clamp(math.sqrt((tonumber(sideMeta.circleWidth) or 300)/300),.78,1.22)
  local reference=clamp(scene.scaleReference or 1,.75,1.25)
  local nearLift=role=='player' and 1.06 or 1.0
  local desiredH=160*intrinsic*projection*circleFactor*reference*nearLift
  local maxH=role=='player' and 352 or 320;local maxW=role=='player' and 420 or 380
  desiredH=clamp(desiredH,88,maxH)
  local pixelScale=desiredH/nativeH
  pixelScale=math.min(pixelScale,maxW/nativeW,maxH/nativeH)
  pixelScale=clamp(pixelScale,1,5)
  local sizePercent=clamp((pixelScale-1)/4*100,0,100)
  sizePercent=math.floor(sizePercent+.5)
  local w,h=nativeW*pixelScale,nativeH*pixelScale
  local anchor=type(req.anchor)=='table' and req.anchor or {x=role=='player' and 630 or 1400,y=role=='player' and 790 or 570}
  local x=clamp(anchor.x or 0,w/2,1920-w/2)
  local y=clamp(anchor.y or 0,86+h,1016)
  local rect={x=x-w/2,y=y-h,w=w,h=h};local uiAdjusted=false
  -- UI correction is deliberately small: keep battle-circle coherence first.
  for _,u in pairs(type(req.uiRects)=='table' and req.uiRects or {}) do
    if intersects(rect,u) then
      local dir=(x < (u.x+u.w/2)) and -1 or 1
      local nx=clamp(x+dir*32,w/2,1920-w/2)
      local nr={x=nx-w/2,y=y-h,w=w,h=h}
      if not intersects(nr,u) then x=nx;rect=nr;uiAdjusted=true end
    end
  end
  return {
    role=role,
    current=req.current,
    suggested={size=sizePercent,position={x=math.floor(x+.5),y=math.floor(y+.5)}},
    predictedBounds={x=rect.x,y=rect.y,w=rect.w,h=rect.h},
    inputs={heightM=req.heightM or 1,nativeWidth=nativeW,nativeHeight=nativeH,depth=sideMeta.depth,circleWidth=sideMeta.circleWidth,
      horizonY=scene.horizonY,perspectiveStrength=scene.perspectiveStrength,scaleReference=scene.scaleReference},
    flags={uiAdjusted=uiAdjusted,clamped=(pixelScale<=1 or pixelScale>=5)},
  }
end
return M
