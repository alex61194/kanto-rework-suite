local root=assert(arg[1],"UI root required")
local catalog=assert(loadfile(root.."/runtime/item_descriptions.lua"))()

local expected={
  "MASTER_BALL","ULTRA_BALL","GREAT_BALL","POKE_BALL","TOWN_MAP","BICYCLE","SURFBOARD","SAFARI_BALL","POKEDEX","MOON_STONE",
  "ANTIDOTE","BURN_HEAL","ICE_HEAL","AWAKENING","PARLYZ_HEAL","FULL_RESTORE","MAX_POTION","HYPER_POTION","SUPER_POTION","POTION",
  "BOULDERBADGE","CASCADEBADGE","THUNDERBADGE","RAINBOWBADGE","SOULBADGE","MARSHBADGE","VOLCANOBADGE","EARTHBADGE","ESCAPE_ROPE","REPEL",
  "OLD_AMBER","FIRE_STONE","THUNDER_STONE","WATER_STONE","HP_UP","PROTEIN","IRON","CARBOS","CALCIUM","RARE_CANDY","DOME_FOSSIL","HELIX_FOSSIL","SECRET_KEY","ITEM_2C","BIKE_VOUCHER","X_ACCURACY","LEAF_STONE","CARD_KEY","NUGGET","ITEM_32","POKE_DOLL","FULL_HEAL","REVIVE","MAX_REVIVE","GUARD_SPEC","SUPER_REPEL","MAX_REPEL","DIRE_HIT","COIN","FRESH_WATER","SODA_POP","LEMONADE","S_S_TICKET","GOLD_TEETH","X_ATTACK","X_DEFEND","X_SPEED","X_SPECIAL","COIN_CASE","OAKS_PARCEL","ITEMFINDER","SILPH_SCOPE","POKE_FLUTE","LIFT_KEY","EXP_ALL","OLD_ROD","GOOD_ROD","SUPER_ROD","PP_UP","ETHER","MAX_ETHER","ELIXER","MAX_ELIXER",
  "FLOOR_B2F","FLOOR_B1F","FLOOR_1F","FLOOR_2F","FLOOR_3F","FLOOR_4F","FLOOR_5F","FLOOR_6F","FLOOR_7F","FLOOR_8F","FLOOR_9F","FLOOR_10F","FLOOR_11F","FLOOR_B4F",
}

assert(#expected==97,"Gen I ROM manifest base item count changed")
assert(#catalog.baseItemIds==#expected,"catalog must declare every base item-name ID")
local seen={}
for i,id in ipairs(catalog.baseItemIds) do
  assert(id==expected[i],"catalog order diverged at "..i..": "..tostring(id))
  assert(not seen[id],"duplicate catalog ID: "..id);seen[id]=true
  local value,source=catalog.resolve(nil,id,{})
  assert(type(value)=="string" and #value>=12,id.." has no useful field note")
  assert(source=="krs.gen1_catalog",id.." must resolve through the KRS Gen I fallback")
end

local game={data={text={MOD_NOTE="Mod-authored item copy."}}}
local value,source=catalog.resolve(game,"POTION",{description="MOD_NOTE"},function(g,v)
  return g.data.text[v] or v
end)
assert(value=="Mod-authored item copy." and source=="definition.description",
  "runtime/mod-authored item descriptions must override KRS copy")

local f=assert(io.open(root.."/ui/native_presenter.lua","rb"));local presenter=f:read("*a");f:close()
assert(presenter:find("runtime.ItemDescriptions.resolve",1,true),"Bag presenter uses the shared item field-note resolver")
assert(presenter:find("itemDescription(game,row,def,machine)",1,true),"selected Bag item is routed through the resolver")
local _,descriptionPanels=presenter:gsub("itemDescription%(game,row,def,machine%)","")
assert(descriptionPanels>=3,"Bag, Shop, and Player PC item surfaces must all render field notes")
print("97-item Gen I menu description coverage tests passed")
