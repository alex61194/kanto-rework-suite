return function(C)
  local Layout={}
  local function dims(viewport)
    return math.max(1,tonumber(viewport and viewport.width) or C.DESIGN_WIDTH),math.max(1,tonumber(viewport and viewport.height) or C.DESIGN_HEIGHT)
  end
  function Layout.transform(viewport)
    local w,h=dims(viewport)
    local scale=math.min(w/C.DESIGN_WIDTH,h/C.DESIGN_HEIGHT)
    local vw=C.DESIGN_WIDTH*scale;local vh=C.DESIGN_HEIGHT*scale
    return {scale=scale,offsetX=(w-vw)/2,offsetY=(h-vh)/2,screenWidth=w,screenHeight=h,viewportWidth=vw,viewportHeight=vh,aspect=w/h}
  end
  function Layout.classify(viewport)
    local t=Layout.transform(viewport)
    local w,h=dims(viewport)
    if w>=C.MIN_WIDE_WIDTH and h>=C.MIN_WIDE_HEIGHT and math.abs(w*9-h*16)<=16 then
      return "wide",t.scale,t.aspect
    end
    if t.aspect>=.85 then return "classic",t.scale,t.aspect end
    return "vertical",t.scale,t.aspect
  end
  function Layout.supportsWide(viewport) return true end
  function Layout.toLogical(viewport,x,y)
    local t=Layout.transform(viewport);if t.scale<=0 then return nil end
    local lx,ly=(x-t.offsetX)/t.scale,(y-t.offsetY)/t.scale
    return lx,ly,lx>=0 and ly>=0 and lx<=C.DESIGN_WIDTH and ly<=C.DESIGN_HEIGHT
  end
  function Layout.toPhysical(viewport,x,y)
    local t=Layout.transform(viewport)
    return math.floor(t.offsetX+x*t.scale+.5),math.floor(t.offsetY+y*t.scale+.5)
  end
  function Layout.physicalRect(viewport,r)
    local t=Layout.transform(viewport)
    local x=math.floor(t.offsetX+r.x*t.scale+.5);local y=math.floor(t.offsetY+r.y*t.scale+.5)
    local x2=math.floor(t.offsetX+(r.x+r.w)*t.scale+.5);local y2=math.floor(t.offsetY+(r.y+r.h)*t.scale+.5)
    return {x=x,y=y,w=math.max(1,x2-x),h=math.max(1,y2-y)}
  end
  function Layout.partyDetail() return {x=64,y=120,w=500,h=856} end
  function Layout.partySurface() return {x=596,y=120,w=1260,h=856} end
  function Layout.partyCards(count)
    local out={};for i=1,math.min(6,count or 0) do local col=(i-1)%2;local row=math.floor((i-1)/2);out[i]={x=620+col*624,y=220+row*256,w=604,h=236,index=i} end;return out
  end
  function Layout.partyNeighbor(index,direction,count)
    count=math.max(0,math.min(6,count or 0));if index<1 or index>count then return index end
    local col=(index-1)%2;local row=math.floor((index-1)/2);local nc,nr=col,row
    if direction=="left" then nc=math.max(0,col-1) elseif direction=="right" then nc=math.min(1,col+1) elseif direction=="up" then nr=math.max(0,row-1) elseif direction=="down" then nr=math.min(2,row+1) end
    local candidate=nr*2+nc+1;if candidate>count then return index end;return candidate
  end
  function Layout.columns() return {{x=64,y=120,w=380,h=856},{x=468,y=120,w=884,h=856},{x=1376,y=120,w=480,h=856}} end
  function Layout.activeMoveSlots() local out={};for i=1,4 do out[i]={x=88,y=585+(i-1)*74,w=452,h=68,index=i} end;return out end
  function Layout.learnedMoveSlots(count) local out={};for i=1,math.min(8,count or 0) do out[i]={x=592,y=196+(i-1)*76,w=472,h=68,index=i} end;return out end
  function Layout.headerTabs() return {party={x=753.5,y=24,w=140,h=40},summary={x=910.5,y=24,w=124,h=40},moves={x=1042.5,y=24,w=124,h=40}} end
  function Layout.contains(r,x,y) return r and x>=r.x and y>=r.y and x<=r.x+r.w and y<=r.y+r.h end
  return Layout
end
