local root=assert(arg[1],"root path required")
local function loadModule(path)local chunk,err=loadfile(root.."/"..path);assert(chunk,err);return chunk() end
local function check(value,label)if not value then error(label or "check failed",2) end end
local function eq(actual,expected,label)if actual~=expected then error((label or "value")..": expected "..tostring(expected)..", got "..tostring(actual),2) end end

-- Render the two previously crashing Party states with a strict graphics
-- stub. setColor deliberately rejects numbers/tables in the wrong position,
-- which reproduces the bad five-argument separator failure from 0.8.3.
local font={getWidth=function(_,v)return #tostring(v or "")*8 end}
love={graphics={
  setColor=function(r,g,b)check(type(r)=="number" and type(g)=="number" and type(b)=="number","invalid color passed to renderer")end,
  rectangle=function()end,line=function()end,circle=function()end,polygon=function()end,
  setLineWidth=function()end,setFont=function()end,print=function()end,printf=function()end,
  newFont=function()return font end,push=function()end,pop=function()end,origin=function()end,
  setScissor=function()end,stencil=function(fn)fn()end,setStencilTest=function()end,draw=function()end,
}}
local C=loadModule("generated/tokens.lua")
local Layout=loadModule("ui/party_layout.lua")(C)
local move=function(id,name,typ,category)return{id=id,name=name,type=typ,category=category,pp=10,maxPP=20,power=40,accuracy=100,description="Move description."}end
local model={source={moves={{},{},{},{}}},name="PIKACHU",level=25,ot="RED",otId=12345,hp=42,stats={hp=60,attack=40,defense=30,speed=70,special=50},types={"ELECTRIC"},moves={move("A","THUNDERBOLT","ELECTRIC","SPECIAL"),move("B","QUICK ATTACK","NORMAL","PHYSICAL")},dvs={attack=15,defense=14,speed=13,special=12},statExp={},exp=1000,toNextLevel=250,expRatio=.6}
local failFront=false
local Adapter={pokemon=function()return model end,frontSprite=function()if failFront then error('simulated visual provider failure') end return nil end,drawPartyIcon=function()return false end,topState=function(game)return game.stack:top()end}
local runtime={viewport={width=1920,height=1080},partyNav={},Focus={isPointer=function()return false end}}
local noop={draw=function()end}
local Presenter=loadModule("ui/party_presenter.lua")({C=C,Layout=Layout,Adapter=Adapter,TypeIcon=noop,TypeChip=noop,StatusToken={drawIcon=function()end,drawToken=function()end},Footer=noop,Palette={resolve=function()return{colors=C.colors,typeColors=C.typeColors,profile="standard",colorMode="standard"}end},Core={journalContext=function()return{location="PALLET_TOWN",playTime=60}end},runtime=runtime})
local game={stack={top=function()return nil end}}
for _,mode in ipairs({"PartyBrowse","SummaryActive","MovesActive"})do
  local state={__kantoPartyUi=true,mode=mode,game=game,pokemon=model,party={model.source},regions={},statMode="stats",activeMoveFocus=1,movePhase="active",learned={move("C","SLAM","NORMAL","PHYSICAL")},learnedFirst=1}
  state.partyFocus=1;state.selectedParty=1
  game.stack.top=function()return state end
  local ok,err=pcall(Presenter.draw,Presenter,game,runtime.viewport);check(ok,mode.." must render: "..tostring(err))
end

-- A visual provider failure must stay local to the art cell. Round5 allowed
-- an animated-atlas error to abort the complete Party presenter.
failFront=true
do
  local state={__kantoPartyUi=true,mode="PartyBrowse",game=game,pokemon=model,party={model.source},regions={},partyFocus=1,selectedParty=1}
  game.stack.top=function()return state end
  local ok,err=pcall(Presenter.draw,Presenter,game,runtime.viewport);check(ok,"Party must survive a provider exception: "..tostring(err))
end
failFront=false

-- Exercise transfers from a current box to another box and from Party to a
-- third box. The screen uses the same methods for mouse drop and A/Enter.
local Boxes={COUNT=20,CAPACITY=20,ensure=function(save)return save.boxes end}
package.preload["src.ui.BoxMenu"]=function()return{new=function()return{}end}end
local namingCreated={}
package.preload["src.ui.NamingScreen"]=function()return{new=function(game,opts)local v={game=game,opts=opts};namingCreated[#namingCreated+1]=v;return v end}end
package.preload["src.pokemon.Boxes"]=function()return Boxes end
package.preload["src.pokemon.Party"]=function()return{MAX=6}end
package.preload["src.pokemon.Stats"]=function()return{ensure=function()end}end
package.preload["src.world.PikachuFollower"]=function()return{modifyHappiness=function()end}end
local soundCues={}
package.preload["src.core.Sound"]=function()return{play=function(_,cue)soundCues[#soundCues+1]=cue end}end
local pcRuntime={Layout={isWide=function()return true end,contains=function(x,y,r)return x>=r.x and y>=r.y and x<r.x+r.w and y<r.y+r.h end}}
local Screen=loadModule("screens/pc_storage.lua").factory(pcRuntime)
local a={species="PIKACHU"};local b={species="EEVEE"};local c={species="MEW"};local d={species="DITTO"}
local boxes={};for i=1,Boxes.COUNT do boxes[i]={} end;boxes[1]={a};boxes[2]={b}
local writes=0;local pcStack={states={}};function pcStack:push(v)self.states[#self.states+1]=v end;function pcStack:pop()return table.remove(self.states)end;function pcStack:top()return self.states[#self.states]end
local pcGame={save={boxes=boxes,currentBox=1,party={c,d}},stack=pcStack,data={pokemon={PIKACHU={name='Pikachu',index=84,dex=25,types={'ELECTRIC'}},EEVEE={name='Eevee',index=102,dex=133,types={'NORMAL'}},MEW={name='Mew',index=21,dex=151,types={'PSYCH_TYPE'}},DITTO={name='Ditto',index=76,dex=132,types={'NORMAL'}}},moves={THUNDERBOLT={name='THUNDERBOLT'},['QUICK ATTACK']={name='QUICK ATTACK'}}},writeSave=function()writes=writes+1 end,input={wasPressed=function()return false end}}
local screen=Screen.new(pcGame);screen.area="stored";screen.monIndex=1
pcRuntime.PartyAdapter={pokemon=function(_,mon)return{moves={{name='THUNDERBOLT',pp=12,maxPP=15},{name='QUICK ATTACK',pp=28,maxPP=30}}}end}
local contextMoves=screen:contextMoves();eq(contextMoves[1].name,'THUNDERBOLT','PC context exposes selected Pokémon move names');eq(contextMoves[2].maxPP,30,'PC context exposes current/max PP')
screen.hover={kind='party',value=2};eq(screen:contextMon(),d,'mouse-highlighted party Pokémon drives PC context');screen.hover=nil
check(screen:beginMove(),"box Pokémon can be picked up");eq(screen.selected.boxIndex,1,"source box is recorded")
check(screen:placeInBox(2),"box-to-box placement");eq(#boxes[1],0,"source box emptied");eq(boxes[2][2],a,"destination receives exact Pokémon");eq(pcGame.save.currentBox,1,"cross-box move keeps the current box view")
screen.area="party";screen.partyIndex=1;check(screen:beginMove(),"party Pokémon can be picked up")
check(screen:placeInBox(3),"party-to-arbitrary-box placement");eq(#pcGame.save.party,1,"party keeps at least one Pokémon");eq(boxes[3][1],c,"third box receives party Pokémon")
eq(writes,0,"PC edits remain in-memory until explicit game Save")
eq(soundCues[1],'Press_AB','PC pickup emits an explicit SFX cue')
eq(soundCues[2],'Swap','PC drop emits an explicit SFX cue')

-- Search and sort are presentation-only: they expose canonical information
-- while preserving the source index used by release and move operations.
boxes[8]={{species='EEVEE',level=18,moves={{id='QUICK ATTACK',pp=20}}},{species='MEW',level=50,moves={}},{species='PIKACHU',level=12,moves={{id='THUNDERBOLT',pp=12}}}};pcGame.save.currentBox=8
local knownCalls=0
pcRuntime.Core={
  restoreAllKnownMovePP=function()return false end,
  knownMoves=function(mon)knownCalls=knownCalls+1;if mon.species=='MEW' then return{{id='THUNDERBOLT',pp=4,ppUps=0}} end return{} end,
}
screen=Screen.new(pcGame);screen:enter();screen.searchQuery='psychic'
local filtered=screen:displayEntries();eq(#filtered,1,'PC search filters names/species/types');eq(filtered[1].sourceIndex,2,'filtered entry keeps the save source index');eq(screen:typeNames(filtered[1].mon)[1],'PSYCHIC','Psychic aliases use the canonical glyph/type name')
local callsAfterEntry=knownCalls
screen.searchQuery='thunderbolt';local moveFiltered=screen:displayEntries();eq(#moveFiltered,2,'PC search includes current and remembered move names')
eq(knownCalls,callsAfterEntry,'PC filtering is a pure read and does not re-observe Move Memory')
    screen.searchQuery='';screen.sortMode='pokedex';local dexSorted=screen:displayEntries();eq(dexSorted[1].mon.species,'PIKACHU','PC Pokédex sort uses definition.dex rather than internal index')
    screen.sortMode='level';local sorted=screen:displayEntries();eq(sorted[1].mon.species,'PIKACHU','PC level sort is functional');eq(boxes[8][1].species,'EEVEE','PC sort never mutates save order')

-- A live search evaluates every box without changing its order. Boxes with no
-- matches remain in place but are not selectable until the query clears.
boxes[9]={{species='EEVEE',level=8}};screen.searchQuery='psychic'
check(screen:boxHasSearchResult(8),'box containing a search result stays active')
check(not screen:boxHasSearchResult(9),'box without a search result is detected')
check(not screen:boxSelectable(9),'box without result cannot be selected')
local beforeBox=pcGame.save.currentBox;check(not screen:setBox(9),'disabled search box rejects selection');eq(pcGame.save.currentBox,beforeBox,'search does not mutate current box on rejected selection')
screen.searchQuery='';check(screen:boxSelectable(9),'clearing search restores box state immediately')

-- Box names are playthrough state, not direct disk writes. The native naming
-- screen supplies the validated exclusive text-input behavior.
local function copyTable(t)local o={} for k,v in pairs(t or{})do if type(v)=='table'then o[k]=copyTable(v)else o[k]=v end end return o end
local persisted={}
local working=copyTable(persisted)
local function storeFor(bucket)return{get=function(_,key,default)local v=bucket[key];return v==nil and default or v end,set=function(_,key,value)bucket[key]=copyTable(value)end}end
pcRuntime.mod={save=storeFor(working)}
pcGame.save.currentBox=8;screen=Screen.new(pcGame)
check(screen:renameBox(8),'box rename action opens naming input')
local naming=namingCreated[#namingCreated];eq(naming.opts.maxLen,13,'box rename length is bounded for PC card layout')
naming.opts.onDone('KANTO TEAM');eq(screen:boxName(8),'KANTO TEAM','box name updates immediately in memory');eq(writes,0,'box rename never writes the save directly')
-- Reload without a true Save: bind a fresh KRS runtime to the last persisted
-- modData snapshot, not to the unsaved working copy.
pcRuntime.mod={save=storeFor(copyTable(persisted))};local unsavedReload=Screen.new(pcGame);eq(unsavedReload:boxName(8),'BOX 08','reload without Save restores persisted box name')
-- Simulate the engine's explicit Save capturing live modData, then reload it.
persisted=copyTable(working);pcRuntime.mod={save=storeFor(copyTable(persisted))};local savedReload=Screen.new(pcGame);eq(savedReload:boxName(8),'KANTO TEAM','true Save snapshot persists renamed box')

-- Controller parity: Select is unused while focus is in the Box Bank, so it is
-- the explicit Rename action there. In Stored/Party it keeps its pickup role.
local controllerRename=Screen.new(pcGame);controllerRename.area='boxes';controllerRename.boxIndex=8
local controllerPressed='select';pcGame.input.wasPressed=function(_,action)if action==controllerPressed then controllerPressed=nil;return true end return false end
controllerRename:update();check(namingCreated[#namingCreated]~=naming,'controller Select opens box rename while Box Bank is focused')

-- Mouse drag from a stored cell directly onto another box card.
local e={species="PIKACHU"};boxes[4]={e};boxes[5]={};pcGame.save.currentBox=4
screen=Screen.new(pcGame);pcRuntime.pcMonRects={[1]={x=0,y=0,w=100,h=100}};pcRuntime.pcBoxRects={[5]={x=200,y=0,w=100,h=100}};pcRuntime.pcPartyRects={}
screen:pointerEvent({phase="pressed",source="mouse",button=1},10,10)
screen:pointerEvent({phase="moved",source="mouse",button=1},30,30)
screen:pointerEvent({phase="released",source="mouse",button=1},210,10)
eq(boxes[5][1],e,"mouse drag drops into destination box")

-- The action-based path is shared by keyboard and controller: Select picks up,
-- A/Enter places on the focused box card.
local f={species="EEVEE"};boxes[6]={f};boxes[7]={};pcGame.save.currentBox=6
screen=Screen.new(pcGame);local pressed="select";pcGame.input.wasPressed=function(_,action)if action==pressed then pressed=nil;return true end return false end
screen:update();check(screen.selected and screen.selected.mon==f,"Select action picks up focused Pokémon")
screen.area="boxes";screen.boxIndex=7;pressed="a";screen:update();eq(boxes[7][1],f,"A/Enter action places into focused box")

if io and io.open then
  local battle=assert(io.open(root.."/runtime/battle_backgrounds.lua","rb")):read("*a")
  check(battle:find('OAKS_LAB="oak_lab"',1,true)
    and battle:find('PEWTER_GYM="gym_pewter"',1,true)
    and battle:find('starts(mapId,"ROUTE_")',1,true),
    "Figma Resources battle background routing includes Oak Lab, routes/cities and gyms")
  local menu=assert(io.open(root.."/ui/menu_presenter.lua","rb")):read("*a")
  check(not menu:find("kind='main_menu'",1,true),"Main Menu must not route compact representations through front battle art")
  check(menu:find("local moves=screen:contextMoves()",1,true) and menu:find("pp..' / '..maxpp..' PP'",1,true),"PC context renders four real move rows with current/max PP")
  check(menu:find("local cols,visible=4,20;local visibleRows=5",1,true),"PC Stored Pokémon exposes a full fifth row without shrinking cards")
  check(not menu:find("string.rep('█'",1,true) and not menu:find("string.rep('░'",1,true),"PC no longer renders completion-glyph bars")
  check(menu:find("love.graphics.push('all')",1,true) and menu:find("love.graphics.setColor(1,1,1,1)",1,true),"PC Pokémon icon render isolates theme tint and preserves source colours")
end

print("party summary/moves and PC search/sort/cross-box regression tests passed")
