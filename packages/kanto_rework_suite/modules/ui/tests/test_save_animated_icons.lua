local src=assert(io.open('ui/menu_presenter.lua','rb')):read('*a')
assert(src:find("'save.icon'",1,true),'Save party rows request save.icon from KRS Graphics')
assert(src:find("runtime.Graphics.draw",1,true),'Save party rows use the shared Graphics draw service')
print('KRS Save animated icon resolver test passed')
