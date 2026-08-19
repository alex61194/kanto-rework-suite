local RELEASE = "0.1.44"
local EXPORT_API = 40

return function(mod)
  -- Gen1Recomp 0.1.84+ runs every mod inside an isolated sandbox.  Mod-owned
  -- source is read through the public facade and compiled by the sandboxed
  -- load(), which keeps all secondary chunks in this mod's environment.
  local function loadModule(relative)
    local source,readErr=mod:read(relative)
    assert(type(source)=="string",readErr or ("Unable to read "..tostring(relative)))
    local chunk,err=load(source,"@"..mod.id.."/"..relative)
    assert(chunk,err or ("Unable to compile "..tostring(relative)))
    return chunk()
  end

  local Layout=loadModule("core/layout.lua")
  local createProfileStore=loadModule("core/profile.lua")
  local createPointer=loadModule("core/pointer.lua")
  local createGamePalette=loadModule("core/game_palette.lua")
  local createModManager=loadModule("core/mod_manager.lua")
  local createFoundation=loadModule("core/foundation.lua")
  local createTextInput=loadModule("core/text_input.lua")
  local createGameSave=loadModule("core/game_save.lua")
  local createMapInteraction=loadModule("core/map_interaction.lua")
  local createMoveDescriptions=loadModule("core/move_descriptions.lua")
  local createMoveLibrary=loadModule("core/move_library.lua")
  local createVideoMode=loadModule("core/video_mode.lua")
  local createInputDevice=loadModule("core/input_device.lua")
  local createInputMode=loadModule("core/input_mode.lua")
  local createInputActions=loadModule("core/input_action_registry.lua")
  local createFieldActions=loadModule("core/field_action_registry.lua")
  local createNotifications=loadModule("core/notifications.lua")
  local createInferredMoves=loadModule("core/inferred_moves.lua")
  local createTrainerData=loadModule("core/trainer_data.lua")
  local createStartMenuRuntime=loadModule("core/start_menu_runtime.lua")
  local createOptionsRuntime=loadModule("core/options_runtime.lua")
  local createJournalContext=loadModule("core/journal_context.lua")
  local createCapabilityRegistry=loadModule("core/capability_registry.lua")
  local createModIntegrations=loadModule("core/mod_integration_registry.lua")
  local createRestartResume=loadModule("core/restart_resume.lua")
  local createSaveSlots=loadModule("core/save_slots.lua")
  local createTypography=loadModule("core/typography.lua")
  local createElevation=loadModule("core/elevation.lua")
  local createGraphicsRegistry=loadModule("core/graphics_registry.lua")

  -- The visual-theme option was deliberately removed. Core exposes functional
  -- options as data; product UIs decide how to present them.
  mod.options:define({
    {key="accessibility",label="COLOR ACCESSIBILITY",type="choice",default="standard",
      choices={{"STANDARD","standard"},{"PROTANOPIA","protanopia"},{"DEUTERANOPIA","deuteranopia"},{"TRITANOPIA","tritanopia"}},
      description="Apply a full-frame color-accessibility correction to every display mode, tileset, trueColor asset, battle background and UI layer."},
  })

  -- Private runtime state. Cross-mod communication is published explicitly
  -- through mod.exports/mod.find; private _G tables are no longer shared by
  -- Gen1Recomp's sandbox.
  local global={original={}}
  global.global=global;global.mod=mod;global.release=RELEASE
  if not global.lastInput then
    local okPlatform,Platform=pcall(require,"src.core.Platform")
    local detected=okPlatform and Platform and Platform.detect and Platform.detect() or {}
    global.lastInput=(detected.mobile==true) and "touch" or "keyboard"
  end
  global.viewport=global.viewport or {width=1920,height=1080}
  global.pointerSessions=global.pointerSessions or {};global.handlers=global.handlers or {}
  global.presenterReady=false;global.presenterError=nil;global.startMenu=nil
  global.contextMode=false;global.editMode=false;global.drag=nil;global.partyDrag=nil
  global.overlayRegions=global.overlayRegions or {};global.focusedOverlay=global.focusedOverlay or "encounters"
  local OVERLAY_IDS={"encounters","capture"}

  local foundation=createFoundation({runtime=global,release=RELEASE});global.foundation=foundation
  local capabilityRegistry=createCapabilityRegistry({runtime=global,release=RELEASE});global.capabilityRegistry=capabilityRegistry
  local modIntegrations=createModIntegrations();global.modIntegrations=modIntegrations
  local restartResume=createRestartResume({runtime=global,mod=mod});global.restartResumeService=restartResume
  local saveSlots=createSaveSlots({runtime=global});global.saveSlotsService=saveSlots
  local typography=createTypography({runtime=global});global.typography=typography
  local elevation=createElevation();global.elevation=elevation
  local graphicsRegistry=createGraphicsRegistry();global.graphicsRegistry=graphicsRegistry
  capabilityRegistry.define({
    id="compatibility.registry",label="COMPATIBILITY REGISTRY",mode="additive",
    description="Cooperative provider selection, policy evaluation and diagnostics.",
  })
  capabilityRegistry.define({id="ui.shell",label="FULL UI SHELL",mode="exclusive"})
  capabilityRegistry.define({id="ui.party",label="PARTY UI",mode="exclusive"})
  capabilityRegistry.define({id="bag.organization",label="BAG ORGANIZATION",mode="exclusive"})
  capabilityRegistry.define({id="field.actions",label="FIELD ACTIONS",mode="exclusive"})
  capabilityRegistry.define({id="move.relearn",label="MOVE RELEARNING",mode="exclusive"})
  capabilityRegistry.define({id="battle.exp",label="BATTLE EXPERIENCE PIPELINE",mode="middleware"})
  capabilityRegistry.define({id="battle.camera",label="BATTLE CAMERA",mode="exclusive"})
  capabilityRegistry.define({id="pokemon.menu_icon",label="PARTY MENU ICONS",mode="exclusive"})
  capabilityRegistry.define({id="audio.music",label="MUSIC PROVIDERS",mode="exclusive"})
  capabilityRegistry.registerProvider({
    id="kanto_rework_core.compatibility",capability="compatibility.registry",
    source=mod.id,modId=mod.id,label="Kanto Rework Core",priority=120,
  })
  local neutralPresenter={
    isSupportedStartMenu=function() return false,nil,"core does not replace the native Start Menu" end,
    hitTest=function() return nil end,
    topState=function(game) local stack=game and game.stack;return stack and type(stack.top)=="function" and stack:top() or nil end,
  }
  global.presenter=neutralPresenter

  local profileStore=createProfileStore({
    allowedThemes={neutral=true},defaults={
      theme="neutral",overlayVisible=false,widgetLocked=true,
      encountersX=.66,encountersY=.04,captureX=.69,captureY=.42,
      encountersWidth=1,encountersHeight=1,encountersMode="overworld",
      encountersCollapsed=false,encountersTabEdge="",encountersTabPosition=.5,
      captureWidth=1,captureHeight=1,captureMode="battle",
      captureCollapsed=false,captureTabEdge="",captureTabPosition=.5,
    },
    read=function()
      local game=global.game
      if not game then return nil end
      local value=mod.storage:read(game,"overlay_profile")
      return type(value)=="table" and value or nil
    end,
    write=function(value)
      local game=global.game
      if not game then return false,"playthrough unavailable" end
      local ok,code,message=mod.storage:write(game,"overlay_profile",value)
      return ok==true,ok==true and nil or (message or code)
    end,
  })
  local profile,notice=profileStore.load();profile.theme="neutral"
  -- Established session behavior: the overlay starts hidden and locked.
  profile.overlayVisible=false;profile.widgetLocked=true;global.profile=profile
  do
    local known=false;for _,id in ipairs(OVERLAY_IDS) do if global.focusedOverlay==id then known=true break end end
    if not known then global.focusedOverlay="encounters" end
  end
  if notice then mod.log:warn("profile: %s",tostring(notice)) end
  local function persist() local ok,err=profileStore.save(global.profile);if not ok then mod.log:warn("profile save failed: %s",tostring(err)) end;return ok end

  local gamePalette
  local function syncOptions()
    local value=mod.options:get("accessibility") or "standard"
    if gamePalette then gamePalette.set(value,{persist=false}) else global.accessibility=value end
  end
  syncOptions();gamePalette=createGamePalette({mod=mod,runtime=global});global.gamePalette=gamePalette

  local modManager=createModManager({mod=mod,runtime=global,release=RELEASE,compatibility=capabilityRegistry,integrations=modIntegrations,restartResume=restartResume});global.modManager=modManager
  local managerInstalled,managerError=modManager.install();if not managerInstalled then mod.log:warn("mod manager adapter deferred: %s",tostring(managerError)) end

  local inputDevice=createInputDevice({runtime=global});global.inputDevice=inputDevice
  local inputMode=createInputMode({runtime=global,inputDevice=inputDevice});global.inputMode=inputMode
  inputDevice.install();inputMode.install()
  local textInput=createTextInput({mod=mod,runtime=global,inputDevice=inputDevice});global.textInput=textInput
  local textInstalled,textError=textInput.install();if not textInstalled then mod.log:warn("text input adapter deferred: %s",tostring(textError)) end
  local gameSave=createGameSave({runtime=global,presenter=neutralPresenter});global.gameSave=gameSave
  local mapInteraction=createMapInteraction({runtime=global,foundation=foundation,devFlyUnlocked=function()
    local handle=mod.find("dev_tools")
    local exports=handle and handle.exports
    return exports and type(exports.flyUnlocked)=="function" and exports.flyUnlocked()==true
  end});global.mapInteraction=mapInteraction
  local moveDescriptions=createMoveDescriptions({mod=mod,runtime=global});global.moveDescriptions=moveDescriptions
  local moveLibrary=createMoveLibrary({mod=mod,runtime=global});global.moveLibrary=moveLibrary
  local videoMode=createVideoMode({mod=mod,runtime=global});global.videoModeService=videoMode
  local videoModeInstalled,videoModeError=videoMode.install();if not videoModeInstalled then mod.log:warn("video mode extension deferred: %s",tostring(videoModeError)) end
  local inputActions=createInputActions({mod=mod,runtime=global,inputDevice=inputDevice});global.inputActions=inputActions
  local unregisterAccessibilityCycle=inputActions.register({
    id="COLOR_ACCESSIBILITY_CYCLE",label="CYCLE COLOR ACCESSIBILITY",source=mod.id,
    group="KANTO REWORK ACCESSIBILITY",
    description="Cycle Standard, Protanopia, Deuteranopia and Tritanopia while the game is running.",
    defaults={key="f7",pad="rightstick"},priority=120,
  })
  local fieldActions=createFieldActions({runtime=global});global.fieldActions=fieldActions
  local notifications=createNotifications({mod=mod,runtime=global});global.notifications=notifications
  local inferredMoves=createInferredMoves({runtime=global});global.inferredMoves=inferredMoves
  local trainerData=createTrainerData({runtime=global});global.trainerData=trainerData
  local startMenuRuntime=createStartMenuRuntime({runtime=global,trainer=trainerData,integrations=modIntegrations});global.startMenuRuntime=startMenuRuntime
  local optionsRuntime=createOptionsRuntime({runtime=global,videoMode=videoMode});global.optionsRuntime=optionsRuntime
  local journalContext=createJournalContext({runtime=global});global.journalContext=journalContext

  local pointer=createPointer({mod=mod,runtime=global,presenter=neutralPresenter,Layout=Layout,persist=persist,mapInteraction=mapInteraction,foundation=foundation,loadModule=loadModule})
  global.pointer=pointer

  local function toggleOverlayVisibility()
    global.profile.overlayVisible=not global.profile.overlayVisible
    if not global.profile.overlayVisible then
      global.contextMode=false;global.editMode=false;global.profile.widgetLocked=true
      global.drag=nil;global.overlayRegions={}
    end
    return true
  end
  local function toggleOverlayContext()
    local game=global.game;local top=game and game.stack and game.stack.top and game.stack:top()
    local context=game and (top==game.overworld or (type(top)=="table" and
      (top.kind=="overlay_context" or top.kind=="overlay_layout" or top.kind=="overlay_editor" or top.kind=="wild" or top.kind=="trainer" or top.kind=="link")))
    if not global.profile.overlayVisible or not context then return false end
    global.contextMode=not global.contextMode
    -- Kept only as a compatibility mirror for consumers of API 25 and older.
    -- Layout manipulation no longer depends on this legacy edit/lock state.
    global.editMode=global.contextMode;global.profile.widgetLocked=true
    if global.contextMode then global.drag=nil end
    return true
  end

  -- Raw physical input now arrives through Core's Game-method bridge.  This
  -- preserves custom F-keys without assigning love.keypressed, which the
  -- Gen1Recomp 0.1.86 sandbox explicitly forbids.
  local unregisterCorePhysical=inputDevice.onPhysical("kanto_rework_core.keys",function(ev)
    if not (type(ev)=="table" and ev.kind=="keyboard" and ev.phase=="pressed") then return false end
    local keyName,scancode,isrepeat=ev.code,ev.scancode,ev.isrepeat==true
    if textInput and textInput.keypressed and textInput.keypressed(keyName,scancode,isrepeat) then return true end
    local consumed=foundation.dispatchKeypressed(global.game,keyName,scancode,isrepeat);if consumed==true then return true end
    if isrepeat then return false end
    if keyName=="f8" then return toggleOverlayVisibility() end
    if keyName=="f9" then return toggleOverlayContext() end
    if keyName=="escape" and global.contextMode then
      global.contextMode=false;global.editMode=false;global.profile.widgetLocked=true;global.drag=nil;return true
    end
    return false
  end)
  global.keyBridgeInstalled=true

  for i,id in ipairs(OVERLAY_IDS) do
    foundation.registerOverlay({id="widget."..id,priority=100-i,defaultVisible=true,draggable=true,collapsible=true,lockable=true,persistentPosition=true,layer=20+i,visible=function() return global.profile.overlayVisible==true end})
  end
  foundation.registerAction({id="overlay.toggle",priority=100,run=toggleOverlayVisibility})
  foundation.registerAction({id="overlay.context_toggle",priority=100,run=toggleOverlayContext})
  foundation.registerAction({id="overlay.lock_toggle",priority=10,run=toggleOverlayContext})
  foundation.registerAction({id="game.save",priority=100,run=function(opts) return gameSave.request(global.game,opts) end})
  foundation.registerScreen({id="native.party",priority=10,match=function() return global.nativePointer and global.nativePointer.kind()=="party" end})
  foundation.registerScreen({id="native.town_map",priority=10,match=function() return global.nativePointer and global.nativePointer.kind()=="town_map" end})

  local function restoreProfileForCurrentPlaythrough()
    if not (profileStore and global.game) then return false end
    local restored,restoreNotice=profileStore.load()
    if type(restored)=="table" then
      restored.theme="neutral";restored.overlayVisible=false;restored.widgetLocked=true
      global.profile=restored
    end
    if restoreNotice then mod.log:warn("profile: %s",tostring(restoreNotice)) end
    return type(restored)=="table"
  end

  mod.events:on("game.ready",function(payload)
    global.game=payload and payload.game or global.game
    restoreProfileForCurrentPlaythrough()
    if modManager then modManager.install() end;if textInput then textInput.install() end
    if videoMode then videoMode.install();videoMode.reconcile(global.game) end
    if inputDevice then inputDevice.install() end
    if inputMode then inputMode.install() end
    if inputActions then inputActions.attachGame(global.game);inputActions.install() end
    if gamePalette then gamePalette.attachGame(global.game) end
    if moveLibrary then moveLibrary.observeParty(global.game) end
  end)
  -- Continue/new-game replaces the title-session save after game.ready.
  -- Reload the namespaced storage profile at that boundary so overlay layout
  -- follows the selected playthrough rather than the temporary title skeleton.
  mod.events:on("save.loaded",function() restoreProfileForCurrentPlaythrough() end)
  mod.events:on("save.created",function()
    if global.game then restoreProfileForCurrentPlaythrough() end
  end)

  mod.events:on("input.focus",function(payload)
    if inputMode then inputMode.focus(not payload or payload.focused~=false) end
  end)
  mod.events:on("mod.options_changed",function(payload)
    if payload and payload.mod==mod.id then syncOptions() end
  end)

  mod.events:on("pokemon.move_learned",function(payload)
    if moveLibrary and payload and payload.mon and payload.moveId then
      moveLibrary.recordConfirmed(global.game,payload.mon,payload.moveId,"pokemon.move_learned")
    end
  end)

  mod.hooks:wrap("input.step",function(next,game,dt)
    global.game=game
    if restartResume then restartResume.step(game) end
    if inputDevice and type(inputDevice.step)=='function' then inputDevice.step() end
    if inputActions then inputActions.attachGame(game);inputActions.step() end
    if gamePalette then
      gamePalette.syncFromPipeline()
      if inputActions and inputActions.wasPressed("COLOR_ACCESSIBILITY_CYCLE") then
        local value=gamePalette.cycle(1)
        if notifications then notifications.emit({
          id="color_accessibility",source=mod.id,kind="info",priority=100,
          replaceKey="color_accessibility",duration=2.5,
          message="COLOR ACCESSIBILITY · "..tostring(value):upper(),
          data={profile=value},
        }) end
      end
    end
    if moveLibrary then moveLibrary.observeParty(game) end
    local state=neutralPresenter.topState(game)
    if mapInteraction and mapInteraction.isTownMap(state) then pcall(mapInteraction.registerModelHotspots,game,state) end
    return next(game,dt)
  end,120)
  mod.hooks:wrap("render.hud",function(next,game,viewport)
    global.game=game
    if type(viewport)=="table" then
      local copy={} for k,v in pairs(viewport) do copy[k]=v end
      global.viewport=copy
    end
    if gamePalette and gamePalette.drawFiltered then
      return gamePalette.drawFiltered(next,game,viewport)
    end
    return next(game,viewport)
  end,1000)
  mod.hooks:wrap("render.zones",function(next,game,zones) global.game=game;return next(game,zones) end,120)

  -- Deliberately no product-presentation hooks: Core only exposes shared state
  -- and runtime services. UI modules consume the exports below.

  mod.exports.version=EXPORT_API;mod.exports.release=RELEASE
  mod.exports.layoutClass=function(width,height) return Layout.classify(width,height) end
  mod.exports.profile=function()
    local p=global.profile
    return {accessibility=global.accessibility,overlayVisible=p.overlayVisible==true,
      contextMode=global.contextMode==true,editMode=global.contextMode==true,widgetLocked=true,
      encountersX=p.encountersX,encountersY=p.encountersY,
      encountersWidth=p.encountersWidth,encountersHeight=p.encountersHeight,encountersMode=p.encountersMode,
      encountersCollapsed=p.encountersCollapsed==true,encountersTabEdge=p.encountersTabEdge,encountersTabPosition=p.encountersTabPosition,
      captureX=p.captureX,captureY=p.captureY,
      captureWidth=p.captureWidth,captureHeight=p.captureHeight,captureMode=p.captureMode,
      captureCollapsed=p.captureCollapsed==true,captureTabEdge=p.captureTabEdge,captureTabPosition=p.captureTabPosition}
  end
  mod.exports.capabilities=foundation.capabilities
  mod.exports.compatibility={
    define=capabilityRegistry.define,
    registerProvider=capabilityRegistry.registerProvider,
    registerPolicy=capabilityRegistry.registerPolicy,
    registerDiagnostic=capabilityRegistry.registerDiagnostic,
    definition=capabilityRegistry.definition,
    providers=capabilityRegistry.providers,
    providersForMod=capabilityRegistry.providersForMod,
    resolve=capabilityRegistry.resolve,
    setPreference=capabilityRegistry.setPreference,
    evaluateMod=capabilityRegistry.evaluateMod,
    canEnable=capabilityRegistry.canEnable,
    issues=capabilityRegistry.issues,
    scan=capabilityRegistry.scan,
    status=capabilityRegistry.status,
  }
  mod.exports.registerScreen=foundation.registerScreen;mod.exports.registerOverlay=foundation.registerOverlay
  mod.exports.registerAction=foundation.registerAction;mod.exports.runAction=foundation.runAction
  mod.exports.registerMapHotspot=foundation.registerMapHotspot;mod.exports.registerInputLayer=foundation.registerInputLayer
  -- Public physical-pointer ingress for compatibility adapters whose owning
  -- third-party camera legitimately captures LOVE callbacks. Feeding the
  -- complete Core pointer service (rather than Game methods) preserves input
  -- mode promotion, press/release ownership, overlays, KRS input layers and
  -- the untouched native fallback in exactly the same order as input.pointer.
  mod.exports.dispatchPointerEvent=function(game,event)
    if not (pointer and type(pointer.handle)=="function") then return false end
    return pointer.handle(game or global.game,event)
  end
  mod.exports.setFocus=foundation.setFocus;mod.exports.getFocus=foundation.getFocus;mod.exports.clearFocus=foundation.clearFocus
  mod.exports.beginDrag=foundation.beginDrag;mod.exports.dragState=foundation.dragState;mod.exports.endDrag=foundation.endDrag
  mod.exports.foundationSnapshot=foundation.snapshot
  mod.exports.requestGameSave=function(opts) return gameSave.request(global.game,opts) end
  mod.exports.saveSlots={
    list=saveSlots.list,read=saveSlots.read,active=saveSlots.active,
    save=function(id) return saveSlots.save(global.game,id) end,
    load=function(id) return saveSlots.load(global.game,id) end,
    delete=saveSlots.delete,rename=saveSlots.rename,status=saveSlots.status,
  }
  mod.exports.mapModel=function() return mapInteraction.model(global.game,neutralPresenter.topState(global.game)) end
  -- Explicit map-state variants let presentation modules keep the complete
  -- TownMap model separate from Fly eligibility. Fly progression is a
  -- capability of a location, never the source list for the map itself.
  mod.exports.mapModelFor=function(game,state)
    return mapInteraction.model(game or global.game,state)
  end
  mod.exports.mapDestinationFor=function(game,state,index)
    return mapInteraction.destinationFor(game or global.game,state,index)
  end
  mod.exports.mapFlyStatus=function(game) return mapInteraction.flyStatus(game or global.game) end
  mod.exports.activateMapFly=function(game,state,index,ownerState)
    return mapInteraction.activate(game or global.game,state,index,ownerState)
  end
  mod.exports.moveDescription=function(def,id) return moveDescriptions.describe(def,id) end
  mod.exports.moveDescriptionStatus=moveDescriptions.catalogStatus
  mod.exports.knownMoves=function(mon,includeActive) return moveLibrary.moves(global.game,mon,includeActive) end
  mod.exports.confirmedMoves=function(mon,includeActive) return moveLibrary.confirmed(global.game,mon,includeActive) end
  mod.exports.recordConfirmedMove=function(mon,moveId,source) return moveLibrary.recordConfirmed(global.game,mon,moveId,source) end
  mod.exports.rememberKnownMove=function(mon,moveId,pp,ppUps,source) return moveLibrary.remember(global.game,mon,moveId,pp,ppUps,source) end
  mod.exports.inferredRelearnMoves=function(mon) return inferredMoves.moves(global.game,mon) end
  mod.exports.replaceKnownMove=function(mon,activeIndex,moveId) return moveLibrary.replace(global.game,mon,activeIndex,moveId) end
  mod.exports.moveLibraryStatus=function(mon) return moveLibrary.status(global.game,mon) end
  mod.exports.videoModeStatus=function() return videoMode and videoMode.status() or nil end
  mod.exports.videoModeCurrent=function() return videoMode and videoMode.current(global.game) or nil end
  mod.exports.videoModeStep=function(dir) return videoMode and videoMode.step(global.game,dir) or false,"video service unavailable" end
  mod.exports.videoModeReconcile=function() return videoMode and videoMode.reconcile(global.game) or false end
  mod.exports.activeAccessibilityProfile=function() return global.accessibility or "standard" end
  mod.exports.setAccessibilityProfile=function(value) return gamePalette and gamePalette.set(value,{persist=true,emit=true}) or nil end
  mod.exports.cycleAccessibilityProfile=function(dir) return gamePalette and gamePalette.cycle(dir) or nil end
  mod.exports.fullFrameColorAccessibility=function()
    local status=gamePalette and gamePalette.status() or nil
    return status and status.fullFrame==true and status.available==true or false
  end
  mod.exports.activeColorMode=function() local st=gamePalette and gamePalette.status and gamePalette.status() or nil;return st and st.colorsMode or nil end
  mod.exports.inputDeviceStatus=function() return inputDevice and inputDevice.status(global.game) or {kind=global.lastInput or "keyboard"} end
  mod.exports.inputBinding=function(action,kind) return inputDevice and inputDevice.binding(global.game,action,kind) or nil end
  mod.exports.nativeActionPressed=function(action,game)
    game=game or global.game
    local input=game and game.input
    local logical=input and type(input.wasPressed)=='function' and input:wasPressed(action)==true
    local physical=inputDevice and type(inputDevice.wasNativeActionPressed)=='function' and inputDevice.wasNativeActionPressed(game,action)==true
    return logical or physical
  end
  -- Generic logical input actions. Registration belongs to the owning module;
  -- Core stores/resolves bindings and physical state without Kanto gameplay rules.
  mod.exports.inputActions={
    register=inputActions.register,list=inputActions.list,definition=inputActions.definition,
    binding=inputActions.binding,setBinding=inputActions.setBinding,clearBinding=inputActions.clearBinding,
    resetAll=inputActions.resetAll,conflict=inputActions.conflict,
    beginCapture=inputActions.beginCapture,cancelCapture=inputActions.cancelCapture,captureState=inputActions.captureState,
    wasPressed=inputActions.wasPressed,wasReleased=inputActions.wasReleased,isDown=inputActions.isDown,status=inputActions.status,
  }
  mod.exports.typography={
    registerFamily=typography.registerFamily,paths=typography.paths,resolve=typography.resolve,
    font=typography.font,list=typography.list,status=typography.status,
  }
  mod.exports.elevation={shadowSamples=elevation.shadowSamples,cardShadow=elevation.cardShadow}
  mod.exports.fieldActions={
    register=fieldActions.register,list=fieldActions.list,evaluate=fieldActions.evaluate,
    execute=fieldActions.execute,definition=fieldActions.definition,status=fieldActions.status,
  }
  mod.exports.notifications={emit=notifications.emit,subscribe=notifications.subscribe,eventName=notifications.eventName,status=notifications.status}
  mod.exports.inputMode=function(scope) return inputMode and inputMode.snapshot(scope) or nil end
  mod.exports.setActiveInputItem=function(scope,id) return inputMode and inputMode.setActiveItem(scope,id) or nil end
  mod.exports.activeInputItem=function(scope) return inputMode and inputMode.activeItem(scope) or nil end
  mod.exports.setInputNavigation=function(scope,id) return inputMode and inputMode.navigation(scope,id) or nil end
  mod.exports.setInputPointer=function(scope,id) return inputMode and inputMode.pointer(scope,id) or nil end
  mod.exports.trainerModel=function() return trainerData and trainerData.model(global.game) or nil end
  mod.exports.journalContext=function() return journalContext and journalContext.model(global.game) or {location="KANTO",playTime=0} end
  mod.exports.overlayState=function()
    local p=global.profile or {}
    local widgets={}
    for _,id in ipairs(OVERLAY_IDS) do
      local width=tonumber(p[id.."Width"]) or tonumber(p[id.."Scale"]) or 1
      local height=tonumber(p[id.."Height"]) or tonumber(p[id.."Scale"]) or 1
      widgets[id]={x=tonumber(p[id.."X"]) or 0,y=tonumber(p[id.."Y"]) or 0,
        width=width,height=height,scale=math.sqrt(width*height),mode=p[id.."Mode"] or "none",
        collapsed=p[id.."Collapsed"]==true,tabEdge=p[id.."TabEdge"] or "",
        tabPosition=tonumber(p[id.."TabPosition"]) or .5}
    end
    return {visible=p.overlayVisible==true,contextMode=global.contextMode==true,
      editMode=global.contextMode==true,locked=true,
      focused=global.focusedOverlay or "encounters",order=OVERLAY_IDS,widgets=widgets}
  end
  mod.exports.setOverlayRegion=function(id,region)
    if type(id)~="string" then return false end
    if region==nil then global.overlayRegions[id]=nil;return true end
    if type(region)~="table" then return false end
    local modeRects={}
    for _,rect in ipairs(region.modeRects or {}) do
      if type(rect)=="table" then modeRects[#modeRects+1]={x=tonumber(rect.x) or 0,y=tonumber(rect.y) or 0,w=math.max(0,tonumber(rect.w) or 0),h=math.max(0,tonumber(rect.h) or 0),mode=rect.mode} end
    end
    local collapseRect=region.collapseRect
    if type(collapseRect)=="table" then collapseRect={x=tonumber(collapseRect.x) or 0,y=tonumber(collapseRect.y) or 0,w=math.max(0,tonumber(collapseRect.w) or 0),h=math.max(0,tonumber(collapseRect.h) or 0)} else collapseRect=nil end
    global.overlayRegions[id]={id=id,kind="overlay",x=tonumber(region.x) or 0,y=tonumber(region.y) or 0,w=math.max(0,tonumber(region.w) or 0),h=math.max(0,tonumber(region.h) or 0),headerH=math.max(0,tonumber(region.headerH) or 0),resizeSize=math.max(0,tonumber(region.resizeSize) or 0),widthScale=tonumber(region.widthScale) or 1,heightScale=tonumber(region.heightScale) or 1,widthUnit=tonumber(region.widthUnit) or 1,heightUnit=tonumber(region.heightUnit) or 1,minScale=tonumber(region.minScale) or .6,maxScale=tonumber(region.maxScale) or 1.6,modeRects=modeRects,collapseRect=collapseRect,collapsed=region.collapsed==true,edge=region.edge,order=tonumber(region.order) or 0}
    return true
  end
  mod.exports.setOverlayFocus=function(id)
    for _,known in ipairs(OVERLAY_IDS) do if id==known then global.focusedOverlay=id;return true end end
    return false
  end
  mod.exports.visibleOverlayIds=function()
    local entries={}
    for id,region in pairs(global.overlayRegions or {}) do
      entries[#entries+1]={id=id,order=tonumber(region and region.order) or 0}
    end
    table.sort(entries,function(a,b) return a.order<b.order end)
    local out={} for _,entry in ipairs(entries) do out[#out+1]=entry.id end
    return out
  end
  mod.exports.setOverlayPosition=function(id,x,y,save)
    local known=false;for _,value in ipairs(OVERLAY_IDS) do if value==id then known=true break end end
    if not known then return false end
    local nx,ny=math.max(0,math.min(1,tonumber(x) or 0)),math.max(0,math.min(1,tonumber(y) or 0))
    global.profile[id.."X"],global.profile[id.."Y"]=nx,ny
    if save~=false then persist() end
    return true
  end
  mod.exports.moveOverlay=function(id,dx,dy)
    local st=mod.exports.overlayState();local w=st.widgets[id];if not w then return false end
    global.focusedOverlay=id
    if w.collapsed then
      local edge=w.tabEdge;local region=global.overlayRegions[id]
      if edge~="left" and edge~="right" and edge~="top" and edge~="bottom" then
        edge=region and region.edge or "left"
      end
      local position=w.tabPosition
      if region and (w.tabEdge==nil or w.tabEdge=="") then
        local safe=Layout.safeArea(global.viewport)
        if edge=="left" or edge=="right" then
          position=(region.y-safe.y)/math.max(1,safe.h-region.h)
        else
          position=(region.x-safe.x)/math.max(1,safe.w-region.w)
        end
      end
      dx,dy=tonumber(dx) or 0,tonumber(dy) or 0
      if edge=="left" or edge=="right" then
        if dx<0 then edge="left" elseif dx>0 then edge="right" end
        position=position+dy
      else
        if dy<0 then edge="top" elseif dy>0 then edge="bottom" end
        position=position+dx
      end
      return mod.exports.setOverlayTabPlacement(id,edge,position,true)
    end
    return mod.exports.setOverlayPosition(id,w.x+(tonumber(dx) or 0),w.y+(tonumber(dy) or 0),true)
  end
  mod.exports.setOverlayTabPlacement=function(id,edge,position,save)
    local known=false;for _,candidate in ipairs(OVERLAY_IDS) do if candidate==id then known=true break end end
    local valid=edge=="left" or edge=="right" or edge=="top" or edge=="bottom"
    if not known or not valid then return false end
    global.profile[id.."TabEdge"]=edge
    global.profile[id.."TabPosition"]=math.max(0,math.min(1,tonumber(position) or .5))
    global.focusedOverlay=id
    if save~=false then persist() end
    return true
  end
  mod.exports.setOverlaySize=function(id,width,height,save)
    local known=false;for _,candidate in ipairs(OVERLAY_IDS) do if candidate==id then known=true break end end
    if not known then return false end
    global.profile[id.."Width"]=math.max(.6,math.min(1.6,tonumber(width) or 1))
    global.profile[id.."Height"]=math.max(.6,math.min(1.6,tonumber(height) or 1))
    if save~=false then persist() end
    return true
  end
  mod.exports.setOverlayScale=function(id,value,save) return mod.exports.setOverlaySize(id,value,value,save) end
  mod.exports.setOverlayCollapsed=function(id,value,save)
    local known=false;for _,candidate in ipairs(OVERLAY_IDS) do if candidate==id then known=true break end end
    if not known or type(value)~="boolean" then return false end
    global.profile[id.."Collapsed"]=value;global.focusedOverlay=id
    if save~=false then persist() end
    return true
  end
  mod.exports.toggleFocusedOverlayCollapsed=function(save)
    if not(global.profile and global.profile.overlayVisible==true) then return false,"overlays_hidden" end
    local id=global.focusedOverlay;local region=id and global.overlayRegions[id] or nil
    if not region then
      local bestOrder=-math.huge
      for candidate,candidateRegion in pairs(global.overlayRegions or {}) do
        local order=tonumber(candidateRegion and candidateRegion.order) or 0
        if order>bestOrder then id,region,bestOrder=candidate,candidateRegion,order end
      end
    end
    if not(id and region) then return false,"no_visible_overlay" end
    return mod.exports.setOverlayCollapsed(id,not(global.profile[id.."Collapsed"]==true),save)
  end
  mod.exports.setOverlayMode=function(id,value,save)
    local known=false;for _,candidate in ipairs(OVERLAY_IDS) do if candidate==id then known=true break end end
    local modes={overworld=true,battle=true,both=true,none=true}
    value=type(value)=="string" and value:lower() or nil
    if not known or not modes[value] then return false end
    global.profile[id.."Mode"]=value
    if save~=false then persist() end
    return true
  end
  -- Compatibility aliases remain non-product API shims for older consumers.
  -- They point at the first retained overlay instead of resurrecting removed UI.
  mod.exports.companionOverlayState=function()
    local st=mod.exports.overlayState();local p=st.widgets.encounters or {x=0,y=0}
    return {visible=st.visible,contextMode=st.contextMode,editMode=st.contextMode,locked=true,widgetX=p.x,widgetY=p.y}
  end
  mod.exports.setCompanionOverlayRegion=function(region) return mod.exports.setOverlayRegion("encounters",region) end
  mod.exports.interactionModel=function()
    local d=global.partyDrag
    if not (d and d.active) then return nil end
    local mon=d.mon;local def=global.game and global.game.data and global.game.data.pokemon and mon and global.game.data.pokemon[mon.species] or nil
    return {kind="party_drag",active=true,name=tostring(mon and (mon.nickname or (def and def.name)) or "POKéMON"),x=tonumber(d.x) or 0,y=tonumber(d.y) or 0,from=tonumber(d.from) or 0,to=tonumber(d.to) or tonumber(d.from) or 0}
  end
  mod.exports.graphics={
    registerProvider=function(spec) return graphicsRegistry.registerProvider(spec) end,
    resolve=function(context,request,fallback) return graphicsRegistry.resolve(context,request,fallback) end,
    status=function() return graphicsRegistry.status() end,
  }
  mod.exports.resolveAssetPath=function(path)
    local ok,Assets=pcall(require,"src.render.Assets")
    if ok and Assets and Assets.resolve then local ok2,v=pcall(Assets.resolve,path);if ok2 and v then return v end end
    return path
  end
  mod.exports.resolvePokemonArt=function(game,species,side,opts)
    opts=type(opts)=="table" and opts or {}
    side=side=="back" and "back" or "front"
    local kind=tostring(opts.kind or "menu"):lower()
    local request={species=species,side=side,kind=kind,game=game,
      mon=opts.mon,data=game and game.data,prefer=opts.prefer,
      shiny=opts.shiny,gender=opts.gender,form=opts.form}
    -- Provider-specific presentation metadata is intentionally extensible.
    -- Core preserves the canonical fields above, then forwards additional
    -- request keys (background/time/editor overrides, etc.) without learning
    -- any concrete Graphics policy.
    for k,v in pairs(opts) do if request[k]==nil then request[k]=v end end
    -- Context routing is deliberately presentation-aware. Earlier builds sent
    -- every front request through battle.opponent, which defeated the registry
    -- isolation contract and let battle-only settings leak into Party/PC/etc.
    local frontContexts={
      -- Large front-art ownership is deliberately narrow. Compact menu/list
      -- representations resolve through two-frame icon contexts instead.
      party="party.preview",summary="summary.preview",pokedex="pokedex.preview",dex="pokedex.preview",
      moves="moves.icon",pc="pc.icon",main_menu="main_menu.icon",native_menu="menu.icon",
      intro="intro.pokemon",oak="intro.pokemon",
    }
    local context
    if side=="back" then
      context=(kind=="battle") and "battle.player" or "menu.icon"
    else
      context=frontContexts[kind] or ((kind=="battle") and "battle.opponent" or "menu.icon")
    end
    local owned=graphicsRegistry.resolve(context,request,nil)
    if type(owned)=="table" and (owned.path or owned.image or owned.frames) then
      return owned.path,owned.trueColor==true,owned.source or owned.provider,owned
    end
    local path,trueColor
    local ok,Sprites=pcall(require,"src.pokemon.Sprites")
    if ok and Sprites and type(Sprites.path)=="function" then
      local worked,p,tc=pcall(Sprites.path,game and game.data,species,side,opts)
      if worked then path,trueColor=p,tc==true end
    end
    local fallback={path=path,trueColor=trueColor==true,source="gen1recomp"}
    local resolved=modIntegrations.resolvePokemonArt(game,request,fallback)
    if type(resolved)~="table" then resolved=fallback end
    return resolved.path,resolved.trueColor==true,resolved.source or fallback.source,resolved
  end
  mod.exports.createStartMenuRuntime=function(game) return startMenuRuntime.create(game or global.game) end
  mod.exports.createOptionsRuntime=function(game,opts) return optionsRuntime.create(game or global.game,opts) end
  mod.exports.createModRuntime=function(game) return modManager and modManager.create(game or global.game) or nil end
  mod.exports.modManagerModel=function(modId) return modManager and modManager.modelFor(modId) or nil end
  mod.exports.modIntegrations=modIntegrations
  mod.exports.restartResumeStatus=function() return restartResume and restartResume.status() or nil end
  mod.exports.diagnostics=function()
    return {release=RELEASE,visualTheme=false,nativeStartMenuRetained=true,overlay=mod.exports.overlayState(),accessibility=global.accessibility,gamePalette=gamePalette and gamePalette.status() or nil,modManager=modManager and modManager.status() or nil,compatibility=capabilityRegistry.status(),modIntegrations=modIntegrations.status(),restartResume=restartResume and restartResume.status() or nil,textInput=textInput.status and textInput.status() or nil,gameSave=gameSave.status and gameSave.status() or nil,foundation=foundation.snapshot(),moveDescriptions=moveDescriptions.catalogStatus(),videoMode=videoMode and videoMode.status() or nil,inputDevice=inputDevice and inputDevice.status(global.game) or nil,inputMode=inputMode and inputMode.snapshot() or nil,inputActions=inputActions and inputActions.status() or nil,fieldActions=fieldActions and fieldActions.status() or nil,notifications=notifications and notifications.status() or nil,graphics=graphicsRegistry.status(),viewport=global.viewport,lastInput=global.lastInput,nativePointer=global.nativePointer and global.nativePointer.kind() or nil}
  end
  mod.log:info("Kanto Rework Core %s loaded: shared pointer dispatch and plug-and-play integration active",RELEASE)
end
