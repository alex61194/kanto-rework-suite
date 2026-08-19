local Module={}
function Module.factory(runtime)
  local Sound=require('src.core.Sound')
  local Screen={};Screen.__index=Screen;Screen.isOpaque=true
  local function copy(v) if type(v)~='table' then return v end;local o={};for k,x in pairs(v) do o[k]=copy(x) end;return o end
  local function clamp(v,a,b) return math.max(a,math.min(b,tonumber(v) or a)) end
  local function graphicsExports()
    local h=runtime.mod and runtime.mod.find and runtime.mod.find('graphics') or nil
    return h and h.exports or nil
  end
  local function editorApi() local gx=graphicsExports();return gx and gx.graphicsEditor or nil end
  local function sound(game,name) pcall(Sound.play,game.data,name or 'Tink') end
  local function cap(s) s=tostring(s or ''):gsub('_',' ');return s:upper() end
  local function trainerPhaseFromTarget(target)
    local phase=tostring(target or ''):match('^trainer_([%a_]+)$')
    if phase=='intro' or phase=='battle' or phase=='post' then return phase end
    return nil
  end
  local function listIndex(list,value) for i,v in ipairs(list or {}) do if tostring(v)==tostring(value) then return i end end;return nil end
  local function cycle(list,value,delta)
    if #(list or {})==0 then return value end
    local i=listIndex(list,value) or 1;i=((i-1+(delta or 1))%#list)+1;return list[i]
  end
  local function phaseList(bg)
    if runtime.BattleBackgrounds and type(runtime.BattleBackgrounds.availablePeriods)=='function' then
      local p=runtime.BattleBackgrounds.availablePeriods(bg);if type(p)=='table' and #p>0 then return p end
    end
    return {'day'}
  end
  local function catalog()
    if runtime.BattleBackgrounds and type(runtime.BattleBackgrounds.previewCatalog)=='function' then
      local c=runtime.BattleBackgrounds.previewCatalog();if type(c)=='table' and #c>0 then return c end
    end
    return {{id='grass',label='GRASS',periods={'day'}}}
  end
  local function bgIds(c) local out={};for _,b in ipairs(c or {}) do out[#out+1]=b.id end;return out end
  local function bgLabel(c,id) for _,b in ipairs(c or {}) do if b.id==id then return b.label or cap(id) end end;return cap(id) end
  -- Stable Gen I preview representatives present in both front/back Gen5
  -- KRS providers. Authored Gen5 sheet extents make them useful small/medium/
  -- large stress presets without coupling the editor to an arbitrary battle.
  local PREVIEW_PRESETS={small='DIGLETT',medium='PIKACHU',large='SNORLAX'}
  local PREVIEW_ORDER={'small','medium','large'}
  local function presetForSpecies(species)
    species=tostring(species or ''):upper()
    for id,value in pairs(PREVIEW_PRESETS) do if value==species then return id end end
    return 'medium'
  end
  local function generationValues(side,species,mode)
    local gx=graphicsExports();if gx and type(gx.availablePokemonGenerations)=='function' then
      local ok,v=pcall(gx.availablePokemonGenerations,side,species,mode)
      if ok and type(v)=='table' then return v end
    end
    return {}
  end
  local function ensureModeAvailability(self,role)
    local cfg=self.working[role];if not cfg then return end
    local side=(role=='player' and cfg.orientation=='back') and 'back' or 'front'
    local gens=generationValues(side,self[role..'Species'],cfg.mode)
    if #gens==0 and cfg.mode=='animated' then cfg.mode='static';gens=generationValues(side,self[role..'Species'],'static') end
    if #gens>0 and not listIndex(gens,cfg.generation) then cfg.generation=gens[1] end
  end
  function Screen.new(game,opts)
    opts=type(opts)=='table' and opts or {}
    local api=assert(editorApi(),'Kanto Rework Graphics editor service unavailable')
    local c=catalog();local bg=(c[1] and c[1].id) or 'grass';for _,b in ipairs(c) do if b.id=='grass' then bg='grass';break end end
    local battle=opts.battle;local liveBattle=opts.liveBattle==true and battle~=nil
    if liveBattle and runtime.BattleBackgrounds and type(runtime.BattleBackgrounds.resolve)=='function' then
      local ok,v=pcall(runtime.BattleBackgrounds.resolve,game,battle)
      if ok and type(v)=='table' then bg=tostring(v.kind or v.file or bg) end
    end
    local periods=phaseList(bg);local phase='day';if liveBattle and runtime.BattleBackgrounds and type(runtime.BattleBackgrounds.resolve)=='function' then
      local ok,v=pcall(runtime.BattleBackgrounds.resolve,game,battle);if ok and type(v)=='table' and v.period then phase=v.period end
    elseif not listIndex(periods,'day') then phase=periods[1] or 'day' end
    local self=setmetatable({game=game,kind='graphics_editor',nav=runtime.Focus.new('kanto_rework_ui.graphics_editor'),scope=liveBattle and 'local' or 'global',catalog=c,background=bg,phase=phase,
      liveBattle=liveBattle,battle=battle,playerSpecies=liveBattle and battle.player and battle.player.mon and battle.player.mon.species or 'PIKACHU',opponentSpecies=liveBattle and battle.enemy and battle.enemy.mon and battle.enemy.mon.species or 'PIKACHU',playerPreset='medium',opponentPreset='medium',focusIndex=1,scrollY=0,popupX=48,popupY=108,popupW=610,popupH=860,popupDrag=nil,popupResize=nil,spriteDrag=nil,
      positionRole=nil,uiTarget='opponent_frame',trainerPreviewPhase='battle',gridEnabled=false,pressedRow=nil,dirty=false,uiDirty=false,notice=nil,pendingExitDiscard=false,locks={},activeProfile=api.snapshot and (api.snapshot(game).activeProfile or '') or '',profileChoice=nil},Screen)
    self.playerPreset=presetForSpecies(self.playerSpecies);self.opponentPreset=presetForSpecies(self.opponentSpecies)
    if liveBattle and api.resolve then self.working=copy(api.resolve(game,bg,phase)) else self.working=copy(api.global(game)) end;self.uiWorking=runtime.BattleLayoutConfig and runtime.BattleLayoutConfig.resolve(game) or {};ensureModeAvailability(self,'player');ensureModeAvailability(self,'opponent')
    self:captureSaved()
    runtime.Focus.navigation(self.nav,self:activeId());return self
  end
  function Screen:isWide() return runtime.Layout.isWide(runtime.viewport) end
  function Screen:activeId() return 'graphics:'..tostring(self.focusIndex) end
  function Screen:currentResolved()
    local api=editorApi();if self.scope=='local' and api and api.resolve then local v=api.resolve(self.game,self.background,self.phase);return v end
    return self.working
  end
  function Screen:markDirty() self.dirty=true;self.pendingExitDiscard=false;self.notice='LIVE PREVIEW · UNSAVED INTERACTION';return true end
  function Screen:commit()
    if not self.dirty then return true end
    local api=editorApi();if not api then return false end
    local ok,err
    if self.scope=='local' then ok,err=api.commitLocal(self.game,self.background,self.phase,self.working)
    else ok,err=api.commitGlobal(self.game,self.working) end
    if ok~=false then self.dirty=false;self.notice='SAVED';return true end
    self.notice='SAVE FAILED · '..tostring(err or 'UNKNOWN');return false
  end
  function Screen:markUiDirty() self.uiDirty=true;self.pendingExitDiscard=false;self.notice='LIVE UI PREVIEW · UNSAVED INTERACTION';return true end
  function Screen:commitUi()
    if not self.uiDirty then return true end
    local api=runtime.BattleLayoutConfig;if not(api and api.commit) then return false end
    local ok,err=api.commit(self.game,self.uiWorking);if ok~=false then self.uiDirty=false;self.notice='UI LAYOUT SAVED';return true end
    self.notice='UI SAVE FAILED · '..tostring(err or 'UNKNOWN');return false
  end
  function Screen:hasUnsaved() return self.dirty or self.uiDirty end
  function Screen:captureSaved()
    self.savedWorking=copy(self.working);self.savedUi=copy(self.uiWorking);self.pendingExitDiscard=false
    local api=editorApi();self.savedHadLocal=self.scope=='local' and api and api.hasLocal and api.hasLocal(self.game,self.background,self.phase)==true or false
  end
  function Screen:reload()
    local api=editorApi();if self.scope=='local' then self.working=copy(api.resolve(self.game,self.background,self.phase)) else self.working=copy(api.global(self.game)) end
    self.uiWorking=runtime.BattleLayoutConfig and runtime.BattleLayoutConfig.resolve(self.game) or copy(self.uiWorking or {})
    ensureModeAvailability(self,'player');ensureModeAvailability(self,'opponent')
  end
  function Screen:discardUnsaved()
    self.working=copy(self.savedWorking or self.working);self.uiWorking=copy(self.savedUi or self.uiWorking);self.dirty=false;self.uiDirty=false;self.positionRole=nil;self.spriteDrag=nil;self.sliderDrag=nil;self.pendingExitDiscard=false;self.notice='UNSAVED PREVIEW DISCARDED';sound(self.game);return true
  end
  function Screen:saveChanges()
    if not self:hasUnsaved() then self.notice='NO UNSAVED CHANGES';return true end
    local draftGraphics=copy(self.working);local draftUi=copy(self.uiWorking);local oldGraphics=copy(self.savedWorking or self.working)
    local graphicsWasDirty=self.dirty
    if graphicsWasDirty and not self:commit() then self.working=draftGraphics;self.uiWorking=draftUi;self.dirty=true;return false end
    if self.uiDirty and not self:commitUi() then
      if graphicsWasDirty then
        local api=editorApi();local rollbackOk=false
        if self.scope=='local' then
          if self.savedHadLocal then rollbackOk=api and api.commitLocal and api.commitLocal(self.game,self.background,self.phase,oldGraphics)~=false
          else rollbackOk=api and api.deleteLocal and api.deleteLocal(self.game,self.background,self.phase)~=false end
        else rollbackOk=api and api.commitGlobal and api.commitGlobal(self.game,oldGraphics)~=false end
        if not rollbackOk then self.notice='UI SAVE FAILED · GRAPHICS ROLLBACK FAILED' end
      end
      self.working=draftGraphics;self.uiWorking=draftUi;self.dirty=graphicsWasDirty;self.uiDirty=true;return false
    end
    self.working=draftGraphics;self.uiWorking=draftUi;self.dirty=false;self.uiDirty=false;self:captureSaved();self.notice='SCENE SETTINGS SAVED';sound(self.game);return true
  end
  function Screen:contextChangeAllowed()
    if not self:hasUnsaved() then return true end
    self.notice='SAVE OR DISCARD UNSAVED PREVIEW BEFORE CHANGING CONTEXT';sound(self.game);return false
  end
  function Screen:setScope(scope)
    scope=scope=='local' and 'local' or 'global';if scope==self.scope then return false end;if not self:contextChangeAllowed() then return false end
    self.scope=scope;self:reload();self:captureSaved();self.focusIndex=1;self.scrollY=0;sound(self.game);return true
  end
  function Screen:switchBackground(nextBg)
    if self.scope~='local' or nextBg==self.background then return false end;if not self:contextChangeAllowed() then return false end
    local previous=copy(self.working);self.background=nextBg
    local periods=phaseList(nextBg);if not listIndex(periods,self.phase) then self.phase=listIndex(periods,'day') and 'day' or periods[1] or 'day' end
    local api=editorApi();local hasLocal=api and api.hasLocal and api.hasLocal(self.game,self.background,self.phase)
    self:reload();self:captureSaved()
    if api and not hasLocal then self.working=previous;self.dirty=true;self.notice='NEW LOCAL DRAFT · SAVE OR DISCARD TO CONTINUE' end
    sound(self.game);return true
  end
  function Screen:switchPhase(nextPhase)
    if self.scope~='local' or nextPhase==self.phase then return false end;if not self:contextChangeAllowed() then return false end
    local previous=copy(self.working);self.phase=nextPhase
    local api=editorApi();local hasLocal=api and api.hasLocal and api.hasLocal(self.game,self.background,self.phase)
    self:reload();self:captureSaved()
    if api and not hasLocal then self.working=previous;self.dirty=true;self.notice='NEW LOCAL DRAFT · SAVE OR DISCARD TO CONTINUE' end
    sound(self.game);return true
  end
  function Screen:speciesHeightM(role)
    local species=self[role..'Species'];local def=self.game and self.game.data and self.game.data.pokemon and self.game.data.pokemon[species];local dex=def and def.dexEntry
    local metres=tonumber(dex and dex.heightM);if metres and metres>0 then return metres end
    local ft=tonumber(dex and dex.heightFt);local inch=tonumber(dex and dex.heightIn);if ft and inch then return (ft*12+inch)*0.0254 end
    return 1
  end
  function Screen:suggestion(role)
    local gx=graphicsExports();if not(gx and type(gx.placementAssistantSuggest)=='function') then return nil end
    local scene=type(gx.backgroundSpatialMetadata)=='function' and gx.backgroundSpatialMetadata(self.background) or {}
    local sideMeta=copy(scene[role=='opponent' and 'enemy' or 'player'] or {});sideMeta.perspectiveStrength=scene.perspectiveStrength
    local preview=runtime.graphicsEditorPreviewResult or {};local art=role=='player' and preview.playerArt or preview.opponentArt;local metrics=art and art.metrics or nil
    local bounds=runtime.graphicsEditorPreviewBounds and runtime.graphicsEditorPreviewBounds[role];local nativeW=tonumber(metrics and metrics.w) or tonumber(bounds and bounds.w) or 96;local nativeH=tonumber(metrics and metrics.h) or tonumber(bounds and bounds.h) or 96
    local anchor=runtime.graphicsEditorSceneAnchors and runtime.graphicsEditorSceneAnchors[role]
    local cfg=self.working[role] or {};local current={size=tonumber(cfg.size) or 0,position=copy(cfg.position or anchor)}
    local ok,value=pcall(gx.placementAssistantSuggest,{role=role,heightM=self:speciesHeightM(role),nativeWidth=nativeW,nativeHeight=nativeH,scene=scene,sideMeta=sideMeta,anchor=anchor,uiRects=runtime.graphicsEditorUiBounds,current=current})
    return ok and value or nil
  end
  function Screen:applySuggestion(role)
    if self:isLocked(role) then self.notice='LOCKED · '..role:upper();return false end
    local s=self:suggestion(role);if not(s and s.suggested) then self.notice='NO SUGGESTION AVAILABLE';return false end
    local cfg=self.working[role];cfg.size=s.suggested.size;cfg.position=copy(s.suggested.position);self:markDirty();self.notice=role:upper()..' SUGGESTION APPLIED · SAVE TO PERSIST';sound(self.game);return true
  end
  function Screen:profiles()
    local api=editorApi();local map=api and api.profiles and api.profiles(self.game) or {};local names={}
    for name in pairs(type(map)=='table' and map or {}) do names[#names+1]=name end;table.sort(names);return names
  end
  function Screen:profileName() local names=self:profiles();if #names==0 then return nil end;if not self.profileChoice or not listIndex(names,self.profileChoice) then self.profileChoice=names[1] end;return self.profileChoice end
  function Screen:promptName(title,initial,done)
    local NamingScreen=require('src.ui.NamingScreen')
    self.game.stack:push(NamingScreen.new(self.game,{title=title,maxLen=32,default=initial or '',onDone=function(name)
      name=tostring(name or ''):gsub('^%s+',''):gsub('%s+$','');if name~='' then done(name) end
    end}))
  end
  function Screen:rows()
    local rows={{kind='info',id='scene.source',label='SCENE SOURCE',value=self.liveBattle and 'LIVE BATTLE' or 'PREVIEW'}}
    rows[#rows+1]={kind='info',id='scene.edit_state',label='EDIT STATE',value=self:hasUnsaved() and 'UNSAVED LIVE PREVIEW' or 'SAVED CONFIGURATION'}
    rows[#rows+1]={kind='header',label='SESSION'}
    rows[#rows+1]={kind='action',id='session.save',label='SAVE CHANGES',disabled=not self:hasUnsaved()}
    rows[#rows+1]={kind='action',id='session.discard',label='DISCARD UNSAVED',disabled=not self:hasUnsaved()}
    rows[#rows+1]={kind='action',id='session.reset',label='RESET SCENE COMPOSITION'}
    rows[#rows+1]={kind='scope',label='SCOPE',value=self.scope=='global' and 'GLOBAL' or 'LOCAL'}
    if self.scope=='local' then
      rows[#rows+1]={kind='choice',id='background',label='BATTLE BACKGROUND',value=bgLabel(self.catalog,self.background),values=bgIds(self.catalog)}
      local phases=phaseList(self.background);rows[#rows+1]={kind='choice',id='phase',label='TIME STATE',value=cap(self.phase),values=phases,disabled=#phases<=1}
    end
    local bgcfg=self.working.background or {scale=100,offsetX=0,offsetY=0};self.working.background=bgcfg
    rows[#rows+1]={kind='header',label='BATTLE BACKGROUND'}
    rows[#rows+1]={kind='slider',id='background.scale',label='CROP / ZOOM',value=clamp(bgcfg.scale,100,140),min=100,max=140,suffix='%'}
    rows[#rows+1]={kind='background_position',id='background.offset',label='FRAMING OFFSET',value=('%d, %d'):format(bgcfg.offsetX or 0,bgcfg.offsetY or 0)}
    rows[#rows+1]={kind='action',id='background.reset',label='RESET BACKGROUND FRAMING'}
    rows[#rows+1]={kind='action',id='lock.background',label=self:isLocked('background') and 'UNLOCK BACKGROUND' or 'LOCK BACKGROUND'}
    rows[#rows+1]={kind='header',label='BATTLE UI'}
    local enemyOff=self.uiWorking and self.uiWorking.opponent_frame or {x=0,y=0}
    rows[#rows+1]={kind='ui_position',id='ui.opponent_frame',target='opponent_frame',label='ENEMY POKéMON INFO BOX',value=('%+d, %+d'):format(enemyOff.x or 0,enemyOff.y or 0)}
    rows[#rows+1]={kind='slider',id='ui.opponent_frame.scale',path='opponent_frame.scale',storage='ui',target='opponent_frame',label='ENEMY INFO BOX SCALE',value=clamp(enemyOff.scale or 100,50,150),min=50,max=150,suffix='%'}
    rows[#rows+1]={kind='action',id='ui.opponent_frame.reset',target='opponent_frame',label='RESET ENEMY INFO BOX'}
    rows[#rows+1]={kind='action',id='lock.ui:opponent_frame',target='opponent_frame',label=self:isLocked('ui:opponent_frame') and 'UNLOCK ENEMY INFO BOX' or 'LOCK ENEMY INFO BOX'}
    local playerOff=self.uiWorking and self.uiWorking.player_frame or {x=0,y=0}
    rows[#rows+1]={kind='ui_position',id='ui.player_frame',target='player_frame',label='PLAYER POKéMON INFO BOX',value=('%+d, %+d'):format(playerOff.x or 0,playerOff.y or 0)}
    rows[#rows+1]={kind='slider',id='ui.player_frame.scale',path='player_frame.scale',storage='ui',target='player_frame',label='PLAYER INFO BOX SCALE',value=clamp(playerOff.scale or 100,50,150),min=50,max=150,suffix='%'}
    rows[#rows+1]={kind='action',id='ui.player_frame.reset',target='player_frame',label='RESET PLAYER INFO BOX'}
    rows[#rows+1]={kind='action',id='lock.ui:player_frame',target='player_frame',label=self:isLocked('ui:player_frame') and 'UNLOCK PLAYER INFO BOX' or 'LOCK PLAYER INFO BOX'}
    local commandOff=self.uiWorking and self.uiWorking.command_list or {x=0,y=0,scale=100}
    rows[#rows+1]={kind='ui_position',id='ui.command_list',target='command_list',label='BATTLE ACTION MENU',value=('%+d, %+d'):format(commandOff.x or 0,commandOff.y or 0)}
    rows[#rows+1]={kind='slider',id='ui.command_list.scale',path='command_list.scale',storage='ui',target='command_list',label='ACTION MENU SCALE',value=clamp(commandOff.scale or 100,50,150),min=50,max=150,suffix='%'}
    rows[#rows+1]={kind='action',id='ui.command_list.reset',target='command_list',label='RESET ACTION MENU'}
    rows[#rows+1]={kind='action',id='lock.ui:command_list',target='command_list',label=self:isLocked('ui:command_list') and 'UNLOCK ACTION MENU' or 'LOCK ACTION MENU'}
    local commandLabels={fight='FIGHT',pokemon='POKéMON',bag='BAG',run='RUN'}
    for _,commandId in ipairs({'fight','pokemon','bag','run'}) do
      local target='command_'..commandId;local off=self.uiWorking and self.uiWorking[target] or {x=0,y=0}
      rows[#rows+1]={kind='ui_position',id='ui.'..target,target=target,label=commandLabels[commandId]..' POSITION',value=('%+d, %+d'):format(off.x or 0,off.y or 0)}
      rows[#rows+1]={kind='action',id='ui.'..target..'.reset',target=target,label='RESET '..commandLabels[commandId]..' POSITION'}
      rows[#rows+1]={kind='action',id='lock.ui:'..target,target=target,label=self:isLocked('ui:'..target) and ('UNLOCK '..commandLabels[commandId]) or ('LOCK '..commandLabels[commandId])}
    end
    local moveOff=self.uiWorking and self.uiWorking.move_menu or {x=0,y=0,scale=100}
    rows[#rows+1]={kind='ui_position',id='ui.move_menu',target='move_menu',label='MOVE SELECTION + DESCRIPTION',value=('%+d, %+d'):format(moveOff.x or 0,moveOff.y or 0)}
    rows[#rows+1]={kind='slider',id='ui.move_menu.scale',path='move_menu.scale',storage='ui',target='move_menu',label='MOVE MENU SCALE',value=clamp(moveOff.scale or 100,50,150),min=50,max=150,suffix='%'}
    rows[#rows+1]={kind='action',id='ui.move_menu.reset',target='move_menu',label='RESET MOVE MENU'}
    rows[#rows+1]={kind='action',id='lock.ui:move_menu',target='move_menu',label=self:isLocked('ui:move_menu') and 'UNLOCK MOVE MENU' or 'LOCK MOVE MENU'}
    rows[#rows+1]={kind='header',label='OPPONENT TRAINER'}
    local trainerStyle=self.uiWorking and self.uiWorking.trainer_style or {scale=100,animationSpeed=100}
    local trainerPhaseLabels={intro='INTRO',battle='BATTLE / PERSISTENT',post='POST-BATTLE'}
    rows[#rows+1]={kind='choice',id='trainer.preview_phase',label='PREVIEW TRAINER STATE',value=trainerPhaseLabels[self.trainerPreviewPhase] or 'BATTLE / PERSISTENT',values={'intro','battle','post'},trainerPhaseChoice=true}
    for _,phaseId in ipairs({'intro','battle','post'}) do
      local target='trainer_'..phaseId;local pos=self.uiWorking and self.uiWorking[target] or {x=phaseId=='battle' and 1580 or 1248,y=phaseId=='battle' and 350 or 280}
      rows[#rows+1]={kind='ui_position',id='ui.'..target,target=target,trainerPhase=phaseId,label='TRAINER '..trainerPhaseLabels[phaseId]..' POSITION',value=('%d, %d'):format(pos.x or 0,pos.y or 0)}
      rows[#rows+1]={kind='action',id='ui.'..target..'.reset',target=target,trainerPhase=phaseId,label='RESET TRAINER '..trainerPhaseLabels[phaseId]}
      rows[#rows+1]={kind='action',id='lock.ui:'..target,target=target,trainerPhase=phaseId,label=self:isLocked('ui:'..target) and ('UNLOCK TRAINER '..trainerPhaseLabels[phaseId]) or ('LOCK TRAINER '..trainerPhaseLabels[phaseId])}
    end
    rows[#rows+1]={kind='slider',id='ui.trainer_style.scale',path='trainer_style.scale',storage='ui',target='trainer_style',label='TRAINER SCALE',value=clamp(trainerStyle.scale or 100,25,200),min=25,max=200,suffix='%'}
    rows[#rows+1]={kind='slider',id='ui.trainer_style.animationSpeed',path='trainer_style.animationSpeed',storage='ui',target='trainer_style',label='TRAINER ANIMATION SPEED',value=clamp(trainerStyle.animationSpeed or 100,10,200),min=10,max=200,suffix='%'}
    rows[#rows+1]={kind='action',id='trainer.reset_all',label='RESET ALL TRAINER COMPOSITION'}
    local function roleRows(role,label)
      local cfg=self.working[role];rows[#rows+1]={kind='header',label=label}
      if not self.liveBattle then rows[#rows+1]={kind='choice',id=role..'.preset',label='PREVIEW SIZE PRESET',value=cap(self[role..'Preset'] or presetForSpecies(self[role..'Species'])),values=PREVIEW_ORDER} end
      if role=='player' then rows[#rows+1]={kind='choice',id='player.orientation',label='ORIENTATION',value=cfg.orientation=='front_mirrored' and 'FRONT · MIRRORED' or 'BACK SPRITE',values={'back','front_mirrored'}} end
      local side=(role=='player' and cfg.orientation=='back') and 'back' or 'front'
      local modes={};if #generationValues(side,self[role..'Species'],'static')>0 then modes[#modes+1]='static' end;if #generationValues(side,self[role..'Species'],'animated')>0 then modes[#modes+1]='animated' end
      rows[#rows+1]={kind='choice',id=role..'.mode',label='ANIMATION',value=cap(cfg.mode),values=modes,disabled=#modes<=1}
      local gens=generationValues(side,self[role..'Species'],cfg.mode)
      rows[#rows+1]={kind='choice',id=role..'.generation',label='GENERATION / PROVIDER',value=#gens>0 and cap(cfg.generation) or 'NO COMPATIBLE SOURCE',values=gens,disabled=#gens==0}
      rows[#rows+1]={kind='slider',id=role..'.size',label='SIZE',value=clamp(cfg.size,0,100),min=0,max=100,suffix='%'}
      if cfg.mode=='animated' then rows[#rows+1]={kind='slider',id=role..'.animationSpeed',label='ANIMATION SPEED',value=clamp(cfg.animationSpeed,0,100),min=0,max=100,suffix='%'} end
      rows[#rows+1]={kind='position',id=role..'.position',role=role,label='POSITION',value=cfg.position and (('%d, %d'):format(cfg.position.x or 0,cfg.position.y or 0)) or 'AUTHORED DEFAULT'}
      rows[#rows+1]={kind='action',id=role..'.reset_placement',role=role,label='RESET POSITION / SIZE'}
      rows[#rows+1]={kind='action',id='lock.'..role,role=role,label=self:isLocked(role) and ('UNLOCK '..role:upper()) or ('LOCK '..role:upper())}
    end
    roleRows('player','PLAYER');roleRows('opponent','OPPONENT')
    rows[#rows+1]={kind='header',label='SIZE / PLACEMENT ASSISTANT'}
    for _,role in ipairs({'player','opponent'}) do
      local sug=self:suggestion(role);local cfg=self.working[role] or {};local pos=cfg.position
      local current=('SIZE %d%% · %s'):format(tonumber(cfg.size) or 0,pos and (('%d, %d'):format(pos.x or 0,pos.y or 0)) or 'AUTHORED')
      local sv=sug and sug.suggested;local suggested=sv and (('SIZE %d%% · %d, %d'):format(sv.size or 0,sv.position.x or 0,sv.position.y or 0)) or 'UNAVAILABLE'
      rows[#rows+1]={kind='info',id='assistant.'..role..'.current',label=role:upper()..' · CURRENT',value=current}
      rows[#rows+1]={kind='info',id='assistant.'..role..'.suggested',label=role:upper()..' · SUGGESTED',value=suggested}
      rows[#rows+1]={kind='action',id='assistant.'..role..'.apply',role=role,label='APPLY '..role:upper()..' SUGGESTION',disabled=sv==nil}
      rows[#rows+1]={kind='action',id='assistant.'..role..'.reset',role=role,label='RESET '..role:upper()..' PLACEMENT'}
    end
    if self.scope=='global' then
      local profile=self:profileName();rows[#rows+1]={kind='header',label='GLOBAL PROFILES'}
      rows[#rows+1]={kind='choice',id='profile',label='PROFILE',value=profile or 'NO SAVED PROFILE',values=self:profiles(),disabled=profile==nil}
      rows[#rows+1]={kind='action',id='profile.save',label='SAVE GLOBAL PROFILE'}
      rows[#rows+1]={kind='action',id='profile.load',label='LOAD PROFILE',disabled=profile==nil}
      rows[#rows+1]={kind='action',id='profile.rename',label='RENAME PROFILE',disabled=profile==nil}
      rows[#rows+1]={kind='action',id='profile.delete',label='DELETE PROFILE',disabled=profile==nil}
    else
      rows[#rows+1]={kind='header',label='LOCAL CHECKPOINT'}
      rows[#rows+1]={kind='action',id='local.save',label='SAVE CURRENT'}
      rows[#rows+1]={kind='action',id='local.save_all',label='SAVE ALL'}
    end
    rows[#rows+1]={kind='header',label='DEBUG / TARGETING'}
    rows[#rows+1]={kind='choice',id='debug.grid',label='GRID (TAB)',value=self.gridEnabled and 'ON' or 'OFF',values={'off','on'}}
    rows[#rows+1]={kind='info',id='debug.z',label='Z / DEPTH',value='N/A · RENDER ORDER ONLY',disabled=true}
    return rows
  end
  function Screen:selectableRows() local out={};for i,r in ipairs(self:rows()) do if r.kind~='header' and not r.disabled and r.kind~='info' then out[#out+1]=i end end;return out end
  function Screen:listViewportHeight() return math.max(220,(tonumber(self.popupH) or 860)-206) end
  function Screen:listMetrics()
    local rows=self:rows();local y=0;local tops={};local heights={}
    for i,row in ipairs(rows) do local h=row.kind=='header' and 30 or 52;tops[i]=y;heights[i]=h;y=y+h end
    return y,tops,heights
  end
  function Screen:ensureFocusVisible()
    local total,tops,heights=self:listMetrics();local viewportH=self:listViewportHeight();local top=tops[self.focusIndex] or 0;local bottom=top+(heights[self.focusIndex] or 52)
    if top<self.scrollY then self.scrollY=top elseif bottom>self.scrollY+viewportH then self.scrollY=bottom-viewportH end
    self.scrollY=clamp(self.scrollY,0,math.max(0,total-viewportH));return self.scrollY
  end
  function Screen:clampFocus()
    local rows=self:rows();local changed=false
    if not rows[self.focusIndex] or rows[self.focusIndex].kind=='header' or rows[self.focusIndex].kind=='info' or rows[self.focusIndex].disabled then
      for i,r in ipairs(rows) do if r.kind~='header' and r.kind~='info' and not r.disabled then self.focusIndex=i;changed=true;break end end
    end
    local clamped=math.max(1,math.min(#rows,self.focusIndex));if clamped~=self.focusIndex then self.focusIndex=clamped;changed=true end
    -- Do not force NAVIGATION mode every frame. Pointer intent is owned by
    -- Core InputMode and must survive while the mouse is actually editing.
    if changed then runtime.Focus.navigation(self.nav,self:activeId()) end
    return changed
  end
  function Screen:moveFocus(delta)
    local rows=self:rows();local i=self.focusIndex
    repeat i=i+(delta<0 and -1 or 1);if i<1 then i=#rows elseif i>#rows then i=1 end until rows[i] and rows[i].kind~='header' and rows[i].kind~='info' and not rows[i].disabled
    self.focusIndex=i;local focused=rows[i];if focused and focused.target then self.uiTarget=focused.target;local tp=trainerPhaseFromTarget(focused.target);if tp then self.trainerPreviewPhase=tp end end
    self:ensureFocusVisible();runtime.Focus.navigation(self.nav,self:activeId());sound(self.game)
  end
  local function pathSet(root,path,value)
    local a,b=path:match('^([^.]+)%.(.+)$');if a and root[a] then root[a][b]=value;return true end;return false
  end
  function Screen:setSliderValue(row,value)
    if not row then return false end
    local root=row.storage=='ui' and self.uiWorking or self.working
    local path=row.path or row.id
    if not pathSet(root,path,value) then return false end
    if row.storage=='ui' then self.uiTarget=row.target or self.uiTarget;self:markUiDirty() else self:markDirty() end
    return true
  end
  function Screen:adjust(row,delta)
    if not row or row.disabled then return false end;delta=delta or 1
    if row.id=='background.scale' and self:isLocked('background') then self.notice='LOCKED · BACKGROUND';return false end
    local lockedRole=row.id and row.id:match('^(player)%.size$') or row.id and row.id:match('^(opponent)%.size$')
    if row.storage=='ui' and row.target then lockedRole='ui:'..row.target end
    if lockedRole and self:isLocked(lockedRole) then self.notice='LOCKED · '..lockedRole:upper();return false end
    if row.kind=='scope' then return self:setScope(self.scope=='global' and 'local' or 'global') end
    if row.id=='background' then return self:switchBackground(cycle(row.values,self.background,delta)) end
    if row.id=='phase' then return self:switchPhase(cycle(row.values,self.phase,delta)) end
    if row.id=='profile' then self.profileChoice=cycle(row.values,self:profileName(),delta);sound(self.game);return true end
    if row.id=='debug.grid' then self.gridEnabled=not self.gridEnabled;self.notice=self.gridEnabled and 'GRID ON · X/Y ARE RENDERER COORDINATES · Z N/A' or 'GRID OFF';sound(self.game);return true end
    if row.id=='trainer.preview_phase' then self.trainerPreviewPhase=cycle(row.values,self.trainerPreviewPhase,delta);self.uiTarget='trainer_'..self.trainerPreviewPhase;self.notice='TRAINER PREVIEW · '..self.trainerPreviewPhase:upper();sound(self.game);return true end
    local presetRole=row.id and row.id:match('^(player)%.preset$') or row.id and row.id:match('^(opponent)%.preset$')
    if presetRole then
      local current=self[presetRole..'Preset'] or presetForSpecies(self[presetRole..'Species'])
      local nextPreset=cycle(PREVIEW_ORDER,current,delta);self[presetRole..'Preset']=nextPreset;self[presetRole..'Species']=PREVIEW_PRESETS[nextPreset]
      ensureModeAvailability(self,presetRole);self.notice=presetRole:upper()..' PREVIEW · '..nextPreset:upper()..' · '..PREVIEW_PRESETS[nextPreset];sound(self.game);return true
    end
    if row.kind=='choice' then
      local a,b=row.id:match('^([^.]+)%.(.+)$');local cfg=a and self.working[a]
      if cfg then
        local current=cfg[b];local values=row.values or {};if #values==0 then return false end;cfg[b]=cycle(values,current,delta)
        if b=='mode' or b=='orientation' then ensureModeAvailability(self,a) end
        self:markDirty();sound(self.game);return true
      end
    elseif row.kind=='slider' then
      local keyFine=love and love.keyboard and (love.keyboard.isDown('lshift') or love.keyboard.isDown('rshift'))
      local padFine=self.game and self.game.input and type(self.game.input.isDown)=='function' and self.game.input:isDown('select')
      local step=(keyFine or padFine) and 1 or 5
      local value=clamp(row.value+delta*step,row.min,row.max);self:setSliderValue(row,value);sound(self.game);return true
    end
    return false
  end
  function Screen:defaultPosition(role)
    local b=runtime.graphicsEditorPreviewBounds and runtime.graphicsEditorPreviewBounds[role]
    if b then return {x=math.floor((b.groundX or (b.x+b.w/2))+.5),y=math.floor((b.groundY or (b.y+b.h))+.5)} end
    return role=='player' and {x=630,y=790} or {x=1400,y=570}
  end
  function Screen:isLocked(id) return self.locks and self.locks[id]==true end
  function Screen:toggleLock(id)
    if not id or id=='' then return false end;self.locks=self.locks or {};self.locks[id]=not self.locks[id];if self.locks[id] and (self.positionRole==id or self.positionRole==('ui:'..id)) then self.positionRole=nil end
    self.notice=(self.locks[id] and 'LOCKED · ' or 'UNLOCKED · ')..tostring(id):upper();sound(self.game);return true
  end
  function Screen:nudge(role,dx,dy,coarse)
    if self:isLocked(role) then self.notice='LOCKED · '..role:upper();return false end
    local cfg=self.working[role];if not cfg then return false end;cfg.position=cfg.position or self:defaultPosition(role);local step=coarse and 8 or 1
    cfg.position.x=clamp((cfg.position.x or 0)+dx*step,0,1920);cfg.position.y=clamp((cfg.position.y or 0)+dy*step,88,1016);self:markDirty();return true
  end
  function Screen:nudgeBackground(dx,dy,coarse)
    if self:isLocked('background') then self.notice='LOCKED · BACKGROUND';return false end
    local cfg=self.working.background or {scale=100,offsetX=0,offsetY=0};self.working.background=cfg;local step=coarse and 8 or 1
    cfg.offsetX=clamp((cfg.offsetX or 0)+dx*step,-320,320);cfg.offsetY=clamp((cfg.offsetY or 0)+dy*step,-180,180);self:markDirty();return true
  end
  function Screen:resetBackgroundFraming()
    self.working.background={scale=100,offsetX=0,offsetY=0};self.positionRole=nil;self:markDirty();self.notice='BACKGROUND FRAMING RESET';sound(self.game);return true
  end
  function Screen:uiMovementLimits(target,cfg,bounds)
    local trainer=trainerPhaseFromTarget(target)~=nil
    if trainer then return {minX=0,maxX=1920,minY=86,maxY=1016} end
    cfg=cfg or (self.uiWorking and self.uiWorking[target]) or {x=0,y=0}
    bounds=bounds or (runtime.graphicsEditorUiBounds and runtime.graphicsEditorUiBounds[target])
    if bounds then
      -- Derive legal offsets from the component's ACTUAL rendered bounds.
      -- This removes the former generic ±960/±540 walls while still keeping
      -- the complete component inside the full 1920×1080 screen. HUD/UI may
      -- therefore reach the true top/bottom edges instead of stopping at KRS
      -- header/footer boundaries that felt like invisible walls.
      local cx,cy=tonumber(cfg.x) or 0,tonumber(cfg.y) or 0
      return {
        minX=cx+(0-(tonumber(bounds.x) or 0)),
        maxX=cx+(1920-((tonumber(bounds.x) or 0)+(tonumber(bounds.w) or 0))),
        minY=cy+(0-(tonumber(bounds.y) or 0)),
        maxY=cy+(1080-((tonumber(bounds.y) or 0)+(tonumber(bounds.h) or 0))),
      }
    end
    -- Headless/pre-first-draw fallback: full scene-sized offsets, never the
    -- old half-screen clamp. The next rendered frame tightens to real bounds.
    return {minX=-1920,maxX=1920,minY=-1080,maxY=1080}
  end
  function Screen:nudgeUi(target,dx,dy,coarse)
    if self:isLocked('ui:'..tostring(target)) then self.notice='LOCKED · '..tostring(target):upper();return false end
    if not(self.uiWorking and self.uiWorking[target]) then return false end
    local cfg=self.uiWorking[target];local step=coarse and 8 or 1;local trainer=trainerPhaseFromTarget(target)~=nil
    local limits=self:uiMovementLimits(target,cfg)
    cfg.x=clamp((cfg.x or 0)+dx*step,limits.minX,limits.maxX)
    cfg.y=clamp((cfg.y or 0)+dy*step,limits.minY,limits.maxY)
    if trainer then self.trainerPreviewPhase=target:match('^trainer_(.+)$') end
    self.uiTarget=target;self:markUiDirty();return true
  end
  function Screen:resetUiTarget(target)
    if runtime.BattleLayoutConfig and runtime.BattleLayoutConfig.resetTarget then
      self.uiWorking=runtime.BattleLayoutConfig.resetTarget(self.uiWorking,target)
    else
      self.uiWorking[target]={x=0,y=0}
    end
    self.uiTarget=target;local tp=tostring(target):match('^trainer_(.+)$');if tp then self.trainerPreviewPhase=tp end
    self.positionRole=nil;self:markUiDirty();self.notice=target:upper()..' RESET';sound(self.game);return true
  end
  function Screen:resetSpritePlacement(role)
    local cfg=self.working[role];if not cfg then return false end
    local defaults=editorApi() and editorApi().defaults and editorApi().defaults() or nil
    local base=defaults and defaults[role] or nil
    cfg.position=nil;cfg.size=base and tonumber(base.size) or 0
    self.positionRole=nil;self:markDirty();self.notice=role:upper()..' POSITION / SIZE RESET';sound(self.game);return true
  end
  function Screen:resetSceneComposition()
    local defaults=editorApi() and editorApi().defaults and editorApi().defaults() or {}
    self.working.background=copy(defaults.background or {scale=100,offsetX=0,offsetY=0})
    for _,role in ipairs({'player','opponent'}) do local base=defaults[role] or {};self.working[role].position=nil;self.working[role].size=tonumber(base.size) or 0 end
    self.uiWorking=runtime.BattleLayoutConfig and runtime.BattleLayoutConfig.defaults and runtime.BattleLayoutConfig.defaults() or {opponent_frame={x=0,y=0,scale=100},player_frame={x=0,y=0,scale=100},command_list={x=0,y=0,scale=100},command_fight={x=0,y=0},command_pokemon={x=0,y=0},command_bag={x=0,y=0},command_run={x=0,y=0},move_menu={x=0,y=0,scale=100}}
    self.positionRole=nil;self:markDirty();self:markUiDirty();self.notice='SCENE COMPOSITION RESET · UNSAVED';sound(self.game);return true
  end
  function Screen:requestExit()
    if not self:hasUnsaved() then self.game.stack:pop();return true end
    if self.pendingExitDiscard then self:discardUnsaved();self.game.stack:pop();return true end
    self.pendingExitDiscard=true;self.notice='UNSAVED PREVIEW · BACK AGAIN TO DISCARD & EXIT';sound(self.game);return true
  end
  function Screen:activate(row)
    if not row or row.disabled then return false end
    if row.kind=='scope' or row.kind=='choice' then return self:adjust(row,1) end
    if row.kind=='slider' then self.notice='SLIDER · ←/→ STEP · SHIFT/SELECT = FINE';return self:adjust(row,1) end
    if row.kind=='position' then if self:isLocked(row.role) then self.notice='LOCKED · '..row.role:upper();return false end;self.positionRole=(self.positionRole==row.role) and nil or row.role;return true end
    if row.kind=='background_position' then if self:isLocked('background') then self.notice='LOCKED · BACKGROUND';return false end;self.positionRole=(self.positionRole=='background') and nil or 'background';return true end
    if row.kind=='ui_position' then local lid='ui:'..row.target;if self:isLocked(lid) then self.notice='LOCKED · '..row.target:upper();return false end;self.uiTarget=row.target;self.positionRole=(self.positionRole==lid) and nil or lid;return true end
    local api=editorApi();local id=row.id
    if id=='session.save' then return self:saveChanges() end
    if id=='session.discard' then return self:discardUnsaved() end
    if id=='session.reset' then return self:resetSceneComposition() end
    local lockId=id and id:match('^lock%.(.+)$');if lockId then return self:toggleLock(lockId) end
    local assistantApply=id and id:match('^assistant%.([%w_]+)%.apply$');if assistantApply then return self:applySuggestion(assistantApply) end
    local assistantReset=id and id:match('^assistant%.([%w_]+)%.reset$');if assistantReset then return self:resetSpritePlacement(assistantReset) end
    if id=='background.reset' then return self:resetBackgroundFraming() end
    if id=='trainer.reset_all' then
      for _,target in ipairs({'trainer_intro','trainer_battle','trainer_post','trainer_style'}) do self.uiWorking=runtime.BattleLayoutConfig.resetTarget(self.uiWorking,target) end
      self.trainerPreviewPhase='battle';self.uiTarget='trainer_battle';self.positionRole=nil;self:markUiDirty();self.notice='TRAINER COMPOSITION RESET';sound(self.game);return true
    end
    local uiReset=id and id:match('^ui%.([%w_]+)%.reset$');if uiReset then return self:resetUiTarget(uiReset) end
    local resetRole=id and id:match('^(player)%.reset_placement$') or id and id:match('^(opponent)%.reset_placement$')
    if resetRole then return self:resetSpritePlacement(resetRole) end
    if id=='profile.save' then self:promptName('PROFILE NAME?',self:profileName() or '',function(name) local ok,err=api.saveProfile(self.game,name,self.working);self.profileChoice=name;self.notice=ok and 'PROFILE SAVED' or tostring(err) end);return true end
    if id=='profile.load' then if not self:contextChangeAllowed() then return false end;local name=self:profileName();local ok,v=api.loadProfile(self.game,name);if ok then self.working=copy(v);self.dirty=false;self:captureSaved();self.notice='PROFILE LOADED' else self.notice='LOAD FAILED' end;return true end
    if id=='profile.rename' then local old=self:profileName();self:promptName('RENAME PROFILE?',old,function(name) local ok,err=api.renameProfile(self.game,old,name);if ok then self.profileChoice=name end;self.notice=ok and 'PROFILE RENAMED' or tostring(err) end);return true end
    if id=='profile.delete' then local name=self:profileName();local ok=api.deleteProfile(self.game,name);self.profileChoice=nil;self.notice=ok and 'PROFILE DELETED' or 'DELETE FAILED';return true end
    if id=='local.save' or id=='local.save_all' then local ok=self:saveChanges();if ok then self.notice=id=='local.save_all' and 'ALL LOCAL OVERRIDES COMMITTED' or 'CURRENT OVERRIDE SAVED' end;return ok end
    return false
  end
  function Screen:nativePressed(action)
    local Core=runtime.Core
    if Core and type(Core.nativeActionPressed)=='function' then
      local ok,value=pcall(Core.nativeActionPressed,action,self.game)
      if ok then return value==true end
    end
    local input=self.game and self.game.input
    return input and type(input.wasPressed)=='function' and input:wasPressed(action)==true or false
  end
  function Screen:update()
    if not self:isWide() then return end
    self:clampFocus();runtime.Focus.syncDevice(self.nav,self:activeId())
    local input=self.game.input;local row=self:rows()[self.focusIndex]
    local pressed=function(action) return self:nativePressed(action) end
    if self.positionRole then
      local coarse=type(input.isDown)=='function' and input:isDown('select')
      if pressed('b') or pressed('a') then self.positionRole=nil;return end
      local move=function(dx,dy) if self.positionRole=='background' then return self:nudgeBackground(dx,dy,coarse) end;local ui=self.positionRole and self.positionRole:match('^ui:(.+)$');if ui then return self:nudgeUi(ui,dx,dy,coarse) end;return self:nudge(self.positionRole,dx,dy,coarse) end
      if pressed('left') then move(-1,0) elseif pressed('right') then move(1,0)
      elseif pressed('up') then move(0,-1) elseif pressed('down') then move(0,1) end;return
    end
    if pressed('b') then self:requestExit();return end
    if pressed('up') then self:moveFocus(-1) elseif pressed('down') then self:moveFocus(1)
    elseif pressed('left') then self:adjust(row,-1) elseif pressed('right') then self:adjust(row,1)
    elseif pressed('a') then self:activate(row) end
  end
  function Screen:keypressed(key)
    if key=='tab' then self.gridEnabled=not self.gridEnabled;self.notice=self.gridEnabled and 'GRID ON · X/Y RENDERER COORDINATES · Z N/A' or 'GRID OFF';sound(self.game);return true end
    -- The editor is modal over battle: raw keys are consumed here so typing or
    -- adjustment cannot leak into BattleState. Numeric free-entry is intentionally absent.
    return true
  end
  local function hit(rects,x,y) for i,r in pairs(rects or {}) do if runtime.Layout.contains(x,y,r) then return i,r end end end
  function Screen:pointerEvent(event,lx,ly)
    if event.phase=='moved' and self.popupResize then
      local maxW=math.max(480,1920-self.popupX-8);local maxH=math.max(520,1016-self.popupY-8)
      self.popupW=clamp(self.popupResize.pw+lx-self.popupResize.x,480,math.min(1200,maxW))
      self.popupH=clamp(self.popupResize.ph+ly-self.popupResize.y,520,math.min(900,maxH))
      self:ensureFocusVisible();return true
    end
    if event.phase=='moved' and self.popupDrag then local w,h=self.popupW or 610,self.popupH or 860;self.popupX=clamp(self.popupDrag.px+lx-self.popupDrag.x,8,math.max(8,1920-w-8));self.popupY=clamp(self.popupDrag.py+ly-self.popupDrag.y,88,math.max(88,1016-h-8));return true end
    if event.phase=='moved' and self.spriteDrag then
      if self.spriteDrag.uiTarget then
        local target=self.spriteDrag.uiTarget;if self:isLocked('ui:'..target) then self.spriteDrag=nil;self.notice='LOCKED · '..target:upper();return true end;local cfg=self.uiWorking[target]
        local trainer=trainerPhaseFromTarget(target)~=nil;local limits=self.spriteDrag.limits or self:uiMovementLimits(target,cfg)
        cfg.x=clamp(self.spriteDrag.gx+lx-self.spriteDrag.x,limits.minX,limits.maxX);cfg.y=clamp(self.spriteDrag.gy+ly-self.spriteDrag.y,limits.minY,limits.maxY)
        if trainer then self.trainerPreviewPhase=target:match('^trainer_(.+)$') end
        self.uiTarget=target;self.positionRole='ui:'..target;self:markUiDirty();return true
      end
      local role=self.spriteDrag.role;if self:isLocked(role) then self.spriteDrag=nil;self.notice='LOCKED · '..role:upper();return true end;local cfg=self.working[role];cfg.position=cfg.position or self:defaultPosition(role);cfg.position.x=clamp(self.spriteDrag.gx+lx-self.spriteDrag.x,0,1920);cfg.position.y=clamp(self.spriteDrag.gy+ly-self.spriteDrag.y,88,1016);self.positionRole=role;self:markDirty();return true
    end
    if event.phase=='moved' and self.sliderDrag then
      local row=self:rows()[self.sliderDrag.index]
      local lr=self.sliderDrag.id=='background.scale' and 'background' or self.sliderDrag.id:match('^(player)%.size$') or self.sliderDrag.id:match('^(opponent)%.size$')
      if row and row.storage=='ui' and row.target then lr='ui:'..row.target end
      if lr and self:isLocked(lr) then self.sliderDrag=nil;self.notice='LOCKED · '..lr:upper();return true end
      local tr=runtime.graphicsEditorSliderTracks and runtime.graphicsEditorSliderTracks[self.sliderDrag.index]
      if tr and row then local pct=clamp((lx-tr.x)/tr.w,0,1);local lo,hi=tonumber(row.min) or 0,tonumber(row.max) or 100;self:setSliderValue(row,math.floor((lo+pct*(hi-lo))+.5)) end;return true
    end
    if event.phase=='released' or event.phase=='cancelled' then
      self.pressedRow=nil
      if self.popupResize then self.popupResize=nil;return true end
      if self.popupDrag then self.popupDrag=nil;return true end
      if self.spriteDrag then self.spriteDrag=nil;self.positionRole=nil;return true end
      if self.sliderDrag then self.sliderDrag=nil;return true end
    end
    if event.phase=='moved' then
      self.scopeHover=nil
      for _,scope in ipairs({'global','local'}) do local r=runtime.graphicsEditorScopeRects and runtime.graphicsEditorScopeRects[scope];if r and runtime.Layout.contains(lx,ly,r) then self.scopeHover=scope;break end end
      local i=hit(runtime.graphicsEditorRowRects,lx,ly);runtime.Focus.pointerMove(self.nav,i and ('graphics:'..i) or nil);return true
    end
    if event.phase~='pressed' then return true end
    if event.source=='mouse' and event.button==2 then return self:requestExit() end
    if not(event.source=='touch' or event.button==1) then return true end
    for _,scope in ipairs({'global','local'}) do
      local sr=runtime.graphicsEditorScopeRects and runtime.graphicsEditorScopeRects[scope]
      if sr and runtime.Layout.contains(lx,ly,sr) then self.scopePressed=scope;local ok=self:setScope(scope);self.scopePressed=nil;return ok or true end
    end
    local rh=runtime.graphicsEditorPopupResizeHandle;if rh and runtime.Layout.contains(lx,ly,rh) then self.popupResize={x=lx,y=ly,pw=self.popupW or 610,ph=self.popupH or 860};return true end
    local hdr=runtime.graphicsEditorPopupHeader;if hdr and runtime.Layout.contains(lx,ly,hdr) then self.popupDrag={x=lx,y=ly,px=self.popupX,py=self.popupY};return true end
    local b=runtime.graphicsEditorPreviewBounds
    for _,role in ipairs({'player','opponent'}) do local r=b and b[role];if r and runtime.Layout.contains(lx,ly,r) then if self:isLocked(role) then self.notice='LOCKED · '..role:upper();return true end;local p=self.working[role].position or self:defaultPosition(role);self.spriteDrag={role=role,x=lx,y=ly,gx=p.x,gy=p.y};self.positionRole=role;return true end end
    local ub=runtime.graphicsEditorUiBounds;local seen={}
    local uiPriority={'command_fight','command_pokemon','command_bag','command_run','move_menu','opponent_frame','player_frame','trainer_intro','trainer_battle','trainer_post','command_list'}
    for _,target in ipairs(uiPriority) do local r=ub and ub[target];seen[target]=true;if r and runtime.Layout.contains(lx,ly,r) then if self:isLocked('ui:'..target) then self.notice='LOCKED · '..target:upper();return true end;local o=self.uiWorking[target] or {x=0,y=0};self.spriteDrag={uiTarget=target,x=lx,y=ly,gx=o.x or 0,gy=o.y or 0,limits=self:uiMovementLimits(target,o,r)};self.uiTarget=target;self.positionRole='ui:'..target;return true end end
    for target,r in pairs(ub or {}) do if not seen[target] and r and runtime.Layout.contains(lx,ly,r) then if self:isLocked('ui:'..target) then self.notice='LOCKED · '..target:upper();return true end;local o=self.uiWorking[target] or {x=0,y=0};self.spriteDrag={uiTarget=target,x=lx,y=ly,gx=o.x or 0,gy=o.y or 0,limits=self:uiMovementLimits(target,o,r)};self.uiTarget=target;self.positionRole='ui:'..target;return true end end
    local i=hit(runtime.graphicsEditorRowRects,lx,ly);if i then self.focusIndex=i;self.pressedRow=i;runtime.Focus.pointerPress(self.nav,self:activeId());local row=self:rows()[i]
      if row and row.target then self.uiTarget=row.target;local tp=trainerPhaseFromTarget(row.target);if tp then self.trainerPreviewPhase=tp end end
      local track=runtime.graphicsEditorSliderTracks and runtime.graphicsEditorSliderTracks[i]
      if row and row.kind=='slider' and track and runtime.Layout.contains(lx,ly,track) then
        local lr=row.id=='background.scale' and 'background' or row.id:match('^(player)%.size$') or row.id:match('^(opponent)%.size$')
        if row.storage=='ui' and row.target then lr='ui:'..row.target end
        if lr and self:isLocked(lr) then self.notice='LOCKED · '..lr:upper();return true end
        local pct=clamp((lx-track.x)/track.w,0,1);local lo,hi=tonumber(row.min) or 0,tonumber(row.max) or 100;self:setSliderValue(row,math.floor((lo+pct*(hi-lo))+.5));self.sliderDrag={index=i,id=row.id};return true end
      return self:activate(row)
    end
    return true
  end
  function Screen:wheel(_,dy) if dy==0 then return false end;local total=self:listMetrics();self.scrollY=clamp(self.scrollY-dy*48,0,math.max(0,total-self:listViewportHeight()));return true end
  function Screen:previewPresets() return copy(PREVIEW_PRESETS) end
  function Screen:draw() end
  return Screen
end
return Module
