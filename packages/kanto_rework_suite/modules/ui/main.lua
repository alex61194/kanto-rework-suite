return function(mod)
  local function loadModule(relative)
    local source,readErr=mod:read(relative)
    assert(type(source)=="string",readErr or ("Unable to read "..tostring(relative)))
    local chunk,err=load(source,"@"..mod.id.."/"..relative)
    assert(chunk,err or ("Unable to compile "..tostring(relative)))
    return chunk()
  end
  local function assetPath(relative) return mod.assets:path(relative) end

  local C=loadModule("generated/tokens.lua")
  local GeneratedAssets=loadModule("generated/assets.lua")
  local ColorProfiles=loadModule("generated/color_profiles.lua")
  local ThemeSpecs=loadModule("generated/themes.lua")
  local MoveSpec=loadModule("generated/specs/party_moves.lua")
  local PartyLayout=loadModule("ui/party_layout.lua")(C)
  local MenuLayout=loadModule("ui/menu_layout.lua")
  local Fixture=loadModule("ui/dev_fixture.lua")

  mod.options:define({
    {key="ui_theme",label="UI THEME",type="choice",default="firered",group="APPEARANCE",
      choices={{"ROJO FUEGO","firered"},{"CREAM","cream"},{"GRAPHITE","graphite"},{"PURPLE NIGHT","purplenight"},{"RETRO","retro"},{"GAMMA EMERALD","emerald"}},
      description="Choose the Kanto Rework visual theme. Accessibility color profiles remain independent."},
    {key="replace_battle_ui",label="BATTLE HUD",type="choice",default="journal",group="APPEARANCE",
      choices={{"MODERNO HD (GAMMA / WIDE)","journal"},{"CLÁSICO 8-BIT","floating"}},
      description="Choose between Modern HD Battle UI or Classic 8-bit Box."},
    {key="overlay_style",label="STYLE",type="choice",default="paper",group="OVERLAYS",
      choices={{"PAPER","paper"},{"GLASS","glass"}},
      description="Choose an opaque paper surface or a semi-transparent glass surface for every overlay."},
    {key="overlay_scale",label="SCALE",type="number",default=100,min=50,max=100,step=10,suffix="%",group="OVERLAYS",
      description="Resize every overlay from 50 to 100 percent. F11 cycles the same values."},
  })
  -- Legacy `replace_party_ui` values from 0.4.0 and earlier are intentionally
  -- ignored. Party replacement is now an intrinsic responsibility of this UI
  -- module whenever the validated Wide layout is supported.

  local runtime={}
  runtime.mod=mod
  runtime.assetPath=assetPath
  local coreHandle=mod.find("core")
  local Core=coreHandle and coreHandle.exports
  assert(Core and tonumber(Core.version or 0)>=40
      and type(Core.toggleFocusedOverlayCollapsed)=="function"
      and type(Core.setOverlayTabPlacement)=="function"
      and type(Core.registerInputLayer)=="function"
      and type(Core.createStartMenuRuntime)=="function"
      and type(Core.createOptionsRuntime)=="function"
      and type(Core.createModRuntime)=="function",
    "kanto_rework_core 0.1.40+ service exports are required")

  assert(Core.inputActions and type(Core.inputActions.register)=="function",
    "Core Input Action Registry is required")
  assert(Core.typography and type(Core.typography.registerFamily)=="function",
    "Core Typography Registry is required")
  assert(Core.compatibility and type(Core.compatibility.registerProvider)=="function",
    "Core Capability Registry is required")
  if runtime.unregisterUiShellProvider then pcall(runtime.unregisterUiShellProvider) end
  if runtime.unregisterPartyUiProvider then pcall(runtime.unregisterPartyUiProvider) end
  runtime.unregisterUiShellProvider=Core.compatibility.registerProvider({
    id="kanto_rework_ui.shell",capability="ui.shell",source=mod.id,modId=mod.id,
    label="Kanto Rework UI",priority=200,restartRequired=true,
  })
  runtime.unregisterPartyUiProvider=Core.compatibility.registerProvider({
    id="kanto_rework_ui.party",capability="ui.party",source=mod.id,modId=mod.id,
    label="Kanto Rework Party UI",priority=200,restartRequired=true,
  })
  runtime.unregisterFieldActionInput = runtime.unregisterFieldActionInput or nil
  runtime.unregisterMapInput = runtime.unregisterMapInput or nil
  runtime.unregisterOverlayScaleInput = runtime.unregisterOverlayScaleInput or nil
  runtime.unregisterOverlayCollapseInput = runtime.unregisterOverlayCollapseInput or nil
  runtime.unregisterOverlayLayoutInput = runtime.unregisterOverlayLayoutInput or nil
  runtime.unregisterPokedexCryInput = runtime.unregisterPokedexCryInput or nil
  runtime.unregisterPokedexOakInput = runtime.unregisterPokedexOakInput or nil
  runtime.unregisterSubmenuPrevInput = runtime.unregisterSubmenuPrevInput or nil
  runtime.unregisterSubmenuNextInput = runtime.unregisterSubmenuNextInput or nil
  runtime.unregisterBattleInfoInput = runtime.unregisterBattleInfoInput or nil
  runtime.unregisterLiveBattleEditorInput = runtime.unregisterLiveBattleEditorInput or nil
  if runtime.unregisterFieldActionInput then pcall(runtime.unregisterFieldActionInput) end
  if runtime.unregisterMapInput then pcall(runtime.unregisterMapInput) end
  if runtime.unregisterOverlayScaleInput then pcall(runtime.unregisterOverlayScaleInput) end
  if runtime.unregisterOverlayCollapseInput then pcall(runtime.unregisterOverlayCollapseInput) end
  if runtime.unregisterOverlayLayoutInput then pcall(runtime.unregisterOverlayLayoutInput) end
  if runtime.unregisterPokedexCryInput then pcall(runtime.unregisterPokedexCryInput) end
  if runtime.unregisterPokedexOakInput then pcall(runtime.unregisterPokedexOakInput) end
  if runtime.unregisterSubmenuPrevInput then pcall(runtime.unregisterSubmenuPrevInput) end
  if runtime.unregisterSubmenuNextInput then pcall(runtime.unregisterSubmenuNextInput) end
  if runtime.unregisterBattleInfoInput then pcall(runtime.unregisterBattleInfoInput) end
  if runtime.unregisterLiveBattleEditorInput then pcall(runtime.unregisterLiveBattleEditorInput) end
  runtime.unregisterFieldActionInput=Core.inputActions.register({
    id="FIELD_ACTIONS",label="FIELD ACTIONS",source=mod.id,group="KANTO REWORK",
    description="Open the contextual Kanto Rework Field Actions popup.",
    defaults={key="f"},priority=100,
  })
  runtime.unregisterMapInput=Core.inputActions.register({
    id="MAP",label="MAP / FLY",source=mod.id,group="KANTO REWORK",
    description="Open the Kanto Rework full-screen Map / Fly view.",
    defaults={key="m"},priority=90,
  })
  runtime.unregisterOverlayScaleInput=Core.inputActions.register({
    id="OVERLAY_SCALE_CYCLE",label="CYCLE OVERLAY SCALE",source=mod.id,group="KANTO REWORK OVERLAYS",
    description="Cycle the responsive overlay scale from 50 to 100 percent.",
    defaults={key="f11"},priority=80,
  })
  runtime.unregisterOverlayCollapseInput=Core.inputActions.register({
    id="OVERLAY_COLLAPSE_TOGGLE",label="COLLAPSE / RESTORE OVERLAY",source=mod.id,group="KANTO REWORK OVERLAYS",
    description="Collapse or restore the last targeted visible overlay without opening edit mode.",
    defaults={key="f12",pad="leftstick"},priority=75,
  })
  runtime.unregisterOverlayLayoutInput=Core.inputActions.register({
    id="OVERLAY_LAYOUT_ADJUST",label="ADJUST OVERLAY LAYOUT",source=mod.id,group="KANTO REWORK OVERLAYS",
    description="Focus a visible F8 overlay for controller or keyboard movement and free-aspect resizing.",
    defaults={key="f6",pad="touchpad"},priority=76,
  })
  runtime.unregisterPokedexCryInput=Core.inputActions.register({
    id="POKEDEX_CRY",label="POKéDEX: PLAY CRY",source=mod.id,group="KANTO REWORK POKéDEX",
    description="Play the selected observed Pokémon's cry from the Kanto Journal.",
    defaults={key="c",pad="x"},priority=95,
  })
  runtime.unregisterPokedexOakInput=Core.inputActions.register({
    id="POKEDEX_OAK_EVAL",label="POKéDEX: OAK'S EVALUATION",source=mod.id,group="KANTO REWORK POKéDEX",
    description="Open Professor Oak's current Pokédex evaluation.",
    defaults={key="o",pad="y"},priority=94,
  })
  runtime.unregisterSubmenuPrevInput=Core.inputActions.register({
    id='UI_SUBMENU_PREV',label='PREVIOUS SUB-MENU / TAB',source=mod.id,group='KANTO REWORK NAVIGATION',
    description='Additive shortcut for the previous lateral page, pocket, tab or category.',
    defaults={key='pageup',pad='leftshoulder'},priority=92,
  })
  runtime.unregisterSubmenuNextInput=Core.inputActions.register({
    id='UI_SUBMENU_NEXT',label='NEXT SUB-MENU / TAB',source=mod.id,group='KANTO REWORK NAVIGATION',
    description='Additive shortcut for the next lateral page, pocket, tab or category.',
    defaults={key='pagedown',pad='rightshoulder'},priority=92,
  })
  runtime.unregisterBattleInfoInput=Core.inputActions.register({
    id='BATTLE_INFO',label='BATTLE INFO',source=mod.id,group='KANTO REWORK BATTLE',
    description='Open or close the Kanto Rework battle information panel.',
    defaults={key='tab'},priority=90,
  })
  runtime.unregisterLiveBattleEditorInput=Core.inputActions.register({
    id='LIVE_BATTLE_EDITOR',label='LIVE BATTLE EDITOR',source=mod.id,group='KANTO REWORK BATTLE',
    description='Open the Live Battle Graphics Editor from a supported KRS battle.',
    defaults={key='f10'},priority=89,
  })

  if runtime.unregisterInterFamily then pcall(runtime.unregisterInterFamily) end
  if runtime.unregisterRetroFamily then pcall(runtime.unregisterRetroFamily) end
  runtime.fontFamily="kanto_rework.inter"
  -- Plain Pixel is supplied by Gen1Recomp and only covers glyphs absent from
  -- the canonical theme faces. KRS owns and distributes the Figma families.
  runtime.fontFallbackPath="assets/fonts/plainpixel/PlainPixel-Regular.ttf"
  runtime.unregisterInterFamily=Core.typography.registerFamily({
    id=runtime.fontFamily,label="Inter",source=mod.id,
    paths={
      regular=assetPath("assets/fonts/inter/Inter-Regular.ttf"),
      medium=assetPath("assets/fonts/inter/Inter-Medium.ttf"),
      semibold=assetPath("assets/fonts/inter/Inter-SemiBold.ttf"),
      bold=assetPath("assets/fonts/inter/Inter-Bold.ttf"),
      black=assetPath("assets/fonts/inter/Inter-Black.ttf"),
    },
  })
  runtime.retroFontFamily="kanto_rework.pixelify_sans"
  runtime.unregisterRetroFamily=Core.typography.registerFamily({
    id=runtime.retroFontFamily,label="Pixelify Sans",source=mod.id,
    paths={
      regular=assetPath("assets/fonts/pixelify/PixelifySans-Regular.ttf"),
      medium=assetPath("assets/fonts/pixelify/PixelifySans-Medium.ttf"),
      semibold=assetPath("assets/fonts/pixelify/PixelifySans-Bold.ttf"),
      bold=assetPath("assets/fonts/pixelify/PixelifySans-Bold.ttf"),
      black=assetPath("assets/fonts/pixelify/PixelifySans-Bold.ttf"),
    },
  })
  runtime.fontPaths=Core.typography.paths(runtime.fontFamily)

  local function cycleOverlayScale(game)
    local current=tonumber(mod.options:get("overlay_scale")) or 100
    local value=current>=100 and 50 or math.min(100,current+10)
    local session,err=Core.createModRuntime(game or runtime.game);if not session then return false,err end
    session:enter()
    if type(session.setOption)~="function" then return false,"Core option setter unavailable" end
    return session:setOption(mod.id,"overlay_scale",value)
  end
  runtime.cycleOverlayScale=cycleOverlayScale
  runtime.toggleFocusedOverlay=function()
    if type(Core.toggleFocusedOverlayCollapsed)~="function" then return false,"unsupported" end
    return Core.toggleFocusedOverlayCollapsed(true)
  end
  runtime.overlayLayoutMode=false;runtime.overlayLayoutOperation="move"

  local foundation={
    registerInputLayer=Core.registerInputLayer,
    setFocus=Core.setFocus,getFocus=Core.getFocus,clearFocus=Core.clearFocus,
    beginDrag=Core.beginDrag,dragState=Core.dragState,endDrag=Core.endDrag,
  }

  -- Screen-specific engine adaptation remains in the UI module. Shared data,
  -- input ownership, bindings, accessibility and menu runtime services come
  -- only through Core.
  runtime.Graphics=loadModule("runtime/graphics.lua")({Core=Core,mod=mod})
  runtime.PokemonArt=loadModule("runtime/pokemon_art.lua")({Core=Core,mod=mod})
  runtime.MenuPokemonPresentation=loadModule("runtime/menu_pokemon_presentation.lua")({Core=Core,mod=mod})
  runtime.PokemonName=loadModule("runtime/pokemon_name.lua")
  runtime.worldPhase=function(game)
    game=game or runtime.game
    local handle=mod.find and mod.find("graphics")
    local gx=handle and handle.exports or nil
    if type(gx)=='table' and type(gx.timeOfDayPeriod)=='function' then
      local ok,value=pcall(gx.timeOfDayPeriod)
      if ok then
        value=tostring(value or ''):lower()
        if value=='sunrise' or value=='day' or value=='sunset' or value=='night' then return value end
      end
    end
    local tod=game and game.overworld and (game.overworld.tod or game.overworld.daytime) or 'DAY'
    tod=tostring(tod or 'DAY'):upper()
    if tod:find('MORN',1,true) or tod:find('DAWN',1,true) then return 'sunrise' end
    if tod:find('EVEN',1,true) or tod:find('DUSK',1,true) then return 'sunset' end
    if tod:find('NIGHT',1,true) or tod=='NITE' then return 'night' end
    return 'day'
  end
  runtime.worldTimeLabel=function(game,seconds)
    local sec=math.max(0,math.floor(tonumber(seconds) or 0))
    local clock=('%02d:%02d'):format(math.floor(sec/3600),math.floor(sec/60)%60)
    return clock..' • '..tostring(runtime.worldPhase(game) or 'day'):upper()
  end
  local PartyAdapter=loadModule("ui/party_adapter.lua")({Fixture=Fixture,Core=Core,Graphics=runtime.Graphics,PokemonArt=runtime.PokemonArt,PokemonName=runtime.PokemonName})
  local TypeIcon=loadModule("components/type_icon.lua")({Assets=GeneratedAssets,mod=mod})
  local StatusToken=loadModule("components/status_token.lua")({C=C,Assets=GeneratedAssets,mod=mod,runtime=runtime})
  local TypeChip=loadModule("components/type_chip.lua")({TypeIcon=TypeIcon,runtime=runtime})
  local GlyphTestBoard=loadModule("components/glyph_test_board.lua")({TypeIcon=TypeIcon,TypeChip=TypeChip,StatusToken=StatusToken})
  local OverlayModels=loadModule("components/overlay_models.lua")(runtime.PokemonName)
  local Palette=loadModule("ui/palette.lua")({C=C,Profiles=ColorProfiles,Core=Core,Themes=ThemeSpecs,mod=mod})
  local Footer=loadModule("components/footer.lua")({C=C,Core=Core})
  local WideMoves=loadModule("layouts/party_moves/wide.lua")(MoveSpec)
  local PartyController=loadModule("ui/party_controller.lua")({
    Adapter=PartyAdapter,Layout=PartyLayout,C=C,runtime=runtime,foundation=foundation,
    fixtureEnabled=false,
  })
  local PartyPresenter=loadModule("ui/party_presenter.lua")({
    C=C,Layout=PartyLayout,Adapter=PartyAdapter,TypeIcon=TypeIcon,TypeChip=TypeChip,StatusToken=StatusToken,Footer=Footer,
    Palette=Palette,Core=Core,WideMoves=WideMoves,runtime=runtime,
  })

  runtime.mod=mod;runtime.Core=Core;runtime.coreHandle=coreHandle
  runtime.PartyAdapter=PartyAdapter;runtime.StatusToken=StatusToken;runtime.TypeIcon=TypeIcon;runtime.TypeChip=TypeChip
  runtime.C=C;runtime.Layout=MenuLayout;runtime.PartyLayout=PartyLayout
  runtime.WindowContract=loadModule("ui/window_contract.lua")({Layout=MenuLayout})
  runtime.Focus=loadModule("ui/focus_manager.lua")({Core=Core})
  runtime.partyNav=runtime.partyNav or runtime.Focus.new("kanto_rework_ui.party")
  runtime.ThemeSpecs=ThemeSpecs;runtime.Palette=Palette;runtime.Theme=loadModule("ui/theme.lua")({Palette=Palette,Specs=ThemeSpecs,mod=mod,Core=Core})
  runtime.Draw=loadModule("ui/menu_draw.lua")
  runtime.CharacterNames=loadModule("runtime/character_names.lua")({mod=mod})
  runtime.ItemDescriptions=loadModule("runtime/item_descriptions.lua")
  runtime.DocumentReader=loadModule("ui/document_reader.lua")()
  local NativeTextBox=require("src.render.TextBox")
  local NativeChoiceBox=require("src.ui.ChoiceBox")
  local NativeListMenu=require("src.ui.ListMenu")
  local NativeQuantityBox=require("src.ui.QuantityBox")
  local NativeMenu=require("src.ui.Menu")
  local NativeNamingScreen=require("src.ui.NamingScreen")
  local NativePartyMenu=require("src.ui.PartyMenu")
  local NativeFont=require("src.render.Font")
  local NativeBattleState=require("src.battle.BattleState")
  runtime.DialogueAdapter=loadModule("ui/dialogue_adapter.lua")({
    TextBox=NativeTextBox,ChoiceBox=NativeChoiceBox,ListMenu=NativeListMenu,QuantityBox=NativeQuantityBox,Font=NativeFont,Layout=MenuLayout,CharacterNames=runtime.CharacterNames,
  })
  runtime.DialoguePanel=loadModule("components/dialogue_panel.lua")({Draw=runtime.Draw})
  runtime.dialogueFailed=setmetatable({},{__mode="k"})
  runtime.dialogueRect=nil
  runtime.Scroll=loadModule("ui/scroll_list.lua")
  runtime.ModInfoLayout=loadModule("ui/mod_info_layout.lua")
  runtime.OverlayModels=OverlayModels
  runtime.Catalog=loadModule("runtime/options_catalog.lua")
  local MenuAssets=loadModule("runtime/assets.lua")({Core=Core});runtime.assets=MenuAssets.new()
  runtime.Header=loadModule("components/header.lua")
  runtime.Footer=Footer
  runtime.ControlsCatalog=loadModule("runtime/controls_catalog.lua")(runtime)
  runtime.MenuPresenter=loadModule("ui/menu_presenter.lua")
  runtime.NativePresenter=loadModule("ui/native_presenter.lua")(runtime)
  runtime.ScriptMenuPresenter=loadModule("ui/script_menu_presenter.lua")(runtime)
  runtime.LinkPresenter=loadModule("ui/link_presenter.lua")(runtime)
  runtime.PokedexPresenter=loadModule("ui/pokedex_presenter.lua")(runtime)
  runtime.BattleBackgrounds=loadModule("runtime/battle_backgrounds.lua")
  runtime.BattleLayoutConfig=loadModule("runtime/battle_layout_config.lua")({mod=mod})
  runtime.TrainerScene=loadModule("runtime/trainer_scene.lua")()
  if runtime.BattleBackgrounds.bindMod then runtime.BattleBackgrounds.bindMod(mod) end
  runtime.BattlePresenter=loadModule("ui/battle_presenter.lua")(runtime)
  runtime.IntroPresenter=loadModule("ui/intro_presenter.lua")(runtime)
  runtime.NamingPresenter=loadModule("ui/naming_presenter.lua")(runtime)
  runtime.ModularOverlays=loadModule("components/modular_overlays.lua")({
    Core=Core,Palette=Palette,PartyAdapter=PartyAdapter,TypeIcon=TypeIcon,Models=OverlayModels,mod=mod,runtime=runtime,
  })
  runtime.InteractionVisual=loadModule("components/interaction_visual.lua")({Core=Core,Palette=Palette})
  runtime.partyController=PartyController;runtime.partyPresenter=PartyPresenter
  runtime.viewport=runtime.viewport or {width=C.DESIGN_WIDTH,height=C.DESIGN_HEIGHT}
  runtime.presenterReady=false;runtime.menuReady=false;runtime.error=nil
  runtime.debugEnabled=false
  runtime.glyphBoardEnabled=false

  local StartFactory=loadModule("screens/start_menu.lua").factory(runtime)
  local OptionsFactory=loadModule("screens/options_menu.lua").factory(runtime)
  local ModsFactory=loadModule("screens/mods_menu.lua").factory(runtime)
  local GraphicsEditorFactory=loadModule('screens/graphics_editor.lua').factory(runtime);runtime.GraphicsEditorFactory=GraphicsEditorFactory
  runtime.ModExtension=loadModule("screens/mod_extension_menu.lua")
  local ControlsFactory=loadModule("screens/controls_menu.lua").factory(runtime)
  local FieldActionsFactory=loadModule("screens/field_actions_popup.lua").factory(runtime)
  local SaveSlotsFactory=loadModule("screens/save_slots.lua").factory(runtime)
  local PokedexFactory=loadModule("screens/pokedex_menu.lua").factory(runtime)
  local PcStorageFactory=loadModule("screens/pc_storage.lua").factory(runtime)
  local BagRegisterFactory=loadModule("screens/bag_register.lua").factory(runtime)
  runtime.SaveSlotsFactory=SaveSlotsFactory
  runtime.PokedexFactory=PokedexFactory
  runtime.PcStorageFactory=PcStorageFactory
  runtime.BagRegisterFactory=BagRegisterFactory
  local MapFactory=loadModule("screens/map_screen.lua").factory(runtime)
  -- Fly is a manual Field Action backed by the real KRS Map/Fly screen. It
  -- never implements a second teleport path: Core.mapFlyStatus enforces the
  -- HM/badge/world gates and MapFactory delegates the destination/confirmation
  -- to Core.activateMapFly -> the engine OverworldController:flyTo seam.
  local function partyCapability(game,moveId)
    moveId=tostring(moveId or ''):upper()
    for index,mon in ipairs(game and game.save and game.save.party or {}) do
      for _,mv in ipairs(mon.moves or {}) do
        local id = tostring(type(mv)=='table' and mv.id or mv):upper()
        if id==moveId or (moveId=='FLY' and (id=='FLY' or id=='VUELO')) or (moveId=='CUT' and (id=='CUT' or id=='CORTE')) or (moveId=='SURF' and (id=='SURF')) or (moveId=='FLASH' and (id=='FLASH' or id=='DESTELLO')) or (moveId=='DIG' and (id=='DIG' or id=='EXCAVAR')) or (moveId=='TELEPORT' and (id=='TELEPORT' or id=='TELETRANSPORTE')) or (moveId=='SOFTBOILED' and (id=='SOFTBOILED' or id=='AMORTIGUADOR')) then
          return index,'active'
        end
      end
      if type(Core.knownMoves)=='function' then
        local ok,known=pcall(Core.knownMoves,mon,true)
        if ok and type(known)=='table' then
          for _,mv in ipairs(known) do
            local id = tostring(mv and mv.id or ''):upper()
            if id==moveId or (moveId=='FLY' and (id=='FLY' or id=='VUELO')) or (moveId=='CUT' and (id=='CUT' or id=='CORTE')) or (moveId=='SURF' and (id=='SURF')) or (moveId=='FLASH' and (id=='FLASH' or id=='DESTELLO')) or (moveId=='DIG' and (id=='DIG' or id=='EXCAVAR')) or (moveId=='TELEPORT' and (id=='TELEPORT' or id=='TELETRANSPORTE')) or (moveId=='SOFTBOILED' and (id=='SOFTBOILED' or id=='AMORTIGUADOR')) then
              return index,'memory'
            end
          end
        end
      end
    end
  end
  if Core.fieldActions and type(Core.fieldActions.register)=='function' then
    runtime.unregisterFlyFieldAction=Core.fieldActions.register({
      id='kanto.fly',label='VUELO',description='Abrir el mapa de Kanto y volar a cualquier destino visitado',
      source=mod.id,trigger='manual',priority=290,
      requirements=function(context)
        local game=(context and context.game) or runtime.game
        local index,source=partyCapability(game,'FLY')
        if not index then return {ok=false,reason='move_not_known',move='FLY'} end
        return {ok=true,move='FLY',pokemon=index,capabilitySource=source}
      end,
      availability=function(context)
        local game=(context and context.game) or runtime.game
        local status=type(Core.mapFlyStatus)=='function' and Core.mapFlyStatus(game) or nil
        if type(status)~='table' then return {available=false,reason='engine_unavailable'} end
        return {available=status.available==true,reason=status.reason,hm=status.hm,badge=status.badge}
      end,
      execute=function(context)
        local game=(context and context.game) or runtime.game
        if not (game and game.stack) then return false,'no_game_stack' end
        local screen=MapFactory.new(game)
        if not screen then return false,'map_unavailable' end
        game.stack:push(screen);return true,'map_opened'
      end,
    })
  end
  local TitleFactory=loadModule("screens/title_screen.lua").factory(runtime)
  local OverlayContextFactory=loadModule("screens/overlay_context.lua").factory(runtime)
  local OverlayLayoutFactory=loadModule("screens/overlay_layout.lua").factory(runtime)
  runtime.FieldActionsFactory=FieldActionsFactory;runtime.MapFactory=MapFactory;runtime.TitleFactory=TitleFactory
  runtime.OptionsFactory=OptionsFactory;runtime.ModsFactory=ModsFactory;runtime.ControlsFactory=ControlsFactory
  -- First-party Graphics utility lives in the Mods hierarchy but opens a real
  -- KRS battle-renderer preview state rather than a generic document wrapper.
  if runtime.unregisterGraphicsEditorIntegration then pcall(runtime.unregisterGraphicsEditorIntegration) end
  if Core.modIntegrations and type(Core.modIntegrations.register)=='function' then
    runtime.unregisterGraphicsEditorIntegration=Core.modIntegrations.register({
      id='kanto_rework_ui.graphics_editor',modId='kanto_rework_suite',priority=300,label='KRS LIVE GRAPHICS EDITOR',
      utilities=function(game) return {{id='live_battle_editor',label='LIVE BATTLE GRAPHICS EDITOR',group='VISUALS',
        description='Edit the real KRS battle background and Pokémon presentation pipeline with live Global/Local overrides.',
        open=function() return GraphicsEditorFactory.new(game) end}} end,
    })
  end
  runtime.OverlayContextFactory=OverlayContextFactory;runtime.OverlayLayoutFactory=OverlayLayoutFactory
  local function override(id,factory)
    mod.content.screens:override(id,{new=function(game,...)
      runtime.game=game
      return factory.new(game,...)
    end})
  end
  override("StartMenu",StartFactory)
  override("TitleState",TitleFactory)
  override("OptionsMenu",OptionsFactory)
  override("ManagerState",ModsFactory)
  override("PokedexMenu",PokedexFactory)
  override("BoxMenu",PcStorageFactory)
  mod.content.screens:register("KantoControls",{new=function(game,...) runtime.game=game;return ControlsFactory.new(game,...) end})

  -- Wide Options renders the CONTROLS category directly. The native Options
  -- row is deliberately left untouched so unsupported layouts retain the
  -- engine's own BindingsMenu fallback. KantoControls stays registered only
  -- as a compatibility screen for callers that explicitly request it.

  local function top(game)
    local stack=game and game.stack
    return stack and type(stack.top)=="function" and stack:top() or nil
  end
  local MenuPointerGuard=loadModule("ui/menu_pointer_guard.lua")({Core=Core,Layout=MenuLayout,runtime=runtime})
  local function restoreKrsMenuPointer(game,state) return MenuPointerGuard.restore(game,state or top(game)) end
  runtime.restoreKrsMenuPointer=restoreKrsMenuPointer
  runtime.krsOwnsPointerSurface=function(game,state) return MenuPointerGuard.owns(game,state or top(game)) end
  local function logFailure(scope,err)
    local value=tostring(err);runtime.error=value
    local key=scope..":"..value
    if runtime.lastLoggedError~=key then runtime.lastLoggedError=key;mod.log:error("%s failed; native fallback retained: %s",scope,value) end
  end

  -- Wide overworld dialogue keeps the official TextBox state/update/input, but
  -- suppresses only TextBox:draw itself.  Clearing Renderer.uiCanvas erased the
  -- overworld whenever the map was being drawn in the UI pass; hiding the whole
  -- state through screen.render_visible changed palette/base ownership.  A draw
  -- interposition is the narrow operation we actually need: world pixels stay
  -- untouched and the state remains fully visible to the engine's stack walk.
  local nativeTextBoxDraw=NativeTextBox._krsOriginalDraw or NativeTextBox.draw
  NativeTextBox._krsOriginalDraw=nativeTextBoxDraw
  local nativeChoiceBoxDraw=NativeChoiceBox._krsOriginalDraw or NativeChoiceBox.draw
  NativeChoiceBox._krsOriginalDraw=nativeChoiceBoxDraw
  local nativeChoiceBoxUpdate=NativeChoiceBox._krsOriginalUpdate or NativeChoiceBox.update
  NativeChoiceBox._krsOriginalUpdate=nativeChoiceBoxUpdate
  local nativeListMenuUpdate=NativeListMenu._krsOriginalUpdate or NativeListMenu.update
  NativeListMenu._krsOriginalUpdate=nativeListMenuUpdate
  local nativeQuantityBoxUpdate=NativeQuantityBox._krsOriginalUpdate or NativeQuantityBox.update
  NativeQuantityBox._krsOriginalUpdate=nativeQuantityBoxUpdate
  local nativeMenuUpdate=NativeMenu._krsOriginalUpdate or NativeMenu.update
  local nativeNamingScreenUpdate=NativeNamingScreen._krsOriginalUpdate or NativeNamingScreen.update
  NativeMenu._krsOriginalUpdate=nativeMenuUpdate
  local nativePartyMenuUpdate=NativePartyMenu._krsOriginalUpdate or NativePartyMenu.update
  NativePartyMenu._krsOriginalUpdate=nativePartyMenuUpdate
  local nativeListMenuDraw=NativeListMenu._krsOriginalDraw or NativeListMenu.draw
  NativeListMenu._krsOriginalDraw=nativeListMenuDraw
  local NativeOakSpeech=require('src.ui.OakSpeech')
  local nativeOakSpeechDraw=NativeOakSpeech._krsOriginalDraw or NativeOakSpeech.draw
  NativeOakSpeech._krsOriginalDraw=nativeOakSpeechDraw
  NativeOakSpeech.draw=function(state,...)
    local game=state and state.game or runtime.game
    if state and runtime.IntroPresenter and runtime.IntroPresenter.handles(game,runtime.viewport)
        and MenuLayout.isWide(runtime.viewport) then return end
    return nativeOakSpeechDraw(state,...)
  end

  local function prepareDialogueState(game,state,requireOverworldOwner)
    if not state or runtime.dialogueFailed[state] or state._krsDialoguePrepared then
      return state and state._krsDialoguePrepared==true or false
    end
    if requireOverworldOwner and not runtime.DialogueAdapter.isSupported(game,state,runtime.viewport) then return false end
    -- Automatic/stay TextBoxes can drive cutscene choreography. They still
    -- receive KRS presentation, but their native pages and timing are left
    -- byte-for-byte intact. Manual semantic boxes may safely use Wide
    -- repagination before their first typed glyph.
    if runtime.DialogueAdapter.canRepaginate and not runtime.DialogueAdapter.canRepaginate(state) then
      state._krsDialoguePrepared=true
      return true
    end
    local ok,err=pcall(function()
      local m=MenuLayout.metrics(runtime.viewport)
      local prose=runtime.DialogueAdapter.presentationText(state,game)
      local lines=runtime.DialoguePanel.wrap(runtime,m,prose)
      assert(runtime.DialogueAdapter.repaginate(state,lines,runtime.DialoguePanel.maxLinesPerPage()),
        "dialogue pagination could not be prepared before typing")
      state._krsDialoguePrepared=true
    end)
    if not ok then
      -- A native overlay can already have typed one or more glyphs before its
      -- first KRS draw. In that case presentation still stays KRS, but the
      -- engine's current pagination is retained rather than marking the whole
      -- state as a visual failure and falling back to vanilla.
      if runtime.DialogueAdapter.canRepaginate and runtime.DialogueAdapter.canRepaginate(state)
          and ((tonumber(state.charIndex) or 0)>0 or (tonumber(state.lineIndex) or 1)>1 or (tonumber(state.pageIndex) or 1)>1) then
        state._krsDialoguePrepared=true
        return true
      end
      runtime.dialogueFailed[state]=true
      logFailure("Wide dialogue preparation",err)
      return false
    end
    return true
  end
  local function prepareDialogue(game,state) return prepareDialogueState(game,state,true) end
  local function prepareNativeDialogue(game,state) return prepareDialogueState(game,state,false) end
  runtime.prepareDialogue=prepareDialogue

  NativeTextBox.draw=function(state,...)
    local game=state and state.game or runtime.game
    if state and runtime.IntroPresenter and runtime.IntroPresenter.ownsText(game,state,runtime.viewport) then
      prepareNativeDialogue(game,state)
      return -- OakSpeech state machine owns timing; KRS intro presenter owns pixels.
    end
    if state and runtime.NativePresenter and type(runtime.NativePresenter.handles)=="function"
        and MenuLayout.isWide(runtime.viewport) and runtime.NativePresenter.handles(game,state) then
      -- MoveLearn/item-target TextBoxes are native semantic owners too. Give
      -- manual ones the same Wide repagination as overworld dialogue before
      -- NativePresenter mirrors them, so a long learning exchange uses the
      -- whole KRS box instead of inheriting Game Boy page cuts.
      prepareNativeDialogue(game,state)
      return -- native state/update stays authoritative; NativePresenter owns this KRS overlay's pixels.
    end
    if state and not runtime.dialogueFailed[state]
        and runtime.DialogueAdapter.isSupported(game,state,runtime.viewport)
        and (state._krsDialoguePrepared or prepareDialogue(game,state)) then
      return -- presentation is drawn once, later, by render.hud
    end
    return nativeTextBoxDraw(state,...)
  end

  -- The anchored YES/NO box spawned by an eligible TextBox remains the native
  -- input/timing owner, but its Game Boy chrome is replaced by the integrated
  -- KRS confirmation region. Bare ChoiceBoxes elsewhere remain untouched.
  NativeChoiceBox.draw=function(state,...)
    local game=state and state.game or runtime.game
    local battleHudMode=pcall(mod.options.get,mod.options,"replace_battle_ui") and mod.options:get("replace_battle_ui") or "floating"
    if battleHudMode=="journal" and state and runtime.BattlePresenter and type(runtime.BattlePresenter.ownsChoice)=="function"
        and runtime.BattlePresenter.ownsChoice(game,state) then
      return -- native timing/callback owner; KRS Battle draws the horizontal choice surface
    end
    if state and runtime.NativePresenter and type(runtime.NativePresenter.handles)=="function"
        and MenuLayout.isWide(runtime.viewport) and runtime.NativePresenter.handles(game,state) then return end
    if state and runtime.DialogueAdapter.isMirroredChoice(game,state,runtime.viewport) then return end
    return nativeChoiceBoxDraw(state,...)
  end

  local function krsOwnsNativeUpdate(state,dt)
    local game=state and state.game or runtime.game
    if not (state and runtime.NativePresenter and type(runtime.NativePresenter.update)=="function") then return false end
    local ok,owned=pcall(runtime.NativePresenter.update,game,state,dt)
    if not ok then logFailure("KRS Wide native menu controller",owned);return false end
    return owned==true
  end

  -- Wide KRS screens own their controller as well as their presentation.
  -- Native callbacks/data remain authoritative, but native update is suppressed
  -- for states explicitly handled by NativePresenter so two controllers cannot
  -- react to the same physical input.
  NativeListMenu.update=function(state,dt)
    if krsOwnsNativeUpdate(state,dt) then return end
    return nativeListMenuUpdate(state,dt)
  end
  NativeQuantityBox.update=function(state,dt)
    if krsOwnsNativeUpdate(state,dt) then return end
    return nativeQuantityBoxUpdate(state,dt)
  end
  NativeMenu.update=function(state,dt)
    if krsOwnsNativeUpdate(state,dt) then return end
    return nativeMenuUpdate(state,dt)
  end

  -- Wide player/rival naming keeps native editing semantics, but B becomes a
  -- genuine Back action once the field is empty: it returns to the engine's
  -- own preset chooser. While text exists B still performs the vanilla delete.
  if not NativeNamingScreen._krsOriginalUpdate then NativeNamingScreen._krsOriginalUpdate=nativeNamingScreenUpdate end
  NativeNamingScreen.update=function(state,dt)
    if MenuLayout.isWide(runtime.viewport) and state and state.presets and #(state.glyphs or {})==0
        and state.game and state.game.input and state.game.input:wasPressed("b") then
      state:enter();return
    end
    return nativeNamingScreenUpdate(state,dt)
  end

  -- Native PartyMenu remains the semantic/callback owner for battle switching
  -- and Bag item targeting. KRS presents both on the canonical two-column
  -- Party grid, so their keyboard/controller navigation must follow that same
  -- geometry instead of the Game Boy's vertical 1->2->3 list.
  NativePartyMenu.update=function(state,dt)
    local game=state and state.game or runtime.game
    local wide=MenuLayout.isWide(runtime.viewport)
    local input=state and state.game and state.game.input
    if state and wide and input and type(input.wasPressed)=="function" then
      local old=input.wasPressed

      -- Item/TM/HM target pickers are `pickOnly` PartyMenus. Apply the exact
      -- PartyLayout neighbour graph already used by the normal KRS Party
      -- screen, while preserving native A/B, callbacks, keepOpen healing and
      -- item-effect ownership.
      if state.pickOnly and not state.submenu then
        local direction=old(input,"left") and "left"
          or old(input,"right") and "right"
          or old(input,"up") and "up"
          or old(input,"down") and "down"
        if direction then
          local party=state.party or (state.game.save and state.game.save.party) or {}
          state.index=PartyLayout.partyNeighbor(state.index or 1,direction,#party)
          state.game.partyMenuSavedIndex=state.index
        end
        input.wasPressed=function(self,action)
          if action=="left" or action=="right" or action=="up" or action=="down" then return false end
          return old(self,action)
        end
        local packed={xpcall(function() return nativePartyMenuUpdate(state,dt) end,tostring)}
        input.wasPressed=old
        if not packed[1] then error(packed[2],0) end
        return unpack(packed,2)
      end

      -- Gen1's battle party submenu is vertically encoded, while the
      -- canonical KRS Battle Action popup is horizontal.
      if state.battle and state.submenu then
        local left=old(input,"left") == true
        local right=old(input,"right") == true
        input.wasPressed=function(self,action)
          if action=="up" then return left end
          if action=="down" then return right end
          if action=="left" or action=="right" then return false end
          return old(self,action)
        end
        local packed={xpcall(function() return nativePartyMenuUpdate(state,dt) end,tostring)}
        input.wasPressed=old
        if not packed[1] then error(packed[2],0) end
        return unpack(packed,2)
      end
    end
    return nativePartyMenuUpdate(state,dt)
  end

  -- The native two-option controller is vertical because the Game Boy YES/NO
  -- menu stacks its rows. KRS presents those same two semantic choices side by
  -- side, so only mirrored KRS choices remap directional navigation to
  -- left/right. A/B, pending hold frames, sound and callbacks stay native.
  NativeChoiceBox.update=function(state,dt)
    if krsOwnsNativeUpdate(state,dt) then return end
    local game=state and state.game or runtime.game
    local battleHudMode=pcall(mod.options.get,mod.options,"replace_battle_ui") and mod.options:get("replace_battle_ui") or "floating"
    local battleChoice=battleHudMode=="journal" and state and runtime.BattlePresenter and type(runtime.BattlePresenter.ownsChoice)=="function"
      and runtime.BattlePresenter.ownsChoice(game,state) or false
    if battleChoice and state.pending==nil then
      local input=state.game and state.game.input
      if input and type(input.wasPressed)=="function" then
        local old=input.wasPressed
        local left=old(input,"left") == true
        local right=old(input,"right") == true
        if left or right then state.index=state.index==1 and 2 or 1 end
        -- Preserve native A/B, pending hold frames, SFX and callbacks, but the
        -- KRS choices are horizontal so native up/down must not toggle them.
        input.wasPressed=function(self,action)
          if action=="left" or action=="right" or action=="up" or action=="down" then return false end
          return old(self,action)
        end
        local packed={xpcall(function() return nativeChoiceBoxUpdate(state,dt) end,tostring)}
        input.wasPressed=old
        if not packed[1] then error(packed[2],0) end
        return unpack(packed,2)
      end
    end
    if state and state.pending==nil
        and runtime.DialogueAdapter.choiceNavigation(game,state,runtime.viewport)=="horizontal" then
      local input=state.game and state.game.input
      if input then
        if input:wasPressed("left") or input:wasPressed("right") then
          state.index=state.index==1 and 2 or 1
          return
        elseif input:wasPressed("up") or input:wasPressed("down") then
          return -- vertical movement is intentionally inert for horizontal KRS choices
        end
      end
    end
    return nativeChoiceBoxUpdate(state,dt)
  end

  -- KRS Battle keeps the engine's battle/update business logic but replaces
  -- the navigation geometry of the Wide command and move selectors. The
  -- native update still receives A/B/SELECT and all turn resolution; only
  -- directional reads are masked after KRS has applied the Figma row/list
  -- semantics.
  local nativeStatBoxDraw=NativeBattleState.StatBox._krsOriginalDraw or NativeBattleState.StatBox.draw
  NativeBattleState.StatBox._krsOriginalDraw=nativeStatBoxDraw
  NativeBattleState.StatBox.draw=function(state,...)
    -- Progression/timing remains entirely native, but the Gen 1 stats box is
    -- presentation-only. In Wide KRS battles suppress that draw so a Voxel
    -- background cannot show the vanilla box through our translucent level-up
    -- modal. BattlePresenter renders the canonical KRS LEVEL UP surface later
    -- in render.hud while StatBox:update still owns dismissal/onDone.
    if MenuLayout.isWide(runtime.viewport) and state and state.game then
      if runtime.BattlePresenter and runtime.BattlePresenter.handles(state.game) then return end
      if runtime.NativePresenter and runtime.NativePresenter.handles(state.game,state) then return end
    end
    return nativeStatBoxDraw(state,...)
  end

  -- SHIFT-style trainer replacement is one semantic prompt in KRS. The Gen 1
  -- engine emits it as two queue entries (ABOUT TO USE, then WILL ... CHANGE?)
  -- with hard page-control bytes. Preserve the exact battle decision/callback,
  -- but fuse the presentation into one responsive dialogue row and give the
  -- choices action names instead of generic YES/NO.
  local nativeBattleSay=NativeBattleState._krsOriginalSay or NativeBattleState.say
  local nativeBattleSayChoice=NativeBattleState._krsOriginalSayChoice or NativeBattleState.sayChoice
  NativeBattleState._krsOriginalSay=nativeBattleSay
  NativeBattleState._krsOriginalSayChoice=nativeBattleSayChoice
  local function cleanBattlePromptText(value)
    return tostring(value or ''):gsub('[\v\f\n]',' '):gsub('%s+',' ')
      :gsub('^%s+',''):gsub('%s+$','')
  end
  NativeBattleState.say=function(state,text)
    local raw=tostring(text or '')
    if state and state.kind=='trainer' and raw:find(' is\nabout to use\v',1,false) then
      state._krsPendingShiftPrompt=raw
      return
    end
    if state and state._krsPendingShiftPrompt then
      nativeBattleSay(state,state._krsPendingShiftPrompt)
      state._krsPendingShiftPrompt=nil
    end
    return nativeBattleSay(state,text)
  end
  NativeBattleState.sayChoice=function(state,text,onChoose)
    local pending=state and state._krsPendingShiftPrompt
    local raw=tostring(text or '')
    if pending and raw:find('change POK',1,true) then
      state._krsPendingShiftPrompt=nil
      local merged=cleanBattlePromptText(pending)..' '..cleanBattlePromptText(raw)
      nativeBattleSayChoice(state,merged,onChoose)
      local row=state.queue and state.queue[#state.queue]
      if row then
        row._krsUnifiedShift=true
        row._krsChoiceLabels={'CHANGE',"DON'T CHANGE"}
      end
      return
    end
    if pending then nativeBattleSay(state,pending);state._krsPendingShiftPrompt=nil end
    return nativeBattleSayChoice(state,text,onChoose)
  end

  local nativeBattleUpdate=NativeBattleState._krsOriginalUpdate or NativeBattleState.update
  NativeBattleState._krsOriginalUpdate=nativeBattleUpdate
  NativeBattleState.update=function(state,dt)
    local wide=state and not state.demo and MenuLayout.isWide(runtime.viewport)
    local input=state and state.game and state.game.input
    if wide and input and type(input.wasPressed)=="function"
        and (state.phase=="menu" or state.phase=="moveSelect") then
      local old=input.wasPressed
      local left=old(input,"left") == true
      local right=old(input,"right") == true
      local up=old(input,"up") == true
      local down=old(input,"down") == true
      if state.phase=="menu" then
        if left then state.menuIndex=(tonumber(state.menuIndex) or 1)>1 and state.menuIndex-1 or 4
        elseif right then state.menuIndex=(tonumber(state.menuIndex) or 1)<4 and state.menuIndex+1 or 1 end
      else
        local count=state.player and state.player.curMoves and #state.player.curMoves or 0
        if count>0 then
          if up then state.moveIndex=(tonumber(state.moveIndex) or 1)>1 and state.moveIndex-1 or count
          elseif down then state.moveIndex=(tonumber(state.moveIndex) or 1)<count and state.moveIndex+1 or 1 end
        end
      end
      input.wasPressed=function(self,action)
        if action=="left" or action=="right" or action=="up" or action=="down" then return false end
        return old(self,action)
      end
      local packed={xpcall(function() return nativeBattleUpdate(state,dt) end,tostring)}
      input.wasPressed=old
      if not packed[1] then error(packed[2],0) end
      return unpack(packed,2)
    end
    return nativeBattleUpdate(state,dt)
  end

  -- Poké Mart BUY/SELL lists embed the clerk line directly in ListMenu:draw,
  -- rather than using TextBox. Preserve the native list and money box, but
  -- suppress only its bottom dialogue border/text so the same KRS panel can
  -- be painted in render.hud. This temporary Font.drawBox interposition is
  -- scoped to one draw call and always restored.
  NativeListMenu.draw=function(state,...)
    local game=state and state.game or runtime.game
    if state and runtime.ScriptMenuPresenter and runtime.ScriptMenuPresenter.handles(game,state,runtime.viewport) then return end
    if not runtime.DialogueAdapter.shopFooterSupported(state,runtime.viewport) then
      return nativeListMenuDraw(state,...)
    end
    local footer=state.footer
    local drawBox=NativeFont.drawBox
    state.footer=nil
    NativeFont.drawBox=function(tx,ty,tw,th,...)
      if tx==0 and ty==12 and tw==20 and th==6 then return end
      return drawBox(tx,ty,tw,th,...)
    end
    local packed={pcall(nativeListMenuDraw,state,...)}
    NativeFont.drawBox=drawBox
    state.footer=footer
    if not packed[1] then error(packed[2],0) end
    return unpack(packed,2)
  end

  -- Script commands are the authoritative event timeline. Resolve the speaker
  -- from the exact text key (or the runner's current NPC) before show_text/ask
  -- pushes its TextBox. This prevents a starter ball, an earlier actor or an
  -- Oak's Lab location prefix from leaking into the next dialogue.
  mod.hooks:wrap("script.command",function(next,ctx,name,args)
    local record
    if (name=="show_text" or name=="ask") and type(args)=="table" then
      local textKey=args[1]
      local game=ctx and ctx.game or runtime.game
      local speaker,handled
      if runtime.CharacterNames and type(runtime.CharacterNames.eventSpeaker)=="function" then
        local ok,a,b=pcall(runtime.CharacterNames.eventSpeaker,game,textKey)
        if ok then speaker,handled=a,b==true end
      end
      if not handled and runtime.CharacterNames and ctx and ctx.npc
          and type(runtime.CharacterNames.npc)=="function" then
        local mapId=ctx.overworld and ctx.overworld.map and ctx.overworld.map.id
        local ok,value=pcall(runtime.CharacterNames.npc,game,ctx.npc,{mapId=mapId})
        if ok and value then speaker=value;handled=true end
      end
      if not handled and runtime.CharacterNames and type(runtime.CharacterNames.fromTextKey)=="function" then
        local ok,value=pcall(runtime.CharacterNames.fromTextKey,game,textKey)
        if ok and value then speaker=value;handled=true end
      end
      record={textKey=textKey,speaker=speaker,handled=handled==true}
      runtime.pendingScriptDialogue=record
      runtime.pendingSpeakerHint=nil
    end
    local result={next(ctx,name,args)}
    if record and runtime.pendingScriptDialogue==record then runtime.pendingScriptDialogue=nil end
    return unpack(result)
  end,360)

  -- Do not prepare presentation on screen.pushed: world.interacted is emitted
  -- later in the same overworld step. The event speaker metadata itself is
  -- safe to attach here, before the first glyph, and is locked to the exact
  -- script command so the later interaction notification cannot replace it.
  mod.events:on("screen.pushed",function(payload)
    local state=payload and payload.state
    if state and state.game then runtime.game=state.game end
    if state and getmetatable(state)==NativeTextBox then
      local event=runtime.pendingScriptDialogue
      if event then
        state._krsTextKey=event.textKey
        state._krsEventSpeakerLocked=true
        state._krsInteractionKind="script"
        state._krsSpeaker=nil
        state._krsSpeakerHint=event.speaker
        runtime.pendingScriptDialogue=nil
        runtime.pendingSpeakerHint=nil
      elseif runtime.pendingSpeakerHint then
        state._krsSpeakerHint=runtime.pendingSpeakerHint
        runtime.pendingSpeakerHint=nil
      end
    end
  end)

  local function npcSpeakerHint(game,payload)
    local target=payload and payload.target
    if not (runtime.CharacterNames and target) then return nil end
    local ok,value=pcall(runtime.CharacterNames.npc,game,target,{mapId=payload and payload.mapId})
    return ok and value or nil
  end

  -- Trainer sight encounters can open their challenge TextBox without a
  -- world.interacted event. Capture the same stable identity at the public
  -- trainer-engagement seam so dialogue and the later battle header agree.
  mod.events:on("world.trainer_engaged",function(payload)
    local game=runtime.game
    if not runtime.CharacterNames then return end
    local ok,value=pcall(runtime.CharacterNames.trainer,game,payload and payload.trainerClass,{
      mapId=game and game.overworld and game.overworld.map and game.overworld.map.id,
      npcId=payload and payload.npc and payload.npc.id,partyIndex=payload and payload.partyIndex})
    if ok and value then runtime.pendingSpeakerHint=value end
  end)

  local function activeOverworldTextBox(game)
    local states=game and game.stack and game.stack.states
    if type(states)~="table" then return nil end
    local state=states[#states]
    if getmetatable(state)==NativeTextBox then return state end
    if getmetatable(state)==NativeChoiceBox and state.anchor=="bottom" then
      local text=states[#states-1]
      if getmetatable(text)==NativeTextBox and type(text.choice)=="function" then return text end
    end
    return nil
  end

  mod.events:on("world.interacted",function(payload)
    local game=runtime.game
    local kind=payload and payload.kind or nil
    local hint=kind=="npc" and npcSpeakerHint(game,payload) or nil
    -- This event is authoritative for the current A press. Invalidate any
    -- sight-encounter hint left over from an earlier dialogue before looking
    -- through a bottom-anchored YES/NO overlay for its TextBox owner.
    runtime.pendingSpeakerHint=nil
    local state=activeOverworldTextBox(game)
    if not state then
      if hint then runtime.pendingSpeakerHint=hint end
      return
    end
    if state._krsEventSpeakerLocked then return end
    state._krsInteractionKind=kind
    state._krsSpeaker=nil
    state._krsSpeakerHint=hint
  end)

  -- Menu pointer layer. Core dispatch owns the complete physical pointer
  -- sequence, so a press that pushes Bag/Link/etc cannot replay its release
  -- into the new state.
  if runtime.unregisterMenuInput then pcall(runtime.unregisterMenuInput) end
  runtime.unregisterMenuInput=foundation.registerInputLayer({
    id="kanto_rework_ui.menus",priority=220,
    active=function(game)
      local s=top(game)
      return s and (s.kind=="krs_title" or s.kind=="main" or s.kind=="options" or s.kind=="mods" or s.kind=="controls" or s.kind=="mod_extension" or s.kind=="save_slots" or s.kind=="krs_pokedex" or s.kind=="bag_register" or s.kind=="pc_storage" or s.kind=="graphics_editor")
        and (not s.isWide or s:isWide())
    end,
    pointer=function(game,event)
      local s=top(game);if not (s and type(s.pointerEvent)=="function") then return false end
      local lx,ly=MenuLayout.toLogical(runtime.viewport,event.x or 0,event.y or 0)
      return s:pointerEvent(event,lx,ly)==true
    end,
    wheel=function(game,dx,dy,x,y)
      local s=top(game);if not (s and type(s.wheel)=="function") then return false end
      local lx,ly=MenuLayout.toLogical(runtime.viewport,x or 0,y or 0)
      return s:wheel(dx,dy,lx,ly)==true
    end,
    keypressed=function(game,key,scancode,isrepeat)
      local s=top(game);if s and s.nav then runtime.Focus.syncDevice(s.nav) end
      if s and type(s.keypressed)=="function" then return s:keypressed(key,scancode,isrepeat)==true end
      return false
    end,
  })

  -- Wide native-menu pointer adapter. For handled semantic menus, KRS now
  -- owns update/navigation as well as presentation; native callbacks and data
  -- remain authoritative, with local fallback outside supported Wide states.
  if runtime.unregisterNativeMenuInput then pcall(runtime.unregisterNativeMenuInput) end
  runtime.unregisterNativeMenuInput=foundation.registerInputLayer({
    id="kanto_rework_ui.native_menus",priority=230,
    active=function(game) local s=top(game);return s and runtime.NativePresenter.handles(game,s) and MenuLayout.isWide(runtime.viewport) end,
    pointer=function(game,event) local lx,ly=MenuLayout.toLogical(runtime.viewport,event.x or 0,event.y or 0);return runtime.NativePresenter.pointer(game,event,lx,ly)==true end,
    wheel=function(game,dx,dy,x,y) local s=top(game);local lx,ly=MenuLayout.toLogical(runtime.viewport,x or 0,y or 0);return runtime.NativePresenter.wheel(game,s,dx,dy,lx,ly)==true end,
    keypressed=function(game,key) local s=top(game);return runtime.NativePresenter.keypressed(game,s,key)==true end,
  })

  -- Script-driven ListMenus keep the engine update/timeline owner. KRS only
  -- replaces their pixels and maps pointer input back to native actions.
  if runtime.unregisterScriptMenuInput then pcall(runtime.unregisterScriptMenuInput) end
  runtime.unregisterScriptMenuInput=foundation.registerInputLayer({
    id="kanto_rework_ui.script_menus",priority=231,
    active=function(game) local s=top(game);return s and runtime.ScriptMenuPresenter.handles(game,s,runtime.viewport) end,
    pointer=function(game,event) local lx,ly=MenuLayout.toLogical(runtime.viewport,event.x or 0,event.y or 0);return runtime.ScriptMenuPresenter.pointer(game,event,lx,ly)==true end,
    wheel=function(game,dx,dy) return runtime.ScriptMenuPresenter.wheel(game,dy)==true end,
    keypressed=function() return false end,
  })

  -- LinkState/Tournament keep their native transport and state-machine update;
  -- KRS supplies only the Wide themed pixels and pointer-to-native-action map.
  if runtime.unregisterLinkInput then pcall(runtime.unregisterLinkInput) end
  runtime.unregisterLinkInput=foundation.registerInputLayer({
    id="kanto_rework_ui.link",priority=232,
    active=function(game) local s=top(game);return s and runtime.LinkPresenter.handles(game,s) and MenuLayout.isWide(runtime.viewport) end,
    pointer=function(game,event) local lx,ly=MenuLayout.toLogical(runtime.viewport,event.x or 0,event.y or 0);return runtime.LinkPresenter.pointer(game,event,lx,ly)==true end,
    wheel=function(game,dx,dy,x,y) local lx,ly=MenuLayout.toLogical(runtime.viewport,x or 0,y or 0);return runtime.LinkPresenter.wheel(game,dy,lx,ly)==true end,
    keypressed=function() return false end,
  })

  -- Battle command/move-select presentation keeps BattleState update ownership.
  if runtime.unregisterBattleInput then pcall(runtime.unregisterBattleInput) end
  runtime.unregisterBattleInput=foundation.registerInputLayer({
    id="kanto_rework_ui.battle",priority=235,
    active=function(game)
      local s=top(game)
      -- The Live Graphics Editor is a modal state pushed above BattleState.
      -- Keep the battle renderer alive underneath, but never let the battle
      -- input layer (priority 235) pre-empt the editor/menu layer (220).
      if s and s.kind=='graphics_editor' then return false end
      return s and runtime.BattlePresenter.handles(game,s) and not runtime.NativePresenter.handles(game,s) and MenuLayout.isWide(runtime.viewport)
    end,
    pointer=function(game,event) local lx,ly=MenuLayout.toLogical(runtime.viewport,event.x or 0,event.y or 0);return runtime.BattlePresenter.pointer(game,event,lx,ly)==true end,
    wheel=function() return false end,keypressed=function(game,key) return runtime.BattlePresenter.keypressed(game,key)==true end,
  })

  -- Oak's Lab keeps the engine DexEntryMenu state for cry, A/B and onDone
  -- ownership; PokedexPresenter replaces only its Wide presentation with the
  -- KRS DATA frame and the selected Pokemon-art provider. This input bridge
  -- gives pointer/touch users the same exits and releases Voxel mouse capture.
  do
    local okDex,DexEntryMenu=pcall(require,'src.ui.DexEntryMenu')
    if runtime.unregisterStarterDexInput then pcall(runtime.unregisterStarterDexInput) end
    runtime.unregisterStarterDexInput=foundation.registerInputLayer({
      id='kanto_rework_ui.starter_dex_entry',priority=238,
      active=function(game)
        local s=top(game);return okDex and DexEntryMenu and s and getmetatable(s)==DexEntryMenu
          and MenuLayout.isWide(runtime.viewport)
      end,
      pointer=function(game,event)
        if event.phase~='pressed' then return true end
        if event.source=='mouse' and event.button==2 then mod.input:tap(game,'b');return true end
        if event.source=='touch' or event.button==1 then mod.input:tap(game,'a');return true end
        return true
      end,
      wheel=function() return true end,
      keypressed=function() return false end,
    })
  end

  -- Validated Party/Summary/Moves input layer from the real 0.1.3 source.
  if runtime.unregisterPartyInput then pcall(runtime.unregisterPartyInput) end
  runtime.unregisterPartyInput=foundation.registerInputLayer({
    id="kanto_rework_ui.party",priority=200,
    active=function(game) return runtime.state~=nil and PartyAdapter.topState(game)==runtime.state end,
    pointer=function(game,event) return PartyController:pointer(game,event) end,
    wheel=function(game,dx,dy,x,y) return PartyController:wheel(game,dx,dy,x,y) end,
    keypressed=function(game,key,scancode,isrepeat) return PartyController:keypressed(game,key,scancode,isrepeat) end,
  })

  -- Contextual popup/map/context pointer layer. These transient screens own
  -- the complete pointer sequence and expose the same focus model as keyboard
  -- and controller navigation.
  if runtime.unregisterTransientInput then pcall(runtime.unregisterTransientInput) end
  runtime.unregisterTransientInput=foundation.registerInputLayer({
    id="kanto_rework_ui.transient",priority=240,
    active=function(game)
      local s=top(game);return s and (s.kind=="field_actions_popup" or s.kind=="krs_map" or s.kind=="overlay_context" or s.kind=="overlay_layout")
    end,
    pointer=function(game,event)
      local s=top(game);if not(s and type(s.pointerEvent)=="function") then return false end
      local lx,ly=MenuLayout.toLogical(runtime.viewport,event.x or 0,event.y or 0)
      return s:pointerEvent(event,lx,ly)==true
    end,
    wheel=function(game,dx,dy,x,y)
      local s=top(game);if not(s and type(s.wheel)=="function") then return false end
      local lx,ly=MenuLayout.toLogical(runtime.viewport,x or 0,y or 0)
      return s:wheel(dx,dy,lx,ly)==true
    end,
    keypressed=function(game,key,scancode,isrepeat)
      local s=top(game);if s and s.nav then runtime.Focus.syncDevice(s.nav,s.activeId and s:activeId() or nil) end
      if s and type(s.keypressed)=='function' then return s:keypressed(key,scancode,isrepeat)==true end
      return false
    end,
  })

  -- Engine NamingScreen keeps its gameplay callbacks and glyph buffer. KRS
  -- owns only Wide presentation and pointer/touch mapping; Core text_input
  -- continues to capture physical keyboard events exclusively.
  if runtime.unregisterNamingInput then pcall(runtime.unregisterNamingInput) end
  runtime.unregisterNamingInput=foundation.registerInputLayer({
    id="kanto_rework_ui.naming",priority=246,
    active=function(game) return runtime.NamingPresenter.handles(game,runtime.viewport) end,
    pointer=function(game,event) local lx,ly=MenuLayout.toLogical(runtime.viewport,event.x or 0,event.y or 0);return runtime.NamingPresenter.pointer(game,event,lx,ly)==true end,
    wheel=function() return true end,
    keypressed=function() return false end,
  })

  -- Native TextBox / ChoiceBox keep keyboard/controller update ownership.
  -- This layer only maps pointer/touch hit testing to the KRS panel and
  -- integrated YES/NO rows.
  if runtime.unregisterDialogueInput then pcall(runtime.unregisterDialogueInput) end
  runtime.unregisterDialogueInput=foundation.registerInputLayer({
    id="kanto_rework_ui.overworld_dialogue",priority=245,
    active=function(game)
      local s=top(game)
      local text,choice=runtime.DialogueAdapter.choicePair(game,runtime.viewport)
      if choice and s==choice then return true end
      local _,shopOverlay=runtime.DialogueAdapter.shopContext(game,runtime.viewport)
      if shopOverlay==s and getmetatable(shopOverlay)==NativeChoiceBox then return true end
      return s and not runtime.dialogueFailed[s]
        and runtime.DialogueAdapter.isSupported(game,s,runtime.viewport)
    end,
    pointer=function(game,event)
      local s=top(game);if not s then return false end
      local text,choice=runtime.DialogueAdapter.choicePair(game,runtime.viewport)
      local shopList,shopOverlay=runtime.DialogueAdapter.shopContext(game,runtime.viewport)
      local target=text or s
      local model
      if text then
        model=runtime.DialogueAdapter.model(text,choice)
      elseif shopList and getmetatable(shopOverlay)==NativeChoiceBox then
        choice=shopOverlay
        model=runtime.DialogueAdapter.shopFooterModel(shopList,choice)
      else
        model=runtime.DialogueAdapter.model(target,choice)
      end
      local lx,ly=MenuLayout.toLogical(runtime.viewport,event.x or 0,event.y or 0)
      local m=MenuLayout.metrics(runtime.viewport)
      local layout=runtime.DialoguePanel.layout(runtime,m,model)
      if event.phase=="moved" and choice and layout.choiceRects then
        for i,r in ipairs(layout.choiceRects) do if MenuLayout.contains(lx,ly,r) then choice.index=i;break end end
        return true
      end
      if event.phase=="pressed" then
        if event.source=="mouse" and event.button==2 then mod.input:tap(game,"b");return true end
        if choice and layout.choiceRects and (event.source=="touch" or event.button==1) then
          for i,r in ipairs(layout.choiceRects) do
            if MenuLayout.contains(lx,ly,r) then choice.index=i;mod.input:tap(game,"a");return true end
          end
          return true
        end
        if MenuLayout.contains(lx,ly,layout) and (event.source=="touch" or event.button==1) then
          mod.input:tap(game,"a")
        end
      end
      return true
    end,
    wheel=function() return true end,
    keypressed=function() return false end,
  })

  mod.events:on("game.ready",function(payload) runtime.game=payload and payload.game or runtime.game end)
  mod.events:on("mod.options_changed",function(payload)
    if not payload or payload.mod~=mod.id then return end
    -- Developer-only presentation controls moved to kanto_rework_dev.
  end)

  -- Party state installation remains screen-specific UI behavior. Core only
  -- owns shared input/data services.
  mod.hooks:wrap("input.step",function(next,game,dt)
    runtime.game=game
    if love and love.graphics and love.graphics.getDimensions then
      local w,h=love.graphics.getDimensions();runtime.viewport={width=w,height=h}
    end
    local before=top(game);restoreKrsMenuPointer(game,before);local overlayState=type(Core.overlayState)=="function" and Core.overlayState() or nil
    local overlayContext=before==game.overworld or (type(before)=="table" and (before.kind=="wild" or before.kind=="trainer" or before.kind=="link"))
    if overlayState and (not overlayState.visible or overlayState.contextMode) then runtime.overlayLayoutMode=false end
    if overlayState and overlayState.visible and overlayState.contextMode and overlayContext and MenuLayout.isWide(runtime.viewport) then
      game.stack:push(OverlayContextFactory.new(game));before=top(game)
    elseif before and before.kind=="overlay_context" and not(overlayState and overlayState.visible and overlayState.contextMode) then
      game.stack:pop();before=top(game)
    elseif runtime.overlayLayoutMode and overlayState and overlayState.visible and overlayContext and MenuLayout.isWide(runtime.viewport) then
      game.stack:push(OverlayLayoutFactory.new(game));before=top(game)
    elseif before and before.kind=="overlay_layout" and not(runtime.overlayLayoutMode and overlayState and overlayState.visible and not overlayState.contextMode) then
      game.stack:pop();before=top(game)
    end
    if not runtime.state and PartyLayout.supportsWide(runtime.viewport) then
      local ok,err=pcall(PartyController.ensureOpen,PartyController,game)
      if not ok then logFailure("Party UI",err) end
    end
    if runtime.quickPartyReorder and runtime.state and runtime.state.mode=="PartyBrowse" then
      runtime.quickPartyReorder=false
      pcall(PartyController.beginPartyReorder,PartyController,runtime.state)
    end
    local pcRoot=runtime.NativePresenter.pcRootKind and runtime.NativePresenter.pcRootKind(top(game))
    if pcRoot and game.input and type(game.input.wasPressed)=="function" then
      if game.input:wasPressed("left") then runtime.NativePresenter.cyclePC(game,-1)
      elseif game.input:wasPressed("right") then runtime.NativePresenter.cyclePC(game,1) end
    end
    local result=next(game,dt)
    local after=top(game);restoreKrsMenuPointer(game,after)
    -- Battle footer actions are real rebindable KRS actions, not labels only.
    -- Raw key ingress is consumed by BattlePresenter when it matches these
    -- bindings; execution happens here on the shared fixed-step action edge.
    local battleTop=after and (after.kind=='wild' or after.kind=='trainer' or after.kind=='link') and after or nil
    if battleTop and runtime.BattlePresenter and runtime.BattlePresenter.handles(game,battleTop) then
      if Core.inputActions.wasPressed('BATTLE_INFO') then runtime.battleInfoOpen=not runtime.battleInfoOpen end
      if Core.inputActions.wasPressed('LIVE_BATTLE_EDITOR') and runtime.GraphicsEditorFactory and runtime.GraphicsEditorFactory.new then
        game.stack:push(runtime.GraphicsEditorFactory.new(game,{liveBattle=true,battle=battleTop}));after=top(game)
      end
    end
    -- L1/LB and R1/RB are additive shortcuts. Existing arrow/d-pad navigation
    -- remains authoritative; battle Party deliberately opts out.
    local prevTab=Core.inputActions.wasPressed('UI_SUBMENU_PREV')
    local nextTab=Core.inputActions.wasPressed('UI_SUBMENU_NEXT')
    local lateral=(prevTab and -1) or (nextTab and 1) or nil
    if lateral and after then
      if after==runtime.state then pcall(PartyController.cycleSubmenu,PartyController,after,lateral)
      elseif after.__kantoPocketState then
        local st=after.__kantoPocketState;local n=#(st.pockets or {})
        if n>0 then local idx=((tonumber(st.pocketIndex or st.focusPocketIndex or 1)-1+lateral)%n)+1;if st.selectPocket then st.selectPocket(idx) end;st.pocketIndex=idx;st.focusPocketIndex=idx;st.uiRegion='items' end
      elseif after.kind=='mods' and type(after.cycleTab)=='function' then after:cycleTab(lateral)
      elseif after.kind=='options' and type(after.selectCategory)=='function' and type(after.categories)=='table' and #after.categories>0 then
        local idx=((tonumber(after.categoryIndex) or 1)-1+lateral)%#after.categories+1;after:selectCategory(idx)
      elseif after.kind=='krs_pokedex' and type(after.cycleView)=='function' then after:cycleView(lateral) end
    end
    if after and after==runtime.state and (Core.inputActions.wasPressed("FIELD_ACTIONS") or (game.input and (game.input:wasPressed("select") or game.input:wasPressed("f")))) then
      local nativeParty=after.partyState
      if game.stack:top()==after then game.stack:pop() end
      runtime.state=nil;foundation.clearFocus("kanto_rework_ui.party")
      PartyAdapter.closeNativeParty(game,nativeParty)
      after=top(game)
      if after==game.overworld and game.overworld and game.overworld.player and not game.overworld.player.moving then
        local fieldScreen=FieldActionsFactory.new(game);if fieldScreen then game.stack:push(fieldScreen);after=fieldScreen end
      end
    elseif after and after==runtime.state and (Core.inputActions.wasPressed("MAP") or (game.input and game.input:wasPressed("m"))) then
      local nativeParty=after.partyState
      if game.stack:top()==after then game.stack:pop() end
      runtime.state=nil;foundation.clearFocus("kanto_rework_ui.party")
      PartyAdapter.closeNativeParty(game,nativeParty)
      after=top(game)
      if after==game.overworld and game.overworld and game.overworld.player and not game.overworld.player.moving then
        game.stack:push(MapFactory.new(game))
      end
    end
    if after and after.__kantoPocketState and after.__kantoItemUseBattle~=true and Core.inputActions.wasPressed("BAG_REGISTER") and runtime.BagRegisterFactory then
      local row=after.items and after.items[after.index]
      if row and row.value then
        local def=game.data and game.data.items and game.data.items[row.value]
        local reg=runtime.BagRegisterFactory.new(game,row.value,def and def.name or row.label)
        if reg then game.stack:push(reg) end
      end
    end
    if Core.inputActions.wasPressed("OVERLAY_SCALE_CYCLE") then cycleOverlayScale(game) end
    if Core.inputActions.wasPressed("OVERLAY_COLLAPSE_TOGGLE") then runtime.toggleFocusedOverlay() end
    if Core.inputActions.wasPressed("OVERLAY_LAYOUT_ADJUST") and overlayState and overlayState.visible and not overlayState.contextMode then
      runtime.overlayLayoutMode=not runtime.overlayLayoutMode;runtime.overlayLayoutOperation="move"
    end
    local current=top(game)
    if current==game.overworld and game.overworld and game.overworld.player and not game.overworld.player.moving then
      local selectPressed = game.input and (game.input:wasPressed("select") or game.input:wasPressed("f"))
      if Core.inputActions.wasPressed("FIELD_ACTIONS") or selectPressed then
        local screen=FieldActionsFactory.new(game);if screen then game.stack:push(screen) end
      elseif Core.inputActions.wasPressed("MAP") or (game.input and game.input:wasPressed("m")) then
        game.stack:push(MapFactory.new(game))
      end
    end
    return result
  end,200)

  mod.hooks:wrap("render.zones",function(next,game,zones) runtime.game=game;return next(game,zones) end,200)

  -- Party still uses its established compose-time replacement.  Overworld
  -- dialogue must never clear uiCanvas: on the normal overworld path that
  -- canvas also contains the map itself.  Dialogue suppresses TextBox:draw
  -- above instead, leaving every non-dialogue pixel byte-for-byte intact.
  mod.hooks:wrap("render.compose",function(next,renderer,ctx)
    local handled=next(renderer,ctx)
    if handled==true then return handled end
    if love and love.graphics and ctx and ctx.uiCanvas
        and runtime.presenterReady and PartyPresenter:isSupported(runtime.game,runtime.viewport) then
      love.graphics.push("all")
      love.graphics.setCanvas(ctx.uiCanvas)
      love.graphics.clear(0,0,0,0)
      love.graphics.pop()
    end
    return handled
  end,200)

  mod.hooks:wrap("render.hud",function(next,game,viewport)
    runtime.game=game;runtime.viewport=viewport or runtime.viewport
    if runtime.WindowContract then runtime.windowContractFrame=runtime.WindowContract.reconcile(runtime.viewport) end
    if runtime.state and not PartyLayout.supportsWide(runtime.viewport) then
      if PartyAdapter.topState(game)==runtime.state then game.stack:pop() end
      runtime.state=nil;foundation.clearFocus("kanto_rework_ui.party")
    end
    local result=next(game,viewport);restoreKrsMenuPointer(game,top(game))
    runtime.presenterReady=false;runtime.menuReady=false;runtime.error=nil
    local introOk,introDrawn=pcall(runtime.IntroPresenter.draw,game,runtime.viewport)
    if introOk and introDrawn==true then runtime.menuReady=true
    elseif not introOk then logFailure('Oak intro presenter',introDrawn) end
    if not runtime.menuReady then
      local namingOk,namingDrawn=pcall(runtime.NamingPresenter.draw,game,runtime.viewport)
      if namingOk and namingDrawn==true then runtime.menuReady=true
      elseif not namingOk then logFailure('Naming presenter',namingDrawn) end
    end
    -- A truly non-16:9 drawable is outside KRS' supported presentation
    -- contract. Native states have already rendered through next(); stop here
    -- so no KRS menu, dialogue, battle or overlay is layered on top. The gate
    -- is frame-local and automatically clears as soon as 16:9 is restored.
    if runtime.windowContractFrame and runtime.windowContractFrame.fallback then return result end

    local menuOk,menuDrawn=pcall(runtime.MenuPresenter.draw,runtime,game,runtime.viewport)
    if menuOk then runtime.menuReady=menuDrawn==true else logFailure("Wide menu presenter",menuDrawn) end
    if not runtime.menuReady then
      local dexOk,dexDrawn=pcall(runtime.PokedexPresenter.draw,game,runtime.viewport)
      if dexOk then runtime.menuReady=dexDrawn==true else logFailure("Wide Pokédex presenter",dexDrawn) end
    end
    if not runtime.menuReady then
      local linkOk,linkDrawn=pcall(runtime.LinkPresenter.draw,game,runtime.viewport)
      if linkOk then runtime.menuReady=linkDrawn==true else logFailure("Wide Link presenter",linkDrawn) end
    end
    if not runtime.menuReady then
      local nativeOk,nativeDrawn=pcall(runtime.NativePresenter.draw,game,runtime.viewport)
      if nativeOk then runtime.menuReady=nativeDrawn==true else logFailure("Wide native menu presenter",nativeDrawn) end
    end
    if not runtime.menuReady then
      local scriptOk,scriptDrawn=pcall(runtime.ScriptMenuPresenter.draw,game,runtime.viewport)
      if scriptOk then runtime.menuReady=scriptDrawn==true else logFailure("Wide scripted menu presenter",scriptDrawn) end
    end

    if PartyLayout.supportsWide(runtime.viewport) then
      local ok,drawn=pcall(PartyPresenter.draw,PartyPresenter,game,runtime.viewport)
      if ok then runtime.presenterReady=drawn==true else logFailure("Party presenter",drawn) end
    end
    local battleHudMode=pcall(mod.options.get,mod.options,"replace_battle_ui") and mod.options:get("replace_battle_ui") or "floating"
    if battleHudMode=="journal" and not runtime.presenterReady and not runtime.menuReady then
      local battleOk,battleDrawn=pcall(runtime.BattlePresenter.draw,game,runtime.viewport)
      if battleOk then runtime.presenterReady=battleDrawn==true else logFailure("Battle presenter",battleDrawn) end
    end

    local dialogueState=top(game);runtime.dialogueRect=nil;runtime.dialogueReady=false
    local pairedText,pairedChoice=runtime.DialogueAdapter.choicePair(game,runtime.viewport)
    local textState=pairedText or dialogueState
    if textState and not runtime.dialogueFailed[textState]
        and runtime.DialogueAdapter.isSupported(game,textState,runtime.viewport) then
      local okDialogue,dialogueResult=pcall(function()
        local resolved=Palette.resolve(game)
        local m=MenuLayout.metrics(runtime.viewport)
        return runtime.DialoguePanel.draw(runtime,m,resolved.colors,runtime.DialogueAdapter.model(textState,pairedChoice,game))
      end)
      if okDialogue then runtime.dialogueRect=dialogueResult;runtime.dialogueReady=true
      else runtime.dialogueFailed[textState]=true;logFailure("Overworld dialogue presenter",dialogueResult) end
    else
      local shopList,shopOverlay=runtime.DialogueAdapter.shopContext(game,runtime.viewport)
      local nativeShopShown=runtime.menuReady and shopList~=nil
      if shopList and not nativeShopShown then
        local okFooter,footerResult=pcall(function()
          local resolved=Palette.resolve(game)
          local m=MenuLayout.metrics(runtime.viewport)
          local choice=getmetatable(shopOverlay)==NativeChoiceBox and shopOverlay or nil
          return runtime.DialoguePanel.draw(runtime,m,resolved.colors,runtime.DialogueAdapter.shopFooterModel(shopList,choice))
        end)
        if okFooter then runtime.dialogueRect=footerResult;runtime.dialogueReady=true
        else logFailure("Shop dialogue footer presenter",footerResult) end
      end
    end

    local okOverlay,overlayErr=pcall(runtime.ModularOverlays.draw,game,runtime.viewport)
    if not okOverlay then logFailure("Modular overlays",overlayErr) end
    local okInteraction,interactionErr=pcall(runtime.InteractionVisual.draw,game)
    if not okInteraction then logFailure("Interaction visual",interactionErr) end
    if runtime.glyphBoardEnabled then
      local okBoard,boardErr=pcall(GlyphTestBoard.draw,Palette.resolve(game),runtime.viewport)
      if not okBoard then logFailure("Glyph test board",boardErr) end
    end
    return result
  end,250)

  mod.exports.version=35
  mod.exports.release="0.8.58"
  mod.exports.scope={"TitleState","StartMenu","SaveSlots","PokedexMenu","OptionsMenu","ManagerState","ModExtension","KantoControls","PartyMenu","Summary","Moves","BagPresentation","BagRegister","ShopPresentation","PCPresentation","FieldActionsPopup","MapFly","OverworldDialogue","BattleCommands","ModularOverlays"}
  mod.exports.layout="wide-16:9"
  mod.exports.battleAnimationLayerContract=2
  mod.exports.windowContractStatus=function() return runtime.WindowContract and runtime.WindowContract.status() or nil end
  mod.exports.resolveSemanticColor=function(role) return Palette.role(Palette,runtime.game,role) end
  mod.exports.semanticColor=mod.exports.resolveSemanticColor
  mod.exports.activeAccessibilityProfile=function() return Palette.profile(Palette,runtime.game) end
  -- Explicit cross-mod surfaces for Compatibility/Dev; private sandbox globals
  -- are intentionally not used on Gen1Recomp 0.1.86+.
  mod.exports.krsOwnsPointerSurface=function(game,state)
    return runtime.krsOwnsPointerSurface and runtime.krsOwnsPointerSurface(game or runtime.game,state) or false
  end
  mod.exports.themeColors=function(game)
    if runtime.Theme and type(runtime.Theme.resolveAll)=="function" then
      local ok,value=pcall(runtime.Theme.resolveAll,runtime,game or runtime.game)
      if ok and type(value)=="table" then return value end
    end
    if runtime.Palette and type(runtime.Palette.resolve)=="function" then
      local ok,value=pcall(runtime.Palette.resolve,game or runtime.game)
      return ok and type(value)=="table" and (value.colors or value) or nil
    end
  end
  mod.exports.status=function()
    return {version="0.8.58",partyState=runtime.state and runtime.state.mode or nil,
      partyReady=runtime.presenterReady,menusReady=runtime.menuReady,dialogueReady=runtime.dialogueReady==true,error=runtime.error,
      debug=runtime.debugEnabled,visualProfile=runtime.visualProfile,colorMode=runtime.colorMode,
      fixtureEnabled=PartyController.fixtureEnabled,coreRelease=Core.release}
  end
  mod.log:info("Kanto Rework UI 0.8.58 loaded: Candidate.6 Live Editor scope/action/HUD boundary corrections enabled")
end
