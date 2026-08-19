local menu=assert(io.open('ui/menu_presenter.lua','rb')):read('*a')
local assets=assert(io.open('runtime/assets.lua','rb')):read('*a')
local function count(hay,needle)local n,p=0,1 while true do local i=hay:find(needle,p,true);if not i then return n end;n=n+1;p=i+#needle end end
assert(count(menu,'drawPixelImage(m,portrait,')>=2,'Save and Main Menu must both render trainer portrait service output')
assert(count(menu,',112,276)')>=2,'Save and Main Menu use canonical Figma 112x276 trainer presentation size')
assert(not menu:find(',224,250)',1,true),'legacy stretched backsprite placement must be gone')
assert(assets:find("local filter=meta.filter",1,true),'presentation metadata controls intended image filtering')
print('Save/Main Menu player front presentation tests passed')
