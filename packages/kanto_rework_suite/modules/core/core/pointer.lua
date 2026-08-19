-- Shared pointer dispatcher. Modular overlays are the only core-owned visual
-- hit regions; product modules otherwise receive first refusal through
-- the foundation input-layer registry, then unconsumed events reach native UI.
return function(deps)
  local mod=assert(deps.mod);local runtime=assert(deps.runtime)
  local presenter=assert(deps.presenter);local foundation=deps.foundation
  local mapInteraction=deps.mapInteraction;local Layout=assert(deps.Layout)
  local persist=deps.persist or function() return true end
  local loadModule=assert(deps.loadModule,"sandbox module loader is required")
  local nativeFactory=loadModule("core/native_pointer.lua")
  local native=nativeFactory({mod=mod,runtime=runtime,presenter=presenter,mapInteraction=mapInteraction})
  runtime.nativePointer=native;runtime.pointerSessions=runtime.pointerSessions or {}
  local Pointer={}
  local function game() return runtime.game end
  local function id(ev) return ev and ev.id~=nil and ev.id or (ev and ev.source=="touch" and "touch" or "mouse") end
  local function primary(ev) return ev.source=="touch" or ev.button==nil or ev.button==1 end
  local function moved(session,ev)
    local dx=(ev.x or session.x)-session.x;local dy=(ev.y or session.y)-session.y
    local threshold=session.source=="touch" and 18 or 12
    return dx*dx+dy*dy>threshold*threshold
  end
  local function hasTop() local g=game();return g and g.stack and type(g.stack.top)=="function" and g.stack:top()~=nil end
  local function contains(r,x,y) return r and x>=r.x and y>=r.y and x<=r.x+r.w and y<=r.y+r.h end
  local function overlayAt(x,y)
    local best,bestOrder
    for id,region in pairs(runtime.overlayRegions or {}) do
      if contains(region,x,y) then
        local order=tonumber(region.order) or 0
        if not best or order>bestOrder then
          best,bestOrder=region,order;best.id=best.id or id
        end
      end
    end
    return best
  end
  local function beginOverlayDrag(region,x,y)
    if region.collapsed==true then
      runtime.focusedOverlay=region.id
      -- A reduced tab is both a restore control and a draggable object. Delay
      -- restoration until release so a pointer move can reposition it without
      -- touching the expanded window geometry.
      runtime.drag={mode="collapsed",id=region.id,offsetX=x-region.x,offsetY=y-region.y,
        width=region.w,height=region.h,edge=region.edge}
      return "tab"
    end
    -- Collapse, movement and resizing belong to the normal F8 overlay layer.
    -- F9 is reserved exclusively for context selection.
    if contains(region.collapseRect,x,y) then
      runtime.focusedOverlay=region.id
      runtime.profile[tostring(region.id).."Collapsed"]=true
      persist()
      return "control"
    end
    if runtime.contextMode==true then
      for _,control in ipairs(region.modeRects or {}) do
        if contains(control,x,y) then
          runtime.focusedOverlay=region.id
          runtime.profile[tostring(region.id).."Mode"]=control.mode
          persist()
          return "control"
        end
      end
      return false
    end
    local resizeSize=math.max(44,tonumber(region.resizeSize) or 0)
    if resizeSize>0 and x>=region.x+region.w-resizeSize
        and y>=region.y+region.h-resizeSize then
      runtime.focusedOverlay=region.id
      runtime.drag={mode="resize",id=region.id,startX=x,startY=y,
        width=region.w,height=region.h,
        widthScale=tonumber(region.widthScale) or 1,heightScale=tonumber(region.heightScale) or 1,
        widthUnit=math.max(1,tonumber(region.widthUnit) or region.w),
        heightUnit=math.max(1,tonumber(region.heightUnit) or region.h),
        minScale=tonumber(region.minScale) or .6,maxScale=tonumber(region.maxScale) or 1.6}
      return "drag"
    end
    if y>region.y+region.headerH then return false end
    runtime.focusedOverlay=region.id
    runtime.drag={mode="move",id=region.id,offsetX=x-region.x,offsetY=y-region.y,width=region.w,height=region.h};return "drag"
  end
  local function moveOverlay(x,y)
    local drag=runtime.drag;local viewport=runtime.viewport;if not (drag and viewport and runtime.profile) then return false end
    if drag.mode=="resize" then
      local dx,dy=x-drag.startX,y-drag.startY
      -- Resolve both coordinates from the same pointer event. Using the
      -- displayed starting rectangle keeps diagonal resizing immediate even
      -- when responsive content established a larger baseline than the raw
      -- design dimensions.
      local targetWidth=math.max(1,drag.width+dx)
      local targetHeight=math.max(1,drag.height+dy)
      local width=math.max(drag.minScale,math.min(drag.maxScale,
        drag.widthScale+(targetWidth-drag.width)/drag.widthUnit))
      local height=math.max(drag.minScale,math.min(drag.maxScale,
        drag.heightScale+(targetHeight-drag.height)/drag.heightUnit))
      runtime.profile[tostring(drag.id).."Width"]=width
      runtime.profile[tostring(drag.id).."Height"]=height
      return true
    end
    if drag.mode=="collapsed" then
      local safe=Layout.safeArea(viewport)
      local width,height=math.max(1,drag.width),math.max(1,drag.height)
      local tx=math.max(safe.x,math.min(safe.x+safe.w-width,x-drag.offsetX))
      local ty=math.max(safe.y,math.min(safe.y+safe.h-height,y-drag.offsetY))
      local cx,cy=tx+width/2,ty+height/2
      local distances={
        {"left",cx-safe.x},{"right",safe.x+safe.w-cx},
        {"top",cy-safe.y},{"bottom",safe.y+safe.h-cy},
      }
      table.sort(distances,function(a,b) return a[2]<b[2] end)
      local edge=distances[1][1]
      local position
      if edge=="left" or edge=="right" then
        position=(ty-safe.y)/math.max(1,safe.h-height)
      else
        position=(tx-safe.x)/math.max(1,safe.w-width)
      end
      runtime.profile[tostring(drag.id).."TabEdge"]=edge
      runtime.profile[tostring(drag.id).."TabPosition"]=math.max(0,math.min(1,position))
      drag.edge=edge
      return true
    end
    local safe=Layout.safeArea(viewport)
    local tx=math.max(safe.x,math.min(safe.x+safe.w-drag.width,x-drag.offsetX))
    local ty=math.max(safe.y,math.min(safe.y+safe.h-drag.height,y-drag.offsetY))
    local nx,ny=Layout.windowToNormalized(tx,ty,viewport,drag.width,drag.height)
    local xKey,yKey=tostring(drag.id).."X",tostring(drag.id).."Y"
    runtime.profile[xKey],runtime.profile[yKey]=nx,ny
    return true
  end
  local function endOverlayDrag()
    if not runtime.drag then return false end;runtime.drag=nil;persist();return true
  end
  local function activate(x,y)
    if native.activate(x,y) then return true end
    if native.inGameViewport(x,y) and hasTop() and not native.kind() then mod.input:tap(game(),"a");return true end
    return false
  end

  function Pointer.handle(currentGame,ev)
    if type(ev)~="table" then return false end
    runtime.game=currentGame or runtime.game
    local pointerIntent=true
    if runtime.inputMode and type(runtime.inputMode.pointerEvent)=="function" then
      pointerIntent=runtime.inputMode.pointerEvent(ev)==true
    elseif runtime.inputDevice and runtime.inputDevice.observePointer then
      runtime.inputDevice.observePointer(ev)
    else runtime.lastInput=ev.source=="touch" and "touch" or "mouse" end
    ev.kantoPointerIntent=pointerIntent
    local pid=id(ev);local phase=ev.phase;local x,y=ev.x or 0,ev.y or 0
    local session=runtime.pointerSessions[pid]
    -- Windows/SDL may emit one cursor-resync mousemoved immediately after a
    -- focus regain. InputModeResolver marks that event non-intentional; do not
    -- let it move native/UI focus or reactivate pointer mode.
    if phase=="moved" and ev.source=="mouse" and pointerIntent==false then return false end

    -- A visible overlay is globally topmost, but consumes only its own region.
    if phase=="pressed" then
      local region=overlayAt(x,y)
      if region then
        runtime.focusedOverlay=region.id
        local interaction=primary(ev) and beginOverlayDrag(region,x,y) or false
        runtime.pointerSessions[pid]={mode="overlay",source=ev.source,x=x,y=y,
          overlayId=region.id,dragging=interaction=="drag",tab=interaction=="tab",moved=false}
        return true
      end
    elseif session and session.mode=="overlay" then
      if phase=="moved" then
        session.moved=session.moved or moved(session,ev)
        if session.dragging or (session.tab and session.moved) then moveOverlay(x,y) end
      end
      if phase=="released" or phase=="cancelled" then
        runtime.pointerSessions[pid]=nil
        if session.dragging or session.tab then endOverlayDrag() end
        if phase=="released" and session.tab and not session.moved then
          runtime.profile[tostring(session.overlayId).."Collapsed"]=false
          runtime.focusedOverlay=session.overlayId
          persist()
        end
      end
      return true
    end

    if foundation and type(foundation.dispatchPointer)=="function" then
      local consumed=foundation.dispatchPointer(runtime.game,ev)
      if consumed==true then return true end
    end

    session=runtime.pointerSessions[pid]
    if phase=="moved" then
      if session then
        session.moved=session.moved or moved(session,ev)
        if session.mode=="party_drag" and session.moved then native.partyDragMove(session.drag,x,y) end
        return true
      end
      native.hover(x,y);return false
    end
    if phase=="cancelled" then
      runtime.pointerSessions[pid]=nil
      if session and session.mode=="party_drag" then native.partyDragEnd(session.drag,session.x,session.y,true) end
      return session~=nil
    end
    if phase=="pressed" then
      if ev.button==2 and hasTop() then runtime.pointerSessions[pid]={mode="back",source=ev.source,x=x,y=y};return true end
      if primary(ev) and type(native.partyDragBegin)=="function" then
        local drag=native.partyDragBegin(x,y)
        if drag then runtime.pointerSessions[pid]={mode="party_drag",source=ev.source,x=x,y=y,drag=drag};return true end
      end
      if primary(ev) and native.inGameViewport(x,y) then native.hover(x,y);runtime.pointerSessions[pid]={mode="primary",source=ev.source,x=x,y=y};return true end
      return false
    end
    if phase=="released" then
      runtime.pointerSessions[pid]=nil;if not session then return false end
      if session.mode=="back" then mod.input:tap(game(),"b");return true end
      if session.mode=="party_drag" then
        if session.moved or moved(session,ev) then native.partyDragEnd(session.drag,x,y,false)
        else native.partyDragEnd(session.drag,session.x,session.y,true);activate(x,y) end
        return true
      end
      if session.mode=="primary" and not session.moved and not moved(session,ev) then activate(x,y) end
      return true
    end
    return false
  end

  mod.hooks:wrap("input.pointer",function(next,currentGame,ev)
    if Pointer.handle(currentGame,ev) then return true end
    return next(currentGame,ev)
  end,120)

  local function installWheelBridge()
    local ok,Game=pcall(require,"src.core.Game")
    if not ok or type(Game)~="table" or type(Game.wheelmoved)~="function" then return false end
    local patch=runtime.pointerWheelPatch
    if type(patch)~="table" or patch.target~=Game then
      patch={target=Game,original=Game.wheelmoved}
      runtime.pointerWheelPatch=patch
      Game.wheelmoved=function(self,dx,dy)
        local live=runtime.pointerWheelPatch
        local consumed=false
        if live and type(live.handler)=="function" then
          local callOk,result=pcall(live.handler,self,dx,dy)
          consumed=callOk and result==true
        end
        if consumed then return true end
        if live and type(live.original)=="function" then return live.original(self,dx,dy) end
      end
    end
    patch.handler=function(currentGame,dx,dy)
      runtime.game=currentGame or runtime.game
      if dy==0 then return false end
      if runtime.inputMode and type(runtime.inputMode.wheel)=="function" then runtime.inputMode.wheel(dx,dy)
      elseif runtime.inputDevice and runtime.inputDevice.observePointer then runtime.inputDevice.observePointer({source="mouse"}) else runtime.lastInput="mouse" end
      local x,y=0,0
      if love and love.mouse and love.mouse.getPosition then x,y=love.mouse.getPosition() end
      if overlayAt(x,y) then return true end
      if foundation and type(foundation.dispatchWheel)=="function" then
        local used=foundation.dispatchWheel(runtime.game,dx,dy,x,y);if used==true then return true end
      end
      return native.wheel(dy)
    end
    runtime.wheelBridgeInstalled=true
    return true
  end
  runtime.pointer=Pointer;installWheelBridge();return Pointer
end
