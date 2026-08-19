local root=assert(arg[1],"root path required")
local factory=assert(loadfile(root.."/main.lua"))()

local oldLove=love
love={
  filesystem={load=function(path) return assert(loadfile(path)) end},
  mouse={getRelativeMode=function() return false end,setRelativeMode=function() end,setVisible=function() end},
  mousemoved=function() end,mousepressed=function() end,mousereleased=function() end,
}
package.loaded["src.render.Pipelines"]={level=function() return 0 end}

local selectedCalls,unselectedCalls=0,0
package.loaded["src.mods.Runtime"]={hooks={chains={
  ["music.select"]={{owner="SFXMusicReplacementMod",priority=100,callback=function(next,song,ctx) return next(song,ctx) end}},
  ["pokemon.sprite"]={
    {owner="future_sprite_mod",priority=300,callback=function(next,path,ctx)
      selectedCalls=selectedCalls+1
      local base=next(path,ctx)
      ctx.trueColor=true
      return "future/"..base
    end},
    {owner="unselected_sprite_mod",priority=200,callback=function(next,path,ctx)
      unselectedCalls=unselectedCalls+1
      return "wrong/"..next(path,ctx)
    end},
  },
}}}

local defs={
  ["audio.music"]={id="audio.music",label="MUSIC PROVIDERS",mode="exclusive"},
}
local providers,prefs={},{ }
local compatibility={}
function compatibility.define(d) defs[d.id]=d;return function() defs[d.id]=nil;return true end end
function compatibility.registerProvider(d)
  assert(defs[d.capability],"unknown capability: "..tostring(d.capability))
  providers[d.id]=d
  return function() if providers[d.id]==d then providers[d.id]=nil;return true end return false end
end
function compatibility.registerDiagnostic() return function() return true end end
function compatibility.definition(id) return defs[id] end
function compatibility.providers(id) local out={} for _,p in pairs(providers) do if p.capability==id then out[#out+1]=p end end return out end
function compatibility.resolve(id)
  local out={}
  for _,p in pairs(providers) do
    if p.capability==id and (type(p.enabled)~="function" or p.enabled()~=false) then out[#out+1]=p end
  end
  table.sort(out,function(a,b) local ap,bp=a.priority or 0,b.priority or 0;if ap==bp then return a.id<b.id end return ap>bp end)
  local pref=prefs[id]
  if pref then for i,p in ipairs(out) do if p.id==pref then table.remove(out,i);table.insert(out,1,p);break end end end
  return {id=id,mode=(defs[id] or {}).mode,providers=out,selected=out[1] and out[1].id,preferred=pref}
end
function compatibility.setPreference(id,p) assert(providers[p],"provider exists");prefs[id]=p;return true end

local adapters={}
local Core={version=40,dispatchPointerEvent=function() return true end,compatibility=compatibility,
  modIntegrations={
    register=function(a) adapters[#adapters+1]=a;return function() return true end end,
    registerDiscovery=function() return function() return true end end,
  },
  inputMode=function() return {activeMode="pointer",activeDevice={kind="mouse"}} end,
  fieldActions={execute=function() return false end},
}

local ascendant={id="trainer_rematch",version="9.4.2",exports={
  ascendantMenu={},
  crystalAnimation={staticFrameOne=function() return "future_ascendant/pikachu.png" end,selected={}},
}}
local handles={
  core={exports=Core},
  ui={id="ui",version="0.8.24",exports={}},
  trainer_rematch=ascendant,
  SFXMusicReplacementMod={id="SFXMusicReplacementMod",version="9.0.0",exports={}},
  dynamic_cries_next={id="dynamic_cries_next",version="2.7.0",exports={}},
  future_sprite_mod={id="future_sprite_mod",version="42.0.0",exports={}},
  unselected_sprite_mod={id="unselected_sprite_mod",version="1.0.0",exports={}},
}
local ready={}
local mod={id="compatibility",suite={id="kanto_rework_suite"},path=root,exports={},
  read=function(_,relative) local f=assert(io.open(root.."/"..relative,"rb"));local body=f:read("*a");f:close();return body end,
  hooks={wrap=function() return function() return true end end},
  find=function(id) return handles[id] end,
  events={on=function(_,name,fn) if name=="game.ready" then ready[#ready+1]=fn end return function() return true end end},
  log={info=function() end},
}

factory(mod)

local game={
  save={options={kantoReworkCapabilityPreferences={ ["audio.cries"]="stadium_dynamic_cries.1_4_3" }}},
  data={
    pokemon={PIKACHU={dex=25,spriteFront="rom/pikachu.png",spriteBack="rom/pikachu_back.png"}},
    audio={_owners={
      songs={Music_PalletTown="SFXMusicReplacementMod"},
      sfx={Press_AB="SFXMusicReplacementMod",Damage="SFXMusicReplacementMod"},
      cries={PIKACHU="dynamic_cries_next"},
    }},
  },
  mods={
    modOptions={trainer_rematch={kanto_crystal_art=true,crystal_animation=false}},
    optionSchemas={
      SFXMusicReplacementMod={{key="soundtrack",label="SOUNDTRACK"},{key="sfx_pack",label="SOUND EFFECTS"}},
    },
    mods={
      trainer_rematch={manifest={id="trainer_rematch",name="Kanto Ascendant",version="9.4.2",github="Roxas2712/kanto-ascendant"}},
      SFXMusicReplacementMod={manifest={id="SFXMusicReplacementMod",name="SFX Music Replacement",version="9.0.0",github="AlucardTheFirstHunter/MusicReplacementMod"}},
      dynamic_cries_next={manifest={id="dynamic_cries_next",name="Dynamic Cries Next",version="2.7.0",github="Lockerz102/Stadium-Cries"}},
      future_sprite_mod={manifest={id="future_sprite_mod",name="Future Sprite Provider",version="42.0.0"}},
      unselected_sprite_mod={manifest={id="unselected_sprite_mod",name="Unselected Sprite Provider",version="1.0.0"}},
    },
  },
}
for _,fn in ipairs(ready) do fn({game=game}) end

assert(mod.exports.release=="0.4.20","0.4.20 release exported")
local ascAdapter
for _,a in ipairs(adapters) do if a.id=="kanto_ascendant.family" then ascAdapter=a end end
assert(ascAdapter and ascAdapter.version=="9.4.2","future Ascendant release is accepted by live export contract")
assert(providers["kanto_ascendant.crystal_sprites"],"future Ascendant Crystal provider registered")
assert(providers["sfx_music_replacement.music"] and providers["sfx_music_replacement.sfx"],"future SFX release is detected from options/hooks/audio ownership")
assert(providers["stadium_dynamic_cries"] and providers["stadium_dynamic_cries"].modId=="dynamic_cries_next","future Dynamic Cries id/version is detected from repository + cry ownership")
assert(prefs["audio.cries"]=="stadium_dynamic_cries","legacy Dynamic Cries provider preference migrates to stable family id")
assert(providers["external_sprite.future_sprite_mod"] and providers["external_sprite.unselected_sprite_mod"],"previously unknown pokemon.sprite hook owners are discovered as providers")

assert(compatibility.setPreference("pokemon.sprite_art","kanto_ascendant.crystal_sprites"))
local crystal=mod.exports.resolvePokemonArt(game,"PIKACHU","front",{kind="party"})
assert(crystal and crystal.path=="future_ascendant/pikachu.png","future Ascendant resolver works without a version allowlist")

assert(compatibility.setPreference("pokemon.sprite_art","external_sprite.future_sprite_mod"))
local external=mod.exports.resolvePokemonArt(game,"PIKACHU","front",{kind="party"})
assert(external and external.path=="future/rom/pikachu.png" and external.trueColor==true,"generic selected sprite owner receives immutable ROM terminal")
assert(selectedCalls==1,"selected external hook called exactly once")
assert(unselectedCalls==0,"unselected external sprite hook never receives fallback control")

assert(mod.exports.rules.kantoAscendant.latestAudited=="6.0.11","audited version remains informational metadata")
assert(mod.exports.rules.sfxMusicReplacement.latestAudited=="2.0.0","SFX audited version remains informational metadata")
assert(mod.exports.rules.dynamicCries.latestAudited=="1.4.3","cry audited version remains informational metadata")

love=oldLove
print("Future provider versions and unknown pokemon.sprite owners are contract-driven and terminal")
