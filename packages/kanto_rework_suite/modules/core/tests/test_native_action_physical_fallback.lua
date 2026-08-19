local root=assert(arg[1])
local Game={}
function Game:keypressed()return false end;function Game:keyreleased()return false end
function Game:gamepadpressed()return false end;function Game:gamepadreleased()return false end
function Game:joystickpressed()return false end;function Game:joystickreleased()return false end
function Game:gamepadaxis()return false end;function Game:joystickaxis()return false end;function Game:joystickhat()return false end
package.preload['src.core.Game']=function()return Game end
local runtime={game={save={options={bindings={}}}}}
local device=assert(loadfile(root..'/core/input_device.lua'))()({runtime=runtime})
local joy={getName=function()return'DualSense Wireless Controller'end,getGUID=function()return'030000004c050000e60c000000000000'end,isGamepad=function()return true end}
device.install()
Game.gamepadpressed(runtime.game,joy,'b')
device.step()
assert(device.status(runtime.game).kind=='controller','physical pad input selects controller')
assert(device.wasNativeActionPressed(runtime.game,'b')==true,'raw Circle/B must provide shared native Back fallback')
device.step();assert(device.wasNativeActionPressed(runtime.game,'b')==false,'physical fallback is one-frame edge')
Game.gamepadreleased(runtime.game,joy,'b')
print('Native action physical fallback tests passed')
