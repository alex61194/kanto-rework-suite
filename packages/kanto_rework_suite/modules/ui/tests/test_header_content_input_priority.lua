local root=assert(arg[1],"root path required")
local function loadModule(path)local c,e=loadfile(root..'/'..path);assert(c,e);return c()end
local function check(v,msg)if not v then error(msg or'check failed',2)end end
local function eq(a,b,msg)if a~=b then error((msg or'value')..': expected '..tostring(b)..', got '..tostring(a),2)end end
local function input()
  local o={pressed=nil}
  function o:wasPressed(action)if self.pressed==action then self.pressed=nil;return true end return false end
  return o
end
local Focus={new=function()return{}end,navigation=function()end,syncDevice=function()end,pointerMove=function()end,pointerPress=function()end}
local Layout={isWide=function()return true end,contains=function()return false end}
local Scroll={
  total=function(n,pitch,rowH)return n*pitch end,
  clamp=function(v,total,h)return math.max(0,math.min(v or 0,math.max(0,total-h)))end,
  ensure=function(v,top,bottom,total,h)if top<v then return top elseif bottom>v+h then return bottom-h end return v end,
  model=function()return nil end,
}

-- OPTIONS -------------------------------------------------------------------
local optionStep=0
local rows={
  {id='brightness',label='BRIGHTNESS',category='GRAPHICS',step=function(_,dir)optionStep=optionStep+dir;return true end},
  {id='about',label='ABOUT',category='GRAPHICS'},
  {id='music',label='MUSIC',category='AUDIO',step=function(_,dir)optionStep=optionStep+dir*10;return true end},
}
local optSession={rows=rows,native={update=function()end},syncVideoMode=function()end}
local optCore={createOptionsRuntime=function()return optSession end,inputActions={captureState=function()return nil end,cancelCapture=function()end},inputDeviceStatus=function()return{kind='keyboard'}end}
local optRuntime={Core=optCore,Focus=Focus,Layout=Layout,Scroll=Scroll,viewport={width=1920,height=1080},Catalog={
  categories=function()return{'GRAPHICS','AUDIO'}end,
  rows=function(all,category)local out={}for _,r in ipairs(all)do if r.category==category then out[#out+1]=r end end return out end,
  meta=function(row)return{disabled=false,control=row.step and'choice'or'label'}end,
}}
local Options=loadModule('screens/options_menu.lua').factory(optRuntime)
local game={input=input(),stack={pop=function()end},save={options={}}}
local options=Options.new(game)
-- Header keeps horizontal tab navigation.
game.input.pressed='right';options:update();eq(options.headerIndex,2,'Options header Right changes submenu')
-- Enter content and lock the active category.
game.input.pressed='down';options:update();eq(options.region,'settings','Options Down enters active submenu list');eq(options.categoryIndex,2,'Options enters the header-selected category')
-- Use a controlled GRAPHICS content state for line-level behavior.
options:selectCategory(1);options.region='settings';options.settingIndex=1;options.headerIndex=1
local headerBefore=options.headerIndex
game.input.pressed='right';options:update();eq(optionStep,1,'Options content Right acts on focused horizontal value');eq(options.headerIndex,headerBefore,'Options content Right never moves header submenu')
game.input.pressed='left';options:update();eq(optionStep,0,'Options content Left acts on focused horizontal value');eq(options.headerIndex,headerBefore,'Options content Left keeps submenu locked')
options.settingIndex=2;game.input.pressed='right';options:update();eq(optionStep,0,'Options row without horizontal action ignores Right');eq(options.headerIndex,headerBefore,'Options inert row cannot silently switch submenu')
options.settingIndex=1;game.input.pressed='up';options:update();eq(options.region,'settings','Options Up at first content row stays in list like Bag navigation');eq(options.settingIndex,1,'Options content clamps at first row')
game.input.pressed='b';options:update();eq(options.region,'header','Options Back explicitly returns to header')

-- MODS ----------------------------------------------------------------------
local adjustCalls={}
local modModel={id='demo_mod',name='Demo Mod',enabled=true,category='UI'}
local optionValue={id='quality',label='QUALITY',type='number',group='GENERAL'}
local optionAction={id='reset',label='RESET',type='action',group='GENERAL'}
local modSession={native={update=function()end}}
function modSession:models()return{modModel}end
function modSession:utilities()return{}end
function modSession:options()return{optionValue,optionAction}end
function modSession:profiles()return{}end
function modSession:errors()return{}end
function modSession:refresh()end
function modSession:prompt()return nil end
function modSession:model()return modModel end
function modSession:adjustOption(modId,optionId,dir)adjustCalls[#adjustCalls+1]={modId=modId,optionId=optionId,dir=dir};return true end
function modSession:restartRequired()return false end
function modSession:toggle()return true end
local modCore={createModRuntime=function()return modSession end}
local modRuntime={Core=modCore,Focus=Focus,Layout=Layout,Scroll=Scroll}
local Mods=loadModule('screens/mods_menu.lua').factory(modRuntime)
local modGame={input=input(),stack={pop=function()end}}
local mods=Mods.new(modGame)
-- Header still changes tabs.
modGame.input.pressed='right';mods:update();eq(mods.headerIndex,2,'Mods header Right changes submenu')
-- Return to MODS tab, expand and enter content.
mods:setTab(1,false);mods:setExpanded(modModel,true);mods:refresh();mods:enterContent()
local qualityIndex,qualityRow=mods:findKey('option:demo_mod:quality');check(qualityIndex and qualityRow,'expanded Mods option row exists')
mods.focusIndex=qualityIndex;mods.focusKey=qualityRow.key;mods.headerIndex=1;mods.tab=1;mods.region='content'
local modsHeader=mods.headerIndex
modGame.input.pressed='right';mods:update();eq(#adjustCalls,1,'Mods content Right changes supported option');eq(adjustCalls[1].dir,1,'Mods Right uses next value');eq(mods.headerIndex,modsHeader,'Mods content Right never changes header submenu')
modGame.input.pressed='left';mods:update();eq(#adjustCalls,2,'Mods content Left changes supported option');eq(adjustCalls[2].dir,-1,'Mods Left uses previous value');eq(mods.headerIndex,modsHeader,'Mods content Left keeps submenu locked')
local actionIndex,actionRow=mods:findKey('option:demo_mod:reset');mods.focusIndex=actionIndex;mods.focusKey=actionRow.key
modGame.input.pressed='right';mods:update();eq(#adjustCalls,2,'Mods action/submenu row ignores Right');eq(mods.headerIndex,modsHeader,'Mods inert horizontal action cannot switch submenu')
local firstIndex=mods.focusIndex
for i,row in ipairs(mods:rows())do if not row.header then firstIndex=i;break end end
mods.focusIndex=firstIndex;mods.focusKey=(mods:rows()[firstIndex] or {}).key;mods.region='content'
modGame.input.pressed='up';mods:update();eq(mods.region,'content','Mods Up at first content row stays in list like Bag navigation');eq(mods.focusIndex,firstIndex,'Mods content clamps at first row')
modGame.input.pressed='b';mods:update();eq(mods.region,'header','Mods Back explicitly returns to header')

print('Options/Mods header-content input priority tests passed')
