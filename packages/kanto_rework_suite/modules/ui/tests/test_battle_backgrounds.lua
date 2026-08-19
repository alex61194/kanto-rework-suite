local root=assert(arg[1],"UI root required")
local Backgrounds=assert(loadfile(root.."/runtime/battle_backgrounds.lua"))()
local function map(id,tileset,water,grass)
  return {id=id,def={tileset=tileset},isWaterCell=function() return water==true end,isGrassCell=function() return grass==true end}
end
local function game(id,tileset,tod,water,grass)
  local ow={map=map(id,tileset,water,grass),player={cellX=1,cellY=1}}
  function ow:timeOfDay() return tod end
  return {overworld=ow}
end
local b={}
assert(Backgrounds.resolve(game("OAKS_LAB","LAB","MORNING"),b).file=="oak_lab_sunrise","Oak Lab sunrise")
assert(Backgrounds.resolve(game("OAKS_LAB","LAB","NIGHT"),b).file=="oak_lab_sunrise","selection stays stable during one battle")
b={};assert(Backgrounds.resolve(game("ROUTE_3","OVERWORLD","SUNSET",false,true),b).file=="grass_sunset","grass follows world sunset")
b={};assert(Backgrounds.resolve(game("ROUTE_19","OVERWORLD","NITE",true,false),b).file=="sea_night","surf follows world night")
b={};assert(Backgrounds.resolve(game("POWER_PLANT","FACILITY","DAY"),b).file:match("^power_plant_[1-4]$"),"interior variant")
local first=Backgrounds.resolve(game("POWER_PLANT","FACILITY","DAY"),b).file
assert(Backgrounds.resolve(game("POWER_PLANT","FACILITY","NIGHT"),b).file==first,"random interior is stable")
b={};assert(Backgrounds.resolve(game("FIGHTING_DOJO","GYM","DAY"),b).file=="gym_saffron_fighting","dojo-specific background")
b={};assert(Backgrounds.resolve(game("LORELEIS_ROOM","GYM","DAY"),b).file=="league_lorelei","Elite Four room")
b={};assert(Backgrounds.resolve(game("SILPH_CO_11F","INTERIOR","NIGHT"),b).file=="silph_co","Silph Co uses its fixed authored interior")
b={};assert(Backgrounds.resolve(game("ROCKET_HIDEOUT_B4F","FACILITY","DAY"),b).file=="rocket_hideout","Rocket Hideout uses its fixed authored interior")
b={};assert(Backgrounds.resolve(game("GAME_CORNER","CLUB","DAY"),b).file=="rocket_hideout","Game Corner Rocket encounter uses the nearest Team Rocket scene")

local fallbacks={
  {"CUSTOM_FOREST","FOREST","viridian_forest_day"},
  {"CUSTOM_SHIP","SHIP","ss_anne_day"},
  {"CUSTOM_TOWER","CEMETERY","pokemon_tower_day"},
  {"CUSTOM_CAVE","CAVERN","cave_dark"},
  {"CUSTOM_LAB","LAB","oak_lab_day"},
  {"CUSTOM_INTERIOR","INTERIOR","silph_co"},
}
for _,row in ipairs(fallbacks) do
  b={};assert(Backgrounds.resolve(game(row[1],row[2],"DAY"),b).file==row[3],row[2].." semantic fallback")
end
b={};assert(Backgrounds.resolve(game("CUSTOM_FACILITY","FACILITY","DAY"),b).file:match("^power_plant_[1-4]$"),"facility semantic fallback")
b={};local unknown=Backgrounds.resolve(game("CUSTOM_UNKNOWN","","SUNSET"),b);assert(unknown.file=="road_sunset" and unknown.fallback=="unknown_map","unknown map receives an explicit canonical fallback")

-- Every tileset exported by Gen1Recomp 0.1.80 must have a canonical result,
-- even when a future map is not yet present in the explicit location table.
local gen1Tilesets=[[
OVERWORLD REDS_HOUSE_1 MART FOREST REDS_HOUSE_2 DOJO POKECENTER GYM HOUSE FOREST_GATE MUSEUM UNDERGROUND
GATE SHIP SHIP_PORT CEMETERY INTERIOR CAVERN LOBBY MANSION LAB CLUB FACILITY PLATEAU
]]
local tilesetsCovered=0
for tileset in gen1Tilesets:gmatch("%S+") do
  b={};local result=Backgrounds.resolve(game("CUSTOM_"..tileset,tileset,"DAY"),b)
  assert(type(result.file)=="string" and result.file~="",tileset.." has no canonical fallback")
  tilesetsCovered=tilesetsCovered+1
end
assert(tilesetsCovered==24,"Gen1Recomp tileset inventory changed")

-- Gen1Recomp 0.1.80 ROM manifest: every map containing a trainer or static
-- battle object must resolve to a packaged canonical file.
local trainerMaps=[[
AGATHAS_ROOM BRUNOS_ROOM CELADON_GYM CERULEAN_CAVE_B1F CERULEAN_CITY CERULEAN_GYM CINNABAR_GYM FIGHTING_DOJO FUCHSIA_GYM GAME_CORNER
LANCES_ROOM LORELEIS_ROOM MT_MOON_1F MT_MOON_B2F OAKS_LAB PEWTER_GYM POKEMON_MANSION_1F POKEMON_MANSION_2F POKEMON_MANSION_3F POKEMON_MANSION_B1F
POKEMON_TOWER_3F POKEMON_TOWER_4F POKEMON_TOWER_5F POKEMON_TOWER_6F POKEMON_TOWER_7F POWER_PLANT ROCKET_HIDEOUT_B1F ROCKET_HIDEOUT_B2F ROCKET_HIDEOUT_B3F ROCKET_HIDEOUT_B4F
ROCK_TUNNEL_1F ROCK_TUNNEL_B1F ROUTE_10 ROUTE_11 ROUTE_12 ROUTE_13 ROUTE_14 ROUTE_15 ROUTE_16 ROUTE_17 ROUTE_18 ROUTE_19 ROUTE_20 ROUTE_21 ROUTE_24 ROUTE_25 ROUTE_3 ROUTE_4 ROUTE_6 ROUTE_8 ROUTE_9
SAFFRON_GYM SEAFOAM_ISLANDS_B4F SILPH_CO_10F SILPH_CO_11F SILPH_CO_2F SILPH_CO_3F SILPH_CO_4F SILPH_CO_5F SILPH_CO_6F SILPH_CO_7F SILPH_CO_8F SILPH_CO_9F
SS_ANNE_1F_ROOMS SS_ANNE_2F SS_ANNE_2F_ROOMS SS_ANNE_B1F_ROOMS SS_ANNE_BOW VERMILION_GYM VICTORY_ROAD_1F VICTORY_ROAD_2F VICTORY_ROAD_3F VIRIDIAN_FOREST VIRIDIAN_GYM
]]
local covered=0
for id in trainerMaps:gmatch("%S+") do
  b={};local result=Backgrounds.resolve(game(id,"OVERWORLD","DAY"),b)
  assert(type(result.file)=="string" and result.file~="",id.." has no canonical battle background")
  covered=covered+1
end
assert(covered==74,"Gen1Recomp trainer/static-battle map inventory changed")

-- Every canonical time-of-day asset resolves through a calibrated geometry
-- profile rather than the legacy global fallback. There are 36 distinct scene
-- geometries for the 72 files (four time variants share one profile).
assert(Backgrounds.anchorProfileCount()==36,"battle-circle anchor profile inventory changed")
local anchorCases={
  {file="pokemon_tower_day",profile="pokemon_tower",px=592,py=640,ex=1292,ey=460},
  {file="rocket_hideout",profile="rocket_hideout",px=520,py=720,ex=1470,ey=495},
  {file="grass_night",profile="grass",px=604,py=672,ex=1460,ey=520},
  {file="power_plant_3",profile="power_plant_3",px=636,py=736,ex=1452,ey=512},
}
for _,row in ipairs(anchorCases) do
  local a=Backgrounds.groundAnchors({file=row.file,kind=row.profile})
  assert(a.profile==row.profile,row.file.." anchor profile")
  assert(a.player.x==row.px and a.player.y==row.py,row.file.." player anchor")
  assert(a.enemy.x==row.ex and a.enemy.y==row.ey,row.file.." enemy anchor")
end
local fallback=Backgrounds.groundAnchors({file="future_mod_background"})
assert(fallback.profile=="fallback" and fallback.player.x==630 and fallback.player.y==704,"unknown backgrounds preserve the legacy fallback anchor")

print("72-asset canonical routing, 36 circle-anchor profiles, 24-tileset fallback and 74 battle-map coverage tests passed")
