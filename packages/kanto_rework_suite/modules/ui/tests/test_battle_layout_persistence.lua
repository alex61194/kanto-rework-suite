local root=assert(arg[1])
local globalOptions={}
local legacyByGame=setmetatable({}, {__mode='k'})
local mod={
  options={
    get=function(_,key) return globalOptions[key] end,
    set=function(_,key,value) globalOptions[key]=value;return value end,
  },
  storage={
    read=function(_,game,key) local s=legacyByGame[game];return s and s[key] end,
    write=function() error('new battle layout writes must not use playthrough storage') end,
  },
}
local factory=assert(loadfile(root..'/runtime/battle_layout_config.lua'))()
local service=factory({mod=mod})
local saveA,saveB={},{}
local d=service.resolve(saveA)
assert(d.opponent_frame.x==0 and d.opponent_frame.scale==100 and d.player_frame.y==0 and d.player_frame.scale==100 and d.command_list.scale==100 and d.move_menu.scale==100,'defaults')
assert(d.command_fight.x==0 and d.command_pokemon.x==0 and d.command_bag.x==0 and d.command_run.x==0,'independent command defaults')
-- Legacy schema migrates from ONE playthrough into the global option bucket.
legacyByGame[saveA]={[service.storageKey()]={schema=1,opponent_frame={x=77,y=0},move_menu={x=0,y=-31}}}
local migrated=service.resolve(saveA)
assert(migrated.opponent_frame.x==77 and migrated.opponent_frame.scale==100 and migrated.move_menu.y==-31 and migrated.move_menu.scale==100,'schema1 merge migration')
assert(type(globalOptions[service.globalOptionKey()])=='table','legacy layout must be promoted to global KRS option')
-- A different Pokemon save sees the same visual configuration.
local acrossSave=service.resolve(saveB)
assert(acrossSave.opponent_frame.x==77 and acrossSave.move_menu.y==-31,'layout must persist across Pokemon saves')
acrossSave.opponent_frame.scale=125
assert(service.commit(saveB,acrossSave),'global commit')
local reloaded=service.resolve(saveA)
assert(reloaded.opponent_frame.x==77 and reloaded.opponent_frame.scale==125 and reloaded.move_menu.y==-31,'reload persisted global layout/scale')
local reset=service.resetTarget(reloaded,'opponent_frame')
assert(reset.opponent_frame.x==0 and reset.opponent_frame.scale==100 and reset.move_menu.y==-31,'individual reset must reset scale and preserve sibling target')
assert(legacyByGame[saveA][service.storageKey()].opponent_frame.x==77,'legacy storage must remain intact for rollback')
print('PASS test_battle_layout_persistence')
