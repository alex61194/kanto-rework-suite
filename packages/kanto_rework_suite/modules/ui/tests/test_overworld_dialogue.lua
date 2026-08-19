local root=assert(arg[1],"root path required")
local function loadModule(path)local chunk,err=loadfile(root.."/"..path);assert(chunk,err);return chunk() end
local function eq(actual,expected,label)if actual~=expected then error((label or "value")..": expected "..tostring(expected)..", got "..tostring(actual),2) end end
local function check(value,label)if not value then error(label or "check failed",2) end end

local TextBox={};TextBox.__index=TextBox
function TextBox:beginLine()
  self.charIndex=0;self.codes={}
  local line=(self.pages[self.pageIndex] or {})[self.lineIndex] or ""
  for i=1,#line do self.codes[#self.codes+1]=line:byte(i) end
  if #self.shown>=2 then table.remove(self.shown,1) end
  self.shown[#self.shown+1]={}
end
local ChoiceBox={};ChoiceBox.__index=ChoiceBox
local ListMenu={};ListMenu.__index=ListMenu
local QuantityBox={};QuantityBox.__index=QuantityBox
local Font={}
function Font.split(text)local out={};for i=1,#text do out[#out+1]={from=i,to=i,code=text:byte(i)} end;return out end
local Layout={isWide=function(v)return v and v.width==1920 and v.height==1080 end}
local Adapter=loadModule("ui/dialogue_adapter.lua")({TextBox=TextBox,ChoiceBox=ChoiceBox,ListMenu=ListMenu,QuantityBox=QuantityBox,Font=Font,Layout=Layout})
local overworld={}
local function state(fields)
  fields=fields or {};fields.pages=fields.pages or {{"SAFARI ZONE has a ","zoo in front of"}}
  fields.pageIndex=fields.pageIndex or 1;fields.lineIndex=fields.lineIndex or 2
  fields.charIndex=fields.charIndex or #fields.pages[1][fields.lineIndex];fields.shown=fields.shown or {{}}
  return setmetatable(fields,TextBox)
end
local function gameWith(s)local game={overworld=overworld};game.stack={states={overworld,s}};s.game=game;return game end
local vp={width=1920,height=1080}

local s=state();local game=gameWith(s)
check(Adapter.isSupported(game,s,vp),"manual direct-overworld TextBox should be supported")
eq(Adapter.visibleText(s),"SAFARI ZONE has a zoo in front of","vanilla line-wrap recomposition")
eq(Adapter.speaker(s,game),nil,"sign text must not invent a speaker")

local koga=state({pages={{"KOGA: Fwahahaha! A mere child like you dares to challenge me?"}},lineIndex=1,charIndex=0,shown={{}}})
game=gameWith(koga)
local kogaText,kogaSpeaker=Adapter.presentationText(koga,game)
eq(kogaSpeaker,"KOGA","explicit ROM speaker prefix becomes chip")
eq(kogaText,"Fwahahaha! A mere child like you dares to challenge me?","speaker prefix removed from prose")
local rematch=state({pages={{"★ TRAINER RANK: EXPERT I'll try harder this time. Let's battle again!"}},lineIndex=1,charIndex=0,shown={{}},_krsInteractionKind="npc",_krsSpeakerHint="YOUNGSTER BEN"})
game=gameWith(rematch)
local rematchText,rematchSpeaker=Adapter.presentationText(rematch,game)
eq(rematchSpeaker,"YOUNGSTER BEN","rematch metadata must not replace the authoritative trainer name")
eq(rematchText,"EXPERT I'll try harder this time. Let's battle again!","rematch metadata label removed from prose")
local namedRematch=state({pages={{"KOGA: We shall battle again!"}},lineIndex=1,charIndex=0,shown={{}},_krsInteractionKind="npc",_krsSpeakerHint="YOUNGSTER BEN"})
game=gameWith(namedRematch)
local namedText,namedSpeaker=Adapter.presentationText(namedRematch,game)
eq(namedSpeaker,"KOGA","canonical explicit speaker still wins over an interaction hint")
eq(namedText,"We shall battle again!","canonical explicit prefix remains stripped")
local signPrefix=state({pages={{"TRAINER TIPS: Press START to open the menu."}},lineIndex=1,charIndex=0,shown={{}},_krsInteractionKind="sign"})
game=gameWith(signPrefix)
local signText,signSpeaker=Adapter.presentationText(signPrefix,game)
eq(signSpeaker,nil,"sign prefix must not become speaker")
eq(signText,"TRAINER TIPS: Press START to open the menu.","sign content remains intact")

local safari=state({pages={{"SAFARI ZONE has a","zoo in front of","the entrance."},{"Out back is the","SAFARI GAME for","catching POKéMON."}},lineIndex=1,charIndex=0,shown={{}}})
safari.pages.contBefore={{false,false,true},{false,false,true}};game=gameWith(safari)
eq(Adapter.fullText(safari),"SAFARI ZONE has a zoo in front of the entrance. Out back is the SAFARI GAME for catching POKéMON.","full Safari prose")
check(Adapter.repaginate(safari,{"SAFARI ZONE has a zoo in front of the entrance. Out back is the SAFARI GAME for catching POKéMON."},3),"repagination must succeed")
eq(#safari.pages,1,"wide Safari pages")

local choiceText=state({choice=function()end,pages={{"Welcome to our POKéMON CENTER! We heal your POKéMON back to perfect health!"}},lineIndex=1,charIndex=0,shown={{}}})
game=gameWith(choiceText);game.data={text={_PokemonCenterWelcomeText="Welcome to our\nPOKéMON CENTER! We heal your POKéMON back to perfect health!"}}
check(Adapter.isSupported(game,choiceText,vp),"choice TextBox must be supported")
eq(Adapter.speaker(choiceText,game),"NURSE JOY","known Pokémon Center dialogue must expose Nurse Joy")
local choice=setmetatable({game=game,index=2,anchor="bottom"},ChoiceBox)
game.stack.states={overworld,choiceText,choice}
local pairedText,pairedChoice=Adapter.choicePair(game,vp)
check(pairedText==choiceText and pairedChoice==choice,"anchored choice pair must resolve")
check(Adapter.isMirroredChoice(game,choice,vp),"ChoiceBox must be mirrored")
eq(Adapter.choiceNavigation(game,choice,vp),"horizontal","mirrored KRS YES/NO navigation is horizontal")
local cm=Adapter.model(choiceText,choice,game);eq(cm.choice.index,2,"native focus index preserved");eq(cm.speaker,"NURSE JOY","model speaker")
local bare=setmetatable({game=game,index=1},ChoiceBox);game.stack.states={overworld,bare}
check(not Adapter.isMirroredChoice(game,bare,vp),"bare ChoiceBox must remain native")

local auto=state({auto={delay=3}});game=gameWith(auto);check(Adapter.isSupported(game,auto,vp),"auto TextBox should use KRS presentation")
check(not Adapter.canRepaginate(auto),"auto TextBox timing must keep native pagination")
local stay=state({stay={}});game=gameWith(stay);check(Adapter.isSupported(game,stay,vp),"stay TextBox should use KRS presentation")
check(not Adapter.canRepaginate(stay),"stay TextBox choreography must keep native pagination")
check(Adapter.canRepaginate(s),"manual TextBox may be repaginated to Wide KRS")

local martGreeting=state({pages={{"Hi there! May I help you?"}},lineIndex=1,charIndex=0,shown={{}}})
game=gameWith(martGreeting);game.data={text={_PokemartGreetingText="Hi there!\nMay I help you?"}}
eq(Adapter.speaker(martGreeting,game),"CLERK","known Poké Mart greeting exposes clerk speaker")

local shop=setmetatable({dialogue=true,footer="ULTRA BALL?\nThat will be\n¥1200. OK?"},ListMenu)
check(Adapter.shopFooterSupported(shop,vp),"mart dialogue footer recognized")
eq(Adapter.shopFooterModel(shop).text,"ULTRA BALL? That will be ¥1200. OK?","mart footer reflow")
eq(Adapter.shopFooterModel(shop).speaker,"CLERK","mart dialogue has reliable clerk role")
local shopGame={overworld=overworld,stack={states={overworld,shop}}}
local qty=setmetatable({isOpaque=false},QuantityBox);shopGame.stack.states={overworld,shop,qty}
local shopOwner,shopOverlay=Adapter.shopContext(shopGame,vp);check(shopOwner==shop and shopOverlay==qty,"quantity overlay keeps footer")
local shopChoice=setmetatable({index=2},ChoiceBox);shopGame.stack.states={overworld,shop,shopChoice}
shopOwner,shopOverlay=Adapter.shopContext(shopGame,vp);check(shopOwner==shop and shopOverlay==shopChoice,"mart YES/NO pair")

local fakeFont={lastLimit=nil}
function fakeFont:getWrap(text,limit)self.lastLimit=limit;if text=="THREE" then return limit,{"one","two","three"} end;return limit,{text} end
function fakeFont:getWidth(text)return #tostring(text or "")*9 end
local Draw={font=function()return fakeFont end}
local Panel=loadModule("components/dialogue_panel.lua")({Draw=Draw});local m={scale=1,ox=0,oy=0}
local one=Panel.layout({},m,{text="Hello"});eq(one.x,400,"panel x");eq(one.w,1120,"panel width");eq(one.h,80,"single line sign height");eq(one.textW,1056,"full text width");eq(fakeFont.lastLimit,1056,"full wrap width");check(not one.speakerRect,"speaker absent for sign")
local message=Panel.layout({},m,{speaker="NURSE JOY",text="Welcome"});check(message.speakerRect~=nil,"speaker chip present");check(message.h>one.h,"speaker increases panel height")
local confirm=Panel.layout({},m,{speaker="NURSE JOY",text="Shall we heal your POKéMON?",choice={count=2,index=1,labels={"YES","NO"}}})
check(confirm.choiceRects and #confirm.choiceRects==2,"confirmation exposes two pointer rectangles")
eq(confirm.choiceRects[1].w,180,"YES compact width");eq(confirm.choiceRects[2].w,180,"NO compact width")
eq(confirm.choiceRects[1].h,64,"choice height");eq(confirm.choiceRects[2].x-confirm.choiceRects[1].x,190,"compact choice gap")
check(confirm.choiceRects[2].x+confirm.choiceRects[2].w < confirm.innerX+confirm.innerW,"choices must not fill dialogue width")

if io and io.open then
  local panelSource=assert(io.open(root.."/components/dialogue_panel.lua","rb")):read("*a")
  check(not panelSource:find("CONTINUE",1,true),"runtime Continue Cue remains removed")
  check(not panelSource:find("tostring(index)",1,true),"choice ordinals remain removed")
  check(not panelSource:find("dividerY",1,true),"choice divider remains removed")
  local main=assert(io.open(root.."/main.lua","rb")):read("*a")
  check(main:find('release="0.8.58"',1,true),"release export updated")
  check(main:find('mod.hooks:wrap("script.command"',1,true),"event dialogue is routed at the public script command seam")
  check(main:find('_krsEventSpeakerLocked',1,true),"later world interaction metadata cannot replace an event-owned speaker")
  check(main:find('input:wasPressed("left") or input:wasPressed("right")',1,true),"mirrored choice update must use left/right")
  check(main:find('input:wasPressed("up") or input:wasPressed("down")',1,true),"vertical mirrored input must be explicitly neutralized")
end

print("overworld dialogue: minimal speaker/message/compact-choice tests passed")
