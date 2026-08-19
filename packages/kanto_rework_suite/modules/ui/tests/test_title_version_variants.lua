local root=assert(arg[1],'root path required')
local function loadModule(path)local c,e=loadfile(root..'/'..path);assert(c,e);return c()end
local current='RED'
local nativeDraws=0
local Native={}
function Native.new(game,opts)
  return {game=game,enter=function()end,draw=function()nativeDraws=nativeDraws+1 end,
    openMenu=function(self)self.game.stack:push({items={{label='EXIT GAME',onSelect=function()end}}})end}
end
package.preload['src.ui.TitleState']=function()return Native end
package.preload['src.core.SaveData']=function()return{listSlots=function()return{}end}end
package.preload['src.core.GameVersion']=function()return{
  get=function()return current end,isBlue=function()return current=='BLUE'end,isYellow=function()return current=='YELLOW'end,
}end
package.preload['src.ui.Screens']=function()return{push=function()end}end
package.preload['src.core.Sound']=function()return{play=function()end}end
package.preload['src.core.Strings']=function()return function(v)return v end end
package.preload['src.mods.Runtime']=function()return{call=function(_,_,_,items)return items end}end
local loaded={}
love={graphics={newImage=function(path)loaded[#loaded+1]=path;return{setFilter=function()end,getDimensions=function()return 1920,1080 end}end}}
local runtime={assetPath=function(p)return p end,Core={saveSlots={list=function()return{}end}},
  Focus={new=function()return{}end,navigation=function()end,syncDevice=function()end,pointerMove=function()end,pointerPress=function()end},
  Layout={isWide=function()return true end,contains=function()return false end}}
local stack={states={}};function stack:push(v)self.states[#self.states+1]=v end;function stack:pop()return table.remove(self.states)end;function stack:top()return self.states[#self.states]end
local game={stack=stack,input={wasPressed=function()return false end},data={}}
local Factory=loadModule('screens/title_screen.lua').factory(runtime)
current='red';local red=Factory.new(game,{});assert(red.version=='red' and red.image and not red.nativeBackdrop,'Red uses authored KRS artwork')
current='blue';local blue=Factory.new(game,{});assert(blue.version=='blue' and blue.image and not blue.nativeBackdrop,'Blue uses authored KRS artwork')
assert(loaded[#loaded]=='assets/title/title_blue.png','Blue resolves supplied Blue artwork')
current='yellow';local yellow=Factory.new(game,{});assert(yellow.version=='yellow' and not yellow.nativeBackdrop and yellow.image,'Yellow uses authored KRS Wide artwork')
assert(loaded[#loaded]=='assets/title/title_yellow.png','Yellow resolves supplied Yellow artwork')
yellow:draw();assert(nativeDraws==0,'Yellow does not render the vanilla 160x144 title as the primary backdrop')
assert(yellow:isWide(),'Yellow no longer falls back to vanilla title menu')
current='gold';local gold=Factory.new(game,{});assert(gold.version=='unknown' and gold.nativeBackdrop and gold.image==nil,'Unsupported Gold must not inherit Red artwork')
gold:draw();assert(nativeDraws==1,'Unsupported version keeps engine-owned backdrop')
current='future';local unknown=Factory.new(game,{});assert(unknown.version=='unknown' and unknown.nativeBackdrop and unknown.image==nil,'Unknown/future version must not inherit Red artwork')
print('Red/Blue/Yellow + safe unknown Start Screen variant tests passed')
