local root=assert(arg[1],"root path required")
local function check(v,msg)if not v then error(msg or "check failed",2)end end
local src=assert(io.open(root..'/ui/menu_presenter.lua','rb')):read('*a')
check(src:find("if screen.searchActive then pcFocusOutline",1,true),'PC search uses plain PC focus outline')
check(src:find("pcFocusOutline(runtime,m,r,colors.focus) end",1,true),'PC sort selection uses plain PC focus outline')
check(not src:find("screen.searchActive then D.focusBorder",1,true),'PC search no longer uses global focus rail')
print('PC search/sort focus outline regression tests passed')
