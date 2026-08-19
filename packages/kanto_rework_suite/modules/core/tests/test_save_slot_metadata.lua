local root=assert(arg[1],"root path required")
local decoded={
  SLOT_ONE={player={name='RED',map='REDS_HOUSE_2F'},badges={BOULDER=true},pokedex={seen={A=true,B=true},owned={A=true}},money=3000,playTime=61,party={{species='PIKACHU',level=18}}},
  SLOT_TWO={player={name='BLUE',map='PEWTER_GYM'},badges={BOULDER=true,CASCADE=true},pokedex={seen={A=true,B=true,C=true},owned={A=true,B=true}},money=9876,playTime={hours=1,minutes=2,seconds=3},party={{species='EEVEE',level=22},{species='MEW',level=50}}},
  SLOT_THREE={player={name='YELLOW',map='PALLET_TOWN'},badges={},pokedex={seen={},owned={}},money=42,playTime=5,party={}},
}
local files={
  ['saves/red/slot1.lua']='SLOT_ONE',
  ['saves/red/slot2.lua']='SLOT_TWO',
  ['saves/red/slot3.lua']='BROKEN',
  ['saves/red/slot3.lua.tmp']='SLOT_THREE',
}
local fs={
  getInfo=function(path)return files[path] and {type='file'} or nil end,
  read=function(path)return files[path] end,
}
local SaveData={
  persistenceFs=function()return fs end,
  listSlots=function()return{
    {id='slot1',exists=true,label='SAVE SLOT 01'},
    {id='slot2',exists=true,label='SAVE SLOT 02'},
    {id='slot3',exists=true,label='SAVE SLOT 03'},
  }end,
  activeSlot=function()return 'slot1' end,
}
package.preload['src.core.SaveData']=function()return SaveData end
package.preload['src.core.SaveSerializer']=function()return{decode=function(body)return decoded[body],decoded[body] and nil or 'invalid save' end}end
package.preload['src.core.GameVersion']=function()return{get=function()return'red'end}end
package.preload['src.inventory.Badges']=function()return{count=function(_,save)local n=0;for _,v in pairs(save.badges or {})do if v then n=n+1 end end;return n end}end

local runtime={game={data={
  maps={REDS_HOUSE_2F={name="Red's House 2F"},PEWTER_GYM={name='Pewter Gym'},PALLET_TOWN={name='Pallet Town'}},
  pokemon={PIKACHU={name='Pikachu'},EEVEE={name='Eevee'},MEW={name='Mew'}},
}}}
local service=assert(loadfile(root..'/core/save_slots.lua'))()({runtime=runtime})
local slots=service.list({minimum=4})
assert(slots[1].money==3000 and slots[1].badges==1 and slots[1].owned==1 and slots[1].seen==2,"slot 1 metadata comes from slot 1")
assert(slots[2].name=='BLUE' and slots[2].money==9876 and slots[2].badges==2 and slots[2].location=='Pewter Gym',"slot 2 metadata comes from slot 2")
assert(slots[2].timeText=='1:02:03' and #slots[2].party==2 and slots[2].party[2].name=='Mew',"slot 2 time and party are decoded independently")
assert(slots[3].name=='YELLOW' and slots[3].money==42,"slot recovery checks the slot-specific temporary file")
assert(slots[4].virtual==true and slots[4].money==0,"minimum cards append a genuinely empty slot")
local raw=assert(service.read('slot2'));assert(raw.player.name=='BLUE',"direct reads return the requested slot")
assert(service.read('../slot1')==nil,"invalid slot ids are rejected")
print('save-slot metadata is isolated per persisted slot')
