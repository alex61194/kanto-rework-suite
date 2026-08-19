local root=assert(arg[1])
local kind='keyboard';local cursor=true
love={mouse={setVisible=function(v)cursor=v end},timer={getTime=function()return 1 end}}
local device={
  status=function()return{kind=kind,controllerFamily=kind=='controller' and'playstation'or nil,bindings={}}end,
  observePointer=function(ev)kind=ev.source=='touch' and'touch'or'mouse'end,
}
local mode=assert(loadfile(root..'/core/input_mode.lua'))()({runtime={},inputDevice=device})
kind='controller';mode.observeDevice('controller');assert(mode.snapshot().activeDevice.kind=='controller','controller becomes active')
assert(mode.pointerEvent({source='mouse',phase='moved',dx=1,dy=1,x=10,y=10})==false,'tiny motion 1 ignored')
assert(mode.snapshot().activeDevice.kind=='controller','tiny motion must not steal controller mode')
assert(mode.pointerEvent({source='mouse',phase='moved',dx=1,dy=1,x=11,y=11})==false,'tiny motion 2 ignored')
assert(mode.snapshot().activeDevice.kind=='controller','accumulated subthreshold motion keeps controller')
assert(mode.pointerEvent({source='mouse',phase='moved',dx=2,dy=0,x=13,y=11})==true,'deliberate mouse motion promotes pointer')
assert(mode.snapshot().activeDevice.kind=='mouse' and cursor==true,'real mouse move changes active device and shows cursor')
kind='controller';mode.observeDevice('controller');assert(mode.snapshot().activeDevice.kind=='controller','controller can immediately reclaim mode')
assert(mode.pointerEvent({source='mouse',phase='pressed',button=1,x=20,y=20})==true,'mouse click is immediate intent')
assert(mode.snapshot().activeDevice.kind=='mouse','mouse click switches footer/device immediately')
kind='controller';mode.observeDevice('controller');mode.focus(true)
assert(mode.pointerEvent({source='mouse',phase='moved',dx=20,dy=0,x=40,y=20})==false,'first post-focus cursor resync is ignored')
assert(mode.snapshot().activeDevice.kind=='controller','post-focus synthetic move must not steal controller')
print('Input mode hysteresis tests passed')
