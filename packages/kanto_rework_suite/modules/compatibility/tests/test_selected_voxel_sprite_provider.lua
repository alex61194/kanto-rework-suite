local root=assert(arg[1],"root path required")
local factory=assert(loadfile(root.."/main.lua"))()

local oldLove=love
love={
  filesystem={load=function(path) return assert(loadfile(path)) end},
  mouse={getRelativeMode=function() return false end,setRelativeMode=function() end,setVisible=function() end},
  mousemoved=function() end,mousepressed=function() end,mousereleased=function() end,
}
package.loaded["src.render.Pipelines"]={level=function() return 0 end}

local frontImage={id="voxel-front"}
local shinyFrontImage={id="voxel-front-shiny"}
local backImage={id="voxel-back"}
local applyCalls=0
local BattleArt={
  setting={get=function() return "animated" end},
  frontAnimationSetting={get=function() return "gen5" end},
  backAnimationSetting={get=function() return "gen5" end},
  apply=function() applyCalls=applyCalls+1 end,
  applyTrainers=function() end,
  releaseSpeciesOverrides=function() end,
  metrics=function(image) return {w=64,h=64,id=image and image.id} end,
  playerSide=function() return "back" end,
}
local Animated={
  update=function(battle)
    if battle.enemy and battle.enemy.mon and battle.enemy.mon.species then
      battle.enemy.sprite=battle.enemy.mon.shiny and shinyFrontImage or frontImage
    end
    if battle.player and battle.player.mon and battle.player.mon.species then battle.player.sprite=backImage end
  end,
  finish=function() end,
}
local OverworldBattle={battle=function() return nil end}
local FirstPerson={driving=function() return false end,moveVector=function() return 0,0 end,moveWorld=function(x,z) return x,z end}
local FreeMove={_blockedCell=function() return nil end}
local lib={require=function(name)
  return ({BattleArt=BattleArt,AnimatedBattleArt=Animated,OverworldBattle=OverworldBattle,FirstPerson=FirstPerson,FreeMove=FreeMove})[name]
end}
local voxel={id="BATTLE_ART_VOXEL_FORK",name="BATTLE ART VOXEL FORK",version="1.8.4",exports={lib=lib}}

local defs,providers,prefs={}, {}, {}
local compatibility={}
function compatibility.define(d) defs[d.id]=d;return function() defs[d.id]=nil end end
function compatibility.registerProvider(d) providers[#providers+1]=d;return function() end end
function compatibility.registerDiagnostic() return function() end end
function compatibility.definition(id) return defs[id] end
function compatibility.providers(id) local out={} for _,p in ipairs(providers) do if p.capability==id then out[#out+1]=p end end return out end
function compatibility.resolve(id)
  local out={}
  for _,p in ipairs(providers) do
    if p.capability==id and (type(p.enabled)~="function" or p.enabled()~=false) then out[#out+1]=p end
  end
  table.sort(out,function(a,b) return (a.priority or 0)>(b.priority or 0) end)
  local pref=prefs[id]
  if pref then for i,p in ipairs(out) do if p.id==pref then table.remove(out,i);table.insert(out,1,p);break end end end
  return {id=id,mode=(defs[id] or {}).mode,providers=out,selected=out[1] and out[1].id}
end
function compatibility.setPreference(id,p) prefs[id]=p;return true end

local adapters={}
local Core={
  version=40,dispatchPointerEvent=function() return true end,
  compatibility=compatibility,
  modIntegrations={register=function(a) adapters[#adapters+1]=a;return function() end end,registerDiscovery=function() return function() end end},
  inputMode=function() return {activeMode="pointer",activeDevice={kind="mouse"}} end,
  fieldActions={execute=function() return false end},
}
local wrappers={}
local mod={
  id="compatibility",suite={id="kanto_rework_suite"},path=root,exports={},
  read=function(_,relative) local f=assert(io.open(root.."/"..relative,"rb"));local body=f:read("*a");f:close();return body end,
  hooks={wrap=function(_,name,fn) wrappers[name]=fn;return function() end end},
  find=function(id)
    if id=="core" then return {exports=Core} end
    if id=="ui" then return {id=id,version="0.8.24"} end
    if id=="BATTLE_ART_VOXEL_FORK" then return voxel end
    return nil
  end,
  events={on=function() return function() end end},log={info=function() end},
}
factory(mod)

local game={data={pokemon={PIKACHU={spriteFront="rom-front",spriteBack="rom-back"}}}}
local policy=mod.exports.pokemonVisualPolicy()
assert(policy.provider=="battle_art_voxel.pokemon_sprites","Voxel is selected by default when it is the highest-priority active provider")
local front=mod.exports.resolvePokemonArt(game,"PIKACHU","front",{})
assert(front and front.image==frontImage and front.source=="battle_art_voxel.pokemon_sprites","selected Voxel provider supplies menu/front art")
local firstApplyCalls=applyCalls
local frontSecond=mod.exports.resolvePokemonArt(game,"PIKACHU","front",{})
assert(frontSecond and frontSecond.image==frontImage and applyCalls==firstApplyCalls,
  "menu animation preview does not re-apply Voxel BattleArt every render frame")
local shinyMon={species="PIKACHU",shiny=true,dvs={attack=10,defense=10,speed=10,special=10}}
local shinyFront=mod.exports.resolvePokemonArt(game,"PIKACHU","front",{kind="party",mon=shinyMon})
assert(shinyFront and shinyFront.image==shinyFrontImage,"menu preview forwards the real shiny party record to Voxel")
assert(shinyMon.species=="PIKACHU" and shinyMon.shiny==true,"Voxel preview cannot mutate the source party record")
local back=mod.exports.resolvePokemonArt(game,"PIKACHU","back",{player=true})
assert(back and back.image==backImage and back.source=="battle_art_voxel.pokemon_sprites","selected Voxel provider supplies player battle/back art")
local liveFrame={id="voxel-live-frame-2"}
local liveBattler={mon={species="PIKACHU"},sprite=liveFrame}
local beforeLiveApply=applyCalls
local liveBattleArt=mod.exports.resolvePokemonArt(game,"PIKACHU","front",{kind="battle",mon=liveBattler.mon,battler=liveBattler})
assert(liveBattleArt and liveBattleArt.image==liveFrame and liveBattleArt.liveBattle==true,
  "KRS battle renderer consumes the real Voxel battler animation frame")
assert(applyCalls==beforeLiveApply,"resolving a live battle frame never restarts Voxel BattleArt")

assert(compatibility.setPreference("pokemon.sprite_art","gen1recomp.pokemon_sprites"))
local rom=mod.exports.resolvePokemonArt(game,"PIKACHU","front",{})
assert(rom and rom.path=="rom-front" and rom.source=="gen1recomp.pokemon_sprites","switching to Gen 1 immediately changes the shared resolver")
assert(compatibility.setPreference("pokemon.sprite_art","battle_art_voxel.pokemon_sprites"))
local frontAgain=mod.exports.resolvePokemonArt(game,"PIKACHU","front",{})
assert(frontAgain and frontAgain.image==frontImage,"switching back to Voxel immediately restores the same provider on menus")

love=oldLove
print("Selected Voxel sprite provider is honored in menus and battle")
