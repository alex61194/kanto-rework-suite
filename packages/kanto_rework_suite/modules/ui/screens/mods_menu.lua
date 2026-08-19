local ModsMenu={}
function ModsMenu.factory(runtime)
  local Core=assert(runtime.Core);local Screen={};Screen.__index=Screen;Screen.isOpaque=true
  local VIEW_TOP,VIEW_H=218,710
  local VIEW_BOTTOM=VIEW_TOP+VIEW_H
  local function rowKey(row,i)
    if not row then return "row:"..tostring(i) end
    if row.kind=="mod" and row.mod then return "mod:"..tostring(row.mod.id) end
    if row.kind=="option" and row.mod and row.option then return "option:"..tostring(row.mod.id)..":"..tostring(row.option.id) end
    if row.kind=="utility" and row.mod and row.utility then return "utility:"..tostring(row.mod.id)..":"..tostring(row.utility.id) end
    if row.kind=="profile" and row.profile then return "profile:"..tostring(row.profile.id or row.label or i) end
    if row.kind=="error" then return "error:"..tostring(row.error and row.error.modId or "system")..":"..tostring(i) end
    return (row.kind or "row")..":"..tostring(row.label or i)
  end
  local function rowHeight(row) if row.header then return row.subheader and 30 or 34 end return (row.kind=="option" and 52 or 58)+8 end

  function Screen.new(game)
    local session,err=Core.createModRuntime(game);assert(session,err or "Core Mod runtime unavailable")
    local self=setmetatable({game=game,session=session,inner=session.native,kind="mods",tab=1,headerIndex=1,region="header",focusIndex=1,focusKey=nil,selectedId=nil,hoverTab=nil,hoverIndex=nil,overlay=nil,prompt=nil,notice=nil,expanded={},scrollY=0,scrollDrag=nil,infoScrollY=0,infoScrollDrag=nil,infoContentHeight=0,infoViewportHeight=0,infoKey=nil,nav=runtime.Focus.new("kanto_rework_ui.mods")},Screen)
    runtime.Focus.navigation(self.nav,"tab:1")
    return self
  end
  function Screen:isWide() return runtime.Layout.isWide(nil) end
  function Screen:enter(...) self.session:enter();self:refresh();self:selectFirst();self.region="header";self.headerIndex=self.tab;self:syncFocus() end
  function Screen:exit(...) if self.inner and self.inner.exit then return self.inner:exit(...) end end
  function Screen:sgbPalettes(game) if self.inner and self.inner.sgbPalettes then return self.inner:sgbPalettes(game) end end
  function Screen:draw() if not self:isWide() and self.inner and self.inner.draw then self.inner:draw() end end
  function Screen:restartRequired() return self.session:restartRequired() end
  function Screen:dirtyChanges() return self:restartRequired() end
  function Screen:modCard(mod) return mod end
  function Screen:isExpanded(modOrId) local id=type(modOrId)=="table" and modOrId.id or modOrId;return id and self.expanded[id]==true end
  function Screen:setExpanded(modOrId,value)
    local id=type(modOrId)=="table" and modOrId.id or modOrId;if not id then return false end
    local m=type(modOrId)=="table" and modOrId or self.session:model(id)
    self.expanded[id]=(m and m.enabled==true and value==true) or false;return self.expanded[id]
  end
  function Screen:toggleExpanded(mod)
    if not(mod and mod.enabled) then if mod then self.expanded[mod.id]=false end;return false end
    self.expanded[mod.id]=not self.expanded[mod.id];self:refresh();self:focusMod(mod.id);return true
  end
  local CATEGORY_ORDER={
    ["SUITE KANTO REWORK"]=1,["AUDIO Y SONIDO"]=2,["GRÁFICOS Y EFECTOS"]=3,
    ["JUGABILIDAD Y COMBATE"]=4,["MUNDO Y EXPLORACIÓN"]=5,["INTERFAZ Y MENÚS"]=6,
    ["CALIDAD DE VIDA"]=7,["SISTEMA Y HERRAMIENTAS"]=8,["OTROS"]=9,
  }
  local KRS_ORDER={kanto_rework_suite=1}
  local function isKrsFirstParty(id) return tostring(id or ""):lower():match("^kanto_rework_")~=nil end
  local function semanticCategory(m)
    local id=tostring(m and m.id or ""):lower()
    if isKrsFirstParty(id) then return "SUITE KANTO REWORK" end
    local hay=table.concat({tostring(m and m.name or ""),tostring(m and m.category or ""),tostring(m and m.description or ""),id}," "):lower()
    if hay:find("music",1,true) or hay:find("audio",1,true) or hay:find("sound",1,true) or hay:find("cry",1,true) or hay:find("cries",1,true) or hay:find("ost",1,true) then return "AUDIO Y SONIDO" end
    if hay:find("voxel",1,true) or hay:find("sprite",1,true) or hay:find("graphic",1,true) or hay:find("visual",1,true) or hay:find("palette",1,true) or hay:find("shader",1,true) or hay:find("background",1,true) or hay:find("battle art",1,true) then return "GRÁFICOS Y EFECTOS" end
    if hay:find("battle",1,true) or hay:find("combat",1,true) or hay:find("trainer",1,true) or hay:find("rematch",1,true) or hay:find("gameplay",1,true) or hay:find("difficulty",1,true) or hay:find(" exp",1,true) then return "JUGABILIDAD Y COMBATE" end
    if hay:find("overworld",1,true) or hay:find("world",1,true) or hay:find("map",1,true) or hay:find("movement",1,true) or hay:find("explor",1,true) then return "MUNDO Y EXPLORACIÓN" end
    if hay:find("interface",1,true) or hay:find(" ui",1,true) or hay:find("menu",1,true) or hay:find("hud",1,true) then return "INTERFAZ Y MENÚS" end
    if hay:find("quality of life",1,true) or hay:find("qol",1,true) or hay:find("inventory",1,true) or hay:find("bag",1,true) or hay:find("convenience",1,true) then return "CALIDAD DE VIDA" end
    if hay:find("system",1,true) or hay:find("cache",1,true) or hay:find("debug",1,true) or hay:find("tool",1,true) or hay:find("framework",1,true) then return "SISTEMA Y HERRAMIENTAS" end
    return "OTROS"
  end
  function Screen:modRows()
    local cats,map={},{}
    for _,m in ipairs(self.session:models() or {}) do
      if not m.enabled then self.expanded[m.id]=false end
      local c=semanticCategory(m);if not map[c] then map[c]={};cats[#cats+1]=c end;map[c][#map[c]+1]=m
    end
    table.sort(cats,function(a,b)local ao,bo=CATEGORY_ORDER[a] or 99,CATEGORY_ORDER[b] or 99;if ao==bo then return a<b end;return ao<bo end);local out={}
    for _,c in ipairs(cats) do
      out[#out+1]={header=true,label=c,key="header:"..c}
      table.sort(map[c],function(a,b)
        if c=="SUITE KANTO REWORK" then local ao,bo=KRS_ORDER[tostring(a.id)] or 99,KRS_ORDER[tostring(b.id)] or 99;if ao~=bo then return ao<bo end end
        return tostring(a.name or a.id)<tostring(b.name or b.id)
      end)
      for _,m in ipairs(map[c]) do
        out[#out+1]={kind="mod",mod=m,label=m.name or m.id,key="mod:"..m.id}
        if m.enabled and self:isExpanded(m.id) then
          local activeGroup=nil
          for _,u in ipairs((self.session.utilities and self.session:utilities(m.id)) or {}) do
            local group=tostring(u.group or "CARACTERÍSTICAS"):upper()
            if group~=activeGroup then activeGroup=group;out[#out+1]={header=true,subheader=true,mod=m,label=group,key="utility-group:"..m.id..":"..group} end
            out[#out+1]={kind="utility",mod=m,utility=u,label=u.label or u.id,key="utility:"..m.id..":"..u.id}
          end
          for _,o in ipairs(self.session:options(m.id) or {}) do
            local group=tostring(o.group or "GENERAL"):upper()
            if group~=activeGroup then activeGroup=group;out[#out+1]={header=true,subheader=true,mod=m,label=group,key="option-group:"..m.id..":"..group} end
            out[#out+1]={kind="option",mod=m,option=o,def=o,label=o.label or o.id,key="option:"..m.id..":"..o.id}
          end
        end
      end
    end
    if #out==0 then out[1]={header=true,label="NO HAY MODS INSTALADOS",key="empty"} end
    return out
  end
  function Screen:profileRows() local out={};for i,r in ipairs(self.session:profiles() or {}) do out[#out+1]={kind="profile",profile=r,label=r.label,key="profile:"..tostring(r.label or i)} end;return out end
  function Screen:errorRows()
    local out,groups,byGroup={},{},{}
    for i,r in ipairs(self.session:errors() or {}) do
      local group=tostring(r.modName or r.modId or 'SISTEMA'):upper()
      if not byGroup[group] then byGroup[group]={};groups[#groups+1]=group end
      byGroup[group][#byGroup[group]+1]={kind='error',label=r.label,error=r,key='error:'..tostring(r.modId or 'system')..':'..i}
    end
    for _,group in ipairs(groups) do out[#out+1]={header=true,label=group,key='error-group:'..group};for _,row in ipairs(byGroup[group]) do out[#out+1]=row end end
    if #out==0 then out[1]={header=true,label='SIN ERRORES',key='error-empty'} end;return out
  end
  function Screen:rows() if self.tab==1 then return self:modRows() elseif self.tab==2 then return self:profileRows() else return self:errorRows() end end
  function Screen:rowLayout(rows)
    rows=rows or self:rows();local y=0;local out={}
    for i,row in ipairs(rows) do local h=rowHeight(row);out[i]={top=y,h=h,row=row};y=y+h end
    return out,y
  end
  function Screen:maxScroll(rows) local _,total=self:rowLayout(rows);return math.max(0,total-VIEW_H) end
  function Screen:setScroll(v,rows) self.scrollY=math.max(0,math.min(tonumber(v) or 0,self:maxScroll(rows)));return self.scrollY end
  function Screen:scrollBy(delta) return self:setScroll(self.scrollY+(tonumber(delta) or 0)) end
  function Screen:ensureVisible(index)
    local rows=self:rows();local layout=self:rowLayout(rows);local g=layout[index];if not g then return end
    local top,bottom=g.top,g.top+g.h
    if top<self.scrollY then self:setScroll(top,rows)
    elseif bottom>self.scrollY+VIEW_H then self:setScroll(bottom-VIEW_H,rows) end
  end
  function Screen:findKey(key,rows) for i,r in ipairs(rows or self:rows()) do if (r.key or rowKey(r,i))==key then return i,r end end end
  function Screen:clampFocus()
    local rows=self:rows();if #rows==0 then self.focusIndex=1;self.focusKey=nil;return end
    local i=self.focusKey and self:findKey(self.focusKey,rows) or nil
    if not i then i=math.max(1,math.min(self.focusIndex or 1,#rows)) end
    if not rows[i] or rows[i].header then for n,r in ipairs(rows) do if not r.header then i=n;break end end end
    self.focusIndex=i or 1;local r=rows[self.focusIndex];self.focusKey=r and (r.key or rowKey(r,self.focusIndex)) or nil
    if r and r.mod then self.selectedId=r.mod.id end;self:setScroll(self.scrollY,rows)
  end
  function Screen:refresh() self.session:refresh();self.prompt=self.session:prompt();self:clampFocus() end
  function Screen:selectFirst()
    self.focusIndex=1;self.focusKey=nil;self:clampFocus();if not self.selectedId then local ms=self.session:models();if ms[1] then self.selectedId=ms[1].id end end
  end
  function Screen:focusMod(id) local i,r=self:findKey("mod:"..tostring(id));if i then self.focusIndex=i;self.focusKey=r.key;self.selectedId=id;self:ensureVisible(i) end end
  function Screen:activeItemId()
    if self.region=="header" then return "tab:"..self.headerIndex end
    if self.region=="info" then return "info:"..tostring(self.selectedId or "none") end
    return self.focusKey or ("row:"..self.focusIndex)
  end
  function Screen:syncFocus() runtime.Focus.navigation(self.nav,self:activeItemId()) end
  function Screen:move(dir)
    local rows=self:rows();if #rows==0 then return end;local i=self.focusIndex;local step=(tonumber(dir) or 1)<0 and -1 or 1
    while true do i=i+step;if i<1 or i>#rows then return end;if not rows[i].header then self.focusIndex=i;self.focusKey=rows[i].key or rowKey(rows[i],i);if rows[i].mod then self.selectedId=rows[i].mod.id end;self:ensureVisible(i);self:syncFocus();return end end
  end
  function Screen:setTab(tab,keepRegion)
    self.tab=math.max(1,math.min(3,tab));self.headerIndex=self.tab;self.focusIndex=1;self.focusKey=nil;self.scrollY=0;self:clampFocus();if not keepRegion then self.region="header" end;self:syncFocus()
  end
  function Screen:cycleTab(delta) local nextTab=((self.tab-1+(delta or 1))%3)+1;self:setTab(nextTab,true);self.region='content';return true end
  function Screen:enterContent() self.region="content";self:clampFocus();self:ensureVisible(self.focusIndex);self:syncFocus() end
  function Screen:leaveContent() self.region="header";self.hoverIndex=nil;self:syncFocus() end
  function Screen:infoMaxScroll()
    return math.max(0,(tonumber(self.infoContentHeight) or 0)-(tonumber(self.infoViewportHeight) or 0))
  end
  function Screen:setInfoMetrics(contentHeight,viewportHeight,key)
    key=tostring(key or "none")
    if self.infoKey~=key then self.infoKey=key;self.infoScrollY=0 end
    self.infoContentHeight=math.max(0,tonumber(contentHeight) or 0)
    self.infoViewportHeight=math.max(0,tonumber(viewportHeight) or 0)
    self.infoScrollY=math.max(0,math.min(tonumber(self.infoScrollY) or 0,self:infoMaxScroll()))
    if self.region=="info" and self:infoMaxScroll()<=0 then self.region="content";self:syncFocus() end
    return self.infoScrollY
  end
  function Screen:setInfoScroll(value)
    self.infoScrollY=math.max(0,math.min(tonumber(value) or 0,self:infoMaxScroll()))
    return self.infoScrollY
  end
  function Screen:scrollInfoBy(delta) return self:setInfoScroll(self.infoScrollY+(tonumber(delta) or 0)) end
  function Screen:enterInfo()
    if self:infoMaxScroll()<=0 then return false end
    self.region="info";self.hoverIndex=nil;self:syncFocus();return true
  end
  function Screen:leaveInfo() self.region="content";self:syncFocus();return true end
  function Screen:currentRow() return self:rows()[self.focusIndex] end
  function Screen:currentMod() local r=self:currentRow();if r and r.mod then return r.mod end;return self.selectedId and self.session:model(self.selectedId) or nil end
  function Screen:infoContext()
    local row=self:currentRow();local currentMod=self:currentMod()
    if row and row.kind=="option" and row.option and row.mod then
      local description=row.option.description
      if row.option.id=="__reset" and (not description or description=="") then
        description="Restablece todas las opciones de este mod a sus valores predeterminados."
      end
      return {
        kind="option",mod=row.mod,option=row.option,
        label=row.label or row.option.label or row.option.id,
        value=self:optionValue(row),description=description or "",
      }
    end
    if row and row.kind=="utility" and row.utility and row.mod then
      return {kind="utility",mod=row.mod,utility=row.utility,label=row.label,description=row.utility.description or ""}
    end
    return {kind="mod",mod=currentMod}
  end
  function Screen:optionControl(row) local d=row and row.option;if not d then return "multi" end;if d.id=="__reset" or d.type=="action" or d.type=="text" then return "submenu" elseif d.type=="toggle" then return "toggle" elseif d.type=="number" then return "stepper" else return "multi" end end
  function Screen:optionValue(row)
    local option=row and row.option;if not option then return "" end
    local value=option.displayValue
    if type(value)=="function" then local ok,v=pcall(value,self.game,row.mod);if ok then value=v else value="UNAVAILABLE" end end
    return tostring(value==nil and "" or value)
  end
  function Screen:changeOption(row,dir,activate)
    if not(row and row.option and row.mod) then return false end;self.selectedId=row.mod.id
    local ok,valueOrErr
    if type(row.option.adjust)=="function" then ok,valueOrErr=row.option.adjust(self.game,dir or 1,activate==true)
    else ok,valueOrErr=self.session:adjustOption(row.mod.id,row.option.id,dir or 1) end
    if not ok then self.notice=tostring(valueOrErr or "OPTION UNAVAILABLE") else self.notice=nil end;self:refresh();return ok
  end
  function Screen:toggle(mod)
    if not mod then return end;self.selectedId=mod.id;local id=mod.id;local ok,err=self.session:toggle(id);if not ok then self.notice=tostring(err or "TOGGLE FAILED") end;self:refresh();local refreshed=self.session:model(id);if not(refreshed and refreshed.enabled) then self.expanded[id]=false;self:refresh() end;self:focusMod(id)
  end
  function Screen:activateProfile(row) if row and row.profile then self.session:activateProfile(row.profile);self:refresh() end end
  function Screen:activateCurrent()
    local r=self:currentRow();if not r or r.header or r.inert then return end
    if r.kind=="mod" then self.selectedId=r.mod.id;self:toggleExpanded(r.mod)
    elseif r.kind=="option" then self:changeOption(r,1,true)
    elseif r.kind=="utility" then
      local ok,state,err=self.session:openUtility(r.mod.id,r.utility.id)
      if not ok then self.notice=tostring(err or "MOD UTILITY UNAVAILABLE")
      elseif state then if state.kind=='graphics_editor' then self.game.stack:push(state) else self.game.stack:push(runtime.ModExtension.wrap(runtime,self.game,state,{mod=r.mod,title=r.label,presentation=r.utility.presentation})) end end
    elseif r.kind=="profile" then self:activateProfile(r)
    elseif r.kind=="error" and r.error then self.overlay={kind='error_detail',title=tostring(r.error.modName or r.error.modId or 'SYSTEM'):upper(),detail=tostring(r.error.detail or r.label or ''),scroll=0} end
  end
  function Screen:performRestart()
    local ok,mode,reason=self.session:saveAndRestart()
    self.overlay=nil
    if ok then self.notice="GAME SAVED · RESTART REQUESTED"
    else self.notice=tostring(reason or "Automatic restart is unavailable. Restart the game manually.") end
    return ok,mode,reason
  end
  function Screen:deferRestart() self.overlay=nil;self.game.stack:pop();return true end
  function Screen:discardAndLeave() self.session:discardChanges();self.overlay=nil;self.game.stack:pop();return true end
  function Screen:openRestartPrompt()
    self.overlay={kind="restart",index=1,lines={"ONE OR MORE MOD CHANGES REQUIRE A RESTART.","Restart Now saves your game, restarts it, then reloads the same save.","You can also keep the changes pending or discard them."}}
  end
  function Screen:requestLeave() if not self:restartRequired() then self.game.stack:pop();return end;self:openRestartPrompt() end
  function Screen:activeOverlay() return self.overlay or self.prompt end
  function Screen:updateOverlay(input)
    if self.prompt then
      local ov=self.prompt;if ov.kind=="ok" then if input:wasPressed("a") or input:wasPressed("b") then self.session:respondPrompt(false);self:refresh() end;return true end
      if input:wasPressed("up") or input:wasPressed("down") or input:wasPressed("left") or input:wasPressed("right") then ov.index=ov.index==1 and 2 or 1 elseif input:wasPressed("a") then self.session:respondPrompt(ov.index==1);self:refresh() elseif input:wasPressed("b") then self.session:respondPrompt(false);self:refresh() end;return true
    end
    local ov=self.overlay;if not ov then return false end
    if ov.kind=='error_detail' then if input:wasPressed('up') then ov.scroll=math.max(0,(ov.scroll or 0)-48) elseif input:wasPressed('down') then ov.scroll=(ov.scroll or 0)+48 elseif input:wasPressed('a') or input:wasPressed('b') then self.overlay=nil end;return true end
    if input:wasPressed("left") or input:wasPressed("up") then ov.index=ov.index>1 and ov.index-1 or 3
    elseif input:wasPressed("right") or input:wasPressed("down") then ov.index=ov.index<3 and ov.index+1 or 1
    elseif input:wasPressed("a") then if ov.index==1 then self:performRestart() elseif ov.index==2 then self:deferRestart() else self:discardAndLeave() end
    elseif input:wasPressed("b") then self.overlay=nil end;return true
  end
  function Screen:hit(lx,ly,list) for i,r in pairs(list or {}) do if runtime.Layout.contains(lx,ly,r) then return i,r end end end
  function Screen:pointerEvent(event,lx,ly)
    if not self:isWide() then return false end
    if event.phase=="moved" and self.infoScrollDrag then
      local sb=runtime.modInfoScrollbar
      if sb then self:setInfoScroll(runtime.Scroll.dragValue(self.infoScrollDrag,ly,sb)) end
      return true
    end
    if event.phase=="moved" and self.scrollDrag then
      local sb=runtime.modScrollbar;if sb and sb.maxScroll>0 and sb.travel>0 then self:setScroll(self.scrollDrag.startScroll+(ly-self.scrollDrag.startY)*sb.maxScroll/sb.travel) end;return true
    end
    if event.phase=="released" or event.phase=="cancelled" then self.scrollDrag=nil;self.infoScrollDrag=nil;return true end
    if event.phase=="moved" then
      self.hoverTab=self:hit(lx,ly,runtime.modTabRects);self.hoverIndex=runtime.Layout.contains(lx,ly,runtime.modScrollViewport) and self:hit(lx,ly,runtime.modRowRects) or nil
      local target=self.hoverIndex and ((self:rows()[self.hoverIndex] or {}).key or ("row:"..self.hoverIndex)) or (self.hoverTab and ("tab:"..self.hoverTab) or nil)
      runtime.Focus.pointerMove(self.nav,target)
      return true
    end
    if event.phase~="pressed" then return false end
    if event.source=="mouse" and event.button==2 then if self:activeOverlay() then if self.prompt then self.session:respondPrompt(false);self:refresh() else self.overlay=nil end elseif self.region=="info" then self:leaveInfo() elseif self.region~='header' then self:leaveContent() else self:requestLeave() end;return true end
    if not(event.source=="touch" or event.button==1) then return true end
    local ov=self:activeOverlay();if ov then local b=runtime.modOverlayButtons or {};if ov.kind=="restart" then if b.restart and runtime.Layout.contains(lx,ly,b.restart) then self:performRestart() elseif b.later and runtime.Layout.contains(lx,ly,b.later) then self:deferRestart() elseif b.discard and runtime.Layout.contains(lx,ly,b.discard) then self:discardAndLeave() end elseif ov.kind=="confirm" then if b.yes and runtime.Layout.contains(lx,ly,b.yes) then self.session:respondPrompt(true);self:refresh() elseif b.no and runtime.Layout.contains(lx,ly,b.no) then self.session:respondPrompt(false);self:refresh() end elseif ov.kind=='error_detail' then if b.ok and runtime.Layout.contains(lx,ly,b.ok) then self.overlay=nil end elseif b.ok and runtime.Layout.contains(lx,ly,b.ok) then self.session:respondPrompt(false);self:refresh() end;return true end
    local isb=runtime.modInfoScrollbar
    if isb and isb.hit and runtime.Layout.contains(lx,ly,isb.hit) then
      self.region="info";self:syncFocus();self.infoScrollDrag={startY=ly,startScroll=self.infoScrollY};return true
    end
    if runtime.modInfoViewport and runtime.Layout.contains(lx,ly,runtime.modInfoViewport) then
      if self:infoMaxScroll()>0 then self.region="info";self:syncFocus() end
      return true
    end
    local sb=runtime.modScrollbar;if sb and sb.hit and runtime.Layout.contains(lx,ly,sb.hit) then self.scrollDrag={startY=ly,startScroll=self.scrollY};return true end
    local ti=self:hit(lx,ly,runtime.modTabRects);if ti then self:setTab(ti,true);self.region="header";runtime.Focus.pointerPress(self.nav,"tab:"..ti);return true end
    local ri=runtime.Layout.contains(lx,ly,runtime.modScrollViewport) and self:hit(lx,ly,runtime.modRowRects) or nil;if ri then
      local rows=self:rows();local r=rows[ri];if not r or r.header then return true end;self.focusIndex=ri;self.focusKey=r.key;if r.mod then self.selectedId=r.mod.id end;runtime.Focus.pointerPress(self.nav,r.key or ("row:"..ri))
      if r.kind=="mod" then
        local tr=runtime.modToggleRects and runtime.modToggleRects[ri]
        if tr and runtime.Layout.contains(lx,ly,tr) then self:toggle(r.mod) else self:toggleExpanded(r.mod) end
      elseif r.kind=="option" then
        local cr=runtime.modControlRects and runtime.modControlRects[ri];if cr and runtime.Layout.contains(lx,ly,cr) then local k=self:optionControl(r);if k=="submenu" then self:changeOption(r,1,true) elseif k=="toggle" then self:changeOption(r,1,false) else self:changeOption(r,lx<cr.x+cr.w/2 and -1 or 1,false) end end
      elseif r.kind=="utility" then self:activateCurrent()
      elseif r.kind=="profile" then self:activateProfile(r) end
      if r.kind=="error" then self:activateCurrent() end
      return true
    end
    return true
  end
  function Screen:wheel(_,dy,lx,ly)
    if not self:isWide() or dy==0 then return false end
    local active=self:activeOverlay();if active then if active.kind=='error_detail' then active.scroll=math.max(0,(active.scroll or 0)-dy*56);return true end;return false end
    local infoView=runtime.modInfoViewport
    if infoView and runtime.Layout.contains(lx,ly,infoView) then
      if self:infoMaxScroll()<=0 then return true end
      self:scrollInfoBy(-dy*56);return true
    end
    local vr=runtime.modScrollWheelRegion or runtime.modScrollViewport
    if lx~=nil and ly~=nil and vr and not runtime.Layout.contains(lx,ly,vr) then return false end
    self:scrollBy(-dy*72);return true
  end
  function Screen:update(dt)
    if not self:isWide() then return self.inner:update(dt) end
    self:refresh();runtime.Focus.syncDevice(self.nav,self:activeItemId());local input=self.game.input;if self:updateOverlay(input) then return end
    if self.region=="header" then
      if input:wasPressed("left") then self.headerIndex=self.headerIndex>1 and self.headerIndex-1 or 3;self:syncFocus()
      elseif input:wasPressed("right") then self.headerIndex=self.headerIndex<3 and self.headerIndex+1 or 1;self:syncFocus()
      elseif input:wasPressed("down") or input:wasPressed("a") then self:setTab(self.headerIndex,true);self:enterContent()
      elseif input:wasPressed("b") then self:requestLeave() end
      return
    end
    if self.region=="info" then
      if input:wasPressed("up") then self:scrollInfoBy(-48)
      elseif input:wasPressed("down") then self:scrollInfoBy(48)
      elseif input:wasPressed("left") or input:wasPressed("b") then self:leaveInfo() end
      return
    end
    if input:wasPressed("up") then
      self:move(-1)
    elseif input:wasPressed("down") then self:move(1)
    elseif input:wasPressed("left") then
      local r=self:currentRow();if r and r.kind=="option" and self:optionControl(r)~="submenu" then self:changeOption(r,-1,false) end
    elseif input:wasPressed("right") then
      local r=self:currentRow();if r and r.kind=="option" and self:optionControl(r)~="submenu" then self:changeOption(r,1,false) end
    elseif input:wasPressed("a") then self:activateCurrent()
    elseif input:wasPressed("select") then local r=self:currentRow();if r and r.kind=="mod" then self:toggle(r.mod) end
    elseif input:wasPressed("start") then if self:restartRequired() then self:openRestartPrompt() else self.notice="NO CHANGES" end
    elseif input:wasPressed("b") then self:leaveContent() end
  end
  function Screen:bootEnabled(m) return m and m.bootEnabled==true end
  function Screen:isStaged(m) return m and m.staged==true end
  function Screen:viewTop() return VIEW_TOP end
  function Screen:viewHeight() return VIEW_H end
  return Screen
end
return ModsMenu
