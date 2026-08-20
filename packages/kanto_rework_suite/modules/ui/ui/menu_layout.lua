local Layout = {}
Layout.REF_W, Layout.REF_H = 1920, 1080
Layout.MIN_W, Layout.MIN_H = 1280, 720

local function liveDimensions()
  if love and love.graphics and love.graphics.getDimensions then
    local ok,w,h=pcall(love.graphics.getDimensions)
    if ok and tonumber(w) and tonumber(h) and w>0 and h>0 then return w,h end
  end
end

function Layout.dimensions(viewport)
  -- render.hud's viewport describes the frame which is actually being
  -- presented. During an SDL fullscreen/windowed transition,
  -- love.graphics.getDimensions() can already expose the next swapchain while
  -- the current KRS frame still owns the old one. Prefer the explicit frame
  -- dimensions so a one-frame mismatch can never trigger the native fallback.
  local w=viewport and tonumber(viewport.width)
  local h=viewport and tonumber(viewport.height)
  if w and h and w>0 and h>0 then return w,h end
  w,h=liveDimensions()
  return w or 0,h or 0
end

function Layout.isWide(viewport)
  local w,h=Layout.dimensions(viewport)
  return w>0 and h>0
end

function Layout.metrics(viewport)
  local w,h=Layout.dimensions(viewport)
  local scale=math.min(w/Layout.REF_W,h/Layout.REF_H)
  return {width=w,height=h,scale=scale,ox=(w-Layout.REF_W*scale)/2,oy=(h-Layout.REF_H*scale)/2}
end
function Layout.x(m,v) return m.ox+v*m.scale end
function Layout.y(m,v) return m.oy+v*m.scale end
function Layout.s(m,v) return v*m.scale end
function Layout.toLogical(viewport,px,py)
  local m=Layout.metrics(viewport); if m.scale<=0 then return nil,nil end
  return (px-m.ox)/m.scale,(py-m.oy)/m.scale
end
function Layout.contains(x,y,r)
  return x and y and r and x>=r.x and x<=r.x+r.w and y>=r.y and y<=r.y+r.h
end
return Layout
