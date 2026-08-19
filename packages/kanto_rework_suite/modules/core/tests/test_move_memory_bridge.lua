local root=assert(arg[1],'root required')
local storage={}
local mod={save={get=function(_,k,d) return storage[k] or d end,set=function(_,k,v) storage[k]=v end}}
local game={save={player={id=7}},data={moves={EMBER={pp=25},SCRATCH={pp=35}}}}
local L=assert(loadfile(root..'/core/move_library.lua'))()({mod=mod,runtime={}})
local mon={species='CHARMELEON',otId=7,dvs={attack=1,defense=2,speed=3,special=4},moves={{id='SCRATCH',pp=12,ppUps=1}}}
assert(L.remember(game,mon,'EMBER',0,0,'retroactive_pre_evolution'))
local rows=L.moves(game,mon,true);local found
for _,r in ipairs(rows) do if r.id=='EMBER' then found=r end end
assert(found and found.pp==0 and not found.disabled,'retroactively inferred inactive move preserves explicit unknown/depleted PP=0')
assert(L.remember(game,mon,'SCRATCH',1,0,'inference'))
rows=L.moves(game,mon,true);for _,r in ipairs(rows) do if r.id=='SCRATCH' then assert(r.pp==12 and r.disabled,'active move state remains authoritative') end end
local main=assert(io.open(root..'/main.lua','rb')):read('*a')
assert(main:find('mod.exports.rememberKnownMove',1,true),'Core exports the bridge used by Gameplay pre-evolution migration')
print('Move Memory Core bridge tests passed')
