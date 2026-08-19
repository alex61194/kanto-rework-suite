-- Wide Pokemon Red title replacement. The Figma artwork is full-bleed and
-- the four startup actions use the Kanto popup/focus language. Unsupported
-- display layouts retain the engine's native TitleState unchanged.
local Module={}

function Module.factory(runtime)
  local Native=require("src.ui.TitleState")
  local SaveData=require("src.core.SaveData")
  local GameVersion=require("src.core.GameVersion")
  local Screens=require("src.ui.Screens")
  local Sound=require("src.core.Sound")
  local Strings=require("src.core.Strings")
  local HookRuntime=require("src.mods.Runtime")
  local Screen={};Screen.__index=Screen;Screen.isOpaque=true
  local ROWS={
    {id="new_game",label="NUEVA PARTIDA"},
    {id="load_game",label="CARGAR PARTIDA"},
    {id="options",label="OPCIONES"},
    {id="exit_game",label="SALIR DEL JUEGO"},
  }
  local function same(a,b) return tostring(a or "")==tostring(b or "") end

  local function versionId()
    -- Gen1Recomp 0.1.90 also knows Gold. KRS ships authored Start artwork
    -- only for the three Gen-1 games, so resolve Red explicitly instead of
    -- treating every non-Blue/non-Yellow process as Red. Unknown/future
    -- versions keep the engine-owned backdrop rather than receiving the
    -- wrong KRS plate.
    local id=type(GameVersion.get)=="function" and tostring(GameVersion.get() or ""):lower() or ""
    if id=="yellow" or (type(GameVersion.isYellow)=="function" and GameVersion.isYellow()) then return "yellow" end
    if id=="blue" or (type(GameVersion.isBlue)=="function" and GameVersion.isBlue()) then return "blue" end
    if id=="red" then return "red" end
    return "unknown"
  end

  local function loadImage(version)
    runtime.titleImages=runtime.titleImages or {}
    if runtime.titleImages[version]~=nil then return runtime.titleImages[version] or nil end
    -- Red, Blue and Yellow each have an authored 16:9 KRS Start artwork.
    -- Resolve strictly from the active ROM version so no game can inherit a
    -- different version's plate. Unknown/future versions keep native output.
    local relative=version=="yellow" and "assets/title/title_yellow.png"
      or version=="blue" and "assets/title/title_blue.png"
      or version=="red" and "assets/title/title_red.png" or nil
    if not relative then runtime.titleImages[version]=false;return nil end
    local path=runtime.assetPath(relative)
    local ok,image=pcall(love.graphics.newImage,path)
    if not ok or not image then runtime.titleImages[version]=false;return nil end
    if image.setFilter then image:setFilter("linear","linear") end
    runtime.titleImages[version]=image;return image
  end

  local function saveExists()
    if runtime.Core and runtime.Core.saveSlots and type(runtime.Core.saveSlots.list)=="function" then
      local ok,slots=pcall(runtime.Core.saveSlots.list,{minimum=0})
      if ok then for _,slot in ipairs(slots or {}) do if slot.exists then return true end end end
    end
    local ok,slots=pcall(SaveData.listSlots,GameVersion.get())
    if ok then for _,slot in ipairs(slots or {}) do if slot.exists then return true end end end
    return false
  end

  function Screen.new(game,opts)
    opts=opts or {}
    local native=Native.new(game,opts)
    local version=versionId()
    local self=setmetatable({
      game=game,inner=native,kind="krs_title",version=version,image=loadImage(version),rows={},index=1,
      hoverIndex=nil,nav=runtime.Focus.new("kanto_rework_ui.title."..version),
      onNewGame=opts.onNewGame,onContinue=opts.onContinue,
      nativeBackdrop=version=="unknown",
    },Screen)
    self:refreshRows()
    return self
  end

  function Screen:invokeNativeExit()
    -- EXIT GAME is engine-owned because sandboxed mods may not have love.event.
    -- Ask the native TitleState to manufacture the authoritative closure and
    -- call only that item; remove the temporary Menu immediately.
    if not (self.inner and type(self.inner.openMenu)=="function") then return false end
    local before=self.game.stack and self.game.stack.top and self.game.stack:top() or nil
    local ok=pcall(self.inner.openMenu,self.inner)
    if not ok then return false end
    local menu=self.game.stack and self.game.stack.top and self.game.stack:top() or nil
    local exitItem
    if menu and menu~=before then
      for _,item in ipairs(menu.items or {}) do
        if same(item.label,Strings("EXIT GAME")) then exitItem=item break end
      end
      if self.game.stack and self.game.stack.pop then self.game.stack:pop() end
    end
    if exitItem and type(exitItem.onSelect)=="function" then exitItem.onSelect();return true end
    return false
  end

  function Screen:baseTitleItems(hasSave)
    local items={}
    if hasSave then
      items[#items+1]={label=Strings("CONTINUE"),onSelect=function()
        if runtime.SaveSlotsFactory then self.game.stack:push(runtime.SaveSlotsFactory.new(self.game,"load"))
        elseif self.onContinue then self.onContinue() end
      end}
    end
    items[#items+1]={label=Strings("NEW GAME"),onSelect=function() if self.onNewGame then self.onNewGame() end end}
    items[#items+1]={label=Strings("OPTION"),onSelect=function() Screens.push(self.game,"OptionsMenu") end}
    items[#items+1]={label=Strings("EXIT GAME"),onSelect=function() self:invokeNativeExit() end}
    return items
  end

  function Screen:refreshRows()
    local hasSave=saveExists()
    -- Run the official Gen1Recomp title-menu extension hook over KRS-owned
    -- semantic callbacks. This preserves third-party rows (e.g. Voxel
    -- PRECACHE) and wrappers around CONTINUE / NEW GAME while keeping KRS'
    -- validated four-row ordering for its own actions.
    local wanted=self.rows[self.index] and self.rows[self.index].id or nil
    local base=self:baseTitleItems(hasSave)
    local hooked=HookRuntime.call("ui.title_menu.items",function(_,items)return items end,self.game,base)
    if type(hooked)~="table" then hooked=base end
    local standard,external={},{}
    for hookIndex,item in ipairs(hooked) do
      if type(item)=="table" then
        local label=tostring(item.label or "")
        local id
        if same(label,Strings("CONTINUE")) then id="load_game"
        elseif same(label,Strings("NEW GAME")) then id="new_game"
        elseif same(label,Strings("OPTION")) then id="options"
        elseif same(label,Strings("EXIT GAME")) then id="exit_game" end
        if id then
          standard[id]={id=id,label=(id=="load_game" and "CARGAR PARTIDA") or (id=="options" and "OPCIONES") or (id=="new_game" and "NUEVA PARTIDA") or (id=="exit_game" and "SALIR DEL JUEGO") or label,enabled=id~="load_game" or hasSave,onSelect=item.onSelect}
        else
          external[#external+1]={id="external:"..tostring(hookIndex),label=label~="" and label or "ACCIÓN MOD",enabled=type(item.onSelect)=="function",onSelect=item.onSelect,external=true}
        end
      end
    end
    self.rows={}
    for _,row in ipairs(ROWS) do
      if row.id~="exit_game" then
        local item=standard[row.id] or {id=row.id,label=row.label,enabled=row.id~="load_game" or hasSave}
        item.label=row.label
        self.rows[#self.rows+1]=item
      end
    end
    -- External native rows sit before EXIT GAME, matching the common engine
    -- extension convention and Voxel's own insertion point.
    for _,item in ipairs(external) do self.rows[#self.rows+1]=item end
    local exit=standard.exit_game or {id="exit_game",label="SALIR DEL JUEGO",enabled=true}
    exit.label="SALIR DEL JUEGO";self.rows[#self.rows+1]=exit

    local nextIndex
    if wanted then for i,row in ipairs(self.rows) do if row.id==wanted and row.enabled then nextIndex=i break end end end
    if not nextIndex then
      local preferred=hasSave and "load_game" or "new_game"
      for i,row in ipairs(self.rows) do if row.id==preferred and row.enabled then nextIndex=i break end end
    end
    if not nextIndex then for i,row in ipairs(self.rows) do if row.enabled then nextIndex=i break end end end
    self.index=nextIndex or 1
    self.hoverIndex=nil
    runtime.Focus.navigation(self.nav,self:activeId())
  end

  function Screen:wantsFillScale() return true end
  function Screen:isWide() return runtime.Layout.isWide(nil) end
  function Screen:enter(...)
    -- Rebuild from the live extension hook every time the title becomes active.
    -- This also fixes CLOSE -> title returning with stale/empty action rows.
    self:refreshRows()
    if self.inner and self.inner.enter then return self.inner:enter(...) end
  end
  function Screen:exit(...)
    if self.inner and self.inner.exit then return self.inner:exit(...) end
  end
  function Screen:sgbPalettes(game)
    if not self:isWide() and self.inner and self.inner.sgbPalettes then return self.inner:sgbPalettes(game) end
  end
  function Screen:activeId() return "title:"..tostring(self.rows[self.index] and self.rows[self.index].id or "new_game") end
  -- Presenter contract shared with the other KRS screens. The old mismatch
  -- (drawTitle called activeItemId while TitleScreen only exposed activeId)
  -- aborted the row draw after CLOSE returned to a fresh title screen.
  function Screen:activeItemId() return self:activeId() end

  function Screen:setIndex(index)
    local row=self.rows[index];if not (row and row.enabled) then return false end
    local changed=self.index~=index;self.index=index
    runtime.Focus.navigation(self.nav,self:activeId())
    if changed then pcall(Sound.play,self.game.data,"Tink") end
    return true
  end

  function Screen:move(step)
    local n=#self.rows;if n==0 then return end
    local index=self.index
    for _=1,n do
      index=(index-1+step)%n+1
      if self.rows[index].enabled then self:setIndex(index);return end
    end
  end

  function Screen:activate(index)
    index=index or self.index;local row=self.rows[index]
    if not (row and row.enabled) then return false end
    pcall(Sound.play,self.game.data,"Press_AB")
    -- onSelect is the hook-expanded callback. For standard rows it starts from
    -- KRS' semantic action and may have been wrapped by another mod; for
    -- external rows it is the exact callback supplied by that mod.
    if type(row.onSelect)=="function" then row.onSelect();return true end
    if row.id=="new_game" and self.onNewGame then self.onNewGame();return true end
    if row.id=="load_game" and self.onContinue then self.onContinue();return true end
    if row.id=="options" then Screens.push(self.game,"OptionsMenu");return true end
    if row.id=="exit_game" then return self:invokeNativeExit() end
    return false
  end

  local function hit(runtime,lx,ly)
    for i,r in ipairs(runtime.titleRects or {}) do
      if runtime.Layout.contains(lx,ly,r) then return i end
    end
  end

  function Screen:pointerEvent(event,lx,ly)
    if not self:isWide() then return false end
    if event.phase=="moved" then
      self.hoverIndex=hit(runtime,lx,ly)
      local target=self.hoverIndex and ("title:"..self.rows[self.hoverIndex].id) or nil
      runtime.Focus.pointerMove(self.nav,target,function() if self.rows[self.hoverIndex].enabled then self.index=self.hoverIndex end end)
      return true
    end
    if event.phase=="pressed" and (event.source=="touch" or event.button==1) then
      local index=hit(runtime,lx,ly);self.hoverIndex=index
      if index then
        local target="title:"..self.rows[index].id
        runtime.Focus.pointerPress(self.nav,target,function() if self.rows[index].enabled then self.index=index end end)
        self:activate(index)
      end
      return true
    end
    return event.phase=="released" or event.phase=="cancelled"
  end

  function Screen:update(dt)
    if not self:isWide() then return self.inner:update(dt) end
    -- Keep Yellow's native presentation timeline alive for its version-correct
    -- audio/cinematic sequencing, while KRS owns the authored Wide backdrop and
    -- all input. Calling Native:update would also consume A/START and open the
    -- vanilla menu in parallel with KRS.
    if self.version=="yellow" and self.inner then
      if self.inner.phase~="loop" and type(self.inner.updateSequence)=="function" then
        self.inner:updateSequence()
      elseif self.inner.yellowLayout and type(self.inner.updateBlink)=="function" then
        self.inner:updateBlink()
      elseif self.inner.phase=="loop" then
        self.inner.timer=(tonumber(self.inner.timer) or 0)+1
        self.inner.blink=((tonumber(self.inner.blink) or 0)+1)%60
        if type(self.inner.updateCycle)=="function" then self.inner:updateCycle() end
      end
    end
    runtime.Focus.syncDevice(self.nav,self:activeId())
    local input=self.game.input
    if input:wasPressed("up") then self:move(-1)
    elseif input:wasPressed("down") then self:move(1)
    elseif input:wasPressed("a") or input:wasPressed("start") then self:activate()
    end
  end

  function Screen:draw()
    -- Authored Red/Blue/Yellow Wide Start artwork is KRS-owned. Unsupported
    -- versions retain the engine-owned native title. KRS always owns the Wide
    -- Start actions/navigation, so no parallel vanilla menu is opened.
    if self.nativeBackdrop and self.inner and self.inner.draw then return self.inner:draw() end
    if not self:isWide() and self.inner and self.inner.draw then return self.inner:draw() end
  end
  return Screen
end

return Module
