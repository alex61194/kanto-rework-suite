local root=assert(arg[1],'graphics root required')
local M=assert(loadfile(root..'/background_spatial.lua'))()
for _,id in ipairs({'grass','road','sea','viridian_forest','mt_moon','oak_lab','cave_dark','gym_pewter','league_champion','silph_co','rocket_hideout','power_plant_4'}) do
  local m=M.metadata(id)
  assert(m.authored==true and type(m.profile)=='string','metadata identity missing '..id)
  assert(type(m.horizonY)=='number' and type(m.perspectiveStrength)=='number','projection metadata missing '..id)
  assert(type(m.player)=='table' and type(m.player.depth)=='number' and type(m.player.circleWidth)=='number','player metadata missing '..id)
  assert(type(m.enemy)=='table' and type(m.enemy.depth)=='number' and type(m.enemy.circleWidth)=='number','enemy metadata missing '..id)
  assert(m.player.depth<m.enemy.depth,'enemy should be farther in authored scene '..id)
end
assert(M.metadata('grass_night').background=='grass','time variants must share family geometry')
print('PASS test_background_spatial_metadata')
