local ScrollList = {}

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, tonumber(value) or minimum))
end

function ScrollList.total(count, pitch, rowHeight)
  count=math.max(0,tonumber(count) or 0)
  if count==0 then return 0 end
  return (count-1)*(tonumber(pitch) or 0)+(tonumber(rowHeight) or tonumber(pitch) or 0)
end

function ScrollList.max(totalHeight, viewportHeight)
  return math.max(0,(tonumber(totalHeight) or 0)-(tonumber(viewportHeight) or 0))
end

function ScrollList.clamp(value,totalHeight,viewportHeight)
  return clamp(value,0,ScrollList.max(totalHeight,viewportHeight))
end

function ScrollList.ensure(value,itemTop,itemBottom,totalHeight,viewportHeight)
  local scroll=ScrollList.clamp(value,totalHeight,viewportHeight)
  if itemTop<scroll then scroll=itemTop
  elseif itemBottom>scroll+viewportHeight then scroll=itemBottom-viewportHeight end
  return ScrollList.clamp(scroll,totalHeight,viewportHeight)
end

function ScrollList.model(value,totalHeight,viewport,trackX,opts)
  opts=opts or {};local maxScroll=ScrollList.max(totalHeight,viewport.h)
  if maxScroll<=0 then return nil end
  local trackW=opts.trackWidth or 12;local minThumb=opts.minThumb or 56
  local track={x=trackX,y=viewport.y,w=trackW,h=viewport.h}
  local thumbH=math.max(minThumb,track.h*viewport.h/totalHeight)
  local travel=math.max(0,track.h-thumbH)
  local scroll=ScrollList.clamp(value,totalHeight,viewport.h)
  local thumb={x=track.x,y=track.y+(maxScroll>0 and scroll/maxScroll*travel or 0),w=track.w,h=thumbH}
  local hitWidth=math.max(44,opts.hitWidth or 44)
  local hit={x=track.x+track.w/2-hitWidth/2,y=thumb.y,w=hitWidth,h=math.max(44,thumb.h)}
  return {track=track,thumb=thumb,hit=hit,maxScroll=maxScroll,travel=travel,total=totalHeight,viewport=viewport}
end

function ScrollList.dragValue(drag,pointerY,model)
  if not(drag and model and model.maxScroll>0 and model.travel>0) then return drag and drag.startScroll or 0 end
  return clamp(drag.startScroll+((pointerY-drag.startY)*model.maxScroll/model.travel),0,model.maxScroll)
end

return ScrollList
