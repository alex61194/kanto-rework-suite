local text=assert(io.open('../ui/battle_presenter.lua','rb')):read('*a')
for _,row in ipairs({
  "{id='opponent_frame',component='battle.hud.opponent',renderer=hud,movable=true}",
  "{id='player_frame',component='battle.hud.player',renderer=hud,movable=true}",
  "{id='command_list',component='battle.commands',renderer=commandCard,movable=true}",
  "{id='move_menu',component='battle.moves',renderer=moveDock,movable=true}",
}) do assert(text:find(row,1,true),'missing/misconfigured live editor production target: '..row) end
assert(text:find('renderer=hud',1,true) and text:find('renderer=commandCard',1,true) and text:find('renderer=moveDock',1,true),'contract must reference real BattlePresenter functions')
assert(text:find("component='battle.moves'",1,true),'move list/description/info must stay one coherent production move block')
print('PASS test_live_editor_contract')
