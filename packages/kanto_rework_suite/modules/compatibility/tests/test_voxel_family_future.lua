local root=assert(arg[1],'root path required')
local factory=assert(loadfile(root..'/adapters/battle_art_voxel_family.lua'))()
local FirstPerson={driving=function() return false end,moveVector=function() return 0,0 end,moveWorld=function(x,z) return x,z end}
local FreeMove={_blockedCell=function() return nil end}
local BattleArt={apply=function() end,applyTrainers=function() end,metrics=function() return {} end}
local Animated={update=function() end}
local OverworldBattle={battle=function() return nil end}
local voxel={id='BATTLE_ART_VOXEL_FORK',version='1.8.6',exports={lib={require=function(name)
  return ({FirstPerson=FirstPerson,FreeMove=FreeMove,BattleArt=BattleArt,AnimatedBattleArt=Animated,OverworldBattle=OverworldBattle})[name]
end}}}
local Core={dispatchPointerEvent=function() end,inputMode=function() return {} end,fieldActions={execute=function() return false end}}
local adapter=factory({voxel=voxel,findMod=function(id) if id==voxel.id then return voxel end end,Core=Core,hooks={wrap=function() return function() end end}})
assert(adapter.version=='1.8.6' and adapter.match({id='BATTLE_ART_VOXEL_FORK',version='1.8.6'}),'future compatible version follows live identity')
local status=adapter.contractStatus()
assert(status.lib and status.battleArt and status.input,'stable public seams activate family domains independently of version number')
local writes=0
local game={save={options={}},writeOptions=function() writes=writes+1 end,mods={optionSchemas={BATTLE_ART_VOXEL_FORK={{key='brandNewKey',label='BRAND NEW KEY'}}}}}
local kept=adapter.filterGlobalOptions(game,{{id='BATTLE_ART_VOXEL_FORK:brandNewKey'},{id='pipeline:voxel'},{id='engineRow'}})
assert(#kept==1 and kept[1].id=='engineRow','future schema additions and pipeline controls remain outside global Options')
package.loaded['src.render.Pipelines']={levelLabel=function() return 'OFF' end,cycle=function() end,syncOptions=function() end}
package.loaded['src.render.Tilt']={setLevel=function() end}
local rows=adapter.decorateOptions(nil,{{id='brandNewKey',label='BRAND NEW KEY'}})
assert(rows[#rows].id=='brandNewKey','new future standard option stays available under the owning mod')
for _,row in ipairs(rows) do assert(row.id~='__krs_compat_sprite_upscale' and row.id~='__krs_compat_pokemon_real_size',"KRS scaling controls must not appear on Voxel's own mod card") end
local controls=adapter.presentationOptionRows();local upscale,real=controls[1],controls[2]
assert(upscale.id=='__krs_compat_sprite_upscale' and real.id=='__krs_compat_pokemon_real_size','Compatibility owns the two Voxel presentation rows')
assert(upscale.displayValue(game)=='DEFAULT','native x1 is the initial scale')
local settings=adapter.presentationSettings(game);assert(settings.upscale=='default' and settings.pixelScale==1 and settings.nativePixels==true,'DEFAULT is literal native x1')
assert(upscale.adjust(game,1) and upscale.displayValue(game)=='X0.5','legacy UPSCALE starts at the supported half scale')
assert(upscale.adjust(game,1) and upscale.displayValue(game)=='X2','UPSCALE includes literal x2')
assert(upscale.adjust(game,1) and upscale.displayValue(game)=='X3','UPSCALE includes literal x3')
assert(upscale.adjust(game,1) and upscale.displayValue(game)=='AUTO','UPSCALE includes computed AUTO')
assert(real.displayValue(game)=='AUTO','new installs default Pokémon real-size policy to AUTO')
assert(real.adjust(game,1) and real.displayValue(game)=='NO','real-size policy cycles independently')
settings=adapter.presentationSettings(game);assert(settings.upscale=='auto' and settings.pixelScale==nil and settings.realSize=='no','AUTO has no fixed multiplier and consumes the real-size policy')
assert(writes>=5,'legacy Compatibility presentation controls persist through the engine options writer')
print('Voxel contract-family future-version resilience tests passed')
