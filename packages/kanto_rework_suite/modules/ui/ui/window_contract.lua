-- KRS desktop 16:9 window contract.
-- Windowed surfaces are snapped to 16:9; fullscreen/borderless surfaces that
-- cannot provide 16:9 are left untouched and KRS presenters fall back to the
-- vanilla UI until a valid surface returns. No save data is written here.
return function(deps)
  local Layout=assert(deps.Layout)
  local W={lastW=nil,lastH=nil,lastValid=false,lastFallback=false,lastReason=nil,snapCount=0,guard=false,pendingW=nil,pendingH=nil}
  local function valid(w,h)
    w,h=tonumber(w),tonumber(h)
    return w and h and w>=Layout.MIN_W and h>=Layout.MIN_H and math.abs(w*9-h*16)<=16
  end
  local function mode()
    if not(love and love.window and love.window.getMode) then return nil end
    local ok,w,h,flags=pcall(love.window.getMode)
    if not ok then return nil end
    return tonumber(w),tonumber(h),type(flags)=='table' and flags or {}
  end
  local function safeFlags(flags)
    return {
      fullscreen=false,borderless=false,resizable=flags.resizable~=false,
      vsync=flags.vsync,msaa=flags.msaa,stencil=flags.stencil,depth=flags.depth,
      display=flags.display,highdpi=flags.highdpi,usedpiscale=flags.usedpiscale,
      minwidth=Layout.MIN_W,minheight=Layout.MIN_H,
    }
  end
  local function target(w,h)
    local tw,th
    if W.lastW and W.lastH and math.abs(h-W.lastH)>math.abs(w-W.lastW) then
      th=math.max(Layout.MIN_H,math.floor(h+.5));tw=math.floor(th*16/9+.5)
    else
      tw=math.max(Layout.MIN_W,math.floor(w+.5));th=math.floor(tw*9/16+.5)
    end
    if th<Layout.MIN_H then th=Layout.MIN_H;tw=math.floor(th*16/9+.5) end
    return tw,th
  end
  function W.reconcile(viewport)
    local vw,vh=Layout.dimensions(viewport)
    local w,h,flags=mode();w,h=w or vw,h or vh;flags=flags or {}
    if valid(vw,vh) then
      W.lastW,W.lastH=vw,vh;W.lastValid=true;W.lastFallback=false;W.lastReason=nil;W.pendingW,W.pendingH=nil,nil
      return {valid=true,fallback=false,snapped=false,width=vw,height=vh}
    end
    W.lastValid=false;W.lastFallback=true
    if flags.fullscreen or flags.borderless then
      W.lastReason=flags.fullscreen and 'non_16_9_fullscreen' or 'non_16_9_borderless'
      return {valid=false,fallback=true,snapped=false,reason=W.lastReason,width=vw,height=vh}
    end
    if W.guard or not(love and love.window and (love.window.updateMode or love.window.setMode)) then
      W.lastReason='non_16_9_window_unavailable'
      return {valid=false,fallback=true,snapped=false,reason=W.lastReason,width=vw,height=vh}
    end
    local tw,th=target(w,h)
    -- LOVE/SDL can expose the old viewport for one or more frames after an
    -- updateMode request. Do not hammer the backend with the same resize or
    -- oscillate KRS <-> Vanilla while the swapchain catches up.
    if W.pendingW==tw and W.pendingH==th then
      W.lastReason='window_snap_pending'
      return {valid=false,fallback=true,snapped=false,pending=true,reason=W.lastReason,targetWidth=tw,targetHeight=th,width=vw,height=vh}
    end
    if W.pendingW and (W.pendingW~=tw or W.pendingH~=th) then W.pendingW,W.pendingH=nil,nil end
    if tw==w and th==h then
      W.lastReason='non_16_9_unsnappable'
      return {valid=false,fallback=true,snapped=false,reason=W.lastReason,width=vw,height=vh}
    end
    W.guard=true
    local fn=love.window.updateMode or love.window.setMode
    local ok,result=pcall(fn,tw,th,safeFlags(flags))
    W.guard=false
    if ok and result~=false then
      W.pendingW,W.pendingH=tw,th;W.snapCount=W.snapCount+1;W.lastReason='window_snap_pending'
      return {valid=false,fallback=true,snapped=true,reason=W.lastReason,targetWidth=tw,targetHeight=th,width=vw,height=vh}
    end
    W.pendingW,W.pendingH=nil,nil;W.lastReason='window_snap_failed'
    return {valid=false,fallback=true,snapped=false,reason=W.lastReason,error=ok and 'backend rejected mode' or tostring(result),width=vw,height=vh}
  end
  function W.status()
    return {valid=W.lastValid,fallback=W.lastFallback,reason=W.lastReason,snapCount=W.snapCount,lastWidth=W.lastW,lastHeight=W.lastH,pendingWidth=W.pendingW,pendingHeight=W.pendingH,ratio='16:9',minimum={width=Layout.MIN_W,height=Layout.MIN_H}}
  end
  W.isValid=valid
  return W
end
