local root=assert(arg[1],"root path required")
package.preload['src.world.Map']=function() return {isOutside=function() return true end} end
package.preload['src.world.FieldDefaults']=function() return {field=function() return {OUTDOOR=true} end} end
local devUnlocked=false
local service=assert(loadfile(root.."/core/map_interaction.lua"))()({runtime={},devFlyUnlocked=function() return devUnlocked end})
local game={data={},save={inventory={}},overworld={map={def={tileset="OUTDOOR"}}}}
local ok,reason=service.canUseFly(game)
assert(ok==false and reason=="hm_required","normal Fly progression remains gated")
devUnlocked=true
local unlocked,why=service.canUseFly(game)
assert(unlocked==true and why==nil,"temporary developer Fly override bypasses HM/badge only")
assert(next(game.save.inventory)==nil,"temporary Fly override does not write inventory/save progression")
print("Temporary developer Fly override tests passed")
