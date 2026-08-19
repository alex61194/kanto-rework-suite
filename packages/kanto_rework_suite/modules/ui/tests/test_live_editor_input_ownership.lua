local root=assert(arg[1],'root path required')
local main=assert(io.open(root..'/main.lua','rb')):read('*a')
assert(main:find("if s and s.kind=='graphics_editor' then return false end",1,true),
  'battle input layer must yield while graphics_editor is top state')
assert(main:find('id="kanto_rework_ui.battle",priority=235',1,true),
  'battle input layer contract unexpectedly changed')
assert(main:find('id="kanto_rework_ui.menus",priority=220',1,true),
  'editor remains owned by menu pointer layer')
print('Live editor modal input ownership test passed')
