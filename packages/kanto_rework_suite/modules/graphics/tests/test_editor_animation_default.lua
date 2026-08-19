local root=assert(arg[1])
local globalOptions={}
local legacyByGame=setmetatable({}, {__mode='k'})
local baseOptions={battle_sprite_mode='animated',sprite_animation=true,back_generation='gen5',front_generation='gen5',animation_speed='normal'}
local mod={
  options={
    get=function(_,k) return globalOptions[k]~=nil and globalOptions[k] or baseOptions[k] end,
    set=function(_,k,v) globalOptions[k]=v;return v end,
  },
  storage={read=function(_,game,key) local s=legacyByGame[game];return s and s[key] end},
}
local service=assert(loadfile(root..'/editor_config.lua'))()({mod=mod})
local saveA,saveB={},{}
local fresh=service.global(saveA)
assert(fresh.player.animationSpeed==15 and fresh.opponent.animationSpeed==15,'fresh editor animation speed must default to 15%')
baseOptions.animation_speed='fast'
local stillFresh=service.global(saveB)
assert(stillFresh.player.animationSpeed==15 and stillFresh.opponent.animationSpeed==15,'global FAST choice must not overwrite editor percentage default')
-- Existing legacy saved editor percentages migrate and remain unchanged.
legacyByGame[saveA]={graphics_editor_global_v1={schema=2,player={animationSpeed=67},opponent={animationSpeed=31}}}
local saved=service.global(saveA)
assert(saved.player.animationSpeed==67 and saved.opponent.animationSpeed==31,'saved editor percentage must be preserved')
assert(globalOptions.graphics_editor_global_v1.player.animationSpeed==67,'legacy percentage must migrate to global option')
local otherSave=service.global(saveB)
assert(otherSave.player.animationSpeed==67 and otherSave.opponent.animationSpeed==31,'global editor values must cross save slots')
print('PASS test_editor_animation_default')
