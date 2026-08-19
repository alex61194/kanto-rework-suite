-- Manual wide layout adapter driven by generated Figma metrics.
return function(spec)
  local W={}
  function W.columns()
    local out={};local x=spec.body.x
    for i,w in ipairs(spec.columns) do out[i]={x=x,y=spec.body.y,w=w,h=spec.body.h};x=x+w+(spec.gaps[i] or 0) end
    return out
  end
  function W.activeSlots()
    local out={}
    for i=1,4 do out[i]={x=spec.activeSlots.x,y=spec.activeSlots.y+(i-1)*spec.activeSlots.step,w=spec.activeSlots.w,h=spec.activeSlots.h,index=i} end
    return out
  end
  return W
end
