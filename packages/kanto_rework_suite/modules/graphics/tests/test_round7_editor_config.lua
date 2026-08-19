local root=assert(arg[1]);local globalOptions={};local legacy={};local base={battle_sprite_mode='animated',sprite_animation=true,back_generation='gen5',front_generation='gen5',animation_speed='normal'}
local mod={options={get=function(_,k)return globalOptions[k]~=nil and globalOptions[k] or base[k] end,set=function(_,k,v)globalOptions[k]=v;return v end},storage={read=function(_,game,key)return legacy[key]end}}
local service=assert(loadfile(root..'/editor_config.lua'))()({mod=mod});local saveA,saveB={},{}
local g=service.global(saveA);assert(g.player.size==0 and g.opponent.orientation=='front','defaults are structured')
g.player.size=42;assert(service.commitGlobal(saveA,g));assert(service.global(saveB).player.size==42,'global commit persists across Pokemon saves')
local localv=service.global(saveA);localv.player.size=73;localv.player.position={x=500,y=700};assert(service.commitLocal(saveA,'grass','day',localv));local resolved,meta=service.resolve(saveB,'grass','day');assert(meta.source=='local' and resolved.player.size==73 and resolved.player.position.x==500,'background override is global across saves')
local other=service.global(saveB);other.player.size=55;assert(service.seedLocal(saveB,'road','sunset',other));local seeded=service.resolve(saveA,'road','sunset');assert(seeded.player.size==55,'new background override is seeded from current global values')
assert(service.saveProfile(saveA,'Large Sprites',g));local profiles=service.profiles(saveB);assert(profiles['Large Sprites'],'profile saved globally');assert(service.renameProfile(saveB,'Large Sprites','Custom'));assert(service.loadProfile(saveA,'Custom'));assert(service.deleteProfile(saveB,'Custom'),'profile lifecycle')
print('round7 graphics editor global persistence tests passed')
