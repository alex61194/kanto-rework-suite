local root=assert(arg[1],"root path required")
local function loadModule(path)local c,e=loadfile(root..'/'..path);assert(c,e);return c()end
local function check(v,msg)if not v then error(msg or'check failed',2)end end
local function eq(a,b,msg)if a~=b then error((msg or'value')..': expected '..tostring(b)..', got '..tostring(a),2)end end

-- ---------------- Title: CLOSE regression + official third-party hook ----------------
local nativeEnterCount=0
local quitCount=0
local NativeTitle={}
function NativeTitle.new(game,opts)
  local inner={game=game,opts=opts}
  function inner:enter()nativeEnterCount=nativeEnterCount+1 end
  function inner:openMenu()
    self.game.stack:push({items={{label='NEW GAME'},{label='EXIT GAME',onSelect=function()quitCount=quitCount+1 end}}})
  end
  return inner
end
package.preload['src.ui.TitleState']=function()return NativeTitle end
package.preload['src.core.SaveData']=function()return{listSlots=function()return{{exists=true}}end}end
package.preload['src.core.GameVersion']=function()return{get=function()return'RED'end,isBlue=function()return false end,isYellow=function()return false end}end
local optionPush=0
package.preload['src.ui.Screens']=function()return{push=function(_,id)if id=='OptionsMenu'then optionPush=optionPush+1 end end}end
package.preload['src.core.Sound']=function()return{play=function()end}end
package.preload['src.core.Strings']=function()return function(v)return v end end
local precacheCount,newWrapped,newBase=0,0,0
package.preload['src.mods.Runtime']=function()return{
  call=function(name,fallback,game,items)
    check(name=='ui.title_menu.items','title uses official engine menu hook')
    local out={}
    for _,item in ipairs(items)do
      if item.label=='NEW GAME'then
        local original=item.onSelect
        out[#out+1]={label=item.label,onSelect=function()newWrapped=newWrapped+1;original()end}
      elseif item.label=='EXIT GAME'then
        out[#out+1]={label='PRECACHE',onSelect=function()precacheCount=precacheCount+1 end}
        out[#out+1]=item
      else out[#out+1]=item end
    end
    return out
  end,
}end
love={graphics={newImage=function()error('headless: no title bitmap')end}}
local stack={states={}}
function stack:push(v)self.states[#self.states+1]=v end
function stack:pop()return table.remove(self.states)end
function stack:top()return self.states[#self.states]end
local game={stack=stack,input={wasPressed=function()return false end},data={}}
local focusNavCount=0
local runtime={
  assetPath=function(p)return p end,
  Focus={new=function()return{}end,navigation=function()focusNavCount=focusNavCount+1 end,syncDevice=function()end,pointerMove=function()end,pointerPress=function()end},
  Layout={isWide=function()return true end,contains=function()return false end},
  Core={saveSlots={list=function()return{{exists=true}}end}},
  SaveSlotsFactory={new=function(_,mode)return{kind='save_slots',mode=mode}end},
}
local Title=loadModule('screens/title_screen.lua').factory(runtime)
local title=Title.new(game,{onNewGame=function()newBase=newBase+1 end})
eq(#title.rows,5,'external PRECACHE row is merged with KRS startup actions')
eq(title.rows[1].id,'new_game','KRS keeps validated NEW GAME order')
eq(title.rows[2].id,'load_game','KRS keeps LOAD GAME order')
eq(title.rows[3].id,'options','KRS keeps OPTIONS order')
eq(title.rows[4].label,'PRECACHE','third-party title row is preserved')
eq(title.rows[5].id,'exit_game','external row stays before EXIT GAME')
check(type(title.activeItemId)=='function','title exposes presenter activeItemId contract')
eq(title:activeItemId(),title:activeId(),'activeItemId aliases canonical active focus')

-- Exact regression from screenshot: returning from CLOSE must not leave title
-- artwork with an empty/actionless presenter. enter() repopulates live rows.
title.rows={};title:enter();eq(#title.rows,5,'CLOSE -> title enter rebuilds visible option rows');eq(nativeEnterCount,1,'native title lifecycle still runs')

local externalIndex
for i,row in ipairs(title.rows)do if row.label=='PRECACHE'then externalIndex=i end end
check(externalIndex~=nil,'PRECACHE remains discoverable after title re-entry')
check(title:activate(externalIndex),'external title action can be activated');eq(precacheCount,1,'exact third-party callback is invoked')
local newIndex;for i,row in ipairs(title.rows)do if row.id=='new_game'then newIndex=i end end
title:activate(newIndex);eq(newWrapped,1,'third-party wrapper around NEW GAME runs');eq(newBase,1,'wrapped KRS NEW GAME action still runs')
local exitIndex;for i,row in ipairs(title.rows)do if row.id=='exit_game'then exitIndex=i end end
title:activate(exitIndex);eq(quitCount,1,'EXIT remains engine-owned and functional')

-- ---------------- In-game Main Menu: external native rows stay out ----------------
local builtPokemon={label='POKéMON',onSelect=function()end}
local cache={label='CACHE',onSelect=function()error('in-game Main Menu must not call external CACHE')end}
local cries={label='CRIES',onSelect=function()error('in-game Main Menu must not call external CRIES')end}
local session={
  native={items={builtPokemon,cache,cries}},
  entries={{id='pokemon',enabled=true},{id='options',enabled=true},{id='mods',enabled=true},{id='close',enabled=true}},
  byNative={pokemon=builtPokemon},supported=true,
  activate=function(self,id)self.lastActivated=id;return true end,
  trainerModel=function()return{}end,
}
local startRuntime={
  Core={createStartMenuRuntime=function()return session end,journalContext=function()return{}end},
  Focus={new=function()return{}end,navigation=function()end,syncDevice=function()end,pointerMove=function()end,pointerPress=function()end},
  Layout={isWide=function()return true end,contains=function()return false end},
}
local Start=loadModule('screens/start_menu.lua').factory(startRuntime)
local start=Start.new({save={party={{}},player={name='RED'}},input={wasPressed=function()return false end}})
for _,entry in ipairs(start.entries)do
  check(entry.label~='CACHE' and entry.label~='CRIES','third-party title/start actions are not projected into the in-game Main Menu')
  check(not entry.external,'in-game Main Menu contains canonical KRS entries only')
end
eq(#start.entries,9,'in-game Main Menu keeps its fixed nine canonical entries')

local presenter=assert(io.open(root..'/ui/menu_presenter.lua','rb')):read('*a')
check(presenter:find('local rows=screen.rows or {};local perColumn=5',1,true),'title presenter has bounded multi-column overflow for extra mod actions')
print('Title-only third-party actions and fixed in-game Main Menu tests passed')
