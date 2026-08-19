local root=assert(arg[1],"root path required")
local function check(v,msg) if not v then error(msg or "check failed",2) end end
local function eq(a,b,msg) if a~=b then error((msg or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end end

-- Only the gameplay adapter is under test; engine UI dependencies are inert.
local MoveLearnMenu={enter=function()end}
local PartyMenu={new=function(_,opts)return{opts=opts}end}
local ListMenu={new=function(_,title,rows,opts)return{title=title,rows=rows,opts=opts}end}
local ItemEffects={use=function()return"failed",{"native"}end}
local TextBox={new=function(_,message,onDone,opts)return{message=message,onDone=onDone,opts=opts}end,soundOpts=function()return{}end}
package.preload['src.ui.MoveLearnMenu']=function()return MoveLearnMenu end
package.preload['src.ui.PartyMenu']=function()return PartyMenu end
package.preload['src.ui.ListMenu']=function()return ListMenu end
package.preload['src.inventory.ItemEffects']=function()return ItemEffects end
package.preload['src.render.TextBox']=function()return TextBox end
package.preload['src.core.Sound']=function()return{play=function()end}end
local boxesEnsureCalls=0
package.preload['src.pokemon.Boxes']=function()return{ensure=function(save)boxesEnsureCalls=boxesEnsureCalls+1;return save.boxes or {} end}end

local function memoryRows(mon)
  local out={}
  for _,row in ipairs(mon.memory or {}) do out[#out+1]={id=row.id,pp=row.pp,ppUps=row.ppUps,source=row.source} end
  return out
end
local Core={}
local rememberCalls={}
function Core.knownMoves(mon,includeActive)
  local out=memoryRows(mon)
  if includeActive then
    local seen={};for _,r in ipairs(out)do seen[r.id]=true end
    for _,r in ipairs(mon.moves or {})do if r.id and not seen[r.id] then out[#out+1]={id=r.id,pp=r.pp,ppUps=r.ppUps,active=true};seen[r.id]=true end end
  end
  return out
end
function Core.rememberKnownMove(mon,id,pp,ppUps,source)
  rememberCalls[#rememberCalls+1]={mon=mon,id=id,pp=pp,ppUps=ppUps,source=source}
  mon.memory=mon.memory or {}
  for _,r in ipairs(mon.memory)do if r.id==id then return false end end
  mon.memory[#mon.memory+1]={id=id,pp=pp,ppUps=ppUps,source=source};return true
end
function Core.restoreKnownMovePP()return true end
function Core.ppUpKnownMove()return true end

local handlers={}
local mod={events={}}
function mod.events:on(name,cb) handlers[name]=cb;return function()handlers[name]=nil end end

local moves={}
for _,id in ipairs({'TACKLE','GROWL','BITE','LATE','EVOMOVE','SURF','CUT','EMBER'})do moves[id]={name=id,pp=20} end
local pokemon={
  BASEMON={name='BASEMON',level1Moves={'TACKLE'},learnset={{level=5,move='GROWL'},{level=10,move='BITE'},{level=40,move='LATE'}},evolutions={{method='level',level=16,species='EVOMON'}}},
  EVOMON={name='EVOMON',level1Moves={'TACKLE'},learnset={{level=20,move='EVOMOVE'},{level=35,move='LATE'}}},
}
local game={data={pokemon=pokemon,moves=moves},save=nil}
local factory=assert(loadfile(root..'/move_memory.lua'))()
local adapter=factory({Core=Core,Game=game,mod=mod})
check(type(handlers['game.ready'])=='function' and type(handlers['save.loaded'])=='function','migration subscribes to load/ready seams')

local low={species='BASEMON',level=7,moves={{id='TACKLE',pp=4,ppUps=0}},memory={}}
local high={species='BASEMON',level=45,moves={{id='SURF',pp=7,ppUps=0}},memory={{id='BITE',pp=1,ppUps=2,source='learned'}}}
local evolved={species='EVOMON',level=50,moves={{id='EVOMOVE',pp=6,ppUps=0}},memory={{id='EMBER',pp=3,ppUps=1,source='observed'}}}
local tmhm={species='BASEMON',level=12,moves={{id='SURF',pp=9,ppUps=0},{id='CUT',pp=20,ppUps=0}},memory={}}
local existing={species='BASEMON',level=12,moves={{id='TACKLE',pp=2,ppUps=0}},memory={{id='GROWL',pp=5,ppUps=1,source='observed'}}}
local boxLow={species='BASEMON',level=3,moves={{id='TACKLE',pp=8,ppUps=0}},memory={}}
game.save={party={low,evolved,tmhm},boxes={{high,existing},{boxLow},{}}}

local beforeActive={low=low.moves[1].pp,evolved=evolved.moves[1].pp,tm1=tmhm.moves[1].pp,tm2=tmhm.moves[2].pp,existing=existing.moves[1].pp}
local first=adapter.migrate(game,'test.first')
check(boxesEnsureCalls>0,'migration uses the active Boxes.ensure storage access point')
eq(first.mons,6,'party + every PC box Pokémon migrated')
check(first.added>0,'migration reconstructs provable level-up history')
eq(first.uncertainEvolution,1,'evolved Pokémon with pre-evolutions remains documented for migration telemetry')

local function find(mon,id)
  for _,r in ipairs(mon.memory or {})do if r.id==id then return r end end
end
check(find(low,'GROWL')~=nil,'low-level Pokémon receives eligible level-up move')
check(find(low,'BITE')==nil and find(low,'LATE')==nil,'moves above current level are excluded')
check(find(high,'TACKLE') and find(high,'GROWL') and find(high,'LATE'),'high-level Pokémon receives all eligible current-species level-up moves')
eq(find(high,'BITE').pp,1,'already remembered move PP is preserved')
eq(find(high,'BITE').ppUps,2,'already remembered PP Ups are preserved')
local migrationRememberedTmHm=false
for _,call in ipairs(rememberCalls)do if call.id=='SURF' or call.id=='CUT' then migrationRememberedTmHm=true end end
check(not migrationRememberedTmHm,'migration never infers/remembers active TM/HM as retroactive candidates')
check(find(high,'SURF')==nil and find(tmhm,'SURF')==nil and find(tmhm,'CUT')==nil,'test ledger receives no TM/HM records from migration')
check(find(tmhm,'TACKLE') and find(tmhm,'GROWL') and find(tmhm,'BITE'),'TM/HM active moves do not block legitimate level-up reconstruction')
check(find(evolved,'TACKLE')~=nil and find(evolved,'LATE')~=nil,'evolved Pokémon receives current-species level-up history')
check(find(evolved,'BITE')~=nil and find(evolved,'GROWL')~=nil,'evolved Pokémon also receives pre-evolution level-up history')
eq(find(evolved,'EMBER').pp,3,'legitimately remembered evolved-mon history is preserved')
eq(find(existing,'GROWL').pp,5,'pre-existing remembered PP is untouched')
check(find(existing,'BITE')~=nil,'already-populated Move Memory can be extended without replacement')
check(find(boxLow,'GROWL')==nil,'PC low-level Pokémon obeys level gate')

-- Newly inferred inactive moves deliberately start at 0 PP: historical PP is
-- not reconstructible and the migration must never manufacture restoration.
eq(find(low,'GROWL').pp,0,'new retroactive memory does not restore PP')
eq(find(existing,'BITE').pp,0,'newly inferred PP is zero')
eq(low.moves[1].pp,beforeActive.low,'active PP preserved (low)')
eq(evolved.moves[1].pp,beforeActive.evolved,'active PP preserved (evolved)')
eq(tmhm.moves[1].pp,beforeActive.tm1,'active HM PP preserved')
eq(tmhm.moves[2].pp,beforeActive.tm2,'second active HM PP preserved')
eq(existing.moves[1].pp,beforeActive.existing,'active PP preserved with existing memory')

local function snapshot()
  local parts={}
  local mons={low,high,evolved,tmhm,existing,boxLow}
  for mi,mon in ipairs(mons)do
    local rows={};for _,r in ipairs(mon.memory or {})do rows[#rows+1]=(r.id or'')..':'..tostring(r.pp)..':'..tostring(r.ppUps)..':'..tostring(r.source) end
    table.sort(rows);parts[#parts+1]=mi..'='..table.concat(rows,',')
  end
  return table.concat(parts,'|')
end
local snap=snapshot();local second=adapter.migrate(game,'test.second')
eq(second.added,0,'second migration is idempotent')
eq(snapshot(),snap,'second migration produces byte-equivalent logical Move Memory state')

-- No duplicate records are allowed.
for _,mon in ipairs({low,high,evolved,tmhm,existing,boxLow})do local seen={} for _,r in ipairs(mon.memory or {})do check(not seen[r.id],'no duplicate move memory entry for '..tostring(r.id));seen[r.id]=true end end

local inferred,meta=adapter.inferLevelMoves(game,evolved)
check(#inferred>=5,'evolved inference includes current-species and pre-evolution learnsets')
eq(meta.reason,'current_species_plus_pre_evolutions_levelup','combined current/pre-evolution reconstruction reason is exposed')
check(meta.preEvolutionHistoryUnknown==true,'presence of pre-evolutions remains documented separately')
check(adapter.uninstall(),'migration adapter uninstalls cleanly')
print('Move Memory retroactive migration tests passed')
