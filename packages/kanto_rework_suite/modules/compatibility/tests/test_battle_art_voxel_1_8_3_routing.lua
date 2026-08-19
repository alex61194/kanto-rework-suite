local root=assert(arg[1],"root path required")
local factory=assert(loadfile(root.."/main.lua"))()

local oldLove=love
local relative=false
love={
  filesystem={load=function(path) return assert(loadfile(path)) end},
  mouse={
    getRelativeMode=function() return relative end,
    setRelativeMode=function(value) relative=value end,
    setVisible=function() end,
  },
  mousemoved=function() end,
  mousepressed=function() end,
  mousereleased=function() end,
}

package.loaded["src.render.Pipelines"]={level=function() return 0 end}

local registeredAdapters={}
local discoveries=0
local diagnostics=0
local wrapped={}
local wrappers={}
local capabilityDefs,capabilityProviders={},{}
local compatibility={}
local preferences={}
function compatibility.define(def) capabilityDefs[def.id]=def;return function() capabilityDefs[def.id]=nil;return true end end
function compatibility.registerProvider(def) capabilityProviders[#capabilityProviders+1]=def;return function() return true end end
function compatibility.registerDiagnostic() diagnostics=diagnostics+1;return function() return true end end
function compatibility.definition(id) return capabilityDefs[id] end
function compatibility.providers(id) local out={};for _,p in ipairs(capabilityProviders) do if p.capability==id then out[#out+1]=p end end;return out end
function compatibility.resolve(id)
  local out={};for _,p in ipairs(capabilityProviders) do if p.capability==id then local enabled=type(p.enabled)~='function' or p.enabled()~=false;if enabled then out[#out+1]=p end end end
  table.sort(out,function(a,b)return (a.priority or 0)>(b.priority or 0) end)
  local preferred=preferences[id]
  if preferred then for i,p in ipairs(out) do if p.id==preferred then table.remove(out,i);table.insert(out,1,p);break end end end
  return {id=id,mode=(capabilityDefs[id] or {}).mode,providers=out,selected=out[1] and out[1].id}
end
function compatibility.setPreference(id,provider) preferences[id]=provider;return true end
local Core={
  version=40,
  dispatchPointerEvent=function() return true end,
  compatibility=compatibility,
  modIntegrations={
    registerDiscovery=function()
      discoveries=discoveries+1
      return function() return true end
    end,
    register=function(adapter)
      registeredAdapters[#registeredAdapters+1]=adapter
      return function() return true end
    end,
  },
  inputMode=function() return {activeMode="pointer",activeDevice={kind="mouse"}} end,
  fieldActions={execute=function() return false end},
}

local voxel={
  id="BATTLE_ART_VOXEL_FORK",
  name="BATTLE ART VOXEL FORK",
  version="1.8.3",
  exports={lib={require=function(name)
    if name=="BattleArt" then return {apply=function() end,applyTrainers=function() end,metrics=function() return {} end} end
    if name=="AnimatedBattleArt" then return {update=function() end} end
    if name=="OverworldBattle" then return {battle=function() return nil end} end
    if name=="FirstPerson" then return {driving=function() return false end,moveVector=function() return 0,0 end,moveWorld=function(x,z) return x,z end} end
    if name=="FreeMove" then return {_blockedCell=function() return nil end} end
    return {}
  end}},
}
local coreHandle={exports=Core}
local hooks={wrap=function(_,name,fn)
  wrapped[#wrapped+1]=name
  wrappers[name]=fn
  return function() wrappers[name]=nil;return true end
end}
local mod={
  id="compatibility",suite={id="kanto_rework_suite"},
  path=root,
  exports={},
  read=function(_,relative) local f=assert(io.open(root.."/"..relative,"rb"));local body=f:read("*a");f:close();return body end,
  hooks=hooks,
  find=function(id)
    if id=="core" then return coreHandle end
    if id=="ui" then return {id=id,version="0.8.24"} end
    if id=="BATTLE_ART_VOXEL_FORK" then return voxel end
    return nil
  end,
  events={on=function() return function() return true end end},
  log={info=function() end},
}

factory(mod)
assert(discoveries==1,"generic discovery still registers")
assert(#registeredAdapters==2,"Compatibility self conflict adapter and Voxel family adapter both register")
local voxelAdapter,selfAdapter
for _,a in ipairs(registeredAdapters) do
  if a.version=="1.8.3" then voxelAdapter=a end
  if a.modId=="kanto_rework_suite" then selfAdapter=a end
end
local ownRows=selfAdapter and selfAdapter.decorateOptions(nil,{}) or {}
local ownIds={};for _,row in ipairs(ownRows) do ownIds[row.id]=true end
assert(not ownIds.__krs_compat_sprite_upscale and not ownIds.__krs_compat_pokemon_real_size,"Graphics owns battle scale/Real Size; Compatibility no longer renders duplicate controls")
assert(voxelAdapter and voxelAdapter.version=="1.8.3","registered Voxel family adapter follows the live 1.8.3 release")
assert(voxelAdapter.match({id="BATTLE_ART_VOXEL_FORK",version="1.8.3"}),"family adapter matches live id/version without requiring a frozen name")
assert(mod.exports.release=="0.4.20","release export updated")
assert(mod.exports.rules.battleArtVoxel.version=="1.8.3" and mod.exports.rules.battleArtVoxel.latestAudited=="1.9.2","audit rule records live + latest audited release")
local sprite=compatibility.resolve("pokemon.sprite_art")
assert(sprite and #sprite.providers==2 and sprite.selected=="battle_art_voxel.pokemon_sprites","KRS exposes Gen1 + Voxel as a conflict-selectable unified Pokémon sprite capability")
compatibility.setPreference("pokemon.sprite_art","gen1recomp.pokemon_sprites")
local gen1=mod.exports.resolvePokemonArt({data={pokemon={PIKACHU={spriteFront="rom/front.png",spriteBack="rom/back.png"}}}},"PIKACHU","front",{})
assert(gen1 and gen1.path=="rom/front.png" and gen1.source=="gen1recomp.pokemon_sprites","GEN 1 provider bypasses live third-party pokemon.sprite hooks for KRS surfaces")
compatibility.setPreference("pokemon.sprite_art","battle_art_voxel.pokemon_sprites")
local sawOptions,sawStep=false,false
for _,name in ipairs(wrapped) do
  if name=="ui.options.rows" then sawOptions=true end
  if name=="input.step" then sawStep=true end
end
assert(sawOptions and sawStep,"1.8.3 stable contracts install both options and input bridges")
local bg=compatibility.resolve("battle.background")
assert(bg and #bg.providers==2,"battle background conflict remains visible after a version-only Voxel update")
local selfAdapter
for _,a in ipairs(registeredAdapters) do if a.id=="kanto_rework_compat.conflicts" then selfAdapter=a end end
local conflictRows=assert(selfAdapter,"Compatibility conflict presenter registered").decorateOptions(nil,{})
local foundBackground=false
for _,row in ipairs(conflictRows) do if row.id=="__compat:battle.background" then foundBackground=true break end end
assert(foundBackground,"Compatibility MOD page exposes the BATTLE BACKGROUND chooser when KRS + Voxel are active")
local game={mods={optionSchemas={
  BATTLE_ART_VOXEL_FORK={{key="voxelGrid",label="VOXEL GRID"},{key="newFutureOption",label="NEW FUTURE OPTION"}},
  OTHER_MOD={{key="foo",label="FOO"}},
}}}
local filter=assert(wrappers["ui.options.rows"],"global provenance filter installed")
local filtered=filter(function(_,rows) return rows end,game,{
  {id="textSpeed",label="TEXT SPEED"},
  {id="BATTLE_ART_VOXEL_FORK:voxelGrid",label="VOXEL GRID"},
  {id="BATTLE_ART_VOXEL_FORK:newFutureOption",label="NEW FUTURE OPTION"},
  {id="OTHER_MOD:foo",label="FOO"},
  {id="foo",label="FOO"},
  {id="pipeline:voxel",label="VOXEL"},
})
assert(#filtered==1 and filtered[1].id=="textSpeed","standard options from any mod plus Voxel engine pipelines are removed from global Options by ownership")
assert(diagnostics==3,"existing diagnostics preserved")

if type(mod.exports.unregister)=="function" then mod.exports.unregister() end
love=oldLove
print("Compatibility contract-family routing also preserves Battle Art Voxel Fork 1.8.3")
