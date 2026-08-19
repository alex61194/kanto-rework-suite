local root=assert(arg[1])
local st={kind='keyboard',bindings={up='up',down='down',left='left',right='right',a='z',b='x',start='escape',select='tab'}}
local Core={inputMode=function()return{activeDevice=st}end,inputBinding=function(a)return st.bindings[a]end}
local Footer=assert(loadfile(root..'/components/footer.lua'))()({C={DESIGN_WIDTH=1920,DESIGN_HEIGHT=1080,FOOTER_HEIGHT=64,colors={}},Core=Core})
local p,label=Footer.resolve({},{{action='b',label='BACK'}});assert(label=='KEYBOARD + MOUSE' and p[1].key=='X','keyboard footer')
st={kind='controller',controllerFamily='playstation',controllerModel='dualsense',controllerName='DualSense',bindings={up='dpup',down='dpdown',left='dpleft',right='dpright',a='a',b='b',start='start',select='back'}}
p,label=Footer.resolve({},{{action='b',label='BACK'}});assert(label=='DUALSENSE' and p[1].key=='CIRCLE','PlayStation footer updates immediately')
st={kind='controller',controllerFamily='xbox',controllerName='Xbox Wireless Controller',bindings={up='dpup',down='dpdown',left='dpleft',right='dpright',a='a',b='b',start='start',select='back'}}
p,label=Footer.resolve({},{{action='b',label='BACK'}});assert(label=='XBOX CONTROLLER' and p[1].key=='B','Xbox footer updates immediately')
st={kind='touch',bindings={}};p,label=Footer.resolve({},{{action='b',label='BACK'}});assert(label=='TOUCH','touch footer mode')
print('Dynamic footer device tests passed')
