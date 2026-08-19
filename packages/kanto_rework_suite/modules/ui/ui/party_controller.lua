return function(options)
  local Adapter=assert(options.Adapter);local Layout=assert(options.Layout);local C=assert(options.C);local runtime=assert(options.runtime);local foundation=assert(options.foundation)
  local controller={fixtureEnabled=options.fixtureEnabled==true}
  controller.actions={NavigateUp="up",NavigateDown="down",NavigateLeft="left",NavigateRight="right",Confirm="a",Back="b",CycleMode="select"}
  local function actionPressed(game,action) local input=game and game.input;local native=controller.actions[action];return native and input and type(input.wasPressed)=="function" and input:wasPressed(native)==true end
  local function sound(game,name) pcall(function() require("src.core.Sound").play(game.data,name or "Press_AB") end) end
  local function top(game) local stack=game and game.stack;return stack and type(stack.top)=="function" and stack:top() or nil end
  local function moveCount(pokemon) local n=0;for i=1,4 do if pokemon and pokemon.moves[i] then n=i end end;return n end
  local function firstSelectable(rows) for i,m in ipairs(rows or {}) do if not m.disabled then return i end end end
  local function nextSelectable(rows,current,delta)
    local n=#(rows or {});if n==0 then return nil end;local i=current or (delta>0 and 0 or 1)
    for _=1,n do i=((i-1+delta)%n)+1;if rows[i] and not rows[i].disabled then return i end end
    return current
  end
  local LEARNED_VISIBLE=8
  local function ensureLearnedVisible(state,index)
    local count=#(state.learned or {});local maxFirst=math.max(1,count-LEARNED_VISIBLE+1);local first=math.max(1,math.min(state.learnedFirst or 1,maxFirst))
    index=index or state.learnedFocus
    if index then if index<first then first=index elseif index>first+LEARNED_VISIBLE-1 then first=index-LEARNED_VISIBLE+1 end end
    state.learnedFirst=math.max(1,math.min(first,maxFirst));return state.learnedFirst
  end
  local function refreshPokemon(state,index) local party=Adapter.party(state.game,state.partyState);local mon=party[index];return mon,Adapter.pokemon(state.game,mon) end
  local function selectedIndex(state) return state.selectedParty or state.partyFocus end
  local function updateSelectedModel(state)
    state.party=Adapter.party(state.game,state.partyState);state.mon,state.pokemon=refreshPokemon(state,selectedIndex(state));state.learned,state.learnedProvider=Adapter.learnedMoves(state.game,state.pokemon,controller.fixtureEnabled);state.learnedFirst=1
  end
  local function transition(state,newMode) if state.mode==newMode then return false end;state.mode=newMode;sound(state.game,"Press_AB");return true end
  function controller:newState(game,partyState)
    local party=Adapter.party(game,partyState);local focus=math.max(1,math.min(#party,tonumber(partyState.index) or 1))
    local state={__kantoPartyUi=true,isOpaque=true,screenId="KantoPartyUI",game=game,partyState=partyState,party=party,mode="PartyBrowse",partyFocus=focus,selectedParty=nil,submenuFocus="summary",statMode="stats",activeMoveFocus=1,selectedActive=nil,movePhase="active",learnedFocus=nil,learned={},learnedProvider={},learnedFirst=1,learnedScrollDrag=nil,inputGuard=1,regions={},drag=nil,pointerSession=nil,message=nil,battleMode=partyState.battle~=nil,forceSwitch=partyState.forceSwitch==true,battleActionFocus=1,summaryReturn=nil}
    state.mon,state.pokemon=refreshPokemon(state,focus);state.learned,state.learnedProvider=Adapter.learnedMoves(game,state.pokemon,self.fixtureEnabled)
    function state:update(dt) controller:update(self,dt) end;function state:draw() end;function state:sgbPalettes() return nil end;return state
  end
  function controller:open(game,partyState)
    if not Adapter.canReplaceParty(partyState) then return false,"unsupported party context" end
    local party=Adapter.party(game,partyState);if #party==0 then return false,"empty party" end
    local state=self:newState(game,partyState);game.stack:push(state);runtime.state=state;foundation.setFocus("kanto_rework_ui.party","party."..state.partyFocus);return true
  end
  function controller:ensureOpen(game)
    if runtime.state and top(game)==runtime.state then return false end;local state=top(game);if Adapter.canReplaceParty(state) then return self:open(game,state) end;return false
  end
  function controller:setPartyFocus(state,index)
    index=math.max(1,math.min(#state.party,index));if index==state.partyFocus then return false end;state.partyFocus=index;state.partyState.index=index;if state.game then state.game.partyMenuSavedIndex=index end
    state.mon,state.pokemon=refreshPokemon(state,index);foundation.setFocus("kanto_rework_ui.party","party."..index);return true
  end
  function controller:navigateParty(state,direction) return self:setPartyFocus(state,Layout.partyNeighbor(state.partyFocus,direction,#state.party)) end
  local function closeWrapper(state,notifyCancel)
    local game=state.game;local partyState=state.partyState
    if top(game)==state then game.stack:pop() end
    runtime.state=nil;foundation.clearFocus("kanto_rework_ui.party")
    return Adapter.popNativeParty(game,partyState,notifyCancel==true)
  end
  function controller:battleSwitch(state)
    local mon=state.party[state.selectedParty or state.partyFocus];if not mon then return false end
    local cb=state.partyState and state.partyState.onSwitch
    closeWrapper(state,false);sound(state.game,"Press_AB")
    if type(cb)=="function" then local ok,err=pcall(cb,mon,state.partyState);if not ok then error(err,0) end end
    return true
  end
  function controller:battleCancel(state)
    local ok=closeWrapper(state,true);sound(state.game,"Press_AB");return ok
  end
  function controller:selectPokemon(state,index)
    if index then self:setPartyFocus(state,index) end
    state.selectedParty=index or state.partyFocus;updateSelectedModel(state)
    if state.battleMode then
      if state.forceSwitch then return self:battleSwitch(state) end
      state.battleActionFocus=1;foundation.setFocus("kanto_rework_ui.party","battle.switch");return transition(state,"BattleAction")
    end
    state.submenuFocus="summary";foundation.setFocus("kanto_rework_ui.party","summary");return transition(state,"SummaryActive")
  end
  function controller:openSubmenu(state)
    updateSelectedModel(state)
    if state.submenuFocus=="moves" then state.activeMoveFocus=1;state.selectedActive=nil;state.learnedFocus=nil;state.movePhase="active";foundation.setFocus("kanto_rework_ui.party","moves.active.1");return transition(state,"MovesActive") end
    foundation.setFocus("kanto_rework_ui.party","summary");return transition(state,"SummaryActive")
  end
  function controller:cancelDrag(state)
    local drag=state.drag;if not drag then return false end
    if drag.input=="navigation" then
      if drag.kind=="party" then foundation.setFocus("kanto_rework_ui.party","party."..tostring(drag.source))
      elseif drag.kind=="move" then foundation.setFocus("kanto_rework_ui.party","moves.active."..tostring(drag.source)) end
    end
    state.drag=nil;state.pointerSession=nil;foundation.endDrag("kanto_rework_ui.party");return true
  end
  function controller:back(state)
    if self:cancelDrag(state) then return true end
    if state.mode=="MovesActive" and state.movePhase=="learned" then state.movePhase="active";state.learnedFocus=nil;state.selectedActive=nil;foundation.setFocus("kanto_rework_ui.party","moves.active."..state.activeMoveFocus);sound(state.game,"Press_AB");return true end
    if state.mode=="SummaryActive" or state.mode=="MovesActive" then
      if state.battleMode then state.mode=state.summaryReturn or "BattleAction";state.summaryReturn=nil;foundation.setFocus("kanto_rework_ui.party","battle."..(({"switch","stats","cancel"})[state.battleActionFocus] or "switch"));sound(state.game,"Press_AB");return true end
      state.mode="PartyBrowse";state.partyFocus=state.selectedParty or state.partyFocus;state.selectedParty=nil;foundation.setFocus("kanto_rework_ui.party","party."..state.partyFocus);sound(state.game,"Press_AB");return true
    end
    if state.mode=="BattleAction" then state.mode="PartyBrowse";state.selectedParty=nil;foundation.setFocus("kanto_rework_ui.party","party."..state.partyFocus);sound(state.game,"Press_AB");return true end
    if state.mode=="SubmenuBrowse" then state.mode="PartyBrowse";state.partyFocus=state.selectedParty or state.partyFocus;state.selectedParty=nil;foundation.setFocus("kanto_rework_ui.party","party."..state.partyFocus);sound(state.game,"Press_AB");return true end
    if state.mode=="PartyBrowse" then if state.battleMode then return self:battleCancel(state) end;local game=state.game;local partyState=state.partyState;if top(game)==state then game.stack:pop() end;runtime.state=nil;foundation.clearFocus("kanto_rework_ui.party");local ok=Adapter.closeNativeParty(game,partyState);sound(game,"Press_AB");return ok end
    return false
  end
  function controller:cycleStats(state) if state.statMode=="stats" then state.statMode="iv" elseif state.statMode=="iv" then state.statMode="ev" else state.statMode="stats" end;return true end
  -- Additive bumper navigation across the authored PARTY / SUMMARY / MOVES
  -- hierarchy. Battle contexts intentionally keep shoulders untouched so no
  -- combat action can collide with this convenience shortcut.
  function controller:cycleSubmenu(state,delta)
    if not state or state.battleMode or state.drag then return false end
    local order={'PartyBrowse','SummaryActive','MovesActive'}
    local current=1;for i,v in ipairs(order) do if state.mode==v then current=i break end end
    local target=order[((current-1+(delta or 1))%#order)+1]
    if target=='PartyBrowse' then
      state.mode='PartyBrowse';state.partyFocus=state.selectedParty or state.partyFocus;state.selectedParty=nil
      foundation.setFocus('kanto_rework_ui.party','party.'..state.partyFocus)
    else
      state.selectedParty=state.selectedParty or state.partyFocus;updateSelectedModel(state)
      if target=='SummaryActive' then state.submenuFocus='summary';state.mode='SummaryActive';foundation.setFocus('kanto_rework_ui.party','summary')
      else state.submenuFocus='moves';state.mode='MovesActive';state.movePhase='active';state.activeMoveFocus=math.max(1,state.activeMoveFocus or 1);state.selectedActive=nil;state.learnedFocus=nil;foundation.setFocus('kanto_rework_ui.party','moves.active.'..state.activeMoveFocus) end
    end
    sound(state.game,'Tink');return true
  end
  function controller:renamePokemon(state)
    if state.battleMode or type(state.mon)~="table" then return false end
    local NamingScreen=require("src.ui.NamingScreen")
    local def=Adapter.speciesDef and Adapter.speciesDef(state.game,state.mon) or nil
    local old=tostring(state.mon.nickname or (def and def.name) or state.mon.species or "POKéMON")
    local target=state.mon
    local naming=NamingScreen.new(state.game,{title="POKéMON NAME?",maxLen=10,default=old,onDone=function(name)
      name=type(name)=="string" and name:gsub("^%s+",""):gsub("%s+$","") or ""
      if name=="" then name=old end
      target.nickname=name
      if runtime.state==state then updateSelectedModel(state) end
    end})
    state.game.stack:push(naming);sound(state.game,"Press_AB");return true
  end
  function controller:reorderMoves(state,fromIndex,toIndex)
    if state.battleMode then state.message="Moves cannot be rearranged during battle.";return false end
    local ok,err=Adapter.reorderMoves(state.game,state.mon,fromIndex,toIndex);if not ok then state.message=err return false end;updateSelectedModel(state);state.activeMoveFocus=toIndex;state.selectedActive=nil;state.movePhase="active";return true
  end
  function controller:beginPartyReorder(state)
    if #state.party<2 then return false end
    state.drag={kind="party",source=state.partyFocus,target=state.partyFocus,input="navigation"}
    foundation.beginDrag({owner="kanto_rework_ui.party",kind="party",source=state.partyFocus,input="navigation"})
    foundation.setFocus("kanto_rework_ui.party","party."..state.partyFocus);sound(state.game,"Press_AB");return true
  end
  function controller:beginMoveReorder(state)
    local count=moveCount(state.pokemon);if count<2 then return false end
    state.drag={kind="move",source=state.activeMoveFocus,target=state.activeMoveFocus,input="navigation"}
    foundation.beginDrag({owner="kanto_rework_ui.party",kind="move",source=state.activeMoveFocus,input="navigation"})
    foundation.setFocus("kanto_rework_ui.party","moves.active."..state.activeMoveFocus);sound(state.game,"Press_AB");return true
  end
  function controller:navigateReorder(state,direction)
    local drag=state.drag;if not (drag and drag.input=="navigation") then return false end
    if drag.kind=="party" then
      drag.target=Layout.partyNeighbor(drag.target,direction,#state.party)
      foundation.setFocus("kanto_rework_ui.party","party."..drag.target);return true
    end
    if drag.kind=="move" then
      local count=moveCount(state.pokemon);if count<=0 then return false end
      if direction=="up" then drag.target=drag.target>1 and drag.target-1 or count
      elseif direction=="down" then drag.target=drag.target<count and drag.target+1 or 1 end
      foundation.setFocus("kanto_rework_ui.party","moves.active."..drag.target);return true
    end
    return false
  end
  function controller:commitReorder(state)
    local drag=state.drag;if not (drag and drag.input=="navigation") then return false end
    local source,target=drag.source,drag.target
    if source==target then self:cancelDrag(state);return true end
    if drag.kind=="party" then
      local ok=Adapter.reorderParty(state.game,state.partyState,source,target)
      if not ok then self:cancelDrag(state);return false end
      state.party=Adapter.party(state.game,state.partyState);state.partyFocus=target;state.selectedParty=nil
      state.mon,state.pokemon=refreshPokemon(state,target);state.learned,state.learnedProvider=Adapter.learnedMoves(state.game,state.pokemon,self.fixtureEnabled)
      state.drag=nil;state.pointerSession=nil;foundation.endDrag("kanto_rework_ui.party");foundation.setFocus("kanto_rework_ui.party","party."..target);return true
    end
    if drag.kind=="move" then
      local ok=self:reorderMoves(state,source,target)
      state.drag=nil;state.pointerSession=nil;foundation.endDrag("kanto_rework_ui.party");foundation.setFocus("kanto_rework_ui.party","moves.active."..state.activeMoveFocus);return ok
    end
    return false
  end
  function controller:chooseActiveForReplacement(state)
    if state.battleMode then state.message="Moves can only be swapped outside battle.";return false end
    local learned=firstSelectable(state.learned);if not learned then state.message="No additional learned moves are available.";return false end
    state.selectedActive=state.activeMoveFocus;state.movePhase="learned";state.learnedFocus=learned;ensureLearnedVisible(state,learned);foundation.setFocus("kanto_rework_ui.party","moves.learned."..learned);sound(state.game,"Press_AB");return true
  end
  function controller:replaceWithLearned(state,index)
    local row=state.learned[index];if not row or row.disabled then return false end
    local ok,err=Adapter.replaceLearnedMove(state.game,state.mon,state.selectedActive,row.id);if not ok then state.message=err return false end
    updateSelectedModel(state);state.activeMoveFocus=state.selectedActive or state.activeMoveFocus;state.selectedActive=nil;state.learnedFocus=nil;state.movePhase="active";foundation.setFocus("kanto_rework_ui.party","moves.active."..state.activeMoveFocus);sound(state.game,"Swap");return true
  end
  function controller:update(state)
    runtime.Focus.syncDevice(runtime.partyNav)
    if state.inputGuard>0 then state.inputGuard=state.inputGuard-1 return end;local game=state.game;if actionPressed(game,"Back") then self:back(state) return end
    if state.mode=="PartyBrowse" then
      if state.drag and state.drag.kind=="party" and state.drag.input=="navigation" then
        if actionPressed(game,"NavigateUp") then self:navigateReorder(state,"up")
        elseif actionPressed(game,"NavigateDown") then self:navigateReorder(state,"down")
        elseif actionPressed(game,"NavigateLeft") then self:navigateReorder(state,"left")
        elseif actionPressed(game,"NavigateRight") then self:navigateReorder(state,"right")
        elseif actionPressed(game,"Confirm") then self:commitReorder(state) end
        return
      end
      if (not state.battleMode) and actionPressed(game,"CycleMode") then self:beginPartyReorder(state)
      elseif actionPressed(game,"NavigateUp") then self:navigateParty(state,"up") elseif actionPressed(game,"NavigateDown") then self:navigateParty(state,"down") elseif actionPressed(game,"NavigateLeft") then self:navigateParty(state,"left") elseif actionPressed(game,"NavigateRight") then self:navigateParty(state,"right") elseif actionPressed(game,"Confirm") then self:selectPokemon(state) end;return
    end
    if state.mode=="BattleAction" then
      if actionPressed(game,"NavigateLeft") or actionPressed(game,"NavigateUp") then state.battleActionFocus=state.battleActionFocus>1 and state.battleActionFocus-1 or 3
      elseif actionPressed(game,"NavigateRight") or actionPressed(game,"NavigateDown") then state.battleActionFocus=state.battleActionFocus<3 and state.battleActionFocus+1 or 1
      elseif actionPressed(game,"Confirm") then
        if state.battleActionFocus==1 then return self:battleSwitch(state)
        elseif state.battleActionFocus==2 then state.summaryReturn="BattleAction";foundation.setFocus("kanto_rework_ui.party","summary");return transition(state,"SummaryActive")
        else return self:battleCancel(state) end
      end
      foundation.setFocus("kanto_rework_ui.party","battle."..(({"switch","stats","cancel"})[state.battleActionFocus]));return
    end
    if state.mode=="SubmenuBrowse" then
      if actionPressed(game,"NavigateLeft") then state.submenuFocus="summary";foundation.setFocus("kanto_rework_ui.party","submenu.summary") elseif actionPressed(game,"NavigateRight") then state.submenuFocus="moves";foundation.setFocus("kanto_rework_ui.party","submenu.moves") elseif actionPressed(game,"Confirm") then self:openSubmenu(state) end;return
    end
    if state.mode=="SummaryActive" then
      if actionPressed(game,"CycleMode") then self:cycleStats(state)
      elseif actionPressed(game,"Confirm") then self:renamePokemon(state)
      elseif actionPressed(game,"NavigateLeft") then state.mode="PartyBrowse";state.partyFocus=state.selectedParty or state.partyFocus;state.selectedParty=nil;foundation.setFocus("kanto_rework_ui.party","party."..state.partyFocus);sound(state.game,"Press_AB")
      elseif actionPressed(game,"NavigateRight") then state.submenuFocus="moves";state.activeMoveFocus=1;state.selectedActive=nil;state.learnedFocus=nil;state.movePhase="active";foundation.setFocus("kanto_rework_ui.party","moves.active.1");transition(state,"MovesActive") end
      return
    end
    if state.mode=="MovesActive" then
      if state.movePhase~="learned" and actionPressed(game,"NavigateLeft") then state.submenuFocus="summary";foundation.setFocus("kanto_rework_ui.party","summary");transition(state,"SummaryActive");return end
      if state.movePhase=="learned" then
        if actionPressed(game,"NavigateUp") then state.learnedFocus=nextSelectable(state.learned,state.learnedFocus,-1);ensureLearnedVisible(state) elseif actionPressed(game,"NavigateDown") then state.learnedFocus=nextSelectable(state.learned,state.learnedFocus,1);ensureLearnedVisible(state) elseif actionPressed(game,"Confirm") then self:replaceWithLearned(state,state.learnedFocus) end;return
      end
      local count=moveCount(state.pokemon);if count<=0 then return end
      if state.drag and state.drag.kind=="move" and state.drag.input=="navigation" then
        if actionPressed(game,"NavigateUp") then self:navigateReorder(state,"up")
        elseif actionPressed(game,"NavigateDown") then self:navigateReorder(state,"down")
        elseif actionPressed(game,"Confirm") then self:commitReorder(state) end
        return
      end
      if actionPressed(game,"CycleMode") then self:beginMoveReorder(state)
      elseif actionPressed(game,"NavigateUp") then state.activeMoveFocus=state.activeMoveFocus>1 and state.activeMoveFocus-1 or count;state.learnedFocus=nil
      elseif actionPressed(game,"NavigateDown") then state.activeMoveFocus=state.activeMoveFocus<count and state.activeMoveFocus+1 or 1;state.learnedFocus=nil
      elseif actionPressed(game,"Confirm") then self:chooseActiveForReplacement(state) end
    end
  end
  local function hit(state,x,y,kind) for i=#(state.regions or {}),1,-1 do local r=state.regions[i];if (not kind or r.kind==kind) and Layout.contains(r,x,y) then return r end end end
  local function logical(x,y) local lx,ly,inside=Layout.toLogical(runtime.viewport,x,y);runtime.pointerLogical={x=lx,y=ly,inside=inside};return lx,ly,inside end
  local function moved(session,x,y) local dx=x-session.startX;local dy=y-session.startY;return dx*dx+dy*dy>=C.DRAG_THRESHOLD*C.DRAG_THRESHOLD end
  function controller:pointer(game,ev)
    local state=runtime.state;if not state or top(game)~=state then return false end
    local x,y,inside=logical(ev.x or 0,ev.y or 0);runtime.lastInput=ev.source=="touch" and "touch" or "mouse"
    if ev.phase=="moved" and state.learnedScrollDrag then
      local sb=state.learnedScrollbar;local drag=state.learnedScrollDrag
      if sb and sb.travel>0 then local first=math.floor(drag.startFirst+(y-drag.startY)*sb.maxFirst/sb.travel+.5);state.learnedFirst=math.max(1,math.min(sb.maxFirst+1,first)) end
      runtime.hoveredRegion=nil;return true
    end
    if (ev.phase=="released" or ev.phase=="cancelled") and state.learnedScrollDrag then state.learnedScrollDrag=nil;return true end
    if state.drag and state.drag.input=="navigation" and (ev.phase=="moved" or ev.phase=="pressed") then self:cancelDrag(state) end
    if ev.button==2 and ev.phase=="pressed" then self:back(state) return true end;if not inside and ev.phase=="pressed" then return true end
    if ev.phase=="moved" then
      local session=state.pointerSession
      if session then
        session.pointerX,session.pointerY=x,y
        if not session.dragging and moved(session,x,y) and session.draggable then session.dragging=true;state.drag={kind=session.kind,source=session.index,target=session.index,x=x,y=y};foundation.beginDrag({owner="kanto_rework_ui.party",kind=session.kind,source=session.index}) end
        if session.dragging then state.drag.x,state.drag.y=x,y;local r=hit(state,x,y,session.kind=="party" and "party_card" or "active_move");state.drag.target=r and r.index or nil end;return true
      end
      local r
      if state.mode=="PartyBrowse" then r=hit(state,x,y,"header_tab") or hit(state,x,y,"party_card");if r and r.kind=="party_card" then self:setPartyFocus(state,r.index) end
      elseif state.mode=="BattleAction" then r=hit(state,x,y,"battle_action");if r then state.battleActionFocus=r.index;foundation.setFocus("kanto_rework_ui.party","battle."..r.id) end
      elseif state.mode=="SubmenuBrowse" then r=hit(state,x,y,"header_tab");if r and (r.id=="summary" or r.id=="moves") then state.submenuFocus=r.id;foundation.setFocus("kanto_rework_ui.party","submenu."..r.id) end
      elseif state.mode=="SummaryActive" then r=hit(state,x,y,"rename") or hit(state,x,y,"header_tab") or hit(state,x,y,"stat_tab")
      elseif state.mode=="MovesActive" then
        r=hit(state,x,y,"header_tab") or hit(state,x,y,"learned_move") or hit(state,x,y,"active_move")
        if r and r.kind~="header_tab" then
          if r.kind=="learned_move" then
            state.learnedFocus=r.index
            foundation.setFocus("kanto_rework_ui.party","moves.learned."..r.index)
          else
            state.activeMoveFocus=r.index;state.learnedFocus=nil
            foundation.setFocus("kanto_rework_ui.party","moves.active."..r.index)
          end
        end
      end
      runtime.hoveredRegion=r and r.id or nil
      runtime.Focus.pointerMove(runtime.partyNav,runtime.hoveredRegion)
      return true
    end
    if ev.phase=="cancelled" then self:cancelDrag(state) return true end
    if ev.phase=="pressed" and (ev.button==nil or ev.button==1 or ev.source=="touch") then
      local sb=state.learnedScrollbar;if state.mode=="MovesActive" and sb and Layout.contains(sb.hit,x,y) then state.learnedScrollDrag={startY=y,startFirst=state.learnedFirst};return true end
      local r=hit(state,x,y);runtime.hoveredRegion=r and r.id or nil;runtime.Focus.pointerPress(runtime.partyNav,runtime.hoveredRegion)
      if state.mode=="PartyBrowse" and r and r.kind=="header_tab" then
        if r.id=="summary" or r.id=="moves" then
          state.selectedParty=state.partyFocus;updateSelectedModel(state);state.submenuFocus=r.id
          if r.id=="moves" then state.activeMoveFocus=1;state.selectedActive=nil;state.learnedFocus=nil;state.movePhase="active";foundation.setFocus("kanto_rework_ui.party","moves.active.1");transition(state,"MovesActive")
          else foundation.setFocus("kanto_rework_ui.party","summary");transition(state,"SummaryActive") end
        end
      elseif state.mode=="PartyBrowse" and r and r.kind=="party_card" then self:setPartyFocus(state,r.index);state.pointerSession={kind="party",index=r.index,startX=x,startY=y,draggable=not state.battleMode}
      elseif state.mode=="BattleAction" and r and r.kind=="battle_action" then
        state.battleActionFocus=r.index
        if r.index==1 then return self:battleSwitch(state) elseif r.index==2 then state.summaryReturn="BattleAction";foundation.setFocus("kanto_rework_ui.party","summary");transition(state,"SummaryActive") else return self:battleCancel(state) end
      elseif state.mode=="SubmenuBrowse" then
        if r and r.kind=="header_tab" then if r.id==state.submenuFocus then self:openSubmenu(state) elseif r.id=="summary" or r.id=="moves" then state.submenuFocus=r.id;foundation.setFocus("kanto_rework_ui.party","submenu."..r.id) end
        elseif r and r.kind=="party_card" and r.index==state.selectedParty then self:openSubmenu(state) end
      elseif state.mode=="SummaryActive" and r and r.kind=="rename" then self:renamePokemon(state)
      elseif state.mode=="SummaryActive" and r and r.kind=="header_tab" then
        if r.id=="party" then state.mode="PartyBrowse";state.partyFocus=state.selectedParty or state.partyFocus;state.selectedParty=nil;foundation.setFocus("kanto_rework_ui.party","party."..state.partyFocus);sound(state.game,"Press_AB")
        elseif r.id=="moves" then state.submenuFocus="moves";state.activeMoveFocus=1;state.selectedActive=nil;state.learnedFocus=nil;state.movePhase="active";foundation.setFocus("kanto_rework_ui.party","moves.active.1");transition(state,"MovesActive") end
      elseif state.mode=="SummaryActive" and r and r.kind=="stat_tab" then state.statMode=r.id
      elseif state.mode=="MovesActive" and r and r.kind=="header_tab" then
        if r.id=="party" then state.mode="PartyBrowse";state.partyFocus=state.selectedParty or state.partyFocus;state.selectedParty=nil;foundation.setFocus("kanto_rework_ui.party","party."..state.partyFocus);sound(state.game,"Press_AB")
        elseif r.id=="summary" then state.submenuFocus="summary";foundation.setFocus("kanto_rework_ui.party","summary");transition(state,"SummaryActive") end
      elseif state.mode=="MovesActive" and r and r.kind=="active_move" then state.activeMoveFocus=r.index;state.learnedFocus=nil;if not state.battleMode then state.pointerSession={kind="move",index=r.index,startX=x,startY=y,draggable=true} end
      elseif state.mode=="MovesActive" and r and r.kind=="learned_move" then
        state.learnedFocus=r.index
      end
      return true
    end
    if ev.phase=="released" then
      local session=state.pointerSession;state.pointerSession=nil
      if session then
        if session.dragging and state.drag then local target=state.drag.target;local source=state.drag.source;if target and target~=source then if session.kind=="party" then local ok=Adapter.reorderParty(state.game,state.partyState,source,target);if ok then state.party=Adapter.party(state.game,state.partyState);state.partyFocus=target;state.selectedParty=nil;state.mon,state.pokemon=refreshPokemon(state,target) end else self:reorderMoves(state,source,target) end end;self:cancelDrag(state)
        elseif session.kind=="party" then self:selectPokemon(state,session.index)
        elseif session.kind=="move" and state.mode=="MovesActive" then self:chooseActiveForReplacement(state) end
      else
        local r=hit(state,x,y,"learned_move");if state.mode=="MovesActive" and state.movePhase=="learned" and r and not state.learned[r.index].disabled then self:replaceWithLearned(state,r.index) end
      end
      return true
    end
    return true
  end
  function controller:keypressed(game,key,_,isrepeat) local state=runtime.state;if not state or top(game)~=state or isrepeat then return false end;runtime.lastInput="keyboard";runtime.Focus.navigation(runtime.partyNav);runtime.hoveredRegion=nil;return false end
  function controller:wheel(game,_,dy)
    local state=runtime.state;if not state or top(game)~=state then return false end
    if state.mode=="MovesActive" and dy~=0 then if state.movePhase=="learned" then state.learnedFocus=nextSelectable(state.learned,state.learnedFocus,dy>0 and -1 or 1);ensureLearnedVisible(state);runtime.hoveredRegion=state.learnedFocus and ("learned."..state.learnedFocus) or nil else local count=moveCount(state.pokemon);if count>0 then state.activeMoveFocus=dy>0 and math.max(1,state.activeMoveFocus-1) or math.min(count,state.activeMoveFocus+1);state.learnedFocus=nil;runtime.hoveredRegion="move."..state.activeMoveFocus end end;runtime.Focus.pointerMove(runtime.partyNav,runtime.hoveredRegion) end;return true
  end
  return controller
end
