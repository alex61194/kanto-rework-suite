local root=assert(arg[1],'root path required')
local factory=assert(loadfile(root..'/adapters/battle_art_voxel_family.lua'))()

local oldLove=love
local decoded=0
local function imageData(w,h)
  return {
    getDimensions=function() return w,h end,
    paste=function() end,
  }
end
love={
  filesystem={getInfo=function(path) return tostring(path):find('/shiny/',1,true) and {type='file'} or nil end},
  image={newImageData=function(a,b)
    if type(a)=='string' then return imageData(2,1) end
    return imageData(a,b)
  end},
}
local BattleArt={
  setting={get=function() return 'animated' end},
  frontAnimationSetting={get=function() return 'gen5' end},
  backAnimationSetting={get=function() return 'gen5' end},
  playerSide=function() return 'back' end,
  displayMode=function() return 'gbc' end,
  apply=function() end,applyTrainers=function() end,releaseSpeciesOverrides=function() end,
  prepareData=function()
    decoded=decoded+1
    return {id='shiny-frame-'..decoded,getDimensions=function() return 1,1 end}
  end,
  metrics=function() return {w=1,h=1,x0=0,x1=0,y0=0,y1=0,center=.5} end,
  shareFrameAnchor=function() end,
}
local dataCalls={}
local datasets={
  animated_battle_sprites_gen5={PIKACHU={front={image='assets/battle/front-animated/gen5/pikachu.png',width=1,height=1,columns=2,frames=2,durations={50,50}}}},
  animated_battle_sprites_gen5_shiny={PIKACHU={front={image='assets/battle/front-animated/gen5/shiny/pikachu.png',width=1,height=1,columns=2,frames=2,durations={80,120}}}},
}
local lib={
  mod={assets={path=function(_,rel) return rel end}},
  require=function(name)
    return ({BattleArt=BattleArt,AnimatedBattleArt={update=function() end},OverworldBattle={battle=function() return nil end},FirstPerson={driving=function() return false end,moveVector=function() return 0,0 end,moveWorld=function(x,z) return x,z end},FreeMove={_blockedCell=function() end}})[name]
  end,
  data=function(name) dataCalls[#dataCalls+1]=name;return datasets[name] end,
}
local voxel={id='BATTLE_ART_VOXEL_FORK',version='1.8.7',exports={lib=lib}}
local Core={dispatchPointerEvent=function() end,inputMode=function() return {} end,fieldActions={execute=function() return false end}}
local adapter=factory({voxel=voxel,findMod=function(id) if id==voxel.id then return voxel end end,Core=Core,hooks={wrap=function() return function() end end}})
local mon={species='PIKACHU',shiny=true}
local art=adapter.resolvePokemonArtImage({save={options={}}},'PIKACHU','front',{kind='battle',mon=mon,battler={mon=mon,sprite={id='normal-live'}}})
assert(art and art.forcedShiny==true,'explicit shiny must bypass the normal live battler frame')
assert(art.frames and #art.frames==2 and art.image==art.frames[1],'shiny dataset atlas is decoded into animated frames')
assert(art.durations[1]==80 and art.durations[2]==120 and art.shinyDataset=='animated_battle_sprites_gen5_shiny','shiny dataset timings and source are authoritative')
local saw=false;for _,name in ipairs(dataCalls) do if name=='animated_battle_sprites_gen5_shiny' then saw=true end end
assert(saw,'Compatibility must request Voxel\'s generated Gen5 shiny dataset directly')
love=oldLove
print('Voxel Gen5 explicit shiny routing uses the fork shiny dataset directly')
