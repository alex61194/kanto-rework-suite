local root=assert(arg[1],"root path required")
local calls={texts={},draws={},status={},types={},anim=0,circles=0,assets={},dialogue=nil}
local function check(v,msg) if not v then error(msg or "check failed",2) end end

local BattleState={}; BattleState.__index=BattleState
BattleState.StatBox={}; BattleState.StatBox.__index=BattleState.StatBox
local ChoiceBox={}; ChoiceBox.__index=ChoiceBox
package.preload['src.battle.BattleState']=function() return BattleState end
package.preload['src.ui.ChoiceBox']=function() return ChoiceBox end
package.preload['src.pokemon.Growth']=function() return {expForLevel=function(_,level) return (level or 1)*100 end} end
package.preload['src.pokemon.Stats']=function()
  local mult={[-6]={25,100},[-5]={28,100},[-4]={33,100},[-3]={40,100},[-2]={50,100},[-1]={66,100},[0]={100,100},[1]={150,100},[2]={200,100},[3]={250,100},[4]={300,100},[5]={350,100},[6]={400,100}}
  return {applyStage=function(value,stage) local q=mult[math.max(-6,math.min(6,stage or 0))]; return math.max(1,math.min(999,math.floor(value*q[1]/q[2]))) end}
end
package.preload['src.render.Font']=function()
  return {split=function(text) local out={};for i=1,#text do out[#out+1]={from=i,to=i} end;return out end}
end

love={timer={getTime=function() return 1 end},graphics={}}
for _,name in ipairs({'push','pop','origin','setColor','setLineWidth','setScissor','translate','scale'}) do love.graphics[name]=function(...) end end
love.graphics.circle=function(...) calls.circles=calls.circles+1 end
love.graphics.draw=function(img,...) calls.draws[#calls.draws+1]={img=img,args={...}} end

local function image(name,w,h) return {name=name,getDimensions=function() return w,h end,setFilter=function() end} end
local enemyImage=image('enemyProvider',112,112)
local playerImage=image('playerProvider',112,112)
local transientEnemy=image('enemyNativeTransient',56,56)
local transientPlayer=image('playerNativeTransient',56,56)
local trainerImage=image('trainer',64,64)
local playerTrainerImage=image('playerTrainer',64,64)
local commandImages={fight=image('fightIcon',112,112),pokemon=image('pokemonIcon',112,112),bag=image('bagIcon',112,112),run=image('runIcon',112,112)}

local colors={
  inverse={.08,.07,.06,1},textInverse={1,1,1,1},faint={.7,.7,.7,1},focus={0,.45,.55,1},
  panel={1,1,1,1},border={.8,.8,.7,1},borderStrong={.2,.2,.2,1},text={.08,.07,.06,1},exp={.07,.38,.48,1},
  textSecondary={.4,.4,.35,1},subtle={.95,.93,.85,1},success={0,.6,.2,1},danger={.8,.1,.1,1},
  warning={.6,.4,0,1},selectionGold={.95,.75,.15,1},disabled={.4,.4,.4,1},typeColors={NORMAL={.5,.5,.5,1},POISON={.6,.3,.7,1}},
}
local D={}
D.roundRect=function() end;D.panel=function() end;D.focusBorder=function() end;D.line=function() end;D.icon=function() error('battle command should use exact exported asset') end
D.font=function() return {getWidth=function(_,v) return #tostring(v)*7 end} end
D.text=function(_,_,text,x,y,size,color,opts) calls.texts[#calls.texts+1]={text=tostring(text),x=x,y=y,size=size,color=color,opts=opts or {}} end
D.clipText=function(_,_,text,x,y,width,size,color,opts) D.text(nil,nil,text,x,y,size,color,opts) end

local voxelPresentation={upscale='default',pixelScale=1,realSize='auto',nativePixels=true}
local useGraphicsPresentation=false
local graphicsExports={battlePresentation=function() return voxelPresentation end,battleBackgroundsEnabled=function() return true end}
local backgroundOwner='krs'
local compatExports={
  prepareBattleArt=function() return true end,
  battleVisualPolicy=function() return {backgroundOwner=backgroundOwner} end,
  battleArtMetrics=function(img)
    if img==enemyImage then return {x0=28,x1=83,y0=28,y1=83,w=112,h=112,center=56} end
    if img==playerImage then return {x0=40,x1=71,y0=40,y1=71,w=112,h=112,center=56} end
  end,
  voxelBattleArtPresentation=function() return voxelPresentation end,
}
local artSource='test.provider'
local runtime={
  assetPath=function(relative) return root.."/"..relative end,
  Draw=D,
  Layout={isWide=function() return true end,metrics=function() return {ox=0,oy=0,scale=1} end,contains=function(x,y,r) return r and x>=r.x and y>=r.y and x<=r.x+r.w and y<=r.y+r.h end},
  Theme={resolveAll=function() return colors end},
  Footer={resolve=function(_,prompts) local out={};for _,p in ipairs(prompts) do out[#out+1]={key=p.key or (p.navigation and 'ARROWS' or 'ENTER'),label=p.label} end;return out,'KEYBOARD + MOUSE' end},
  Core={journalContext=function() return {location='PALLET TOWN',worldTime='18:42  •  DAY'} end},
  StatusToken={drawIcon=function(status,hp,x,y,size) calls.status[#calls.status+1]={status=status,hp=hp,x=x,y=y,size=size};return true end},
  TypeIcon={draw=function(typ,x,y,size) calls.types[#calls.types+1]={typ=typ,x=x,y=y,size=size};return true end},
  PokemonArt={image=function(_,game,species,side,opts)
    if side=='back' then return {image=playerImage,metrics={x0=40,x1=71,y0=40,y1=71,w=112,h=112,center=56},source=artSource} end
    return {image=enemyImage,metrics={x0=28,x1=83,y0=28,y1=83,w=112,h=112,center=56},source=artSource}
  end},
  CharacterNames={battleOpponent=function() return 'BUG CATCHER BEN' end},
  assets={image=function(_,path)
    calls.assets[#calls.assets+1]=path
    local kind=path:match('/battle_actions/([^/]+)%.png$')
    return kind and commandImages[kind] or nil
  end},
  mod={path=root,find=function(id) if id=='graphics' and useGraphicsPresentation then return {exports=graphicsExports} end;if id=='compatibility' then return {exports=compatExports} end end,input={tap=function() end}},
  viewport={},
}
runtime.BattleBackgrounds=assert(loadfile(root..'/runtime/battle_backgrounds.lua'))()
runtime.DialoguePanel={draw=function(_,_,_,model)
  calls.dialogue=model
  local rects=model.choice and {{x=500,y=900,w=180,h=64},{x=690,y=900,w=180,h=64}} or nil
  return {x=400,y=800,w=1120,h=120,choiceRects=rects}
end}

local Presenter=assert(loadfile(root..'/ui/battle_presenter.lua'))()(runtime)

local playerMon={species='DRATINI',nickname='DRATINI',level=23,hp=32,exp=2350,status='BRN',stats={hp=67,attack=41,defense=34,speed=40,special=37}}
local enemyMon={species='GRIMER',level=23,hp=32,status='FRZ',stats={hp=60,attack=40,defense=40,speed=20,special=30}}
local battle=setmetatable({
  kind='trainer',trainer={name='BUG CATCHER'},phase='moveSelect',moveIndex=1,menuIndex=1,bgMode=function() return 'white' end,
  player={name='DRATINI',mon=playerMon,sprite=transientPlayer,shownHP=32,shownStatus='PAR',curStats={hp=67,attack=41,defense=34,speed=40,special=37},curTypes={'NORMAL'},stages={attack=1,defense=0,special=0,speed=0,accuracy=1,evasion=0},curMoves={{id='WRAP',pp=14,maxPP=20},{id='MOVE2',pp=5,maxPP=10},{id='MOVE3',pp=7,maxPP=20},{id='MOVE4',pp=7,maxPP=15}}},
  enemy={name='GRIMER',mon=enemyMon,sprite=transientEnemy,shownHP=32,shownStatus='FRZ',curStats={hp=60,attack=40,defense=40,speed=20,special=30},curTypes={'POISON'},stages={attack=0,defense=-1,special=1,speed=-2,accuracy=0,evasion=0}},
  enemyParty={enemyMon},fx={},fxHidden=function() return false end,picOffset=function() return 0 end,
  fxFaintActive=function() return false end,fxFaintOffset=function() return 0 end,
  animPlaying=true,animPlayer={stepIndex=1,steps={{sprites={{x=40,y=60,tile=1}}}}},
  drawAnimLayer=function(_,colorized) check(colorized==false,'attack animation must use native uncolorized OAM layer');calls.anim=calls.anim+1 end,
},BattleState)
local game={
  stack={states={battle},top=function(self) return self.states[#self.states] end},
  save={player={name='RED'},party={playerMon},options={}},
  data={constants={levelCap=100},growth_rates={},pokemon={DRATINI={growthRate='medium'}},moves={
    WRAP={name='WRAP',type='NORMAL',power=15,accuracy=85,pp=20,description='Wraps the target.'},
    MOVE2={name='DRAGON RAGE',type='DRAGON',power=1,accuracy=100,pp=10},MOVE3={name='THUNDER WAVE',type='PSYCH_TYPE',power=0,accuracy=100,pp=20},MOVE4={name='THUNDERSHOCK',type='ELECTRIC',power=40,accuracy=100,pp=15},
  },text={}},
}
local function reset() calls.texts={};calls.draws={};calls.status={};calls.types={};calls.anim=0;calls.circles=0;calls.assets={};calls.dialogue=nil end
local function hasText(v) for _,t in ipairs(calls.texts) do if t.text==v then return t end end end

check(Presenter.draw(game,{})==true,'battle presenter draws')
-- Compatibility's normalized live owner is authoritative. An exact staged
-- Voxel 3D battle must not ask KRS for any background asset, avoiding double
-- environment rendering/z-order flashes while retaining KRS HUD/shell output.
backgroundOwner='voxel';reset();check(Presenter.draw(game,{})==true,'battle presenter composes over Voxel 3D battle')
for _,path in ipairs(calls.assets) do check(not path:find('/battle/backgrounds/',1,true),'KRS BattleBackGround requested while Voxel owns the live 3D environment') end
backgroundOwner='krs';reset()
battle.demo=true;check(Presenter.draw(game,{})==true,'battle presenter now also skins scripted demo battles')
battle.demo=nil;reset();Presenter.draw(game,{})
check(calls.anim==1,'native attack animation layer is redrawn over KRS background')
check(#calls.status==1 and calls.status[1].status=='FRZ','move selection hides the player HUD while preserving the opponent HUD')
local moveType;for _,t in ipairs(calls.types) do if t.x==1416 and t.y==850 then moveType=t break end end
check(moveType~=nil,'move type icon center matches Figma x+56/y+18 geometry')
battle.moveIndex=3;reset();Presenter.draw(game,{})
local psychicSeen=false;for _,t in ipairs(calls.types) do if t.typ=='PSYCHIC' then psychicSeen=true break end end
check(psychicSeen,'PSYCH_TYPE is normalized to centered PSYCHIC presentation')
battle.moveIndex=1

-- Animated Voxel art keeps one stable authored-canvas scale across frames.
local fitted={};for _,d in ipairs(calls.draws) do if d.img==enemyImage or d.img==playerImage then fitted[d.img.name]=d.args end end
check(fitted.enemyProvider and fitted.playerProvider,'both Pokémon sprites are drawn')
check(math.abs(fitted.enemyProvider[4]-(380/112))<0.001,'enemy Pokémon uses the full authored battle slot')
check(math.abs(fitted.playerProvider[4]-(380/112))<0.001,'player Pokémon uses the full authored battle slot')
check(math.abs(fitted.enemyProvider[4]-fitted.playerProvider[4])<0.001,'front/back use the same full-size battle scale')
for _,d in ipairs(calls.draws) do check(d.img~=transientEnemy and d.img~=transientPlayer,'normal battlers must use selected provider art instead of transient BattleState fallback sprites') end

-- Voxel fixed modes are literal authored-frame pixel multipliers. DEFAULT is
-- native x1; AUTO is the only mode that derives a species/frame/side scale.
artSource='kanto_rework_graphics.assets'
useGraphicsPresentation=true
voxelPresentation={upscale='default',pixelScale=1,realSize='auto',nativePixels=true}
reset();Presenter.draw(game,{})
local nativeScaled={};for _,d in ipairs(calls.draws) do if d.img==enemyImage or d.img==playerImage then nativeScaled[d.img.name]=d.args end end
check(math.abs(nativeScaled.enemyProvider[4]-1)<0.001 and math.abs(nativeScaled.playerProvider[4]-1)<0.001,'KRS Graphics DEFAULT draws exact authored-frame x1')
check(math.abs(nativeScaled.enemyProvider[1]+56-1440)<0.001 and math.abs(nativeScaled.enemyProvider[2]+112-606)<0.001,'enemy/front frame bottom-centre lands on the road battle-circle anchor')
check(math.abs(nativeScaled.playerProvider[1]+56-600)<0.001 and math.abs(nativeScaled.playerProvider[2]+112-758)<0.001,'player/back frame bottom-centre lands on the road battle-circle anchor')
game.data.pokemon.GRIMER={dexEntry={heightFt=6,heightIn=0}}
game.data.pokemon.DRATINI.dexEntry={heightFt=2,heightIn=0}
voxelPresentation={upscale='auto',pixelScale=nil,realSize='yes',nativePixels=true}
reset();Presenter.draw(game,{})
local heightScaled={};for _,d in ipairs(calls.draws) do if d.img==enemyImage or d.img==playerImage then heightScaled[d.img.name]=d.args end end
check(heightScaled.enemyProvider[4]>heightScaled.playerProvider[4]*1.2,'KRS Graphics AUTO + real-size YES restores inter-species visual hierarchy while accounting for back-side perspective')
-- With equal canonical height and identical authored frame dimensions, AUTO
-- keeps the player/back side only slightly larger for perspective.
game.data.pokemon.GRIMER.dexEntry={heightFt=3,heightIn=3};game.data.pokemon.DRATINI.dexEntry={heightFt=3,heightIn=3}
voxelPresentation={upscale='auto',pixelScale=nil,realSize='auto',nativePixels=true}
reset();Presenter.draw(game,{})
local perspectiveScaled={};for _,d in ipairs(calls.draws) do if d.img==enemyImage or d.img==playerImage then perspectiveScaled[d.img.name]=d.args end end
local perspectiveRatio=perspectiveScaled.playerProvider[4]/perspectiveScaled.enemyProvider[4]
check(perspectiveRatio>1.09 and perspectiveRatio<1.11,'AUTO gives the back/player sprite an approximately 10 percent perspective lift')
voxelPresentation={upscale='x2',pixelScale=2,realSize='yes',nativePixels=true}
reset();Presenter.draw(game,{})
local rawScaled={};for _,d in ipairs(calls.draws) do if d.img==enemyImage or d.img==playerImage then rawScaled[d.img.name]=d.args end end
check(math.abs(rawScaled.enemyProvider[4]-2)<0.001 and math.abs(rawScaled.playerProvider[4]-2)<0.001,'KRS Graphics X2 remains literal and ignores automatic real-size scaling')
voxelPresentation={upscale='default',pixelScale=1,realSize='auto',nativePixels=true};artSource='test.provider';useGraphicsPresentation=false;game.data.pokemon.GRIMER=nil;game.data.pokemon.DRATINI.dexEntry=nil

-- Native battle pic effects must transform provider art without ever reverting to the oversized transient engine/Voxel battler sprite.
battle.picFx={[battle.enemy]={kind='shakeBF',t=4,ox=0,oy=0}};reset();Presenter.draw(game,{})
local providerDuringFx=false;for _,d in ipairs(calls.draws) do if d.img==enemyImage then providerDuringFx=true end;check(d.img~=transientEnemy,'native picFx reverted opponent to transient oversized sprite') end
check(providerDuringFx,'selected opponent provider remains authoritative during native picFx')
battle.picFx={}
check(hasText('BUG CATCHER BEN') and hasText('RED'),'header/footer use generated stable trainer identity and actual player name')

-- Exact command assets exported from Figma are requested for all four cards.
battle.phase='menu';reset();Presenter.draw(game,{})
for _,kind in ipairs({'fight','pokemon','bag','run'}) do
  local found=false;for _,path in ipairs(calls.assets) do if path:find('/battle_actions/'..kind..'.png',1,true) then found=true break end end
  check(found,'missing exact Figma command icon '..kind)
end

local playerNameAt700=false;for _,t in ipairs(calls.texts) do if t.text=='DRATINI' and t.y==714 then playerNameAt700=true end end
check(playerNameAt700,'command-phase player HUD sits 8px above the command row')

-- A real move animation hides both HUD cards, independently from sprite art.
battle.phase='messages';battle.animPlaying=true;battle.animName='WRAP';reset();Presenter.draw(game,{})
check(#calls.status==0,'move animation hides both Pokémon HUD cards')
battle.animPlaying=false;battle.animName=nil

-- Wild battle shows the opponent identity but never invents six opponent party balls.
battle.kind='wild';battle.trainer=nil;reset();Presenter.draw(game,{})
check(hasText('GRIMER'),'wild opponent identity uses the actual Pokémon name')
check(calls.circles==6,'wild header omits opponent party balls; only player footer balls remain')
battle.kind='trainer';battle.trainer={name='BUG CATCHER'}

-- Compact battle dialogue delegates to the KRS dialogue component. Wide KRS
-- retains the whole semantic message even after Gen 1's rolling two-line
-- window has already discarded the first source line.
battle.phase='message';battle.animPlaying=false;battle.current={text='KOPI learned\nTAIL WHIP!'};battle.charIndex=#'KOPI learned'+#'TAIL WHIP!';battle.shown={{1,2,3}};battle.lineIndex=2;battle.scrollPx=4
reset();Presenter.draw(game,{})
check(calls.dialogue and calls.dialogue.text=='KOPI learned TAIL WHIP!','battle dialogue preserves the complete revealed move-learning message')
check(calls.dialogue.bottomMargin==88,'battle dialogue keeps 24px above 64px footer')

-- A direct battle ChoiceBox keeps KRS Battle alive and becomes the integrated horizontal choice region.
local choice=setmetatable({game=game,index=1},ChoiceBox);game.stack.states={battle,choice};reset();
check(Presenter.ownsChoice(game,choice),'direct battle ChoiceBox is owned by KRS')
check(Presenter.draw(game,{})==true and calls.dialogue and calls.dialogue.choice,'battle choice does not revert to vanilla')
battle.current={text='ROCKET is about to use ZUBAT! Will RED change POKEMON?',_krsChoiceLabels={'CHANGE',"DON'T CHANGE"}};reset();Presenter.draw(game,{})
check(calls.dialogue.choice.labels[1]=='CHANGE' and calls.dialogue.choice.labels[2]=="DON'T CHANGE" and calls.dialogue.choice.align=='right','trainer shift actions are semantic and right-aligned')

-- An intervening screen protects its own ChoiceBox from accidental battle capture.
local party={kind='party'};local otherChoice=setmetatable({game=game,index=1},ChoiceBox);game.stack.states={battle,party,otherChoice}
check(not Presenter.ownsChoice(game,otherChoice),'non-battle ChoiceBox remains with its parent screen')

-- Fainted battler is visible only for the engine faint slide, then disappears.
game.stack.states={battle};battle.phase='message';battle.current=nil;battle.shown={};battle.enemy.fainted=true
battle.fxFaintActive=function(_,b) return false end;reset();Presenter.draw(game,{})
for _,d in ipairs(calls.draws) do check(d.img~=enemyImage,'fainted enemy remained on field after faint slide') end
battle.fxFaintActive=function(_,b) return b==battle.enemy end;battle.fxFaintOffset=function() return 28 end;reset();Presenter.draw(game,{})
local faintDraw=false;for _,d in ipairs(calls.draws) do if d.img==enemyImage then faintDraw=true end end
check(faintDraw,'enemy remains drawable during native faint slide')
battle.enemy.fainted=nil;battle.fxFaintActive=function() return false end

-- Native StatBox still owns progression while KRS owns its presentation.
local stat=setmetatable({mon=playerMon},BattleState.StatBox);game.stack.states={battle,stat};reset();Presenter.draw(game,{})
check(hasText('LEVEL UP'),'level-up stays in KRS shell while native StatBox owns progression state')

local mainFile=assert(io.open(root..'/main.lua','rb'));local mainSource=mainFile:read('*a');mainFile:close()
check(mainSource:find('runtime.BattlePresenter.ownsChoice(game,state)',1,true),'native ChoiceBox suppression is scoped to KRS battle choices')
check(mainSource:find('NativeBattleState.StatBox.draw=function',1,true),'Wide KRS suppresses native StatBox drawing')
check(mainSource:find('runtime.NativePresenter.handles(state.game,state)',1,true),'out-of-battle Rare Candy StatBox is suppressed when KRS NativePresenter owns it')
check(mainSource:find('_krsPendingShiftPrompt',1,true) and mainSource:find("_krsChoiceLabels={'CHANGE',\"DON'T CHANGE\"}",1,true),'trainer send-out and change question fuse into one semantic KRS dialogue')
local bpFile=assert(io.open(root..'/ui/battle_presenter.lua','rb'));local bpSource=bpFile:read('*a');bpFile:close()
check(bpSource:find("'+'..tostring(gain)",1,true),'level-up presentation includes per-stat gain deltas')
check(bpSource:find("x+80,y+8,300,12",1,true),'move names keep a 300px single-line budget even while focused')
check(bpSource:find('local function centeredMetric',1,true) and bpSource:find('start=x+(w-(lw+gap+vw))/2',1,true),'POWER / ACCURACY label+value groups are centered as one unit')
check(bpSource:find('BattleBackgrounds.groundAnchors(backdrop)',1,true) and bpSource:find('playerGround.x+intro+backOff+sx',1,true) and bpSource:find('enemyGround.x-intro+foeOff+sx',1,true),'battle Pokémon frames are bottom-centred on per-background authored circle anchors')
check(bpSource:find("pixelScale=1,realSize='auto',nativePixels=true",1,true) and bpSource:find("local bottom=frameAnchor and canvasH",1,true),'Voxel DEFAULT is native x1 and Pokémon grounding uses the complete frame bottom')
check(bpSource:find('autoBattlePixelScale',1,true) and bpSource:find("if isBack then target=target*1.10 end",1,true),'AUTO scaling is per-frame and gives the back/player side a perspective lift')
check(bpSource:find("assets/intro/old_man.png",1,true) and bpSource:find("assets/intro/prof_oak_demo.png",1,true),'Red/Blue old-man and Yellow Oak tutorial trainer assets are wired into demo battles')
check(bpSource:find("s.oakDemo==true",1,true),'Yellow tutorial uses engine oakDemo discriminator rather than guessing from game color')
print('Battle fidelity tests passed')
