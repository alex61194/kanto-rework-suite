local root=assert(arg[1],"root path required")
local Names=assert(loadfile(root.."/runtime/character_names.lua"))()()
local game={save={player={name='RED',rival='BLUE'}},overworld={map={id='ROUTE_3'}}}
local ctx={mapId='ROUTE_3',npcId='ROUTE_3_obj_7',partyIndex=2}
local a=Names.trainer(game,'ROCKET',ctx)
local b=Names.trainer(game,'ROCKET',ctx)
assert(a==b and a:find('ROCKET GRUNT',1,true)==1,'trainer identity must be stable and class-aware')
local other=Names.trainer(game,'ROCKET',{mapId='SILPH_CO_6F',npcId='SILPH_CO_6F_obj_8',partyIndex=3})
assert(type(other)=='string' and other~='','other trainer identity exists')
assert(Names.trainer(game,'RIVAL',ctx)=='BLUE','named rival preserves save identity')
assert(Names.fromTextKey(game,'_BrockPreBattleText')=='BROCK','canonical named trainer remains canonical')
assert(Names.fromTextKey(game,'_OaksLabRivalIPickedTheWrongPokemonText')=='BLUE',
  "Oak's Lab location prefix must never replace Blue on a rival event")
assert(Names.fromTextKey(game,'_OaksLabRivalSmellYouLaterText')=='BLUE',
  'consecutive post-battle rival lines remain attributed to Blue')
assert(Names.fromTextKey(game,'_OaksLabYouWantCharmanderText')=='PROFESSOR OAK'
  and Names.fromTextKey(game,'_OaksLabYouWantSquirtleText')=='PROFESSOR OAK'
  and Names.fromTextKey(game,'_OaksLabYouWantBulbasaurText')=='PROFESSOR OAK',
  'all three starter confirmation prompts are explicitly owned by Professor Oak')
local narration,handled=Names.eventSpeaker(game,'_OaksLabRivalReceivedMonText')
assert(handled==true and narration==nil,'received-Pokémon narration must not inherit Blue or Oak')
local resident=Names.dialogue(game,'Hello there!',{})
assert(type(resident)=='string' and resident~='' and not resident:find('TRAINER ',1,true),'unnamed resident dialogue gets a natural stable Kanto identity')
local lab=Names.dialogue({overworld={map={id='OAKS_LAB'}}},'Research notes.',{})
assert(lab:find('LAB AIDE ',1,true)==1,'unnamed lab dialogue uses a contextual lab identity')
print('Character naming tests passed')
Names.resetAssignments()
local oakGame={save={player={name='RED',rival='BLUE'}},overworld={map={id='OAKS_LAB'}}}
local sci1=Names.npc(oakGame,{id='oak_scientist_1',def={name='OAKSLAB_SCIENTIST1',sprite='SCIENTIST'}},{mapId='OAKS_LAB'})
local sci2=Names.npc(oakGame,{id='oak_scientist_2',def={name='OAKSLAB_SCIENTIST2',sprite='SCIENTIST'}},{mapId='OAKS_LAB'})
assert(sci1:find('SCIENTIST ',1,true)==1 and sci2:find('SCIENTIST ',1,true)==1,'Oak Lab scientists keep their trainer/NPC class')
assert(sci1~=sci2,'two unnamed scientists must never receive the same personal name')
local daisy=Names.npc(oakGame,{id='daisy',def={name='BLUESHOUSE_DAISY1'}},{mapId='BLUES_HOUSE'})
assert(daisy=='DAISY',"Blue/Gary's sister must use her canonical female identity")
local girl=Names.npc(oakGame,{id='girl_1',def={name='CELADON_GIRL',sprite='GIRL'}},{mapId='CELADON_CITY'})
assert(girl and girl~='' and girl~='LEO','female NPC must not receive the observed male fallback identity')
local generated={}
for i=1,12 do
  local n=Names.npc(oakGame,{id='resident_'..i,def={name='GENERIC_MAN_'..i,sprite='MAN'}},{mapId='SAFFRON_CITY'})
  assert(not generated[n],'generated NPC identities must not repeat: '..tostring(n))
  generated[n]=true
end

local persistentStore={}
local fakeMod={save={get=function(_,key,default) return persistentStore[key] or default end,set=function(_,key,value) persistentStore[key]=value end}}
local NamesA=assert(loadfile(root..'/runtime/character_names.lua'))()({mod=fakeMod})
local persistTarget={id='persist_scientist',def={name='OAKSLAB_SCIENTIST3',sprite='SCIENTIST'}}
local persistA=NamesA.npc(oakGame,persistTarget,{mapId='OAKS_LAB'})
local NamesB=assert(loadfile(root..'/runtime/character_names.lua'))()({mod=fakeMod})
local persistB=NamesB.npc(oakGame,persistTarget,{mapId='OAKS_LAB'})
assert(persistA==persistB,'generated presentation identity must remain stable after runtime reload')
print('Character naming uniqueness/gender tests passed')

Names.resetAssignments()
local silphGame={save={player={name='RED',rival='BLUE'}},overworld={map={id='SILPH_CO_6F'}}}
local silphWoman=Names.npc(silphGame,{id='silph_worker_f1',def={name='SILPHCO6F_SILPH_WORKER_F1',sprite='SPRITE_SILPH_WORKER_F'}},{mapId='SILPH_CO_6F'})
local silphWoman2=Names.npc(silphGame,{id='silph_worker_f2',def={name='SILPHCO6F_SILPH_WORKER_F2',sprite='CUSTOM_SILPH_WORKER_F'}},{mapId='SILPH_CO_6F'})
local observedMale={QUENTIN=true,ELIAS=true,IVAN=true,LEO=true,MASON=true,PAUL=true,JACK=true,ADAM=true}
local first1=silphWoman:match('([A-Z]+)$')
local first2=silphWoman2:match('([A-Z]+)$')
assert(first1 and not observedMale[first1],'SPRITE_SILPH_WORKER_F must use the female identity pool, got '..tostring(silphWoman))
assert(first2 and not observedMale[first2],'modded *_F sprite suffix must use the female identity pool, got '..tostring(silphWoman2))
assert(silphWoman~=silphWoman2,'two female Silph workers must still have unique identities')
print('Gen 1 sprite-gender identity tests passed')

Names.resetAssignments()
local keyF1=Names.fromTextKey(silphGame,'TEXT_SILPHCO6F_SILPH_WORKER_F1')
local keyF2=Names.fromTextKey(silphGame,'TEXT_SILPHCO6F_SILPH_WORKER_F2')
assert(keyF1 and keyF2 and keyF1~=keyF2,'female Silph text-key fallback must produce unique identities')
local k1=keyF1:match('([A-Z]+)$');local k2=keyF2:match('([A-Z]+)$')
assert(k1 and not observedMale[k1] and k2 and not observedMale[k2],'female text-key fallback must use female name pools')
print('Text-key gender fallback tests passed')

Names.resetAssignments()
local sameViaText=Names.fromTextKey(silphGame,'TEXT_SILPHCO6F_SILPH_WORKER_F1')
local sameViaNpc=Names.npc(silphGame,{id='SILPH_CO_6F_obj_3',def={name='SILPHCO6F_SILPH_WORKER_F1',sprite='SPRITE_SILPH_WORKER_F'}},{mapId='SILPH_CO_6F'})
assert(sameViaText==sameViaNpc,'text-key fallback and authoritative NPC target must converge on the same semantic identity')
print('Semantic NPC identity convergence tests passed')
