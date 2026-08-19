local options={};local base={battle_sprite_mode='animated',sprite_animation=true,back_generation='gen5',front_generation='gen5',animation_speed='normal'}
local mod={options={get=function(_,k)return options[k]~=nil and options[k] or base[k] end,set=function(_,k,v)options[k]=v;return v end},storage={read=function() return nil end}}
local E=assert(loadfile('../editor_config.lua'))()({mod=mod})
local saveA,saveB={},{}
local cfg=E.global(saveA);cfg.player.size=37
assert(E.commitLocal(saveA,'grass','day',cfg))
assert(E.hasLocal(saveB,'grass','sunrise') and E.hasLocal(saveB,'grass','sunset') and E.hasLocal(saveB,'grass','night'),'time variants share one global family calibration')
local a,ma=E.resolve(saveB,'grass','sunrise');local b,mb=E.resolve(saveA,'grass','night')
assert(a.player.size==37 and b.player.size==37 and ma.source=='local' and mb.source=='local','all time variants resolve shared local settings')
local cave=E.global(saveA);cave.player.size=11;assert(E.commitLocal(saveA,'cave_test','variant_a',cave))
local cave2=E.global(saveB);cave2.player.size=22;assert(E.commitLocal(saveB,'cave_test','variant_b',cave2))
assert(E.resolve(saveB,'cave_test','variant_a').player.size==11 and E.resolve(saveA,'cave_test','variant_b').player.size==22,'structural variants remain independently overridable')
assert(E.variantType('day')=='time' and E.variantType('variant_a')=='structural','variant type is explicit')
print('PASS test_editor_time_family')
