local root=assert(arg[1])
local current={kind='keyboard',bindings={up='up',down='down',left='left',right='right',a='return',b='escape',select='x'}}
local custom={BATTLE_INFO={key='tab',pad='y'},LIVE_BATTLE_EDITOR={key='f10',pad='touchpad'}}
local Core={
  inputMode=function() return {activeDevice=current} end,
  inputBinding=function(a) return current.bindings[a] end,
  inputActions={
    definition=function(id) return custom[id] and {id=id} or nil end,
    binding=function(id,slot) return custom[id] and custom[id][slot] or nil end,
  },
}
local Footer=assert(loadfile(root..'/components/footer.lua'))()({C={DESIGN_WIDTH=1920,DESIGN_HEIGHT=1080,FOOTER_HEIGHT=64,colors={}},Core=Core})
local p,label=Footer.resolve({},{{action='a',label='OPEN'},{action='BATTLE_INFO',label='INFO'}})
assert(label=='KEYBOARD + MOUSE' and p[1].key=='ENTER' and p[2].key=='TAB','keyboard bindings must resolve semantically')
current={kind='controller',controllerFamily='playstation',controllerModel='dualsense',controllerName='DualSense',bindings={up='dpup',down='dpdown',left='dpleft',right='dpright',a='a',b='b',select='back'}}
p,label=Footer.resolve({},{{action='a',label='OPEN'},{action='BATTLE_INFO',label='INFO'},{action='LIVE_BATTLE_EDITOR',label='EDIT'}})
assert(label=='DUALSENSE' and p[1].key=='CROSS' and p[2].key=='TRIANGLE' and p[3].key=='TOUCHPAD','controller custom/native bindings must update immediately')
local main=assert(io.open(root..'/ui/menu_presenter.lua','rb')):read('*a')
assert(main:find('runtime.Footer.menuDraw(runtime,m,D,colors,screen.game,"main")',1,true),'Main Menu must use shared dynamic footer')
assert(main:find("local semantic={{navigation=true,label='SELECT'}",1,true),'Save Slots must use semantic dynamic footer prompts')
assert(main:find("{{navigation=true,label='SELECT SLOT'},{action='a',label='REGISTER'},{action='b',label='BACK'}}",1,true),'Bag Register must use semantic dynamic footer prompts')
assert(main:find("runtime.Footer.resolve(screen.game,semantic)",1,true),'Live Editor footer must use shared semantic resolver')
local battle=assert(io.open(root..'/ui/battle_presenter.lua','rb')):read('*a')
assert(battle:find("{action='BATTLE_INFO',label='BATTLE INFO'}",1,true) and battle:find("{action='LIVE_BATTLE_EDITOR',label='LIVE EDIT'}",1,true),'battle footer must expose semantic custom actions')
local uimain=assert(io.open(root..'/main.lua','rb')):read('*a')
assert(uimain:find("id='BATTLE_INFO'",1,true) and uimain:find("id='LIVE_BATTLE_EDITOR'",1,true),'battle footer actions must be registered/rebindable')
assert(uimain:find("Core.inputActions.wasPressed('BATTLE_INFO')",1,true) and uimain:find("Core.inputActions.wasPressed('LIVE_BATTLE_EDITOR')",1,true),'registered footer actions must drive runtime behavior')
print('PASS test_footer_semantic_runtime')
