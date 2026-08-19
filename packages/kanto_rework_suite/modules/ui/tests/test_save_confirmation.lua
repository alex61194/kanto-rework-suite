local root=assert(arg[1],'root path required')
local saves=0
local played={}
local Core={saveSlots={}}
function Core.saveSlots.list() return {} end
function Core.saveSlots.save(id) saves=saves+1; return true,id or 'slot1' end
function Core.saveSlots.load() return false end
function Core.saveSlots.delete() return false end
package.preload['src.core.Sound']=function() return {play=function(_,name) played[#played+1]=name end} end
local runtime={
  Core=Core,
  Focus={new=function() return {} end,navigation=function() end,pointerMove=function() end},
  Layout={isWide=function() return true end,contains=function(x,y,r) return false end},
  viewport={},
}
local factory=assert(loadfile(root..'/screens/save_slots.lua'))()
local Screen=factory.factory(runtime)
local game={data={},stack={pop=function() end},input={wasPressed=function() return false end}}
local s=Screen.new(game,'save')
assert(s.index==1 and s:slot().id=='slot1','explicit empty slot mapping')
local ok=s:activate()
assert(ok==true and s.confirmSave==true and saves==0,'first activation only opens confirmation')
s.saveChoice='save'
local saved,id=s:activate()
assert(saved==true and id=='slot1' and saves==1,'confirmed save writes exactly once')
assert(s.saveNotice and s.saveNotice.ok and s.saveNotice.text=='SAVED TO SLOT 01','success acknowledgement is visible')
assert(played[1]=='Save','save confirmation plays the engine Save sound')
s:activate()
assert(s.saveNotice==nil,'success acknowledgement dismisses explicitly')
print('Save slot confirmation tests passed')
