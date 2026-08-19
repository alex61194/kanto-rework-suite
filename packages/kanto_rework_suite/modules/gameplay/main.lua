local RELEASE="0.3.18"
local EXPORT_API=6

return function(mod)
  local function loadModule(relative)
    local source,readErr=mod:read(relative)
    assert(type(source)=="string",readErr or ("Unable to read "..tostring(relative)))
    local chunk,err=load(source,"@"..mod.id.."/"..relative)
    assert(chunk,err or ("Unable to compile "..tostring(relative)))
    return chunk()
  end
  local coreHandle=mod.find("core")
  local Core=coreHandle and coreHandle.exports
  assert(Core and tonumber(Core.version or 0)>=40 and Core.inputActions
      and Core.fieldActions and type(Core.fieldActions.register)=="function"
      and type(Core.fieldActions.evaluate)=="function"
      and Core.compatibility and type(Core.compatibility.registerProvider)=="function",
    "kanto_rework_core 0.1.40+ is required")

  local unregisterBagProvider=Core.compatibility.registerProvider({
    id="kanto_rework_gameplay.bag",capability="bag.organization",source=mod.id,modId=mod.id,
    label="Kanto Rework Bag",priority=180,restartRequired=true,
  })
  local unregisterFieldProvider=Core.compatibility.registerProvider({
    id="kanto_rework_gameplay.field_actions",capability="field.actions",source=mod.id,modId=mod.id,
    label="Kanto Rework Field Actions",priority=180,restartRequired=true,
  })

  -- Foundation behaviour is no longer exposed as redundant toggles. Running
  -- on foot/indoors, repeat-item flow, expanded Bag capacity and KRS pockets
  -- are baseline KRS mechanics. Only genuine player choices remain here.
  mod.options:define({
    {key="run_mode",label="RUN MODE",type="choice",default="hold",
      choices={{"HOLD","hold"},{"TOGGLE","toggle"}},
      description="Choose whether RUN is active only while its binding is held, or toggled on/off with each press."},
    {key="field_poison_rule",label="NON-LETHAL FIELD POISON",type="toggle",default=true,
      description="Prevent overworld poison from causing a faint. At 1 HP, PSN is cured; battle poison is unchanged. Disable for vanilla field poison."},
    {key="field_move_mode",label="CONTEXTUAL FIELD MOVES",type="choice",default="automatic",
      choices={{"AUTOMATIC","automatic"},{"VANILLA","vanilla"}},
      description="Use Cut and Surf by moving into or interacting with their target, activate Strength when pushing a boulder, and use Flash on entering a dark area. Automatic requires only the matching HM item and badge; Vanilla keeps learned Field Moves in the Pokemon menu."},
    {key="lawn_mower",label="LAWN MOWER",type="toggle",default=false,
      description="Automatically cut tall grass."},
  })

  local unregisterExpSummary=loadModule("exp_all_summary.lua")(mod)
  local unregisterLowHealthAlarm=loadModule("low_health_alarm.lua")(mod)

  local unregisterRun=Core.inputActions.register({
    id="RUN",label="RUN",source=mod.id,group="KANTO REWORK GAMEPLAY",
    description="Run while exploring on foot. This changes only the player's walking step speed; it never changes global Game Speed.",
    defaults={key="lalt"},priority=100,
  })
  local unregisterBagSort=Core.inputActions.register({
    id="BAG_SORT",label="BAG SORT",source=mod.id,group="KANTO REWORK GAMEPLAY",
    description="Open the Bag sorting chooser. Available while modern Bag pockets are enabled.",
    defaults={key="tab",pad="back"},priority=95,
  })
  local unregisterBagFavorite=Core.inputActions.register({
    id="BAG_FAVORITE",label="BAG FAVORITE",source=mod.id,group="KANTO REWORK GAMEPLAY",
    description="Mark or unmark the focused Bag item as a favorite.",
    defaults={key="f",pad="start"},priority=94,
  })
  local unregisterBagRegister=Core.inputActions.register({
    id="BAG_REGISTER",label="REGISTER BAG SHORTCUT",source=mod.id,group="KANTO REWORK GAMEPLAY",
    description="Assign the focused Bag item to one of the nine registered-item shortcuts.",
    defaults={key="r",pad="rightshoulder"},priority=93,
  })

  local fieldMoves,manualFieldMoves,bagPockets,storageBoxes,shopIntegration,pcItemIntegration,quickItems,moveMemory,centerHealBoxes
  local runState={mode=nil,toggled=false}
  local function runFeatureEnabled() return true end
  local function runIndoorsEnabled() return true end
  local function poisonFeatureEnabled()
    return mod.options:get("field_poison_rule")~=false
  end
  local function itemUseFlowEnabled() return true end
  local function expandedBagEnabled() return true end
  local function bagPocketsEnabled() return true end
  local function mode()
    local value=mod.options:get("run_mode")
    return value=="toggle" and "toggle" or "hold"
  end
  local function syncMode()
    local current=mode()
    if runState.mode~=current then
      runState.mode=current
      runState.toggled=false
    end
    return current
  end
  local function runRequested()
    local current=syncMode()
    if not runFeatureEnabled() then
      runState.toggled=false
      return false
    end
    if current=="toggle" then return runState.toggled==true end
    return Core.inputActions.isDown("RUN")
  end
  local function hasDirectionalInput(input)
    return input and type(input.isDown)=="function" and
      (input:isDown("up") or input:isDown("down") or input:isDown("left") or input:isDown("right"))
  end

  -- Core's input.step wrapper has higher priority and promotes custom action
  -- edges before this link runs. Toggle mode therefore changes state once per
  -- physical press, without ever looking at a physical key/button name here.
  mod.hooks:wrap("input.step",function(next,game,dt)
    local current=syncMode()
    if not runFeatureEnabled() then
      runState.toggled=false
    elseif current=="toggle" and Core.inputActions.wasPressed("RUN") then
      runState.toggled=not runState.toggled
    end
    if fieldMoves then fieldMoves.step(game) end
    return next(game,dt)
  end,80)

  -- Public Gen1Recomp 0.1.75 seam. Player:tryMove passes the player's current
  -- step duration plus onBike/surfing/player/input context. We post-process
  -- downstream speed mods instead of replacing Player:update or global logic
  -- speed. The run duration is the midpoint between the current walking step
  -- and the native bicycle step: stock 16/8 -> 12 frames per tile (1.33x walk,
  -- still slower than the 2x bicycle).
  mod.hooks:wrap("movement.speed",function(next,frames,context)
    local base=tonumber(next(frames,context)) or tonumber(frames) or 16
    context=context or {}
    if not runRequested() then return base end
    if context.onBike or context.surfing then return base end
    local player=context.player
    if player and player.inputLocked then return base end
    if not hasDirectionalInput(context.input) then return base end
    if not runIndoorsEnabled() then
      local ow=Game and Game.overworld
      local okMap,Map=pcall(require,"src.world.Map")
      if okMap and ow and ow.map and ow.map.def and not Map.isOutdoor(ow.map.def) then return base end
    end

    local bike=tonumber(player and player.bikeStepFrames)
    if not bike or bike<=0 then bike=math.max(1,math.floor(base/2)) end
    -- If another movement mod already made walking as fast as the bicycle,
    -- Kanto Run never accelerates past it.
    if base<=bike+1 then return base end
    local run=math.floor((base+bike)/2+.5)
    run=math.max(bike+1,math.min(base-1,run))
    return run
  end,80)

  -- Gen1Recomp 0.1.75 has no public hook around the exact poison-damage
  -- decision. The vanilla logic is deliberately centralized in
  -- OverworldState:applyFieldPoison(), so Gameplay owns one narrow 0.1.75
  -- adapter rather than duplicating onStepComplete/world.stepped.
  --
  -- 0.1.2 tried to protect lethal HP before calling vanilla. Real-runtime
  -- testing showed that path was not reliable. 0.1.3 no longer depends on a
  -- cached game.ready payload and never lets vanilla observe a lethal field
  -- poison result. Non-lethal ticks still delegate to the engine and we only
  -- suppress its poisonFlash presentation afterwards. A tick containing at
  -- least one lethal Pokémon is reproduced locally from the exact v0.1.75
  -- method: same counter/damage/SFX, but HP floors at 1 and PSN is cured.
  local Game=require("src.core.Game")
  local FieldDefaults=require("src.world.FieldDefaults")
  local Sound=require("src.core.Sound")
  local OverworldState=require("src.world.OverworldController")
  local originalApplyFieldPoison=OverworldState.applyFieldPoison
  assert(type(originalApplyFieldPoison)=="function",
    "Gen1Recomp 0.1.76 OverworldState.applyFieldPoison is required")

  local poisonAdapterInstalled=true
  local function clearPoisonFlash(self)
    -- User-facing Kanto rule: retain the Poisoned SFX but no black/dark
    -- overworld flash. Clearing every call also removes a stale frame if an
    -- earlier version/native wrapper armed the effect immediately before us.
    self.poisonFlash=nil
  end

  local function kantoApplyFieldPoison(self,...)
    -- The option is read at the decision point, so APPLY & RESTART and
    -- headless option-profile tests both get an exact vanilla fallback. No
    -- Kanto presentation cleanup is applied while the feature is disabled.
    if not poisonFeatureEnabled() then
      return originalApplyFieldPoison(self,...)
    end

    local save=Game.save
    local data=Game.data
    if not (save and data and type(save.party)=="table") then
      local result=originalApplyFieldPoison(self,...)
      clearPoisonFlash(self)
      return result
    end

    local interval=tonumber(FieldDefaults.world(data,"poisonStepInterval") or 4) or 4
    -- Keep malformed custom configs on the engine path rather than inventing
    -- behavior for an interval the stock modulo expression cannot represent.
    if interval<=0 then
      local result=originalApplyFieldPoison(self,...)
      clearPoisonFlash(self)
      return result
    end
    local damage=tonumber(FieldDefaults.world(data,"poisonDamage") or 1) or 1
    local nextCounter=((save.poisonSteps or 0)+1)%interval

    local lethal=false
    if nextCounter==0 and damage>0 then
      for _,mon in ipairs(save.party) do
        local hp=tonumber(mon.hp) or 0
        if mon.status=="PSN" and hp>0 and hp<=damage then
          lethal=true
          break
        end
      end
    end

    -- No lethal outcome: preserve the exact engine implementation and only
    -- remove its visual poisonFlash. This keeps stock cadence and all
    -- non-lethal damage semantics byte-for-byte downstream of the wrapper.
    if not lethal then
      local result=originalApplyFieldPoison(self,...)
      clearPoisonFlash(self)
      return result
    end

    -- Lethal Kanto tick. This is the smallest local reproduction possible:
    -- only the body of v0.1.75 applyFieldPoison is replaced for this one tick.
    save.poisonSteps=nextCounter -- zero: the configured poison interval fired
    local anyPoisoned=false
    for _,mon in ipairs(save.party) do
      local hp=tonumber(mon.hp) or 0
      if mon.status=="PSN" and hp>0 then
        anyPoisoned=true
        if damage>0 and hp<=damage then
          mon.hp=1
          mon.status=nil
        else
          mon.hp=hp-damage
        end
      end
    end

    clearPoisonFlash(self)
    if anyPoisoned then
      Sound.play(data,"Poisoned")
    end
    -- No faint queue / PSNFNT happiness penalty / blackout is entered.
    return false
  end

  OverworldState.applyFieldPoison=kantoApplyFieldPoison

  do
    local createFieldMoves=loadModule("field_moves.lua")
    fieldMoves=createFieldMoves({
      mod=mod,Core=Core,Game=Game,OverworldState=OverworldState,
    })
  end

  do
    manualFieldMoves=loadModule("manual_field_moves.lua")({mod=mod,Core=Core,Game=Game})
  end

  local function uninstallPoisonAdapter()
    if not poisonAdapterInstalled then return false end
    poisonAdapterInstalled=false
    -- Do not destroy a later mod's wrapper if it chained on top of ours.
    if OverworldState.applyFieldPoison==kantoApplyFieldPoison then
      OverworldState.applyFieldPoison=originalApplyFieldPoison
      return true
    end
    return false
  end

  -- Gen1Recomp 0.1.75 exposes no hook around BagMenu's private target-use
  -- closure. Phase E therefore owns a second narrow, version-bounded adapter:
  -- decorate only Bag-created out-of-battle PartyMenu pickers, then leave the
  -- engine's own ItemEffects/use-flow callbacks untouched. This preserves
  -- medicine animations, move pickers, TM/HM prompts, Rare Candy/evolution
  -- sequences, messages and all compatibility changes already present in the
  -- active BagMenu constructor.
  local BagMenu=require("src.ui.BagMenu")
  local PartyMenu=require("src.ui.PartyMenu")
  local originalBagMenuNew=BagMenu.new
  local originalPartyMenuNew=PartyMenu.new
  local originalPartyMenuUpdate=PartyMenu.update
  assert(type(originalBagMenuNew)=="function",
    "Gen1Recomp 0.1.76 BagMenu.new is required")
  assert(type(originalPartyMenuNew)=="function",
    "Gen1Recomp 0.1.76 PartyMenu.new is required")
  assert(type(originalPartyMenuUpdate)=="function",
    "Gen1Recomp 0.1.76 PartyMenu.update is required")

  local itemUseAdapterInstalled=true
  local function inventoryCount(game,id)
    local inventory=game and game.save and game.save.inventory
    return math.max(0,tonumber(inventory and inventory[id]) or 0)
  end

  local kantoBagMenuNew
  kantoBagMenuNew=function(game,opts)
    opts=opts or {}
    local list=originalBagMenuNew(game,opts)
    if type(list)~="table" then return list end
    list.__kantoItemUseBag=true
    list.__kantoItemUseBattle=opts.battle~=nil

    local choose=list.onChoose
    if type(choose)=="function" then
      list.onChoose=function(item,currentList,...)
        currentList=currentList or list
        if type(item)=="table" and type(item.value)=="string" then
          currentList.__kantoItemUseId=item.value
        end
        return choose(item,currentList,...)
      end
    end
    if bagPockets then
      bagPockets.decorate(game,list,bagPocketsEnabled())
    end
    return list
  end

  local kantoPartyMenuNew
  kantoPartyMenuNew=function(game,opts)
    opts=opts or {}
    local stack=game and game.stack
    local bag=stack and type(stack.top)=="function" and stack:top() or nil
    local itemId=type(bag)=="table" and bag.__kantoItemUseId or nil
    local eligible=itemUseAdapterInstalled and itemUseFlowEnabled()
      and type(bag)=="table" and bag.__kantoItemUseBag==true
      and bag.__kantoItemUseBattle~=true and opts.pickOnly==true
      and type(itemId)=="string"

    if not eligible then return originalPartyMenuNew(game,opts) end

    -- Do not mutate BagMenu's private opts table. keepOpen makes the native
    -- picker remain behind every native item sequence; the instance close
    -- decorator below decides whether quantity/cancel calls may remove it.
    local adapted={}
    for key,value in pairs(opts) do adapted[key]=value end
    adapted.keepOpen=true
    local picker=originalPartyMenuNew(game,adapted)
    if type(picker)~="table" then return picker end

    local baseClose=picker.close
    local baseUpdate=picker.update
    local observedCount=inventoryCount(game,itemId)
    picker.__kantoItemUseFlow=true
    picker.__kantoItemUseId=itemId

    if type(baseClose)=="function" then
      picker.close=function(self)
        -- Native BagMenu calls picker:close() after a message. Keep the
        -- context only while the item still exists; a consumed last unit uses
        -- the untouched native close path and reveals the refreshed Bag.
        if itemUseAdapterInstalled and itemUseFlowEnabled()
          and inventoryCount(game,itemId)>0 then
          return false
        end
        return baseClose(self)
      end
    end

    if type(baseUpdate)=="function" then
      picker.update=function(self,dt)
        local count=inventoryCount(game,itemId)
        if count<observedCount then
          observedCount=count
          self.__kantoItemUseConsumed=true
          self.__kantoItemUseCloseWhenReady=count<=0
        elseif count~=observedCount then
          observedCount=count
        end

        -- Rare Candy, Ether/PP Up, TM/HM and evolution flows do not all call
        -- picker:close(). Once their overlay sequence has returned control to
        -- this picker, close a depleted-item context before it can accept a
        -- stale confirmation. HP medicine is allowed to finish its native bar
        -- animation and message first.
        if self.__kantoItemUseCloseWhenReady and not self.heal
          and stack and stack:top()==self and type(baseClose)=="function" then
          return baseClose(self)
        end
        return baseUpdate(self,dt)
      end
    end
    return picker
  end

  BagMenu.new=kantoBagMenuNew
  PartyMenu.new=kantoPartyMenuNew

  -- A successful HM action selected through the native Pokémon submenu uses
  -- the same textless backend as contextual movement. Refusal messages remain
  -- native (wrong target/current/etc.); successful Cut/Surf/Strength/Flash
  -- never announce the Pokémon or move before executing.
  local PARTY_FIELD_ACTIONS={
    cut="kanto.cut",surf="kanto.surf",strength="kanto.strength",flash="kanto.flash",
  }
  local kantoPartyMenuUpdate
  kantoPartyMenuUpdate=function(self,dt)
    local game=self and self.game
    local input=game and game.input
    if mod.options:get("field_move_mode")~="vanilla" and self.submenu
      and input and type(input.wasPressed)=="function" and input:wasPressed("a") then
      local entry=self.subItems and self.subItems[self.subIndex]
      local actionId=entry and PARTY_FIELD_ACTIONS[entry.action]
      if actionId then
        local context={game=game,overworld=game.overworld,automatic=false,
          source="party_menu"}
        local evaluation=Core.fieldActions.evaluate(actionId,context)
        if evaluation and evaluation.available then
          if game.data then Sound.play(game.data,"Press_AB") end
          self:close()
          local ok=Core.fieldActions.execute(actionId,context)
          if ok then return true end
          -- An intervening mod may invalidate the action between evaluation
          -- and execution. Restore the menu rather than losing the context.
          if game.stack and game.stack:top()~=self then game.stack:push(self) end
        end
      end
    end
    return originalPartyMenuUpdate(self,dt)
  end
  PartyMenu.update=kantoPartyMenuUpdate

  local function uninstallItemUseAdapter()
    if not itemUseAdapterInstalled then return false end
    itemUseAdapterInstalled=false
    local changed=false
    -- Preserve wrappers installed later by other mods instead of tearing down
    -- their chain during a development hot reload.
    if BagMenu.new==kantoBagMenuNew then
      BagMenu.new=originalBagMenuNew
      changed=true
    end
    if PartyMenu.new==kantoPartyMenuNew then
      PartyMenu.new=originalPartyMenuNew
      changed=true
    end
    if PartyMenu.update==kantoPartyMenuUpdate then
      PartyMenu.update=originalPartyMenuUpdate
      changed=true
    end
    return changed
  end

  -- Gen1Recomp centralizes every normal Bag acquisition path in Bag.add.
  -- Keep that API and acquisition order intact while raising its two limits.
  -- The explicit 4096-slot guard is effectively unlimited relative to the
  -- merged Red/Blue/Yellow item catalogs but still rejects corrupt runaway
  -- content. Option-off calls the exact original implementation.
  local Bag=require("src.inventory.Bag")
  local originalBagCapacity=Bag.capacity
  local originalBagAdd=Bag.add
  assert(type(originalBagCapacity)=="function" and type(originalBagAdd)=="function",
    "Gen1Recomp 0.1.75 Bag capacity/add API is required")
  local BAG_SLOT_MAX=4096
  local BAG_STACK_MAX=999
  local bagAdapterInstalled=true

  local function kantoBagCapacity(data)
    if not (bagAdapterInstalled and expandedBagEnabled()) then
      return originalBagCapacity(data)
    end
    return BAG_SLOT_MAX
  end

  local function kantoBagAdd(save,id,qty,data)
    if not (bagAdapterInstalled and expandedBagEnabled()) then
      local wasNew=type(save)=="table" and type(save.inventory)=="table"
        and type(id)=="string" and not save.inventory[id] and not Bag.isBadge(id)
      local added=originalBagAdd(save,id,qty,data)
      if added and wasNew and bagPockets and bagPockets.noteAcquired then
        bagPockets.noteAcquired(id)
      end
      return added
    end
    if type(save)~="table" or type(save.inventory)~="table"
      or type(id)~="string" then return false end
    qty=qty==nil and 1 or tonumber(qty)
    if not qty or qty<=0 or qty~=math.floor(qty) then return false end
    local inv=save.inventory
    local badge=Bag.isBadge(id)
    if not inv[id] and not badge and Bag.slots(save)>=BAG_SLOT_MAX then
      return false
    end
    if not badge and (tonumber(inv[id]) or 0)+qty>BAG_STACK_MAX then
      return false
    end
    local isNew=not inv[id]
    inv[id]=(tonumber(inv[id]) or 0)+qty
    if isNew and not badge then
      table.insert(Bag.order(save),id)
      if bagPockets and bagPockets.noteAcquired then bagPockets.noteAcquired(id) end
    end
    return true
  end

  Bag.capacity=kantoBagCapacity
  Bag.add=kantoBagAdd

  do
    bagPockets=loadModule("bag_pockets.lua")({mod=mod,Game=Game,Bag=Bag,Actions=Core.inputActions})
  end


  do
    storageBoxes=loadModule("storage_boxes.lua")({mod=mod,Core=Core,Game=Game})
    if Game.save and storageBoxes.ensure then storageBoxes.ensure(Game.save) end
  end
  do
    moveMemory=loadModule("move_memory.lua")({mod=mod,Core=Core,Game=Game})
  end
  do
    centerHealBoxes=loadModule("center_heal_boxes.lua")({mod=mod,Core=Core,Game=Game})
  end

  do
    shopIntegration=loadModule("shop_integration.lua")({mod=mod,bagPockets=bagPockets,
      expandedEnabled=expandedBagEnabled,pocketsEnabled=bagPocketsEnabled})
  end

  do
    pcItemIntegration=loadModule("pc_item_integration.lua")({mod=mod,bagPockets=bagPockets,pocketsEnabled=bagPocketsEnabled})
  end

  do
    quickItems=loadModule("quick_items.lua")({mod=mod,Core=Core,Game=Game})
  end

  local function uninstallBagAdapter()
    if not bagAdapterInstalled then return false end
    bagAdapterInstalled=false
    local changed=false
    if Bag.capacity==kantoBagCapacity then
      Bag.capacity=originalBagCapacity
      changed=true
    end
    if Bag.add==kantoBagAdd then
      Bag.add=originalBagAdd
      changed=true
    end
    return changed
  end

  mod.exports.version=EXPORT_API
  mod.exports.release=RELEASE
  mod.exports.capabilities=function()
    return {
      architecture=true,run=true,
      runEnabled=unregisterRun~=nil and runFeatureEnabled(),
      runMode=syncMode(),runActive=runRequested(),
      automaticFieldMoves=fieldMoves and fieldMoves.status().automatic or false,
      manualFieldMoves=manualFieldMoves~=nil,fieldMoveMode=fieldMoves and fieldMoves.status().mode or "vanilla",
      lawnMower=fieldMoves and fieldMoves.status().lawnMower or false,
      poisonRule=true,
      poisonRuleEnabled=poisonAdapterInstalled and poisonFeatureEnabled(),
      itemUseFlow=true,
      itemUseFlowEnabled=itemUseAdapterInstalled and itemUseFlowEnabled(),
      expandedBag=true,
      expandedBagEnabled=bagAdapterInstalled and expandedBagEnabled(),
      bagPockets=true,
      bagPocketsEnabled=bagPockets~=nil and bagPocketsEnabled(),
      storageBoxes=storageBoxes and storageBoxes.status(Game.save) or nil,
      centerHealBoxes=centerHealBoxes and centerHealBoxes.status() or nil,
      shopIntegration=shopIntegration and shopIntegration.status() or nil,
      playerPcIntegration=pcItemIntegration and pcItemIntegration.status() or nil,
      registeredItems=quickItems and quickItems.status() or nil,
      inputAction="RUN",inputActions={"RUN","BAG_SORT","BAG_FAVORITE","BAG_REGISTER"},
    }
  end
  mod.exports.inputActions=function() return {"RUN","BAG_SORT","BAG_FAVORITE","BAG_REGISTER"} end
  mod.exports.runStatus=function()
    local registered=unregisterRun~=nil
    return {registered=registered,enabled=registered and runFeatureEnabled(),
      mode=syncMode(),active=registered and runRequested() or false,
      indoors=runIndoorsEnabled(),toggled=runState.toggled==true,
      stockRatio={walkFrames=16,runFrames=12,bikeFrames=8}}
  end
  mod.exports.poisonRuleStatus=function()
    local enabled=poisonAdapterInstalled and poisonFeatureEnabled()
    return {installed=poisonAdapterInstalled,enabled=enabled,
      vanillaFallback=not enabled,lethalFloorHp=enabled and 1 or 0,
      curesPoison=enabled,battlePoisonChanged=false,
      visualFlash=not enabled,sound=true,
      adapter="OverworldState.applyFieldPoison"}
  end
  mod.exports.itemUseFlowStatus=function()
    local enabled=itemUseAdapterInstalled and itemUseFlowEnabled()
    return {installed=itemUseAdapterInstalled,enabled=enabled,
      vanillaFallback=not enabled,context="out_of_battle_party_target",
      repeatWhileRemaining=enabled,lastUnitReturns=true,
      cancelReturnsToBag=true,battleChanged=false,
      adapter="BagMenu.new + PartyMenu.new/update"}
  end
  mod.exports.expandedBagStatus=function()
    local enabled=bagAdapterInstalled and expandedBagEnabled()
    return {installed=bagAdapterInstalled,enabled=enabled,
      vanillaFallback=not enabled,slotLimit=enabled and BAG_SLOT_MAX or 20,
      stackLimit=enabled and BAG_STACK_MAX or 99,
      adapter="Bag.capacity + Bag.add"}
  end
  mod.exports.bagPocketsStatus=function()
    if not bagPockets then return {installed=false,enabled=false} end
    return bagPockets.status(Game,bagPocketsEnabled())
  end
  mod.exports.itemPocket=function(itemId,definition)
    return bagPockets and bagPockets.classify(itemId,definition)
      or "other_items"
  end
  mod.exports.bagPocketCatalog=function(includeEmpty)
    return bagPockets and bagPockets.catalog(Game,includeEmpty==true) or {}
  end
  mod.exports.setBagSortMode=function(mode)
    return bagPockets and bagPockets.setSortMode(mode) or false
  end
  mod.exports.toggleBagFavorite=function(itemId)
    return bagPockets and bagPockets.toggleFavorite(itemId) or false
  end
  mod.exports.isBagFavorite=function(itemId)
    return bagPockets and bagPockets.isFavorite(itemId) or false
  end
  mod.exports.storageStatus=function() return storageBoxes and storageBoxes.status(Game.save) or {installed=false} end
  mod.exports.moveMemoryStatus=function() return moveMemory and moveMemory.status() or {installed=false} end
  mod.exports.centerHealStatus=function() return centerHealBoxes and centerHealBoxes.status() or {installed=false} end
  mod.exports.shopIntegrationStatus=function() return shopIntegration and shopIntegration.status() or {installed=false} end
  mod.exports.playerPcIntegrationStatus=function() return pcItemIntegration and pcItemIntegration.status() or {installed=false} end
  mod.exports.registeredItems={
    assign=function(slot,itemId) return quickItems and quickItems.assign(slot,itemId) or false end,
    clear=function(slot) return quickItems and quickItems.clear(slot) or false end,
    item=function(slot) return quickItems and quickItems.item(slot) or nil end,
    list=function() return quickItems and quickItems.list() or {} end,
    use=function(slot) return quickItems and quickItems.use(slot,Game) or false end,
    status=function() return quickItems and quickItems.status() or {installed=false} end,
  }
  mod.exports.fieldMoveStatus=function()
    local st=fieldMoves and fieldMoves.status() or {installed=false,mode="vanilla"}
    st.manual=manualFieldMoves and manualFieldMoves.status() or nil
    return st
  end
  mod.exports.unregisterArchitecture=function()
    local changed=uninstallPoisonAdapter()
    changed=uninstallItemUseAdapter() or changed
    changed=uninstallBagAdapter() or changed
    if fieldMoves then changed=fieldMoves.unregister() or changed end
    if manualFieldMoves and manualFieldMoves.unregister then manualFieldMoves.unregister();changed=true end
    if pcItemIntegration and pcItemIntegration.uninstall then pcItemIntegration.uninstall();changed=true end
    if quickItems and quickItems.unregister then quickItems.unregister();changed=true end
    if moveMemory and moveMemory.uninstall then moveMemory.uninstall();changed=true end
    if centerHealBoxes and centerHealBoxes.uninstall then changed=centerHealBoxes.uninstall() or changed end
    if unregisterRun then
      local ok=unregisterRun()
      unregisterRun=nil
      changed=ok or changed
    end
    if unregisterBagSort then
      local ok=unregisterBagSort();unregisterBagSort=nil;changed=ok or changed
    end
    if unregisterBagFavorite then
      local ok=unregisterBagFavorite();unregisterBagFavorite=nil;changed=ok or changed
    end
    if unregisterBagRegister then
      local ok=unregisterBagRegister();unregisterBagRegister=nil;changed=ok or changed
    end
    if unregisterExpSummary then
      local ok=unregisterExpSummary();unregisterExpSummary=nil;changed=ok or changed
    end
    if unregisterLowHealthAlarm then
      local ok=unregisterLowHealthAlarm();unregisterLowHealthAlarm=nil;changed=ok or changed
    end
    if unregisterBagProvider then
      local ok=unregisterBagProvider();unregisterBagProvider=nil;changed=ok or changed
    end
    if unregisterFieldProvider then
      local ok=unregisterFieldProvider();unregisterFieldProvider=nil;changed=ok or changed
    end
    return changed
  end

  mod.log:info("Kanto Rework Gameplay %s loaded with cooperative capability declarations",RELEASE)
end
