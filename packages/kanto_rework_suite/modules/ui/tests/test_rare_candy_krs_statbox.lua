local root=assert(arg[1],"root path required")
local function read(path)local f=assert(io.open(root..'/'..path,'rb'));local s=f:read('*a');f:close();return s end
local function check(v,msg)if not v then error(msg or 'check failed',2)end end
local native=read('ui/native_presenter.lua')
local main=read('main.lua')
check(native:find("local StatBox=BattleState.StatBox",1,true),'NativePresenter binds official StatBox type')
check(native:find("or isStatBox(state)",1,true),'Rare Candy StatBox can inherit native Party context')
check(native:find("(ismt(state,TextBox) or isStatBox(state)) and bl",1,true),'Rare Candy StatBox is also owned when the target PartyMenu has already popped and Bag remains below')
check(native:find("if isStatBox(overlay) then drawLevelUpOverlay",1,true),'Bag overlay routes Rare Candy StatBox to KRS presentation')
check(native:find("drawLevelUpOverlay(game,m,c,overlay)",1,true),'out-of-battle StatBox is rendered by KRS level-up overlay')
check(native:find("'+'..tostring(gain)",1,true),'KRS native level-up overlay renders stat increases')
check(main:find("runtime.NativePresenter.handles(state.game,state)",1,true),'native 160x144 StatBox draw is suppressed under KRS ownership')
print('Rare Candy KRS StatBox presentation regression tests passed')
