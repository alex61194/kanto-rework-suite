package.preload['src.core.Sound']=function()
  return {play=function() return true end}
end

local pressed={}
local focusMode='navigation'
local pointerTarget=nil
local runtime={
  viewport={w=1920,h=1080},
  Layout={
    isWide=function() return true end,
    contains=function(x,y,r) return r and x>=r.x and y>=r.y and x<=(r.x+r.w) and y<=(r.y+r.h) end,
  },
  Focus={
    new=function(owner) return {owner=owner} end,
    navigation=function(_,_) focusMode='navigation' end,
    syncDevice=function() return focusMode end,
    pointerMove=function(_,target) focusMode='pointer';pointerTarget=target end,
    pointerPress=function(_,target) focusMode='pointer';pointerTarget=target end,
  },
  Core={
    nativeActionPressed=function(action)
      if pressed[action] then pressed[action]=nil;return true end
      return false
    end,
  },
  BattleBackgrounds={
    previewCatalog=function() return {{id='grass',label='GRASS',periods={'day'}}} end,
    availablePeriods=function() return {'day'} end,
  },
  BattleLayoutConfig={
    defaults=function() return {opponent_frame={x=0,y=0,scale=100},player_frame={x=0,y=0,scale=100},command_list={x=0,y=0,scale=100},command_fight={x=0,y=0},command_pokemon={x=0,y=0},command_bag={x=0,y=0},command_run={x=0,y=0},move_menu={x=0,y=0,scale=100}} end,
    resolve=function() return {opponent_frame={x=0,y=0,scale=100},player_frame={x=0,y=0,scale=100},command_list={x=0,y=0,scale=100},command_fight={x=0,y=0},command_pokemon={x=0,y=0},command_bag={x=0,y=0},command_run={x=0,y=0},move_menu={x=0,y=0,scale=100}} end,
    resetTarget=function(config,target) config[target]={x=0,y=0};return config end,
  },
  mod={find=function(id)
    if id~='graphics' then return nil end
    local defaults={background={scale=100,offsetX=0,offsetY=0},player={mode='animated',generation='5',orientation='back',size=50,animationSpeed=50},opponent={mode='animated',generation='5',orientation='front',size=50,animationSpeed=50}}
    return {exports={
      availablePokemonGenerations=function() return {'5'} end,
      graphicsEditor={
        snapshot=function() return {activeProfile=''} end,
        global=function() return {background={scale=100,offsetX=0,offsetY=0},player={mode='animated',generation='5',orientation='back',size=50,animationSpeed=50},opponent={mode='animated',generation='5',orientation='front',size=50,animationSpeed=50}} end,
        resolve=function() return {background={scale=100,offsetX=0,offsetY=0},player={mode='animated',generation='5',orientation='back',size=50,animationSpeed=50},opponent={mode='animated',generation='5',orientation='front',size=50,animationSpeed=50}} end,
        hasLocal=function() return false end,
        defaults=function() return defaults end,
        profiles=function() return {} end,
      },
    }}
  end},
}

local game={
  input={wasPressed=function() return false end,isDown=function() return false end},
  data={},
  stack={popped=false,pop=function(self) self.popped=true end,push=function() end},
}

local Factory=assert(loadfile('../screens/graphics_editor.lua'))().factory(runtime)
local s=Factory.new(game)
s:clampFocus()
local start=s.focusIndex
assert(start>1,'editor should clamp initial info row to a selectable control')

-- Shared semantic action path: this is the same API Core resolves from a
-- keyboard binding or a controller button. No device-specific editor branch.
pressed.down=true;s:update()
assert(s.focusIndex~=start,'semantic DOWN must move editor focus')
local afterDown=s.focusIndex
pressed.up=true;s:update()
assert(s.focusIndex==start,'semantic UP must return editor focus')

-- A/B and arrows work through the same semantic resolver; activate RESET SCENE
-- to prove confirmation is reachable without a mouse.
for i,row in ipairs(s:rows()) do if row.id=='session.reset' then s.focusIndex=i;break end end
pressed.a=true;s:update()
assert(s.notice and s.notice:find('SCENE COMPOSITION RESET',1,true),'semantic A must activate focused control')

-- Mouse intent must survive the next update. Candidate.4 forced navigation mode
-- from clampFocus every frame, immediately erasing pointer focus.
runtime.graphicsEditorRowRects={[start]={x=10,y=10,w=200,h=50}}
s:pointerEvent({phase='moved',source='mouse'},20,20)
assert(focusMode=='pointer' and pointerTarget=='graphics:'..start,'mouse move must establish pointer focus')
s:update()
assert(focusMode=='pointer','editor update must not overwrite active pointer mode')

-- Slider pointer geometry must honor each row's min/max (background zoom is
-- 100..140, not 0..100). A midpoint click must therefore produce 120.
local sliderIndex
for i,row in ipairs(s:rows()) do if row.id=='background.scale' then sliderIndex=i;break end end
assert(sliderIndex,'background slider row missing')
runtime.graphicsEditorRowRects[sliderIndex]={x=10,y=70,w=300,h=52}
runtime.graphicsEditorSliderTracks={[sliderIndex]={x=100,y=80,w=200,h=20}}
s:pointerEvent({phase='pressed',source='mouse',button=1},200,90)
assert(s.working.background.scale==120,'slider pointer must map into declared 100..140 range')
s:pointerEvent({phase='moved',source='mouse',button=1},300,90)
assert(s.working.background.scale==140,'slider drag must reach declared max')
s:pointerEvent({phase='released',source='mouse',button=1},300,90)

-- Wheel scroll is device-agnostic and must consume while moving the settings
-- list, without requiring pointer-only controls.
s.popupH=520
local before=s.scrollY
assert(s:wheel(0,-1)==true,'wheel must be consumed')
assert(s.scrollY>before,'wheel must scroll settings viewport')


-- The visible GLOBAL/LOCAL segmented control must be a real pointer target,
-- not decoration. Off-battle opens Global; clicking Local must switch scope.
s.dirty=false;s.uiDirty=false;s:captureSaved()
runtime.graphicsEditorScopeRects={global={x=10,y=300,w=100,h=40},['local']={x=120,y=300,w=100,h=40}}
assert(s.scope=='global','off-battle editor should start Global')
s:pointerEvent({phase='moved',source='mouse'},150,320)
assert(s.scopeHover=='local','Local segment must expose hover state')
s:pointerEvent({phase='pressed',source='mouse',button=1},150,320)
assert(s.scope=='local','clicking visible Local segment must enter Local scope')
s:pointerEvent({phase='pressed',source='mouse',button=1},50,320)
assert(s.scope=='global','clicking visible Global segment must return Global scope')

-- Movement limits derive from actual rendered bounds. This specifically
-- guards Candidate.5's generic ±960/±540 wall: Player must move farther
-- right/up and Enemy farther left/down while remaining fully visible.
s.uiWorking.player_frame={x=960,y=-540,scale=100}
s.uiWorking.opponent_frame={x=-960,y=540,scale=100}
runtime.graphicsEditorUiBounds={
  player_frame={x=960,y=160,w=620,h=180},
  opponent_frame={x=340,y=680,w=620,h=180},
}
local pl=s:uiMovementLimits('player_frame',s.uiWorking.player_frame,runtime.graphicsEditorUiBounds.player_frame)
local en=s:uiMovementLimits('opponent_frame',s.uiWorking.opponent_frame,runtime.graphicsEditorUiBounds.opponent_frame)
assert(pl.maxX>960 and pl.minY<-540,'Player HUD must move beyond former right/up walls')
assert(en.minX<-960 and en.maxY>540,'Enemy HUD must move beyond former left/down walls')

-- Trainer phase rows must switch the semantic preview state. Lua patterns do
-- not support regex alternation, so this guards against the former
-- `intro|battle|post` match that silently left every row on BATTLE.
local function focusRow(id)
  local rows=s:rows();local target
  for i,r in ipairs(rows) do if r.id==id then target=i;break end end
  assert(target,id..' row missing')
  local previous
  for i=target-1,1,-1 do local r=rows[i];if r.kind~='header' and r.kind~='info' and not r.disabled then previous=i;break end end
  assert(previous,id..' previous selectable row missing')
  s.focusIndex=previous;s:moveFocus(1)
  assert(s.focusIndex==target,id..' focus routing failed')
end
focusRow('ui.trainer_intro');assert(s.trainerPreviewPhase=='intro','trainer intro row must select INTRO preview')
focusRow('ui.trainer_battle');assert(s.trainerPreviewPhase=='battle','trainer battle row must select BATTLE preview')
focusRow('ui.trainer_post');assert(s.trainerPreviewPhase=='post','trainer post row must select POST preview')

print('PASS test_live_editor_multi_input')
