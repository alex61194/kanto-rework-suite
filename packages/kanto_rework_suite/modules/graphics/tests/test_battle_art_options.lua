local src=assert(io.open('main.lua','rb')):read('*a')
for _,key in ipairs({'battle_sprite_mode','front_generation','back_generation','player_art','sprite_animation','animation_speed','battle_scale','real_size','time_mode','time_cycle_length','world_lighting'}) do
  assert(src:find("key='"..key.."'",1,true),'missing Graphics option '..key)
end
assert(not src:find("'GEN 6'",1,true),'archive gen6 folder is environment art, not a Pokémon generation option')
assert(src:find("{'SUNRISE','sunrise'}",1,true) and src:find("{'SUNSET','sunset'}",1,true),'four KRS time phases exposed')
assert(not src:lower():find('dramaticshapevoxelmod',1,true),'Graphics must not depend on Voxel')
print('Graphics animated-art and time option tests passed')
