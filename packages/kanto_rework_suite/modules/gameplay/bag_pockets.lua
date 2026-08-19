-- Modern Bag pocket, sorting and favorites model for Gen1Recomp 0.1.75.
--
-- The engine keeps one flat acquisition-ordered inventory. This module derives
-- pocket/sort views without rewriting save.inventory or save.bagOrder.
return function(deps)
  local mod=assert(deps.mod,"mod is required")
  local Game=assert(deps.Game,"Game is required")
  local Bag=assert(deps.Bag,"Bag is required")
  local Actions=deps.Actions
  local service={}

  local PREFS_KEY="bag_organization_v1"
  local transientPrefs={version=1,sortMode="type",favorites={},acquired={},nextSequence=0}
  local SORTS={
    {id="type",label="SORT BY TYPE",short="TYPE"},
    {id="name",label="SORT BY NAME",short="NAME"},
    {id="newest",label="NEWEST FIRST",short="NEW"},
    {id="favorites",label="FAVORITES FIRST",short="FAV"},
  }
  local SORT_BY_ID={}
  for _,definition in ipairs(SORTS) do SORT_BY_ID[definition.id]=definition end

  local function preferences()
    local value=mod.save and mod.save.get and mod.save:get(PREFS_KEY,nil) or transientPrefs
    if type(value)~="table" then value={} end
    value.version=1
    value.sortMode=SORT_BY_ID[value.sortMode] and value.sortMode or "type"
    value.favorites=type(value.favorites)=="table" and value.favorites or {}
    value.acquired=type(value.acquired)=="table" and value.acquired or {}
    value.nextSequence=math.max(0,math.floor(tonumber(value.nextSequence) or 0))
    transientPrefs=value
    return value
  end
  local function persist(value)
    transientPrefs=value
    if mod.save and mod.save.set then mod.save:set(PREFS_KEY,value) end
  end

  local POCKETS={
    {id="medicine",label="MEDICINA",title="MEDICINA",label_en="MEDICINE"},
    {id="poke_balls",label="POKé BALLS",title="BALLS",label_en="POKé BALLS"},
    {id="battle_items",label="COMBATE",title="COMBATE",label_en="BATTLE ITEMS"},
    {id="berries",label="BAYAS",title="BAYAS",label_en="BERRIES"},
    {id="other_items",label="OBJETOS",title="OBJETOS",label_en="OTHER ITEMS"},
    {id="machines",label="MTs Y MOs",title="MT/MO",label_en="TMs & HMs"},
    {id="treasures",label="TESOROS",title="TESOROS",label_en="TREASURES"},
    {id="key_items",label="OBJ. CLAVE",title="CLAVE",label_en="KEY ITEMS"},
  }
  local BY_ID={}
  for index,pocket in ipairs(POCKETS) do pocket.index=index;BY_ID[pocket.id]=pocket end

  local STOCK={}
  local function assign(pocket,ids) for id in ids:gmatch("%S+") do STOCK[id]=pocket end end
  assign("poke_balls",[[MASTER_BALL ULTRA_BALL GREAT_BALL POKE_BALL SAFARI_BALL]])
  assign("medicine",[[
    POTION SUPER_POTION HYPER_POTION MAX_POTION FULL_RESTORE
    ANTIDOTE BURN_HEAL ICE_HEAL AWAKENING PARLYZ_HEAL FULL_HEAL
    REVIVE MAX_REVIVE FRESH_WATER SODA_POP LEMONADE
    HP_UP PROTEIN IRON CARBOS CALCIUM RARE_CANDY
    PP_UP ETHER MAX_ETHER ELIXER MAX_ELIXER
  ]])
  assign("battle_items",[[
    X_ACCURACY GUARD_SPEC DIRE_HIT X_ATTACK X_DEFEND X_SPEED X_SPECIAL POKE_DOLL
  ]])
  assign("other_items",[[
    MOON_STONE FIRE_STONE THUNDER_STONE WATER_STONE LEAF_STONE
    ESCAPE_ROPE REPEL SUPER_REPEL MAX_REPEL ITEM_2C ITEM_32
  ]])
  assign("treasures","NUGGET")
  assign("key_items",[[
    TOWN_MAP BICYCLE SURFBOARD POKEDEX
    OLD_AMBER DOME_FOSSIL HELIX_FOSSIL SECRET_KEY BIKE_VOUCHER CARD_KEY
    COIN S_S_TICKET GOLD_TEETH COIN_CASE OAKS_PARCEL ITEMFINDER
    SILPH_SCOPE POKE_FLUTE LIFT_KEY EXP_ALL OLD_ROD GOOD_ROD SUPER_ROD
    FLOOR_B2F FLOOR_B1F FLOOR_1F FLOOR_2F FLOOR_3F FLOOR_4F FLOOR_5F
    FLOOR_6F FLOOR_7F FLOOR_8F FLOOR_9F FLOOR_10F FLOOR_11F FLOOR_B4F
  ]])

  local ALIASES={
    medicine="medicine",medicines="medicine",recovery="medicine",
    poke_balls="poke_balls",pokeballs="poke_balls",balls="poke_balls",
    battle_items="battle_items",battle="battle_items",
    berries="berries",berry="berries",
    other_items="other_items",items="other_items",other="other_items",
    machines="machines",tms="machines",tm_hm="machines",tmhm="machines",
    treasures="treasures",treasure="treasures",key_items="key_items",key="key_items",
  }
  local function normalizedPocket(value)
    if type(value)~="string" then return nil end
    local key=value:lower():gsub("[^%w]+","_"):gsub("^_+",""):gsub("_+$","")
    return ALIASES[key]
  end
  local function classify(id,def)
    if type(id)~="string" then return "other_items" end
    local authored=normalizedPocket(def and (def.pocket or def.category))
    if authored then return authored end
    if id:find("^TM_") or id:find("^HM_") then return "machines" end
    if STOCK[id] then return STOCK[id] end
    if id:find("BERRY",1,true) then return "berries" end
    if def and def.keyItem then return "key_items" end
    return "other_items"
  end

  local function syncAcquisition(game,prefs)
    if not (game and game.save and type(game.save.inventory)=="table") then return prefs end
    local dirty=false
    for _,id in ipairs(Bag.order(game.save)) do
      if prefs.acquired[id]==nil then
        prefs.nextSequence=prefs.nextSequence+1;prefs.acquired[id]=prefs.nextSequence;dirty=true
      end
    end
    if dirty then persist(prefs) end
    return prefs
  end
  local function rowFor(game,id,pocketId,prefs)
    local def=game.data and game.data.items and game.data.items[id]
    local qty=game.save and game.save.inventory and game.save.inventory[id]
    if not qty then return nil end
    local favorite=prefs.favorites[id]==true
    return {
      value=id,label=(favorite and "* " or "")..tostring(def and def.name or id),
      right=pocketId~="key_items" and "x"..tostring(qty) or nil,pocket=pocketId,
      favorite=favorite,acquired=tonumber(prefs.acquired[id]) or 0,
    }
  end
  local function typeKey(game,row,pocketId)
    local def=game.data and game.data.items and game.data.items[row.value]
    if pocketId=="machines" and def and def.machine then
      return (def.machine.kind=="HM" and 1000 or 0)+(tonumber(def.machine.number) or 999)
    end
    return tonumber(def and def.index) or 100000
  end
  local function sortRows(game,rows,pocketId,mode,sourceOrder)
    table.sort(rows,function(a,b)
      if mode=="favorites" and a.favorite~=b.favorite then return a.favorite end
      if mode=="newest" and a.acquired~=b.acquired then return a.acquired>b.acquired end
      if mode=="name" then
        local an=tostring(a.label):gsub("^%* ",""):lower()
        local bn=tostring(b.label):gsub("^%* ",""):lower()
        if an~=bn then return an<bn end
      end
      local at,bt=typeKey(game,a,pocketId),typeKey(game,b,pocketId)
      if at~=bt then return at<bt end
      local ai,bi=sourceOrder[a.value] or math.huge,sourceOrder[b.value] or math.huge
      if ai~=bi then return ai<bi end
      return tostring(a.value)<tostring(b.value)
    end)
    return rows
  end
  local function rowsFor(game,pocketId,prefs)
    local rows={};if not(game and game.save and type(game.save.inventory)=="table") then return rows end
    local sourceOrder={}
    for index,id in ipairs(Bag.order(game.save)) do
      sourceOrder[id]=index;local def=game.data and game.data.items and game.data.items[id]
      if classify(id,def)==pocketId then
        local row=rowFor(game,id,pocketId,prefs);if row then rows[#rows+1]=row end
      end
    end
    return sortRows(game,rows,pocketId,prefs.sortMode,sourceOrder)
  end
  local function catalog(game,includeEmpty)
    game=game or Game;local prefs=syncAcquisition(game,preferences());local result={}
    for _,pocket in ipairs(POCKETS) do
      local items=rowsFor(game,pocket.id,prefs)
      if includeEmpty or #items>0 then result[#result+1]={id=pocket.id,label=pocket.label,items=items} end
    end
    return result
  end
  local function findIndex(items,id)
    if id then for index,item in ipairs(items) do if item.value==id then return index end end end
  end
  local function sound(game,cue)
    if not(game and game.data) then return end
    local ok,Sound=pcall(require,"src.core.Sound")
    if ok and Sound and type(Sound.play)=="function" then Sound.play(game.data,cue) end
  end

  function service.decorate(game,list,enabled)
    if not enabled or type(list)~="table" then return list end
    local baseUpdate,baseChoose=list.update,list.onChoose
    local state={pockets={},pocketIndex=1,sortMode=preferences().sortMode,battle=list.__kantoItemUseBattle==true}
    list.__kantoPocketState=state

    local function sync(preferredId)
      local current=state.pockets[state.pocketIndex];local currentId=current and current.id
      local all=catalog(game,false)
      if #all==0 then all={{id="other_items",label=BY_ID.other_items.label,items={}}} end
      state.pockets=all;local nextIndex
      if currentId then for index,pocket in ipairs(all) do if pocket.id==currentId then nextIndex=index break end end end
      state.pocketIndex=nextIndex or math.min(state.pocketIndex,#all)
      local pocket=all[state.pocketIndex];local old=list.items and list.items[list.index]
      local keep=preferredId or (old and old.value);list.items=pocket.items
      list.index=findIndex(list.items,keep) or math.max(1,math.min(list.index or 1,#list.items))
      list.scroll=math.max(0,math.min(list.scroll or 0,math.max(0,#list.items-(list.rows or 7))))
      if list.index-(list.scroll or 0)>(list.rows or 7) then list.scroll=list.index-(list.rows or 7)
      elseif list.index-(list.scroll or 0)<1 then list.scroll=list.index-1 end
      local prefs=preferences();state.sortMode=prefs.sortMode
      list.title=("%s %d/%d %s"):format((BY_ID[pocket.id] and BY_ID[pocket.id].title) or pocket.label,state.pocketIndex,#all,
        (SORT_BY_ID[state.sortMode] or SORT_BY_ID.type).short)
      return pocket
    end

    -- Every new Bag instance starts on the first non-empty canonical pocket.
    state.pocketIndex=1;sync()

    local function setSortMode(mode,preferredId)
      if not SORT_BY_ID[mode] then return false end
      local prefs=preferences();prefs.sortMode=mode;persist(prefs);state.sortMode=mode
      sync(preferredId);sound(game,"Swap");return true
    end
    local function openSortMenu()
      if state.battle then return false end
      local Menu=require("src.ui.Menu");local items={};local current=preferences().sortMode
      for _,definition in ipairs(SORTS) do
        local mode=definition.id;local selected=mode==current and "* " or ""
        items[#items+1]={label=selected..definition.label,onSelect=function()
          local item=list.items and list.items[list.index]
          setSortMode(mode,item and item.value)
        end}
      end
      local menu=Menu.new(game,items,{tx=7,ty=2,tw=13,th=10})
      menu.__kantoBagSortMenu=true
      menu.__kantoBagOwner=list
      for index,definition in ipairs(SORTS) do if definition.id==current then menu.index=index break end end
      game.stack:push(menu);return true
    end
    local function toggleCurrentFavorite()
      if state.battle then return false end
      local item=list.items and list.items[list.index];if not item then return false end
      local prefs=preferences();prefs.favorites[item.value]=not(prefs.favorites[item.value]==true)
      persist(prefs);sync(item.value);sound(game,"Swap");return true
    end

    -- Public controller surface for the Wide KRS UI.  It deliberately owns
    -- only navigation/presentation semantics; item callbacks and inventory
    -- mutation remain in the engine/BagMenu closures above.
    state.sync=sync
    state.openSortMenu=openSortMenu
    state.toggleFavorite=toggleCurrentFavorite
    state.switchPocket=function(delta)
      local n=#state.pockets
      if n<=1 then return false end
      state.pocketIndex=((state.pocketIndex-1+(tonumber(delta) or 0))%n)+1
      state.focusPocketIndex=state.pocketIndex
      list.index,list.scroll=1,0
      sync();sound(game,"Swap");return true
    end
    state.selectPocket=function(index)
      index=math.max(1,math.min(#state.pockets,tonumber(index) or state.pocketIndex))
      if index==state.pocketIndex then return true end
      state.pocketIndex=index;state.focusPocketIndex=index;list.index,list.scroll=1,0
      sync();sound(game,"Swap");return true
    end
    -- Validated Bag UI keeps pocket navigation in the fullscreen header.
    -- The item ledger therefore owns vertical focus from the moment Bag opens.
    state.uiRegion="items"
    state.focusPocketIndex=state.pocketIndex

    -- Modern sorting replaces manual SELECT reordering while pockets are on.
    -- Disabling BAG POCKETS leaves the native flat-list swap untouched.
    if state.battle then list.onSelectKey=nil
    else list.onSelectKey=function() return openSortMenu() end end
    list.onChoose=function(item,l,...) if baseChoose then return baseChoose(item,l,...) end end
    if type(baseUpdate)=="function" then
      list.update=function(self,dt)
        if not state.battle and Actions and Actions.wasPressed and Actions.wasPressed("BAG_SORT") then openSortMenu();return end
        if not state.battle and Actions and Actions.wasPressed and Actions.wasPressed("BAG_FAVORITE") then toggleCurrentFavorite();return end
        local input=game.input

        -- Validated fullscreen Bag contract:
        --   LEFT / RIGHT = previous / next visible pocket in canonical order
        --   UP / DOWN     = native item-list navigation
        -- The pocket selector is presentation in the header, never a second
        -- vertical focus region. This keeps battle and overworld Bag identical.
        if input and type(input.wasPressed)=="function" then
          state.uiRegion="items"
          state.focusPocketIndex=state.pocketIndex
          if input:wasPressed("left") then
            state.switchPocket(-1);return
          elseif input:wasPressed("right") then
            state.switchPocket(1);return
          end
        end
        baseUpdate(self,dt);sync();state.uiRegion="items";state.focusPocketIndex=state.pocketIndex
      end
    end
    return list
  end

  function service.noteAcquired(id)
    if type(id)~="string" then return false end
    local prefs=preferences();prefs.nextSequence=prefs.nextSequence+1
    prefs.acquired[id]=prefs.nextSequence;persist(prefs);return true
  end
  function service.setSortMode(mode)
    if not SORT_BY_ID[mode] then return false end
    local prefs=preferences();prefs.sortMode=mode;persist(prefs);return true
  end
  function service.sortMode() return preferences().sortMode end
  function service.toggleFavorite(id)
    if type(id)~="string" then return false end
    local prefs=preferences();prefs.favorites[id]=not(prefs.favorites[id]==true);persist(prefs)
    return prefs.favorites[id]
  end
  function service.isFavorite(id) return preferences().favorites[id]==true end
  function service.classify(id,def) return classify(id,def) end
  function service.catalog(game,includeEmpty) return catalog(game or Game,includeEmpty==true) end
  function service.status(game,enabled)
    local pockets=catalog(game or Game,true);local counts={}
    for _,pocket in ipairs(pockets) do counts[pocket.id]=#pocket.items end
    return {
      installed=true,enabled=enabled==true,vanillaFallback=enabled~=true,
      navigation="header_pockets_horizontal_items_vertical",pockets=POCKETS,counts=counts,
      emptyPocketsHidden=true,saveFormatChanged=false,fallbackPocket="other_items",
      initialPocket="first_non_empty",sortMode=preferences().sortMode,sortModes=SORTS,
      sortAction="BAG_SORT",favoriteAction="BAG_FAVORITE",
      favoritesPersistent=true,sortingMutatesInventory=false,
    }
  end
  return service
end
