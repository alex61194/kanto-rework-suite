-- Kanto Rework Phase F: one backend for contextual and manual Field Actions.
-- Detection delegates to the current engine field-move seams when present;
-- optional adapters are never allowed to abort action registration when a
-- supported Gen1Recomp build exposes a different internal method surface.
-- Execution keeps the engine's own world mutations, animations,
-- music and progression gates. Successful contextual HM announcement boxes
-- are intentionally suppressed; native failure feedback remains available.
return function(deps)
  local mod=assert(deps.mod,"mod is required")
  local Core=assert(deps.Core,"Core is required")
  local Game=assert(deps.Game,"Game is required")
  local OverworldState=assert(deps.OverworldState,"OverworldState is required")

  local Collision=require("src.world.Collision")
  local Music=require("src.core.Music")
  local TextBox=require("src.render.TextBox")
  local Transition=require("src.render.Transition")

  local service={}
  local state={
    game=nil,pendingFlashMap=nil,automaticExecutions=0,lastAction=nil,
    observedMap=nil,registrations={},subscriptions={},
    partyKnowsAdapterInstalled=false,handleInputAdapterInstalled=false,
    strengthAdapterInstalled=false,
  }

  local function mode()
    return mod.options:get("field_move_mode")=="vanilla" and "vanilla"
      or "automatic"
  end

  local function lawnMowerEnabled()
    return mod.options:get("lawn_mower")==true
  end

  local function liveGame(context)
    return context and context.game or state.game or Game
  end

  local function overworld(context)
    local game=liveGame(context)
    return context and context.overworld or game and game.overworld
  end

  local function topIsOverworld(game,ow)
    local stack=game and game.stack
    return ow~=nil and stack and type(stack.top)=="function" and stack:top()==ow
  end

  local HM_ITEMS={
    CUT="HM_CUT",SURF="HM_SURF",STRENGTH="HM_STRENGTH",FLASH="HM_FLASH",
  }
  local BADGES={
    CUT="CASCADEBADGE",SURF="SOULBADGE",STRENGTH="RAINBOWBADGE",
    FLASH="BOULDERBADGE",
  }

  local function inventoryOwns(game,itemId)
    local inventory=game and game.save and game.save.inventory
    local value=inventory and inventory[itemId]
    if type(value)=="number" then return value>0 end
    return value==true
  end

  local function fieldPermission(context,moveId)
    local game=liveGame(context)
    local hm=HM_ITEMS[moveId]
    local badge=BADGES[moveId]
    if not (hm and inventoryOwns(game,hm)) then
      return false,"hm_required",hm,badge
    end
    if not (badge and inventoryOwns(game,badge)) then
      return false,"badge_required",hm,badge
    end
    return true,"hm_badge",hm,badge
  end

  local function partyMoveUser(game,moveId)
    moveId=tostring(moveId or '')
    for index,mon in ipairs(game and game.save and game.save.party or {}) do
      for _,mv in ipairs(mon.moves or {}) do
        if tostring(type(mv)=='table' and mv.id or mv)==moveId then return mon,index,'active' end
      end
      -- KRS Move Memory makes learned moves permanent even while they are not
      -- in the active four. Field capability follows that permanent knowledge,
      -- not the current combat loadout.
      if type(Core.knownMoves)=='function' then
        local ok,known=pcall(Core.knownMoves,mon,true)
        if ok and type(known)=='table' then
          for _,mv in ipairs(known) do if tostring(mv and mv.id or '')==moveId then return mon,index,'memory' end end
        end
      end
    end
  end

  local function fieldProvider(context,moveId)
    local game=liveGame(context)
    local mon=partyMoveUser(game,moveId)
    if mon then return mon end
    local save=game and game.save
    -- Automatic mode preserves the validated HM-item + badge QoL policy: it
    -- may use the first party member as presentation-only provider when the HM
    -- is owned. Manual Field Actions, however, expose only real capabilities.
    return save and save.party and save.party[1]
      or {nickname=moveId,species=nil,__kantoHmProvider=true}
  end

  local function requirement(moveId)
    return function(context)
      local ok,reason,hm,badge=fieldPermission(context,moveId)
      if not ok then return {ok=false,reason=reason,move=moveId,hm=hm,badge=badge} end
      if not (context and context.automatic) then
        local mon,index,source=partyMoveUser(liveGame(context),moveId)
        if not mon then return {ok=false,reason='move_not_known',move=moveId,hm=hm,badge=badge} end
        return {ok=true,move=moveId,hm=hm,badge=badge,pokemon=index,capabilitySource=source,
          eligibility='party_known_move_hm_and_badge'}
      end
      return {ok=true,move=moveId,hm=hm,badge=badge,eligibility='inventory_hm_and_badge'}
    end
  end

  local function contextReady(context)
    local game=liveGame(context)
    local ow=overworld(context)
    if not (game and ow and ow.player and ow.map) then
      return false,"no_overworld",game,ow
    end
    if context and context.automatic and not topIsOverworld(game,ow) then
      return false,"sequence_busy",game,ow
    end
    if ow.player.moving then return false,"player_moving",game,ow end
    return true,nil,game,ow
  end

  local function actionContext(extra)
    local game=state.game or Game
    local out={game=game,overworld=game and game.overworld,automatic=true}
    for key,value in pairs(extra or {}) do out[key]=value end
    return out
  end

  -- Contextual HM actions are intentionally textless. Cut and Surf already
  -- have correct native executors, but those executors put one TextBox in
  -- front of their world mutation. Suppress only that immediate native box,
  -- restore the stack before invoking its completion callback, then retain
  -- the untouched animation, music, movement and map mutation behind it.
  local function runWithoutHmText(game,fn)
    local stack=game and game.stack
    if not (stack and type(stack.push)=="function") then return fn() end
    local originalPush=stack.push
    local suppressed
    stack.push=function(self,value)
      if not suppressed and getmetatable(value)==TextBox then
        suppressed=value
        return value
      end
      return originalPush(self,value)
    end
    local values={pcall(fn)}
    stack.push=originalPush
    local ok=table.remove(values,1)
    if not ok then error(values[1],0) end
    if suppressed and type(suppressed.onDone)=="function" then
      suppressed.onDone()
    end
    return unpack(values)
  end

  -- Native Cut/Surf execution calls partyKnows again after availability has
  -- been checked. In Automatic mode, keep every upstream provider/learned HM
  -- answer first, then supply a presentation-only user when the HM item and
  -- badge are owned. Vanilla mode delegates byte-for-byte to 0.1.75.
  local originalPartyKnows=OverworldState.partyKnows
  local kantoPartyKnows
  if type(originalPartyKnows)=='function' then
    kantoPartyKnows=function(self,moveId)
      local native=originalPartyKnows(self,moveId)
      if native or mode()~="automatic" then return native end
      local context={game=state.game or Game,overworld=self}
      if fieldPermission(context,moveId) then return fieldProvider(context,moveId) end
      return nil
    end
    OverworldState.partyKnows=kantoPartyKnows
    state.partyKnowsAdapterInstalled=true
  end

  local function availabilityCut(context)
    local ready,reason,game,ow=contextReady(context)
    if not ready then return {available=false,reason=reason} end
    local permitted,gateReason,hm,badge=fieldPermission(context,"CUT")
    if not permitted then
      return {available=false,reason=gateReason,hm=hm,badge=badge}
    end
    local fx,fy=ow.player:facingCell()
    local map=ow.map
    local isTallGrass=map and map.def and map.def.tileset=="OVERWORLD"
      and type(map.inBounds)=="function" and map:inBounds(fx,fy)
      and type(map.cellTile)=="function" and map:cellTile(fx,fy)==0x52
    if context and context.automatic and isTallGrass and not lawnMowerEnabled() then
      return {available=false,reason="lawn_mower_disabled",target="tall_grass"}
    end
    local result=ow:useCutFieldMove()
    return {available=result=="ok",reason=result=="ok" and nil or result,
      target=result=="ok" and (isTallGrass and "tall_grass" or "cuttable") or nil}
  end

  local function executeCut(context)
    local game=liveGame(context)
    local ow=overworld(context)
    if not (game and ow) then return false,"no_overworld" end
    local fx,fy=ow.player:facingCell()
    local map=ow.map
    local isTallGrass=map and map.def and map.def.tileset=="OVERWORLD"
      and type(map.inBounds)=="function" and map:inBounds(fx,fy)
      and type(map.cellTile)=="function" and map:cellTile(fx,fy)==0x52
    if context and context.automatic and isTallGrass and not lawnMowerEnabled() then
      return false,"lawn_mower_disabled"
    end
    local ok=runWithoutHmText(game,function()
      return ow:tryCut(fx,fy)==true
    end)==true
    return ok,ok and "executed" or "target_changed"
  end

  -- Automatic Surf is movement-triggered, so it runs before the native
  -- interaction priority chain. Some Gen 1 hidden interaction objects (most
  -- notably Gym statues) reuse collision/tile values that also satisfy the
  -- engine's shore/water probe. Treat those semantic interaction targets as
  -- blockers for AUTOMATIC mounting only; manual/vanilla Surf is unchanged.
  local function automaticSurfBlockReason(context,ow)
    if not (context and context.automatic and ow and ow.player and ow.map) then
      return nil
    end
    -- Dismounting from real water is never blocked by a land interaction.
    if ow.player.surfing then return nil end
    local fx,fy=ow.player:facingCell()
    local game=liveGame(context)
    local field=game and game.data and game.data.field
    local extras=field and field.hiddenExtras
    local byMap=extras and extras.gymStatues
    local statues=byMap and byMap[ow.map.id]
    if type(statues)=="table" and ow.player.facing=="up" then
      for _,statue in ipairs(statues) do
        if type(statue)=="table" and statue.x==fx and statue.y==fy then
          return "gym_statue"
        end
      end
    end
    return nil
  end

  local function availabilitySurf(context)
    local ready,reason,game,ow=contextReady(context)
    if not ready then return {available=false,reason=reason} end
    local permitted,gateReason,hm,badge=fieldPermission(context,"SURF")
    if not permitted then
      return {available=false,reason=gateReason,hm=hm,badge=badge}
    end
    local blocked=automaticSurfBlockReason(context,ow)
    if blocked then
      return {available=false,reason="interactive_target",target=blocked}
    end
    local result=ow:useSurfFieldMove()
    local available=result=="ok" or result=="dismount"
    return {available=available,reason=available and nil or result,
      transition=result}
  end

  local function executeSurf(context)
    local game=liveGame(context)
    local ow=overworld(context)
    if not (game and ow) then return false,"no_overworld" end
    local blocked=automaticSurfBlockReason(context,ow)
    if blocked then return false,"interactive_target" end
    local result=ow:useSurfFieldMove()
    if result=="ok" then
      local fx,fy=ow.player:facingCell()
      runWithoutHmText(game,function() ow:trySurf(fx,fy) end)
      return true,"mounted"
    end
    if result=="dismount" then
      ow.player.surfing=false
      Music.setSurfing(game.data,false)
      game.stack:push(Transition.whiteFlash(game,nil,function()
        ow:stepForwardOrCrossEdge(ow.player.facing)
      end))
      return true,"dismounted"
    end
    return false,result
  end

  local function boulderTarget(ow,dir)
    if not (ow and ow.player and type(dir)=="string") then return nil end
    local fx,fy=Collision.target(ow.player.cellX,ow.player.cellY,dir)
    local npc=ow:pushableAtCell(fx,fy)
    if not npc or npc.moving then return nil end
    return npc,fx,fy
  end

  local function availabilityStrength(context)
    local ready,reason,game,ow=contextReady(context)
    if not ready then return {available=false,reason=reason} end
    local permitted,gateReason,hm,badge=fieldPermission(context,"STRENGTH")
    if not permitted then
      return {available=false,reason=gateReason,hm=hm,badge=badge}
    end
    if ow.strengthActive then
      return {available=false,reason="already_active"}
    end
    if context and context.automatic then
      local npc=boulderTarget(ow,context.direction)
      if not npc then return {available=false,reason="no_boulder"} end
      return {available=true,target=npc}
    end
    return {available=true}
  end

  local function executeStrength(context)
    local game=liveGame(context)
    local ow=overworld(context)
    if not (game and ow) then return false,"no_overworld" end
    ow.strengthActive=true
    game.stack:push(Transition.whiteFlash(game))
    return true,"activated"
  end

  local function availabilityFlash(context)
    local ready,reason,game,ow=contextReady(context)
    if not ready then return {available=false,reason=reason} end
    local permitted,gateReason,hm,badge=fieldPermission(context,"FLASH")
    if not permitted then
      return {available=false,reason=gateReason,hm=hm,badge=badge}
    end
    if not ow.dark or (game.save and game.save.flashLit) then
      return {available=false,reason="area_already_lit"}
    end
    return {available=true}
  end

  local function executeFlash(context)
    local game=liveGame(context)
    local ow=overworld(context)
    if not (game and ow and ow.dark) then return false,"area_already_lit" end
    game.save.flashLit=true
    ow:setDark(false)
    game.stack:push(Transition.whiteFlash(game))
    return true,"lit"
  end

  local definitions={
    {id="kanto.cut",label="CUT",move="CUT",priority=400,
      availability=availabilityCut,execute=executeCut,
      feedback={silent=true}},
    {id="kanto.surf",label="SURF",move="SURF",priority=300,
      availability=availabilitySurf,execute=executeSurf,
      feedback={silent=true}},
    {id="kanto.strength",label="STRENGTH",move="STRENGTH",priority=200,
      availability=availabilityStrength,execute=executeStrength,
      feedback={silent=true}},
    {id="kanto.flash",label="FLASH",move="FLASH",priority=100,
      availability=availabilityFlash,execute=executeFlash,
      feedback={silent=true}},
  }

  for _,definition in ipairs(definitions) do
    state.registrations[#state.registrations+1]=Core.fieldActions.register({
      id=definition.id,label=definition.label,source=mod.id,trigger="both",
      priority=definition.priority,requirements=requirement(definition.move),
      availability=definition.availability,execute=function(context)
        local ok,result=definition.execute(context)
        if ok then
          state.lastAction=definition.id
          if context and context.automatic then
            state.automaticExecutions=state.automaticExecutions+1
          end
        end
        return ok,result
      end,feedback=definition.feedback,
    })
  end

  state.subscriptions[#state.subscriptions+1]=mod.events:on("game.ready",function(payload)
    state.game=payload and payload.game or state.game
    local ow=state.game and state.game.overworld
    if ow and ow.map and ow.dark then state.pendingFlashMap=ow.map.id end
  end)

  state.subscriptions[#state.subscriptions+1]=mod.events:on("map.entered",function(payload)
    state.pendingFlashMap=payload and payload.mapId or nil
  end)

  -- `world.interacted` is emitted synchronously after every native priority
  -- target.  Acting only on kind=none means NPCs, signs, hidden objects,
  -- scripts and bookshelves always win before contextual Cut/Surf.
  state.subscriptions[#state.subscriptions+1]=mod.events:on("world.interacted",function(payload)
    if mode()~="automatic" or not payload or payload.kind~="none" then return end
    local game=state.game or Game
    local ow=game and game.overworld
    if not topIsOverworld(game,ow) then return end
    local context=actionContext({mapId=payload.mapId,x=payload.x,y=payload.y})
    local ok=Core.fieldActions.execute("kanto.cut",context)
    if not ok then Core.fieldActions.execute("kanto.surf",context) end
  end,90)

  -- Cut/Surf are movement-context actions: holding a direction into a valid
  -- tree or water cell must trigger them without an A press. Gen1Recomp
  -- 0.1.75 has no event between the direction poll and Player:tryMove, so
  -- this bounded adapter runs immediately before the untouched input path.
  -- Occupying entities are skipped so NPCs and Strength boulders retain their
  -- native priority.
  local originalHandleInput=OverworldState.handleInput
  local kantoHandleInput
  if type(originalHandleInput)=='function' then
    kantoHandleInput=function(self,...)
    local game=state.game or Game
    local input=game and game.input
    local player=self and self.player
    if mode()=="automatic" and player and not player.moving
      and input and type(input.isDown)=="function"
      and topIsOverworld(game,self) then
      for _,dir in ipairs({"up","down","left","right"}) do
        if input:isDown(dir) then
          if player.facing==dir then
            local fx,fy=player:facingCell()
            local occupied=Collision.occupied(self.entities or {},fx,fy,player)
            if not occupied then
              local context=actionContext({overworld=self,direction=dir,x=fx,y=fy,
                mapId=self.map and self.map.id})
              local ok=Core.fieldActions.execute("kanto.cut",context)
              if not ok then ok=Core.fieldActions.execute("kanto.surf",context) end
              if ok then return "field_move" end
            end
          end
          break
        end
      end
    end
      return originalHandleInput(self,...)
    end
    OverworldState.handleInput=kantoHandleInput
    state.handleInputAdapterInstalled=true
  end

  -- If the active engine exposes this internal seam, use it as a bounded
  -- automatic-Strength adapter. Missing internals disable only automation;
  -- the registered manual action remains available through the public KRS
  -- Field Action registry instead of aborting the whole Gameplay module.
  -- version-bounded adapter activates Strength only when a real pushable is
  -- directly ahead, then arms that same boulder so the next held-direction
  -- poll enters the untouched native push path.
  local originalCheckBoulderPush=OverworldState.checkBoulderPush
  local kantoCheckBoulderPush
  if type(originalCheckBoulderPush)=='function' then
    kantoCheckBoulderPush=function(self,dir)
    if mode()=="automatic" and not self.strengthActive then
      local npc=boulderTarget(self,dir)
      if npc then
        local context=actionContext({overworld=self,direction=dir,target=npc})
        local ok=Core.fieldActions.execute("kanto.strength",context)
        if ok then
          self.boulderTried=npc
          return true
        end
      end
    end
      return originalCheckBoulderPush(self,dir)
    end
    OverworldState.checkBoulderPush=kantoCheckBoulderPush
    state.strengthAdapterInstalled=true
  end

  function service.step(game)
    state.game=game or state.game
    if mode()~="automatic" then
      state.pendingFlashMap=nil
      return false
    end
    local ow=state.game and state.game.overworld
    local mapId=ow and ow.map and ow.map.id
    -- Booting directly from a save can establish the overworld before this
    -- mod observes map.entered. Detect the first stable map identity as a
    -- second, one-shot arming path; it never retries every frame.
    if mapId and state.observedMap~=mapId then
      state.observedMap=mapId
      if ow.dark and not (state.game.save and state.game.save.flashLit) then
        state.pendingFlashMap=mapId
      end
    end
    if not (ow and ow.map and state.pendingFlashMap==ow.map.id
        and topIsOverworld(state.game,ow) and not ow.player.moving) then
      return false
    end
    state.pendingFlashMap=nil
    return Core.fieldActions.execute("kanto.flash",
      actionContext({mapId=ow.map.id}))==true
  end

  function service.status()
    return {
      installed=#state.registrations==#definitions,
      mode=mode(),automatic=mode()=="automatic",vanillaFallback=mode()=="vanilla",
      supported={"CUT","SURF","STRENGTH","FLASH"},
      promptBackend=true,promptUI=false,manualUI=false,
      pendingFlashMap=state.pendingFlashMap,lastAction=state.lastAction,
      automaticExecutions=state.automaticExecutions,
      automaticFeedback="silent",
      lawnMower=lawnMowerEnabled(),tallGrassAutomatic=lawnMowerEnabled(),
      tallGrassManual=true,
      eligibility="automatic: inventory_hm_and_badge; manual: permanent_party_move + HM + badge",
      movementAdapter=state.handleInputAdapterInstalled
        and "OverworldState.handleInput" or nil,
      partyKnowsAdapter=state.partyKnowsAdapterInstalled
        and "OverworldState.partyKnows" or nil,
      strengthAdapter=state.strengthAdapterInstalled
        and "OverworldState.checkBoulderPush" or nil,
    }
  end

  function service.unregister()
    local changed=false
    for i=#state.subscriptions,1,-1 do
      local ok,result=pcall(state.subscriptions[i])
      changed=(ok and result~=false) or changed
      state.subscriptions[i]=nil
    end
    for i=#state.registrations,1,-1 do
      local ok,result=pcall(state.registrations[i])
      changed=(ok and result==true) or changed
      state.registrations[i]=nil
    end
    if state.strengthAdapterInstalled then
      state.strengthAdapterInstalled=false
      if kantoCheckBoulderPush and OverworldState.checkBoulderPush==kantoCheckBoulderPush then
        OverworldState.checkBoulderPush=originalCheckBoulderPush
        changed=true
      end
    end
    if state.handleInputAdapterInstalled then
      state.handleInputAdapterInstalled=false
      if kantoHandleInput and OverworldState.handleInput==kantoHandleInput then
        OverworldState.handleInput=originalHandleInput
        changed=true
      end
    end
    if state.partyKnowsAdapterInstalled then
      state.partyKnowsAdapterInstalled=false
      if kantoPartyKnows and OverworldState.partyKnows==kantoPartyKnows then
        OverworldState.partyKnows=originalPartyKnows
        changed=true
      end
    end
    state.pendingFlashMap=nil
    state.observedMap=nil
    return changed
  end

  return service
end
