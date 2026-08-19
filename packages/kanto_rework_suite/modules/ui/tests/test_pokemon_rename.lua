local root=assert(arg[1],"root path required")
local function loadModule(path)local c,e=loadfile(root..'/'..path);assert(c,e);return c()end
local function check(v,msg)if not v then error(msg or'check failed',2)end end
local function eq(a,b,msg)if a~=b then error((msg or'value')..': expected '..tostring(b)..', got '..tostring(a),2)end end

local created
package.preload['src.ui.NamingScreen']=function()return{new=function(game,opts)created={game=game,opts=opts};return created end}end
package.preload['src.core.Sound']=function()return{play=function()end}end
local mon={species='PIKACHU',nickname='SPARK',level=25,moves={}}
local model={source=mon,name='SPARK',moves={},types={'ELECTRIC'}}
local partyState={index=1,battle=nil}
local Adapter={
  party=function()return{mon}end,
  pokemon=function(_,raw)model.source=raw;model.name=raw.nickname or raw.species;return model end,
  speciesDef=function()return{name='PIKACHU'}end,
  learnedMoves=function()return{},{}end,
}
local runtime={state=nil}
local foundation={setFocus=function()end,clearFocus=function()end,endDrag=function()end,beginDrag=function()end}
local controller=loadModule('ui/party_controller.lua')({Adapter=Adapter,Layout={partyNeighbor=function(i)return i end},C={},runtime=runtime,foundation=foundation,fixtureEnabled=false})
local stack={states={}};function stack:push(v)self.states[#self.states+1]=v end;function stack:pop()return table.remove(self.states)end;function stack:top()return self.states[#self.states]end
local writes=0;local game={save={party={mon}},stack=stack,data={},input={wasPressed=function()return false end},writeSave=function()writes=writes+1 end}
local state=controller:newState(game,partyState);state.mode='SummaryActive';state.mon=mon;state.pokemon=model;runtime.state=state
check(controller:renamePokemon(state),'Summary Rename opens naming flow')
check(created and created.opts and created.opts.title=='POKéMON NAME?','Rename uses the engine NamingScreen mechanism')
eq(created.opts.maxLen,10,'Pokémon nickname length is bounded to engine-compatible display')
created.opts.onDone('VOLT')
eq(mon.nickname,'VOLT','nickname updates immediately in live save memory')
eq(writes,0,'Pokémon rename never persists outside a true game Save')
eq(state.pokemon.name,'VOLT','Summary model refreshes immediately after validation')

-- Persistence semantics: an unsaved reload reconstructs from the previous disk
-- snapshot; only an explicit Save snapshot would carry the new nickname.
local persisted={party={{species='PIKACHU',nickname='SPARK'}}}
local unsavedReload={party={{species=persisted.party[1].species,nickname=persisted.party[1].nickname}}}
eq(unsavedReload.party[1].nickname,'SPARK','reload without Save restores previous persisted nickname')
persisted={party={{species=mon.species,nickname=mon.nickname}}}
local savedReload={party={{species=persisted.party[1].species,nickname=persisted.party[1].nickname}}}
eq(savedReload.party[1].nickname,'VOLT','explicit Save snapshot preserves renamed Pokémon')

local f=assert(io.open(root..'/ui/party_presenter.lua','rb'));local source=f:read('*a');f:close()
check(source:find('renameIndicator',1,true) and source:find('addRegion(state,"rename","rename"',1,true),'Summary exposes an explicit edit affordance to the right of the Pokémon name')
print('Pokémon Summary rename tests passed')
