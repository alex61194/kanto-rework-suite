local root=assert(arg[1],'root path required')
local f=assert(io.open(root..'/main.lua','rb'));local src=f:read('*a');f:close()
local function has(s,msg) assert(src:find(s,1,true),msg) end
has("id='kanto.fly'",'UI must register Fly as a manual Field Action')
has("partyCapability(game,'FLY')",'Fly must require the real party FLY capability')
has("Core.mapFlyStatus(game)",'Fly availability must reuse Core Map/Fly progression gates')
has("local screen=MapFactory.new(game)",'Fly must open the real KRS Map instead of implementing a second teleport path')
has("game.stack:push(screen);return true,'map_opened'",'Fly must enter the KRS Map screen')
print('Field Actions Fly integration contract passed')
