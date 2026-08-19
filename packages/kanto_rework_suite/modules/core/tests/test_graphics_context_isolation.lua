local src=assert(io.open('main.lua','rb')):read('*a')
local function check(v,msg)if not v then error(msg or 'check failed',2)end end
for _,pair in ipairs({
  {'party="party.preview"','Party active'}, {'summary="summary.preview"','Summary'}, {'pokedex="pokedex.preview"','Pokédex'},
  {'moves="moves.icon"','Moves compact'}, {'pc="pc.icon"','PC compact'}, {'main_menu="main_menu.icon"','Main Menu compact'},
}) do check(src:find(pair[1],1,true),pair[2]..' must not route through battle.opponent') end
check(src:find('(kind=="battle") and "battle.opponent"',1,true),'battle opponent context is restricted to actual battles')
check(src:find('(kind=="battle") and "battle.player"',1,true),'battle player context is restricted to actual battles')
check(src:find('mapDestinationFor',1,true) and src:find('mapModelFor',1,true),'Core exports full-state Map/Fly arbitration seams')
print('Core graphics context isolation and Map/Fly seams tests passed')
