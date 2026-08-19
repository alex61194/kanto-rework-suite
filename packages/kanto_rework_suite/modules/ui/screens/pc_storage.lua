local PCStorage={}
function PCStorage.factory(runtime)
  local Native=require('src.ui.BoxMenu')
  local Boxes=require('src.pokemon.Boxes')
  local Party=require('src.pokemon.Party')
  local Stats=require('src.pokemon.Stats')
  local PikachuFollower=require('src.world.PikachuFollower')
  local Sound=require('src.core.Sound')
  local NamingScreen=require('src.ui.NamingScreen')
  local Screen={};Screen.__index=Screen
  local SORTS={'pokedex','type','level'}
  local SORT_LABEL={pokedex='Pokédex',type='Tipo',level='Nivel'}
  local function clamp(v,a,b)return math.max(a,math.min(b,v))end
  function Screen.new(game)
    Boxes.ensure(game.save)
    local self=setmetatable({game=game,kind='pc_storage',inner=Native.new(game),area='stored',boxIndex=game.save.currentBox or 1,monIndex=1,partyIndex=1,selected=nil,hover=nil,releaseConfirm=false,releaseChoice='cancel',drag=nil,searchQuery='',searchActive=false,sortMode='pokedex',sortOpen=false,sortFocus=1,storageStartRow=0,storedMovePpHealed=false,searchMoveTermsByMon={}},Screen)
    return self
  end
  function Screen:isWide() return runtime.Layout.isWide(nil) end
  function Screen:enter(...)
    if not self:isWide() and self.inner.enter then return self.inner:enter(...) end
    self:healStoredMovePP();self:buildSearchMoveCache()
  end
  function Screen:exit(...) if not self:isWide() and self.inner.exit then return self.inner:exit(...) end end
  function Screen:sgbPalettes(game) if not self:isWide() and self.inner.sgbPalettes then return self.inner:sgbPalettes(game) end end
  function Screen:draw() if not self:isWide() then self.inner:draw() end end
  function Screen:boxes() return Boxes.ensure(self.game.save) end
  function Screen:healStoredMovePP()
    if self.storedMovePpHealed then return false end
    self.storedMovePpHealed=true
    local boxes=Boxes.ensure(self.game.save)
    -- PC access is a legitimate PP restore event. Keep it separate from search/
    -- sort reads so filtering remains presentation-only and mutation-free.
    if runtime.Core and type(runtime.Core.restoreAllKnownMovePP)=='function' then
      for _,box in ipairs(boxes or {}) do for _,mon in ipairs(box or {}) do runtime.Core.restoreAllKnownMovePP(mon) end end
    end
    return true
  end
  function Screen:buildSearchMoveCache()
    -- Search itself must be a pure read. Core.knownMoves observes active moves as
    -- part of its bookkeeping, so take one snapshot on PC entry (immediately
    -- after the legitimate PC heal event) and never call that mutating API from
    -- the per-keystroke/per-frame filter path.
    local cache={}
    if runtime.Core and type(runtime.Core.knownMoves)=='function' then
      for _,box in ipairs(Boxes.ensure(self.game.save) or {}) do
        for _,mon in ipairs(box or {}) do
          local terms={}
          local ok,known=pcall(runtime.Core.knownMoves,mon,true)
          if ok and type(known)=='table' then
            for _,raw in ipairs(known) do
              local id=type(raw)=='table' and raw.id or raw
              local md=self.game.data and self.game.data.moves and self.game.data.moves[id]
              terms[#terms+1]=tostring(md and md.name or id or '')
            end
          end
          cache[mon]=table.concat(terms,' '):lower()
        end
      end
    end
    self.searchMoveTermsByMon=cache
    return cache
  end
  function Screen:boxAt(i) return self:boxes()[clamp(tonumber(i) or 1,1,Boxes.COUNT)] or {} end
  function Screen:box() return self:boxAt(self.game.save.currentBox or 1) end
  local BOX_NAMES_KEY='pc_box_names_v1'
  function Screen:boxNames()
    local store=runtime.mod and runtime.mod.save
    if store and type(store.get)=='function' then
      local ok,value=pcall(store.get,store,BOX_NAMES_KEY,{})
      if ok and type(value)=='table' then return value,true end
    end
    -- Headless/test fallback only. Real KRS sessions use mod.save, which is
    -- serialized inside the playthrough by Gen1Recomp's explicit Save flow.
    local save=self.game.save or {};save.krsBoxNames=type(save.krsBoxNames)=='table' and save.krsBoxNames or {}
    return save.krsBoxNames,false
  end
  function Screen:boxName(i)
    i=clamp(tonumber(i) or 1,1,Boxes.COUNT)
    local names=self:boxNames();local value=names[i]
    value=type(value)=='string' and value:gsub('^%s+',''):gsub('%s+$','') or ''
    return value~='' and value or ('CAJA %02d'):format(i)
  end
  function Screen:renameBox(i)
    i=clamp(tonumber(i) or (self.game.save.currentBox or 1),1,Boxes.COUNT)
    local old=self:boxName(i)
    local naming=NamingScreen.new(self.game,{title=('RENOMBRAR CAJA %02d'):format(i),maxLen=13,default=old,onDone=function(name)
      name=type(name)=='string' and name:gsub('^%s+',''):gsub('%s+$','') or ''
      if name=='' then name=old end
      local names,modBacked=self:boxNames();names[i]=name
      local store=runtime.mod and runtime.mod.save
      if modBacked and store and type(store.set)=='function' then store:set(BOX_NAMES_KEY,names) end
      Sound.play(self.game.data,'Press_AB')
    end})
    self.game.stack:push(naming)
    return true
  end
  function Screen:boxHasSearchResult(i)
    local query=tostring(self.searchQuery or ''):lower()
    if query=='' then return true end
    for _,mon in ipairs(self:boxAt(i)) do
      local def=self.game.data and self.game.data.pokemon and self.game.data.pokemon[mon.species]
      local name=tostring(mon.nickname or (def and def.name) or mon.species or '')
      local types=table.concat(self:typeNames(mon),' ')
      if self:searchTerms(mon,def,name,types):find(query,1,true) then return true end
    end
    return false
  end
  function Screen:boxSelectable(i) return tostring(self.searchQuery or '')=='' or self:boxHasSearchResult(i) end
  function Screen:typeNames(mon)
    local def=mon and self.game.data and self.game.data.pokemon and self.game.data.pokemon[mon.species];local out={}
    for _,typ in ipairs((def and def.types) or {}) do local key=tostring(typ):upper();if key=='PSYCH_TYPE' or key=='PSYCHIC_TYPE' or key=='PSYCH' then key='PSYCHIC' else key=key:gsub('_TYPE$','') end;out[#out+1]=key end
    return out
  end
  function Screen:searchTerms(mon,def,name,types)
    local terms={tostring(name or ''),tostring(mon and mon.species or ''),tostring(types or '')}
    -- Active moves are plain save data. Remembered inactive move names come
    -- from the immutable snapshot built on enter; filtering never invokes a
    -- move-memory API that can observe/write state.
    if type(mon and mon.moves)=='table' then
      for _,raw in ipairs(mon.moves) do
        local id=type(raw)=='table' and (raw.id or raw.move or raw[1]) or raw
        local md=self.game.data and self.game.data.moves and self.game.data.moves[id]
        terms[#terms+1]=tostring(md and md.name or id or '')
      end
    end
    if mon and self.searchMoveTermsByMon then terms[#terms+1]=tostring(self.searchMoveTermsByMon[mon] or '') end
    return table.concat(terms,' '):lower()
  end
  function Screen:displayEntries()
    local out={};local query=tostring(self.searchQuery or ''):lower()
    for sourceIndex,mon in ipairs(self:box()) do
      local def=self.game.data and self.game.data.pokemon and self.game.data.pokemon[mon.species]
      local name=tostring(mon.nickname or (def and def.name) or mon.species or '')
      local types=table.concat(self:typeNames(mon),' ')
      local haystack=self:searchTerms(mon,def,name,types)
      if query=='' or haystack:find(query,1,true) then out[#out+1]={mon=mon,sourceIndex=sourceIndex,name=name,def=def,types=types} end
    end
    local mode=self.sortMode
    table.sort(out,function(a,b)
      local av,bv
      if mode=='level' then av,bv=tonumber(a.mon.level) or 0,tonumber(b.mon.level) or 0
      elseif mode=='type' then av,bv=a.types,b.types
      else
        -- Gen1Recomp's Pokédex screen sorts by definition.dex. Definition.index
        -- is the internal species index and is not National/Kanto Pokédex order.
        av=tonumber(a.def and a.def.dex) or tonumber(a.mon.species) or math.huge
        bv=tonumber(b.def and b.def.dex) or tonumber(b.mon.species) or math.huge
      end
      if av==bv then return a.sourceIndex<b.sourceIndex end
      return av<bv
    end)
    return out
  end
  function Screen:sortLabel() return SORT_LABEL[self.sortMode] or SORT_LABEL.pokedex end
  function Screen:cycleSort(delta) local index=1;for i,id in ipairs(SORTS) do if id==self.sortMode then index=i break end end;index=((index-1+(tonumber(delta) or 1))%#SORTS)+1;self.sortMode=SORTS[index];self.monIndex=1;self.storageStartRow=0;Sound.play(self.game.data,'Swap');return true end
  function Screen:openSort() local index=1;for i,id in ipairs(SORTS) do if id==self.sortMode then index=i break end end;self.sortFocus=index;self.sortOpen=true;return true end
  function Screen:setSortIndex(index) index=clamp(tonumber(index) or 1,1,#SORTS);self.sortMode=SORTS[index];self.sortFocus=index;self.sortOpen=false;self.monIndex=1;self.storageStartRow=0;Sound.play(self.game.data,'Swap');return true end
  function Screen:entryAt(displayIndex) return self:displayEntries()[displayIndex] end
  function Screen:actualIndex(displayIndex,allowAppend) local entry=self:entryAt(displayIndex);if entry then return entry.sourceIndex end;return allowAppend and (#self:box()+1) or nil end
  function Screen:displayIndexFor(mon) for i,entry in ipairs(self:displayEntries()) do if entry.mon==mon then return i end end end
  function Screen:setBox(i)
    i=clamp(i,1,Boxes.COUNT);if not self:boxSelectable(i) then return false end; if i==(self.game.save.currentBox or 1) then self.boxIndex=i;return true end
    self.game.save.currentBox=i;self.boxIndex=i;self.monIndex=1;self.storageStartRow=0
    -- PC edits stay in the live save model and are persisted only by the game's explicit Save flow.
    Sound.play(self.game.data,'Swap')
  end
  function Screen:selectedMon()
    if self.selected and self.selected.mon then return self.selected.mon,self.selected.where,self.selected.index end
    if self.area=='party' then return self.game.save.party[self.partyIndex], 'party', self.partyIndex end
    local entry=self:entryAt(self.monIndex);return entry and entry.mon or nil,'box',entry and entry.sourceIndex or self.monIndex
  end
  function Screen:contextMon()
    -- A Pokémon actively picked up is the current subject. Otherwise mouse
    -- hover may preview a card without moving keyboard/controller focus.
    if self.selected and self.selected.mon then return self.selected.mon,self.selected.where,self.selected.index end
    local hover=self.hover
    if hover and hover.kind=='stored' then
      local entry=self:entryAt(hover.value);if entry then return entry.mon,'box',entry.sourceIndex end
    elseif hover and hover.kind=='party' then
      local mon=self.game.save.party[hover.value];if mon then return mon,'party',hover.value end
    end
    return self:selectedMon()
  end
  function Screen:contextMoves()
    local mon=self:contextMon();if not mon then return {} end
    local adapter=runtime.PartyAdapter
    if adapter and type(adapter.pokemon)=='function' then
      local ok,model=pcall(adapter.pokemon,self.game,mon)
      if ok and type(model)=='table' and type(model.moves)=='table' then return model.moves end
    end
    return {}
  end
  function Screen:release()
    local box=self:box();local actual=self:actualIndex(self.monIndex);local mon=actual and box[actual];if not mon then return false end
    self.releaseConfirm=true;self.releaseChoice='cancel';return true
  end
  function Screen:confirmRelease()
    if self.releaseChoice~='release' then self.releaseConfirm=false;return end
    local box=self:box();local actual=self:actualIndex(self.monIndex);local mon=actual and box[actual];if mon then table.remove(box,actual);self.monIndex=clamp(self.monIndex,1,math.max(1,#self:displayEntries()));self.selected=nil;Sound.play(self.game.data,'Swap') end
    self.releaseConfirm=false
  end
  function Screen:beginMove()
    if self.area=='boxes' then return false end
    local mon,where,index=self:selectedMon();if not mon then return false end
    self.selected={where=where,index=index,mon=mon,boxIndex=where=='box' and (self.game.save.currentBox or 1) or nil};Sound.play(self.game.data,'Press_AB');return true
  end
  local function findMon(list,mon,index)
    if list[index]==mon then return index end
    for i,value in ipairs(list) do if value==mon then return i end end
  end
  function Screen:commitStorage(targetBox,targetIndex)
    local viewBox=self.game.save.currentBox or 1;self.game.save.currentBox=viewBox;self.boxIndex=viewBox;self.area='stored';self.selected=nil;self.monIndex=clamp(self.monIndex,1,math.max(1,#self:displayEntries()))
    if targetBox==viewBox and targetIndex then self.monIndex=self:displayIndexFor(self:box()[targetIndex]) or self.monIndex end
    Sound.play(self.game.data,'Swap')
    return true
  end
  function Screen:placeInBox(targetBox)
    local sel=self.selected;if not sel then self:setBox(targetBox);self.area='stored';return true end
    targetBox=clamp(targetBox,1,Boxes.COUNT);local destination=self:boxAt(targetBox)
    if sel.where=='box' then
      local sourceIndex=sel.boxIndex or (self.game.save.currentBox or 1);local source=self:boxAt(sourceIndex)
      local index=findMon(source,sel.mon,sel.index);if not index then self.selected=nil;return false end
      if sourceIndex==targetBox then self.monIndex=self:displayIndexFor(sel.mon) or self.monIndex;self.area='stored';self.selected=nil;Sound.play(self.game.data,'Swap');return true end
      if #destination>=Boxes.CAPACITY then return false end
      local moving=table.remove(source,index);destination[#destination+1]=moving
      return self:commitStorage(targetBox,#destination)
    elseif sel.where=='party' then
      local party=self.game.save.party;local index=findMon(party,sel.mon,sel.index)
      if not index or #party<=1 or #destination>=Boxes.CAPACITY then return false end
      local moving=table.remove(party,index);PikachuFollower.modifyHappiness(self.game.save,'DEPOSITED',moving);destination[#destination+1]=moving
      return self:commitStorage(targetBox,#destination)
    end
    return false
  end
  function Screen:placeMove()
    local sel=self.selected;if not sel then return self:beginMove() end
    local box=self:box();local party=self.game.save.party;local sourceBox=sel.where=='box' and self:boxAt(sel.boxIndex or (self.game.save.currentBox or 1)) or nil;local targetIndex=self:actualIndex(self.monIndex,true)
    if sel.where=='party' and self.area=='stored' then
      if #box>=Boxes.CAPACITY or #party<=1 then return false end
      local src=party[sel.index];if not src then self.selected=nil;return false end
      local dst=box[targetIndex]
      -- Match Gen1Recomp BoxMenu semantics: a party mon being deposited
      -- affects Yellow follower happiness, while a box mon entering the
      -- party must regain its computed party stat block.
      PikachuFollower.modifyHappiness(self.game.save,'DEPOSITED',src)
      if dst then
        Stats.ensure(self.game.data.pokemon[dst.species],dst)
        party[sel.index],box[targetIndex]=dst,src
      else
        table.remove(party,sel.index);box[#box+1]=src;self.monIndex=#box
      end
    elseif sel.where=='box' and self.area=='party' then
      local sourceIndex=findMon(sourceBox,sel.mon,sel.index);local src=sourceIndex and sourceBox[sourceIndex];if not src then self.selected=nil;return false end
      Stats.ensure(self.game.data.pokemon[src.species],src)
      local dst=party[self.partyIndex]
      if dst then
        PikachuFollower.modifyHappiness(self.game.save,'DEPOSITED',dst)
        sourceBox[sourceIndex],party[self.partyIndex]=dst,src
      elseif #party<Party.MAX then
        table.remove(sourceBox,sourceIndex);party[#party+1]=src;self.partyIndex=#party
      end
    elseif sel.where=='box' and self.area=='stored' then
      if (sel.boxIndex or (self.game.save.currentBox or 1))~=(self.game.save.currentBox or 1) then return self:placeInBox(self.game.save.currentBox or 1) end
      local a,b=findMon(box,sel.mon,sel.index),targetIndex
      if not a then self.selected=nil;return false end
      if box[a] and box[b] then box[a],box[b]=box[b],box[a]
      elseif box[a] and b==#box+1 then local moving=table.remove(box,a);table.insert(box,moving);self.monIndex=#box end
    elseif sel.where=='party' and self.area=='party' then
      local a,b=sel.index,self.partyIndex
      if party[a] and party[b] then party[a],party[b]=party[b],party[a]
      elseif party[a] and b==#party+1 and #party<Party.MAX then local moving=table.remove(party,a);table.insert(party,moving);self.partyIndex=#party end
    else return false end
    self.selected=nil;Sound.play(self.game.data,'Swap');return true
  end
  function Screen:move(dir)
    local box=self:box();local party=self.game.save.party;local displayCount=#self:displayEntries()
    if self.area=='boxes' then
      local i=self.boxIndex;local col=(i-1)%2;local row=math.floor((i-1)/2)
      if dir=='left' then
        if col==1 then i=i-1 end
      elseif dir=='right' then
        if col==0 and i<Boxes.COUNT then i=i+1 else self.area='stored';self.monIndex=clamp(row*4+1,1,math.max(1,displayCount+1));return end
      elseif dir=='up' then i=i-2
      elseif dir=='down' then i=i+2 end
      i=clamp(i,1,Boxes.COUNT)
      if not self:boxSelectable(i) then
        local step=(dir=='left' and -1) or (dir=='right' and 1) or (dir=='up' and -2) or 2
        local probe=i
        while probe>=1 and probe<=Boxes.COUNT and not self:boxSelectable(probe) do probe=probe+step end
        if probe>=1 and probe<=Boxes.COUNT then i=probe else return end
      end
      self.boxIndex=i;return
    elseif self.area=='party' then
      local i=self.partyIndex;local col=(i-1)%3
      if dir=='left' then
        if col==0 then self.area='stored';self.monIndex=clamp(math.floor((i-1)/3)*4+4,1,math.max(1,displayCount+1));return else i=i-1 end
      elseif dir=='right' then i=i+1
      elseif dir=='up' then i=i-3
      elseif dir=='down' then i=i+3 end
      self.partyIndex=clamp(i,1,math.max(1,#party));return
    else
      local cols=4;local i=self.monIndex;local col=(i-1)%cols;local row=math.floor((i-1)/cols)
      if dir=='left' then
        if col==0 then self.area='boxes';self.boxIndex=clamp(row*2+2,1,Boxes.COUNT);return else i=i-1 end
      elseif dir=='right' then
        if col==cols-1 then self.area='party';self.partyIndex=clamp(row*3+1,1,math.max(1,#party));return else i=i+1 end
      elseif dir=='up' then i=i-cols
      elseif dir=='down' then i=i+cols end
      self.monIndex=clamp(i,1,math.max(1,displayCount+1));self:ensureStorageVisible();return
    end
  end
  function Screen:ensureStorageVisible() local row=math.floor((math.max(1,self.monIndex)-1)/4);local totalRows=math.ceil(math.max(1,#self:displayEntries()+1)/4);local maxStart=math.max(0,totalRows-5);if row<self.storageStartRow then self.storageStartRow=row elseif row>=self.storageStartRow+5 then self.storageStartRow=row-4 end;self.storageStartRow=clamp(self.storageStartRow,0,maxStart) end
  function Screen:update(dt)
    if not self:isWide() then return self.inner:update(dt) end
    local input=self.game.input
    if self.sortOpen then
      if input:wasPressed('up') then self.sortFocus=self.sortFocus>1 and self.sortFocus-1 or #SORTS
      elseif input:wasPressed('down') then self.sortFocus=self.sortFocus<#SORTS and self.sortFocus+1 or 1
      elseif input:wasPressed('a') then self:setSortIndex(self.sortFocus)
      elseif input:wasPressed('b') then self.sortOpen=false end
      return
    end
    if self.releaseConfirm then
      if input:wasPressed('left') or input:wasPressed('right') then self.releaseChoice=self.releaseChoice=='release' and 'cancel' or 'release'
      elseif input:wasPressed('a') then self:confirmRelease() elseif input:wasPressed('b') then self.releaseConfirm=false end
      return
    end
    if input:wasPressed('up') then self:move('up') elseif input:wasPressed('down') then self:move('down') elseif input:wasPressed('left') then self:move('left') elseif input:wasPressed('right') then self:move('right')
    elseif input:wasPressed('a') then if self.area=='boxes' then if self.selected then self:placeInBox(self.boxIndex) elseif self:setBox(self.boxIndex) then self.area='stored' end else self:placeMove() end
    elseif input:wasPressed('select') then if self.area=='boxes' then self:renameBox(self.boxIndex) else self:beginMove() end
    elseif input:wasPressed('b') then if self.selected then self.selected=nil else self.game.stack:pop() end end
  end
  function Screen:wheel(_,dy,x,y)
    if not self:isWide() or dy==0 or self.releaseConfirm then return false end
    if runtime.pcStoredRect and runtime.Layout.contains(x,y,runtime.pcStoredRect) then local totalRows=math.ceil(math.max(1,#self:displayEntries()+1)/4);self.storageStartRow=clamp(self.storageStartRow+(dy>0 and -1 or 1),0,math.max(0,totalRows-5));return true end
    if runtime.pcPartyPanelRect and runtime.Layout.contains(x,y,runtime.pcPartyPanelRect) then self.partyIndex=clamp(self.partyIndex+(dy>0 and -1 or 1),1,math.max(1,math.min(6,#self.game.save.party+1)));return true end
    return false
  end
  function Screen:keypressed(key)
    if not self:isWide() then return false end
    if self.sortOpen then
      if key=='escape' then self.sortOpen=false;return true
      elseif key=='up' then self.sortFocus=self.sortFocus>1 and self.sortFocus-1 or #SORTS;return true
      elseif key=='down' then self.sortFocus=self.sortFocus<#SORTS and self.sortFocus+1 or 1;return true
      elseif key=='return' or key=='kpenter' then return self:setSortIndex(self.sortFocus) end
      return true
    end
    if self.searchActive then if key=='escape' or key=='return' or key=='kpenter' then self.searchActive=false;return true end;if key=='backspace' then self.searchQuery=self.searchQuery:sub(1,-2) elseif key=='space' then self.searchQuery=self.searchQuery..' ' elseif type(key)=='string' and key:match('^[a-z0-9]$') then self.searchQuery=self.searchQuery..key end;self.monIndex=1;self.storageStartRow=0;return true end
    if key=='tab' then return self:cycleSort(1) end
    if key=='n' then return self:renameBox(self.area=='boxes' and self.boxIndex or (self.game.save.currentBox or 1)) end
    if key=='delete' or key=='r' then return self:release() end
    return false
  end
  function Screen:hitTest(x,y)
    if self.sortOpen then for i,r in pairs(runtime.pcSortChoiceRects or {}) do if runtime.Layout.contains(x,y,r) then return 'sort_choice',i end end;return nil end
    for i,r in pairs(runtime.pcBoxRects or {}) do if runtime.Layout.contains(x,y,r) then return self:boxSelectable(i) and 'box' or 'box_disabled',i end end
    for i,r in pairs(runtime.pcMonRects or {}) do if runtime.Layout.contains(x,y,r) then return 'stored',i end end
    for i,r in pairs(runtime.pcPartyRects or {}) do if runtime.Layout.contains(x,y,r) then return 'party',i end end
    if runtime.pcSearchRect and runtime.Layout.contains(x,y,runtime.pcSearchRect) then return 'search' end
    if runtime.pcSortRect and runtime.Layout.contains(x,y,runtime.pcSortRect) then return 'sort' end
    if runtime.pcRenameBoxRect and runtime.Layout.contains(x,y,runtime.pcRenameBoxRect) then return 'rename_box',self.game.save.currentBox or 1 end
    if runtime.pcReleaseRect and runtime.Layout.contains(x,y,runtime.pcReleaseRect) then return 'release' end
    if self.releaseConfirm then for id,r in pairs(runtime.pcReleaseChoiceRects or {}) do if runtime.Layout.contains(x,y,r) then return 'choice',id end end end
  end
  local function movedEnough(d,x,y)
    if not d then return false end;local dx=x-d.startX;local dy=y-d.startY;return dx*dx+dy*dy>=64
  end
  function Screen:pointerEvent(event,x,y)
    if not self:isWide() then return false end
    if event.phase=='pressed' and event.source=='mouse' and event.button==2 then
      self.drag=nil
      if self.sortOpen then self.sortOpen=false elseif self.searchActive then self.searchActive=false elseif self.releaseConfirm then self.releaseConfirm=false elseif self.selected then self.selected=nil else self.game.stack:pop() end
      return true
    end
    local kind,val=self:hitTest(x,y)
    if event.phase=='moved' then
      self.hover={kind=kind,value=val}
      if self.drag then self.drag.x,self.drag.y=x,y end
      if self.drag and not self.drag.active and movedEnough(self.drag,x,y) then
        local d=self.drag;self.area=d.where=='box' and 'stored' or 'party';if d.where=='box' then self.monIndex=d.index else self.partyIndex=d.index end
        if self:beginMove() then d.active=true end
      end
      return true
    end
    if event.phase=='pressed' and (event.source=='touch' or event.button==1) then
      if kind=='sort_choice' then self.drag=nil;return self:setSortIndex(val) end
      if kind=='search' then self.drag=nil;self.searchActive=true;return true end
      if kind=='sort' then self.drag=nil;return self:openSort() end
      if kind=='rename_box' then self.drag=nil;return self:renameBox(val) end
      if kind=='box_disabled' then self.drag=nil;return true end
      if kind=='box' then self.drag=nil;self.area='boxes';self.boxIndex=val;if self.selected then self:placeInBox(val) else self:setBox(val);self.area='stored' end;return true end
      if kind=='stored' then
        self.area='stored';self.monIndex=val
        if self.selected then self:placeMove();return true end
        if self:entryAt(val) then self.drag={where='box',index=val,startX=x,startY=y,x=x,y=y,active=false} end
        return true
      elseif kind=='party' then
        self.area='party';self.partyIndex=val
        if self.selected then self:placeMove();return true end
        if self.game.save.party[val] then self.drag={where='party',index=val,startX=x,startY=y,x=x,y=y,active=false} end
        return true
      elseif kind=='release' then self.drag=nil;self:release();return true
      elseif kind=='choice' then self.drag=nil;self.releaseChoice=val;self:confirmRelease();return true end
      return true
    end
    if event.phase=='released' or event.phase=='cancelled' then
      local d=self.drag;self.drag=nil
      if d and d.active and event.phase=='released' then
        local targetKind,target=self:hitTest(x,y)
        if targetKind=='box' then self:placeInBox(target)
        elseif targetKind=='stored' then self.area='stored';self.monIndex=target;self:placeMove()
        elseif targetKind=='party' then self.area='party';self.partyIndex=target;self:placeMove()
        else self.selected=nil end
      end
      return true
    end
    return false
  end
  return Screen
end
return PCStorage
