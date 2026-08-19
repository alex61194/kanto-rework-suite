-- Shared footer presentation. Core owns active-device + binding resolution;
-- this component owns human-readable/glyph-like labels and visual layout.
return function(deps)
  local C=assert(deps.C);local Core=assert(deps.Core)
  local Footer={}
  local function status()
    if type(Core.inputMode)=="function" then
      local ok,v=pcall(Core.inputMode)
      if ok and type(v)=="table" and type(v.activeDevice)=="table" then return v.activeDevice end
    end
    if type(Core.inputDeviceStatus)=="function" then local ok,v=pcall(Core.inputDeviceStatus);if ok and type(v)=="table" then return v end end
    return {kind="keyboard",bindings={}}
  end
  local shortKey={escape="ESC",backspace="BKSP",["return"]="ENTER",kpenter="ENTER",space="SPACE",tab="TAB",up="UP",down="DOWN",left="LEFT",right="RIGHT"}
  local genericPad={
    a="A",b="B",x="X",y="Y",dpup="D-PAD UP",dpdown="D-PAD DOWN",dpleft="D-PAD LEFT",dpright="D-PAD RIGHT",
    leftshoulder="L1/LB",rightshoulder="R1/RB",lefttrigger="L2/LT",righttrigger="R2/RT",
    leftstick="L3/LS",rightstick="R3/RS",start="START",back="BACK",guide="GUIDE",touchpad="TOUCHPAD"
  }
  local psPad={
    a="CROSS",b="CIRCLE",x="SQUARE",y="TRIANGLE",dpup="D-PAD UP",dpdown="D-PAD DOWN",dpleft="D-PAD LEFT",dpright="D-PAD RIGHT",
    leftshoulder="L1",rightshoulder="R1",lefttrigger="L2",righttrigger="R2",leftstick="L3",rightstick="R3",
    start="OPTIONS",back="SHARE",guide="PS",touchpad="TOUCHPAD",misc1="MIC"
  }
  local xboxPad={
    a="A",b="B",x="X",y="Y",dpup="D-PAD UP",dpdown="D-PAD DOWN",dpleft="D-PAD LEFT",dpright="D-PAD RIGHT",
    leftshoulder="LB",rightshoulder="RB",lefttrigger="LT",righttrigger="RT",leftstick="LS",rightstick="RS",
    start="MENU",back="VIEW",guide="XBOX"
  }
  local nintendoPad={
    a="A",b="B",x="X",y="Y",dpup="D-PAD UP",dpdown="D-PAD DOWN",dpleft="D-PAD LEFT",dpright="D-PAD RIGHT",
    leftshoulder="L",rightshoulder="R",lefttrigger="ZL",righttrigger="ZR",leftstick="L-STICK",rightstick="R-STICK",
    start="+",back="-",guide="HOME"
  }
  local function rawBinding(game,action,kind,st)
    -- Custom KRS actions own their bindings in Core.inputActions; native GB
    -- actions own theirs in Core.inputBinding. Resolve from the authoritative
    -- registry first so a rebinding is reflected immediately in every footer.
    if Core.inputActions and type(Core.inputActions.definition)=="function" then
      local ok,def=pcall(Core.inputActions.definition,action)
      if ok and def then
        local slot=kind=="controller" and "pad" or "key"
        local bound=type(Core.inputActions.binding)=="function" and Core.inputActions.binding(action,slot) or nil
        return bound or "UNBOUND"
      end
    end
    if st and st.bindings and st.bindings[action] then return st.bindings[action] end
    if type(Core.inputBinding)=="function" then local ok,v=pcall(Core.inputBinding,action,kind);if ok and v then return v end end
    return action
  end
  local function physicalLabel(raw,st)
    st=st or status();raw=tostring(raw or "UNBOUND");local low=raw:lower()
    if st.kind=="controller" then
      local map=genericPad
      if st.controllerFamily=="playstation" then map=psPad
      elseif st.controllerFamily=="xbox" then map=xboxPad
      elseif st.controllerFamily=="nintendo" then map=nintendoPad end
      return map[low] or raw:upper():sub(1,14)
    end
    return shortKey[low] or raw:upper():sub(1,12)
  end
  local function labelBinding(game,action,st)
    st=st or status();local raw=tostring(rawBinding(game,action,st.kind,st) or action)
    return physicalLabel(raw,st)
  end
  function Footer.physicalLabel(raw,kind)
    local st=status()
    if kind=="controller" and st.kind~="controller" then
      st={kind="controller",controllerFamily=st.controllerFamily,controllerModel=st.controllerModel,controllerName=st.controllerName,bindings=st.bindings}
      if not st.controllerFamily and type(Core.inputDeviceStatus)=="function" then
        local ok,v=pcall(Core.inputDeviceStatus);if ok and type(v)=="table" then st.controllerFamily=v.controllerFamily;st.controllerModel=v.controllerModel;st.controllerName=v.controllerName end
      end
    elseif kind=="keyboard" and st.kind=="controller" then
      -- Binding lists frequently show keyboard and controller columns at the
      -- same time. Force keyboard labelling here instead of letting the active
      -- DualSense family turn RETURN/TAB/etc. into generic controller text.
      st={kind="keyboard",bindings=st.bindings}
    end
    return physicalLabel(raw,st)
  end
  local function nav(game,st,vertical)
    if st.kind=="touch" then return "SWIPE" end
    local u,d,l,r=labelBinding(game,"up",st),labelBinding(game,"down",st),labelBinding(game,"left",st),labelBinding(game,"right",st)
    if st.kind=="controller" and u=="D-PAD UP" and d=="D-PAD DOWN" and l=="D-PAD LEFT" and r=="D-PAD RIGHT" then return vertical and "D-PAD UP/DOWN" or "D-PAD" end
    if st.kind~="controller" and u=="UP" and d=="DOWN" and l=="LEFT" and r=="RIGHT" then return vertical and "UP/DOWN" or "ARROWS" end
    return vertical and (u.."/"..d) or (u.."/"..d.."/"..l.."/"..r)
  end
  local function deviceLabel(st)
    if st.kind=="touch" then return "TÁCTIL" end
    if st.kind~="controller" then return "TECLADO + RATÓN" end
    local n=tostring(st.controllerName or ""):lower()
    if st.controllerFamily=="playstation" then return st.controllerModel=="dualsense" and "DUALSENSE" or "MANDO PLAYSTATION" end
    if st.controllerFamily=="xbox" then return "MANDO XBOX" end
    if st.controllerFamily=="nintendo" then return "MANDO NINTENDO" end
    return "MANDO"
  end
  local function back(game,st)
    if st.kind=="touch" then return "VOLVER" end
    local b=labelBinding(game,"b",st);return st.kind=="controller" and b or (b.."/CLIC DER.")
  end

  function Footer.resolve(game,prompts)
    local st=status();local out={}
    for _,p in ipairs(prompts or {}) do
      local show=(not p.pointerOnly or st.kind=="keyboard" or st.kind=="mouse")
        and (not p.keyboardOnly or st.kind=="keyboard" or st.kind=="mouse")
        and (not p.controllerOnly or st.kind=="controller")
        and (not p.touchOnly or st.kind=="touch")
      if show then
        local key=p.key
        if p.action then key=labelBinding(game,p.action,st) end
        if p.navigation then key=nav(game,st,p.navigation=="vertical") end
        out[#out+1]={key=key or "",label=p.label or "",disabled=p.disabled==true}
      end
    end
    return out,deviceLabel(st)
  end

  -- Validated Party/Summary/Moves physical-window footer path.
  function Footer.draw(game,prompts,_,fonts,metrics,colors)
    colors=colors or C.colors;local y=metrics.y(C.DESIGN_HEIGHT-C.FOOTER_HEIGHT);local x0=metrics.x(0);local width=metrics.len(C.DESIGN_WIDTH);local height=metrics.len(C.FOOTER_HEIGHT)
    local function set(c,a) love.graphics.setColor(c[1],c[2],c[3],a or c[4] or 1) end
    local function txt(font,v,x,yy,c,a) love.graphics.setFont(font);set(c,a);love.graphics.print(tostring(v or ""),x,yy) end
    set(colors.header);love.graphics.rectangle("fill",x0,y,width,height)
    local resolved,dlabel=Footer.resolve(game,prompts);local x=metrics.x(32);local gap=math.max(16,metrics.len(28));local inner=math.max(8,metrics.len(10))
    for _,p in ipairs(resolved) do local kw=fonts.key:getWidth(p.key);local lw=fonts.label:getWidth(p.label);local a=p.disabled and .45 or 1;txt(fonts.key,p.key,x,y+metrics.len(21),colors.white,a);txt(fonts.label,p.label,x+kw+inner,y+metrics.len(22),colors.white,.76*a);x=x+kw+inner+lw+gap end
    love.graphics.setFont(fonts.device);local dw=fonts.device:getWidth(dlabel);local right=metrics.x(C.DESIGN_WIDTH-32);txt(fonts.device,dlabel,right-dw,y+metrics.len(22),colors.white,1)
  end

  local function menuPrompts(game,kind,region)
    local st=status();if st.kind=="touch" then return {{key="TOCAR",label="SELECCIONAR"},{key="DESLIZAR",label="MOVER"},{key="VOLVER",label="VOLVER"}},deviceLabel(st) end
    if kind=="main" then return {{key=nav(game,st,false),label="SELECCIONAR"},{key=labelBinding(game,"a",st),label="ABRIR"},{key=labelBinding(game,"select",st),label="ACCIONES"},{key=back(game,st),label="VOLVER"}},deviceLabel(st) end
    if kind=="mod_extension" then return {{key=nav(game,st,false),label="SELECCIONAR"},{key=labelBinding(game,"a",st),label="ABRIR / CONTINUAR"},{key=back(game,st),label="VOLVER"}},deviceLabel(st) end
    if kind=="controls" then return {{key=nav(game,st,true),label="SELECCIONAR"},{key=labelBinding(game,"a",st),label="ASIGNAR/ABRIR"},{key=labelBinding(game,"select",st),label="BORRAR"},{key=back(game,st),label="VOLVER"}},deviceLabel(st) end
    if kind=="map" then return {{key=nav(game,st,false),label="SELECCIONAR"},{key=labelBinding(game,"a",st),label="VOLAR / ABRIR"},{key=back(game,st),label="VOLVER"}},deviceLabel(st) end
    if kind=="options" then
      if region=="header" then return {{key=nav(game,st,true),label="SECCIÓN"},{key=labelBinding(game,"UI_SUBMENU_PREV",st).."/"..labelBinding(game,"UI_SUBMENU_NEXT",st),label="CATEGORÍA"},{key=labelBinding(game,"a",st),label="ABRIR"},{key=back(game,st),label="VOLVER"}},deviceLabel(st) end
      if region=="controls" then return {{key=nav(game,st,true),label="ACCESO RÁPIDO"},{key=labelBinding(game,"a",st),label="ASIGNAR"},{key=labelBinding(game,"select",st),label="RESTABLECER"},{key=labelBinding(game,"left",st).."/"..back(game,st),label="CATEGORÍAS"}},deviceLabel(st) end
      return {{key=nav(game,st,true),label="SELECCIONAR"},{key=labelBinding(game,"left",st).."/"..labelBinding(game,"right",st),label="CAMBIAR"},{key=labelBinding(game,"a",st),label="ABRIR/SIGUIENTE"},{key=labelBinding(game,"select",st),label="SECCIONES"},{key=back(game,st),label="VOLVER"}},deviceLabel(st)
    end
    local p
    if kind=="mods" and region=="header" then
      p={{key=nav(game,st,true),label="SECCIÓN"},{key=labelBinding(game,"a",st),label="ABRIR"},{key=back(game,st),label="VOLVER"}}
    elseif kind=="mods" and region=="info" then
      p={{key=nav(game,st,true),label="DESPLAZAR DETALLES"},{key=labelBinding(game,"left",st).."/"..back(game,st),label="LISTA DE MODS"}}
    else
      p={{key=nav(game,st,false),label="SELECCIONAR"},{key=labelBinding(game,"a",st),label=kind=="mods" and "EXPANDIR/USAR" or "SELECCIONAR"},{key=labelBinding(game,"select",st),label="ACTIVAR"},{key=back(game,st),label="VOLVER"}}
    end
    if kind=='mods' then p[#p+1]={key=labelBinding(game,'UI_SUBMENU_PREV',st)..'/'..labelBinding(game,'UI_SUBMENU_NEXT',st),label='PESTAÑA'} end
    if region=="restart" then p[#p+1]={key=labelBinding(game,"start",st),label="REINICIAR"} end
    return p,deviceLabel(st)
  end

  function Footer.menuDraw(runtime,m,Draw,colors,game,kind,region)
    Draw.roundRect(m,"fill",0,1016,1920,64,0,colors.inverse);local prompts,dlabel=menuPrompts(game,kind,region);local x=32
    for _,p in ipairs(prompts) do Draw.text(runtime,m,p.key,x,1037,13,colors.textInverse,{weight="semibold"});local font=Draw.font(runtime,m,13,"semibold");local keyW=font:getWidth(p.key)/m.scale;Draw.text(runtime,m,p.label,x+keyW+9,1038,12,colors.textInverse,{weight="medium",alpha=.76});x=x+math.max(128,keyW+9+70)+20 end
    Draw.text(runtime,m,dlabel,1660,1038,13,colors.textInverse,{weight="semibold",width=228,align="right"})
  end
  return Footer
end
