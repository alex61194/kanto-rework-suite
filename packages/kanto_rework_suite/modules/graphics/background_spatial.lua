-- Explicit spatial metadata for KRS-authored Battle Background families.
-- This is not image analysis. Values are authored scene heuristics used by the
-- Live Mockup placement assistant; time-of-day variants share family geometry.
local M={}
local PROFILES={
  outdoor_open={horizonY=330,perspectiveStrength=.62,scaleReference=1.00,
    player={depth=.20,circleWidth=350},enemy={depth=.64,circleWidth=270}},
  outdoor_enclosed={horizonY=305,perspectiveStrength=.56,scaleReference=.96,
    player={depth=.22,circleWidth=330},enemy={depth=.61,circleWidth=260}},
  cave={horizonY=300,perspectiveStrength=.50,scaleReference=.94,
    player={depth=.24,circleWidth=320},enemy={depth=.59,circleWidth=250}},
  interior={horizonY=350,perspectiveStrength=.44,scaleReference=.98,
    player={depth=.23,circleWidth=330},enemy={depth=.57,circleWidth=260}},
  gym={horizonY=365,perspectiveStrength=.48,scaleReference=1.00,
    player={depth=.22,circleWidth=340},enemy={depth=.59,circleWidth=265}},
  league={horizonY=350,perspectiveStrength=.52,scaleReference=1.02,
    player={depth=.21,circleWidth=345},enemy={depth=.61,circleWidth=265}},
  neutral={horizonY=340,perspectiveStrength=.50,scaleReference=1.00,
    player={depth=.22,circleWidth=335},enemy={depth=.60,circleWidth=260}},
}
local PROFILE_BY_KEY={
  grass='outdoor_open',road='outdoor_open',sea='outdoor_open',cerulean_bridge='outdoor_open',safari='outdoor_open',power_plant_exterior='outdoor_open',
  viridian_forest='outdoor_enclosed',mt_moon='outdoor_enclosed',ss_anne='outdoor_enclosed',pokemon_tower='outdoor_enclosed',pokemon_mansion='outdoor_enclosed',
  oak_lab='interior',silph_co='interior',rocket_hideout='interior',power_plant='interior',power_plant_1='interior',power_plant_2='interior',power_plant_3='interior',power_plant_4='interior',
  cave_cerulean='cave',cave_dark='cave',cave_seafoam='cave',cave_victory_road='cave',
  gym_celadon='gym',gym_cerulean='gym',gym_cinnabar='gym',gym_fuchsia='gym',gym_pewter='gym',gym_saffron_fighting='gym',gym_saffron_psychic='gym',gym_vermilion='gym',gym_viridian='gym',
  league_agatha='league',league_bruno='league',league_champion='league',league_lance='league',league_lorelei='league',
}
local function copy(v) if type(v)~='table' then return v end;local o={};for k,x in pairs(v) do o[k]=copy(x) end;return o end
local function canonicalKey(value)
  local key=tostring(value or ''):lower()
  for _,suffix in ipairs({'sunrise','day','sunset','night'}) do local tail='_'..suffix;if key:sub(-#tail)==tail then key=key:sub(1,-#tail-1);break end end
  if key:match('^power_plant_[1-4]$') then return key end
  return key
end
function M.metadata(value)
  local key=canonicalKey(value);local profile=PROFILE_BY_KEY[key] or 'neutral';local data=copy(PROFILES[profile])
  data.background=key;data.profile=profile;data.authored=true;data.schema=1
  return data
end
function M.profileIds() local out={};for k in pairs(PROFILES) do out[#out+1]=k end;table.sort(out);return out end
function M.knownBackgrounds() local out={};for k in pairs(PROFILE_BY_KEY) do out[#out+1]=k end;table.sort(out);return out end
return M
