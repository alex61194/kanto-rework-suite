local root=assert(arg[1],"root path required")
local factory=assert(loadfile(root.."/main.lua"))()

local oldLove=love
love={
  filesystem={load=function(path) return assert(loadfile(path)) end},
  mouse={getRelativeMode=function() return false end,setRelativeMode=function() end,setVisible=function() end},
  mousemoved=function() end,mousepressed=function() end,mousereleased=function() end,
}
package.loaded["src.render.Pipelines"]={level=function() return 0 end}

local BattleArt={
  -- Voxel 1.8.5 DUPLICATE FIX: MODDED deliberately routes to an empty flat
  -- shiny folder so another mod / ROM can own missing art. Compatibility must
  -- still prevent a non-selected Ascendant provider from leaking into KRS.
  setting={get=function() return "animated" end},
  frontAnimationSetting={get=function() return "gen5" end},
  backAnimationSetting={get=function() return "gen5" end},
  apply=function() end,applyTrainers=function() end,releaseSpeciesOverrides=function() end,
  metrics=function() return {} end,playerSide=function() return "back" end,prefersModded=function() return true end,
}
local Animated={update=function() end,finish=function() end}
local OverworldBattle={battle=function() return nil end}
local FirstPerson={driving=function() return false end,moveVector=function() return 0,0 end,moveWorld=function(x,z)return x,z end}
local FreeMove={_blockedCell=function() return nil end}
local lib={require=function(name)
  return ({BattleArt=BattleArt,AnimatedBattleArt=Animated,OverworldBattle=OverworldBattle,FirstPerson=FirstPerson,FreeMove=FreeMove})[name]
end}
local voxel={id="BATTLE_ART_VOXEL_FORK",name="BATTLE ART VOXEL FORK",version="1.8.5",exports={lib=lib}}

local crystal={
  staticFrameOne=function() return "ascendant/crystal/pikachu.png" end,
  externalKantoActive=function() return false end,
  selected={},select=function() return nil end,
}
local ascendant={id="trainer_rematch",name="Kanto Ascendant",version="6.0.11",exports={
  ascendantMenu={},crystalAnimation=crystal,
}}

local defs,providers,prefs={}, {}, {}
local compatibility={}
function compatibility.define(d) defs[d.id]=d;return function() end end
function compatibility.registerProvider(d) providers[#providers+1]=d;return function() end end
function compatibility.registerDiagnostic() return function() end end
function compatibility.definition(id) return defs[id] end
function compatibility.providers(id) local o={} for _,p in ipairs(providers) do if p.capability==id then o[#o+1]=p end end return o end
function compatibility.resolve(id)
  local out={}
  for _,p in ipairs(providers) do if p.capability==id and (type(p.enabled)~="function" or p.enabled()~=false) then out[#out+1]=p end end
  table.sort(out,function(a,b) return (a.priority or 0)>(b.priority or 0) end)
  local pref=prefs[id]
  if pref then for i,p in ipairs(out) do if p.id==pref then table.remove(out,i);table.insert(out,1,p);break end end end
  return {id=id,mode=(defs[id] or {}).mode,providers=out,selected=out[1] and out[1].id,preferred=pref}
end
function compatibility.setPreference(id,p) prefs[id]=p;return true end

local adapters={}
local Core={version=40,dispatchPointerEvent=function() return true end,compatibility=compatibility,
  modIntegrations={register=function(a) adapters[#adapters+1]=a;return function() end end,registerDiscovery=function() return function() end end},
  inputMode=function() return {activeMode="pointer",activeDevice={kind="mouse"}} end,
  fieldActions={execute=function() return false end},
}
local mod={id="compatibility",suite={id="kanto_rework_suite"},path=root,exports={},
  read=function(_,relative) local f=assert(io.open(root.."/"..relative,"rb"));local body=f:read("*a");f:close();return body end,
  hooks={wrap=function() return function() end end},
  find=function(id)
    if id=="core" then return {exports=Core} end
    if id=="ui" then return {id=id,version="0.8.24"} end
    if id=="BATTLE_ART_VOXEL_FORK" then return voxel end
    if id=="trainer_rematch" then return ascendant end
    return nil
  end,
  events={on=function() return function() end end},log={info=function() end},
}
factory(mod)

local game={
  data={pokemon={PIKACHU={dex=25,spriteFront="rom/pikachu.png",spriteBack="rom/pikachub.png"}}},
  mods={modOptions={trainer_rematch={kanto_crystal_art=true,legend_art="crystal",crystal_animation=true}}},
}

-- Voxel has highest priority and is the selected Compatibility owner. Because
-- its own DUPLICATE FIX: MODDED path intentionally yields no Voxel image, the
-- correct KRS terminal fallback is Gen I. Returning nil would let Core/Sprites.path
-- run Ascendant's global hook and violate the explicit Compatibility owner.
local policy=mod.exports.pokemonVisualPolicy()
assert(policy.provider=="battle_art_voxel.pokemon_sprites","Voxel selected in Compatibility")
local art=mod.exports.resolvePokemonArt(game,"PIKACHU","front",{kind="party"})
assert(art and art.path=="rom/pikachu.png","selected Voxel provider falls back to immutable Gen I, not another mod")
assert(art.source=="battle_art_voxel.pokemon_sprites:rom_fallback","Voxel fallback remains terminally owned by Voxel capability")

-- Ascendant must only appear after it is explicitly selected.
assert(compatibility.setPreference("pokemon.sprite_art","kanto_ascendant.crystal_sprites"))
local crystalArt=mod.exports.resolvePokemonArt(game,"PIKACHU","front",{kind="party"})
assert(crystalArt and crystalArt.path=="ascendant/crystal/pikachu.png","Ascendant art appears only when explicitly selected")
assert(crystalArt.source=="kanto_ascendant.crystal_sprites","Ascendant source metadata")

-- Switching back to Voxel must immediately evict Ascendant from the shared resolver.
assert(compatibility.setPreference("pokemon.sprite_art","battle_art_voxel.pokemon_sprites"))
local artAgain=mod.exports.resolvePokemonArt(game,"PIKACHU","front",{kind="party"})
assert(artAgain and artAgain.path=="rom/pikachu.png" and artAgain.source:find("battle_art_voxel",1,true),"switching back to Voxel cannot leak Ascendant")

love=oldLove
print("Exclusive Pokemon sprite ownership is terminal across Voxel/Ascendant fallbacks")
