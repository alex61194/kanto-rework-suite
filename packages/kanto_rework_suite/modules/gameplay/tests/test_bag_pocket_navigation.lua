local root=assert(arg[1],"root path required")
local factory=assert(loadfile(root.."/bag_pockets.lua"))()

local persisted={}
local mod={
  save={
    get=function(_,key,default) return persisted[key] or default end,
    set=function(_,key,value) persisted[key]=value end,
  },
}
local pressed=nil
local game={
  input={wasPressed=function(_,name) return pressed==name end},
  data={items={
    POTION={name="Potion",index=1},
    POKE_BALL={name="Poké Ball",index=2},
    X_ATTACK={name="X Attack",index=3},
  }},
  save={inventory={POTION=2,POKE_BALL=5,X_ATTACK=1}},
  stack={push=function() end},
}
local Bag={order=function() return {"POTION","POKE_BALL","X_ATTACK"} end}
local service=factory({mod=mod,Game=game,Bag=Bag})
local baseCalls=0
local list={items={},index=1,scroll=0,rows=7,
  update=function() baseCalls=baseCalls+1 end,
  onChoose=function() return true end,
}
service.decorate(game,list,true)
local state=assert(list.__kantoPocketState)
assert(state.uiRegion=="items" and state.pocketIndex==1,
  "Bag opens directly in the item ledger; pockets live in the header")

local function tap(name)
  pressed=name;list:update(1/60);pressed=nil
end

tap("right")
assert(state.pocketIndex==2 and state.focusPocketIndex==2 and baseCalls==0,
  "RIGHT selects the next visible header pocket without reaching native item input")
tap("left")
assert(state.pocketIndex==1 and state.focusPocketIndex==1 and baseCalls==0,
  "LEFT selects the previous visible header pocket")
tap("left")
assert(state.pocketIndex==3 and state.focusPocketIndex==3,
  "header pocket navigation wraps in canonical visible-pocket order")
local selectedPocket=state.pocketIndex
local beforeBase=baseCalls
tap("down")
assert(state.pocketIndex==selectedPocket and baseCalls==beforeBase+1,
  "DOWN remains native vertical item navigation")
tap("up")
assert(state.pocketIndex==selectedPocket and baseCalls==beforeBase+2,
  "UP remains native vertical item navigation")
assert(state.uiRegion=="items","Bag never creates a second vertical pocket focus region")

local status=service.status(game,true)
assert(status.navigation=="header_pockets_horizontal_items_vertical",
  "status exposes the validated header-pocket navigation contract")

-- Battle Bag deliberately exposes only use, pocket navigation and back.
local battleList={items={},index=1,scroll=0,rows=7,__kantoItemUseBattle=true,
  update=function() end,onChoose=function() return true end}
service.decorate(game,battleList,true)
local battle=assert(battleList.__kantoPocketState)
assert(battle.battle==true,"battle Bag context is detected")
assert(battleList.onSelectKey==nil,"battle Bag removes the sort shortcut")
assert(battle.openSortMenu()==false and battle.toggleFavorite()==false,
  "battle Bag disables sort and favorite actions")
assert(battle.switchPocket(1)==true,"battle Bag keeps pocket navigation")
print("Bag pocket navigation matches validated header-horizontal/item-vertical Figma contract")
