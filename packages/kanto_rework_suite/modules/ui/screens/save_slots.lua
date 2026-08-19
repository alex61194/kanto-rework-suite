local SaveSlots={}
function SaveSlots.factory(runtime)
  local Core=assert(runtime.Core); local Screen={}; Screen.__index=Screen
  local function count(v) local n=0;for _ in pairs(v or {}) do n=n+1 end;return n end
  function Screen.new(game,mode)
    local self=setmetatable({game=game,kind='save_slots',mode=mode=='load' and 'load' or 'save',index=1,hover=nil,confirmDelete=false,confirmSave=false,saveChoice='cancel',saveNotice=nil,rawActivateGuard=0,nav=runtime.Focus.new('kanto_rework_ui.save_slots')},Screen)
    self:refresh(); runtime.Focus.navigation(self.nav,'slot.1'); return self
  end
  function Screen:isWide() return runtime.Layout.isWide(runtime.viewport) end
  function Screen:refresh()
    -- The Figma surface is positional: card N is save id slotN.  The engine
    -- registry is an ordered list of registered saves, so using its array
    -- position directly makes an empty second card allocate slot1.  Normalize
    -- the registry back onto the four explicit UI positions instead.
    local ok,list=pcall(Core.saveSlots.list,{minimum=0})
    list=ok and list or {}
    local byPosition={}
    for _,record in ipairs(list) do
      local n=record and record.id and tonumber(tostring(record.id):match('^slot(%d+)$'))
      if n and n>=1 and n<=4 then byPosition[n]=record end
    end
    self.slots={}
    for i=1,4 do
      local record=byPosition[i]
      if record then
        record.index=i
        self.slots[i]=record
      else
        self.slots[i]={id='slot'..i,exists=false,virtual=true,index=i,name='VACÍA',badges=0,seen=0,owned=0,money=0,party={}}
      end
    end
    self.index=math.max(1,math.min(4,self.index or 1))
  end
  function Screen:slot() return self.slots[self.index] end
  function Screen:setIndex(i) self.index=math.max(1,math.min(4,i));runtime.Focus.navigation(self.nav,'slot.'..self.index) end
  function Screen:move(dir)
    if self.confirmDelete or self.confirmSave or self.saveNotice then return end
    if dir=='left' then self:setIndex(self.index==1 and 4 or self.index-1)
    elseif dir=='right' then self:setIndex(self.index==4 and 1 or self.index+1)
    elseif dir=='up' then self:setIndex(math.max(1,self.index-2))
    elseif dir=='down' then self:setIndex(math.min(4,self.index+2)) end
  end
  function Screen:toggleMode() self.mode=self.mode=='save' and 'load' or 'save' end
  function Screen:activate()
    local s=self:slot()
    if self.saveNotice then self.saveNotice=nil;return true end
    if self.confirmDelete then
      if self.deleteChoice=='delete' then if s and s.id then Core.saveSlots.delete(s.id) end; self.confirmDelete=false;self.deleteChoice='cancel';self:refresh() else self.confirmDelete=false end
      return true
    end
    if self.confirmSave then
      if self.saveChoice~='save' then self.confirmSave=false;self.saveChoice='cancel';return true end
      self.confirmSave=false;self.saveChoice='cancel'
      local ok,id=Core.saveSlots.save(s and s.id or nil)
      if ok then
        self:refresh()
        pcall(function() require('src.core.Sound').play(self.game.data,'Save') end)
        self.saveNotice={ok=true,text=('GUARDADO EN RANURA %02d'):format(self.index),id=id or (s and s.id)}
      else
        self.saveNotice={ok=false,text='ERROR AL GUARDAR'}
      end
      return ok==true,id
    end
    if self.mode=='load' then
      if not(s and s.exists and s.id) then return false end
      -- Core.load calls Game:restoreSave(), which rebuilds the stack to the
      -- restored overworld. Never pop afterwards or the new overworld is lost.
      local ok=Core.saveSlots.load(s.id); return ok==true
    end
    -- Saving is destructive when the slot is occupied and still deserves an
    -- explicit intent check when empty. The write happens only after SAVE is
    -- confirmed; success then receives its own acknowledgement surface/SFX.
    self.confirmSave=true;self.saveChoice='cancel';return true
  end
  function Screen:delete()
    local s=self:slot(); if not(s and s.exists and s.id) then return false end
    self.confirmDelete=true;self.deleteChoice='cancel';return true
  end
  function Screen:hitTest(lx,ly)
    if self.confirmDelete then for id,r in pairs(runtime.saveDeleteRects or {}) do if runtime.Layout.contains(lx,ly,r) then return id end end end
    if self.confirmSave then for id,r in pairs(runtime.saveConfirmRects or {}) do if runtime.Layout.contains(lx,ly,r) then return id end end end
    if self.saveNotice and runtime.saveNoticeRect and runtime.Layout.contains(lx,ly,runtime.saveNoticeRect) then return 'notice' end
    if self.confirmDelete or self.confirmSave or self.saveNotice then return nil end
    for i,r in ipairs(runtime.saveSlotRects or {}) do if runtime.Layout.contains(lx,ly,r) then return i end end
  end
  function Screen:pointerEvent(event,lx,ly)
    if not self:isWide() then return false end
    if event.phase=='moved' then local h=self:hitTest(lx,ly);self.hover=type(h)=='number' and h or nil;runtime.Focus.pointerMove(self.nav,self.hover and ('slot.'..self.hover) or nil);return true end
    if event.phase=='pressed' then
      if event.source=='mouse' and event.button==2 then if self.confirmDelete then self.confirmDelete=false elseif self.confirmSave then self.confirmSave=false elseif self.saveNotice then self.saveNotice=nil else self.game.stack:pop() end;return true end
      if event.source=='touch' or event.button==1 then
        local h=self:hitTest(lx,ly)
        if self.confirmDelete and type(h)=='string' then self.deleteChoice=h;self:activate();return true end
        if self.confirmSave and type(h)=='string' then self.saveChoice=h;self:activate();return true end
        if self.saveNotice and h=='notice' then self:activate();return true end
        if type(h)=='number' then self:setIndex(h);self:activate();return true end
      end
    end
    return event.phase=='released' or event.phase=='cancelled'
  end
  function Screen:keypressed(key,_,isrepeat)
    if isrepeat then return false end
    if key=='delete' and not self.confirmDelete and not self.confirmSave and not self.saveNotice then return self:delete() end
    -- The validated Save Figma explicitly exposes ENTER SAVE.  Raw Enter/Space
    -- must activate the focused card even when they are not mapped to the
    -- engine's logical A action. Guard the next update so a binding that also
    -- maps Enter to A cannot execute the save twice in the same key cycle.
    if key=='return' or key=='kpenter' or key=='space' then
      self.rawActivateGuard=2
      self:activate()
      return true
    end
    return false
  end
  function Screen:update(dt)
    if not self:isWide() then return end
    local input=self.game.input
    local rawGuard=self.rawActivateGuard or 0
    if rawGuard>0 then self.rawActivateGuard=rawGuard-1 end
    if self.saveNotice then
      if (input:wasPressed('a') and rawGuard<=0) or input:wasPressed('b') then self.saveNotice=nil end
      return
    end
    if self.confirmSave then
      if input:wasPressed('left') or input:wasPressed('right') then self.saveChoice=self.saveChoice=='save' and 'cancel' or 'save'
      elseif input:wasPressed('a') and rawGuard<=0 then self:activate()
      elseif input:wasPressed('b') then self.confirmSave=false;self.saveChoice='cancel' end
      return
    end
    if self.confirmDelete then
      if input:wasPressed('left') or input:wasPressed('right') then self.deleteChoice=self.deleteChoice=='delete' and 'cancel' or 'delete'
      elseif input:wasPressed('a') and rawGuard<=0 then self:activate()
      elseif input:wasPressed('b') then self.confirmDelete=false end
      return
    end
    if input:wasPressed('left') then self:move('left') elseif input:wasPressed('right') then self:move('right')
    elseif input:wasPressed('up') then self:move('up') elseif input:wasPressed('down') then self:move('down')
    elseif input:wasPressed('a') and rawGuard<=0 then self:activate()
    elseif input:wasPressed('select') then self:toggleMode()
    elseif input:wasPressed('b') then self.game.stack:pop() end
  end
  function Screen:draw() end
  return Screen
end
return SaveSlots
