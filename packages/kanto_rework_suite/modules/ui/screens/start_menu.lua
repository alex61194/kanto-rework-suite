local StartMenu={}
function StartMenu.factory(runtime)
  local Core=assert(runtime.Core);local Screen={};Screen.__index=Screen
  local DEFS={
    {id="pokedex",label="POKÉDEX",desc="Consulta las especies vistas y capturadas.",icon="pokedex",section="adventure"},
    {id="pokemon",label="POKÉMON",desc="Gestiona tu equipo Pokémon activo.",icon="pokemon",section="adventure"},
    {id="bag",label="MOCHILA",desc="Revisa tus objetos y herramientas.",icon="bag",section="adventure"},
    {id="pc",label="PC",desc="Accede a las cajas de almacenamiento de Bill.",icon="pc",section="adventure"},
    {id="save",label="GUARDAR",desc="Guarda el progreso de tu aventura.",icon="save",section="connectivity"},
    {id="link",label="CONEXIÓN",desc="Intercambia y combate en red local.",icon="link",section="connectivity"},
    {id="options",label="OPCIONES",desc="Ajustes de vídeo, gráficos y audio.",icon="options",section="system"},
    {id="mods",label="MODS",desc="Panel de gestión de modificaciones.",icon="mods",section="system"},
    {id="close",label="CERRAR",desc="Salir a la pantalla de título.",icon="close",section="system"},
  }
  function Screen.new(game)
    local session=assert(Core.createStartMenuRuntime(game),"Core StartMenu runtime unavailable")
    local self=setmetatable({game=game,session=session,inner=session.native,kind="main",focusId=nil,hoverId=nil,supported=session.supported~=false,nav=runtime.Focus.new("kanto_rework_ui.main")},Screen)
    self:refreshModel();self.focusId=self:firstEnabled();runtime.Focus.navigation(self.nav,self.focusId);return self
  end
  function Screen:refreshModel()
    local enabled={}
    for _,e in ipairs(self.session.entries or {}) do enabled[e.id]=e.enabled==true end
    -- The in-game KRS Main Menu is a fixed product surface. Third-party
    -- title/start actions (for example Voxel PRECACHE/CACHE or Dynamic Cries)
    -- belong only to the Start Screen where the engine exposes them. Never
    -- project those native rows into this menu.
    self.entries={};self.entriesById={}
    for _,d in ipairs(DEFS) do
      local e={};for k,v in pairs(d) do e[k]=v end
      e.enabled=enabled[d.id]==true
      self.entries[#self.entries+1]=e;self.entriesById[e.id]=e
    end
    self.systemIds={"options","mods","close"}
    local function enabledIds(ids)
      local out={}
      for _,id in ipairs(ids) do local entry=self.entriesById[id];if entry and entry.enabled then out[#out+1]=id end end
      return out
    end
    self.navRows={
      enabledIds({"pokedex","pokemon","bag","pc"}),
      enabledIds({"save","link"}),
      enabledIds({"options","mods","close"}),
    }
    if self.focusId and (not self.entriesById[self.focusId] or not self.entriesById[self.focusId].enabled) then self.focusId=self:firstEnabled() end
  end
  function Screen:firstEnabled() for _,e in ipairs(self.entries) do if e.enabled then return e.id end end end
  function Screen:isWide() return self.supported and runtime.Layout.isWide(nil) end
  function Screen:enter(...) if self.inner and self.inner.enter then return self.inner:enter(...) end end
  function Screen:exit(...) if self.inner and self.inner.exit then return self.inner:exit(...) end end
  function Screen:sgbPalettes(game) if self.inner and self.inner.sgbPalettes then return self.inner:sgbPalettes(game) end end
  function Screen:draw() if not self:isWide() and self.inner and self.inner.draw then self.inner:draw() end end
  function Screen:activate(id)
    local e=self.entriesById[id];if not(e and e.enabled) then return false end
    if id=="save" and runtime.SaveSlotsFactory then self.game.stack:push(runtime.SaveSlotsFactory.new(self.game,"save"));return true end
    return self.session:activate(id)
  end
  function Screen:move(dir)
    local rowIndex,itemIndex
    for ri,row in ipairs(self.navRows or {}) do for ii,id in ipairs(row) do if id==self.focusId then rowIndex,itemIndex=ri,ii break end end;if rowIndex then break end end
    if not rowIndex then return end
    local target
    if dir=="left" or dir=="right" then
      local row=self.navRows[rowIndex];local nextIndex=itemIndex+(dir=="left" and -1 or 1)
      target=row[math.max(1,math.min(#row,nextIndex))]
    elseif dir=="up" or dir=="down" then
      local nextRow=rowIndex+(dir=="up" and -1 or 1);local row=self.navRows[nextRow]
      if row and #row>0 then
        local rects=runtime.mainRects or {}
        local sourceRect=rects[self.focusId]
        local sourceX=sourceRect and (sourceRect.x+sourceRect.w/2) or ((itemIndex-.5)/math.max(1,#self.navRows[rowIndex]))*1320+512
        local distance=math.huge
        for index,id in ipairs(row) do
          local rect=rects[id];local x=rect and (rect.x+rect.w/2) or ((index-.5)/#row)*1320+512
          local delta=math.abs(x-sourceX);if delta<distance then distance,target=delta,id end
        end
      end
    end
    if target and target~=self.focusId then self.focusId=target;self.hoverId=nil;runtime.Focus.navigation(self.nav,self.focusId) end
  end
  function Screen:hitTest(lx,ly) for id,r in pairs(runtime.mainRects or {}) do if runtime.Layout.contains(lx,ly,r) then return id end end end
  function Screen:pointerEvent(event,lx,ly)
    if not self:isWide() then return false end
    if event.phase=="moved" then
      local id=self:hitTest(lx,ly);local e=id and self.entriesById[id] or nil;self.hoverId=e and e.enabled and id or nil
      runtime.Focus.pointerMove(self.nav,self.hoverId)
      return true
    end
    if event.phase=="pressed" then
      if event.source=="mouse" and event.button==2 then self.game.stack:pop();return true end
      if event.source=="touch" or event.button==1 then
        local id=self:hitTest(lx,ly);local e=id and self.entriesById[id] or nil;id=e and e.enabled and id or nil;self.hoverId=id
        runtime.Focus.pointerPress(self.nav,id,function(target) local e=self.entriesById[target];if e and e.enabled then self.focusId=target end end)
        if id then self:activate(id) end
        return true
      end
    end
    return event.phase=="released" or event.phase=="cancelled"
  end
  function Screen:update(dt)
    if not self:isWide() then return self.inner:update(dt) end
    runtime.Focus.syncDevice(self.nav,self.focusId)
    local input=self.game.input
    if input:wasPressed("up") then self:move("up") elseif input:wasPressed("down") then self:move("down") elseif input:wasPressed("left") then self:move("left") elseif input:wasPressed("right") then self:move("right") elseif input:wasPressed("a") then self:activate(self.focusId) elseif input:wasPressed("select") and self.focusId=="pokemon" then runtime.quickPartyReorder=true;self:activate("pokemon") elseif input:wasPressed("b") or input:wasPressed("start") then self.game.stack:pop() end
  end
  function Screen:trainerData()
    local m=self.session:trainerModel() or {};local b=m.badges or {};local d=m.pokedex or {}
    local journal=type(Core.journalContext)=="function" and Core.journalContext() or {}
    return {name=m.name or "RED",money=m.money or 0,seen=d.seen or 0,owned=d.owned or 0,badges=b.owned or {},badgeCount=b.count or 0,playTime=m.playTime or 0,portrait=m.portrait,badgeSheetPath=b.sheetPath,objective=journal.objective or "Continue your journey through Kanto."}
  end
  return Screen
end
return StartMenu
