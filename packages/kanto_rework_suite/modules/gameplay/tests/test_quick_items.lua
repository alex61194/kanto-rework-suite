local root=assert(arg[1],'root path required')
local used=0
local layer
local stack={states={}}
function stack:top() return self.states[#self.states] end
function stack:push(v) self.states[#self.states+1]=v end
function stack:pop() return table.remove(self.states) end
local overworld={kind='overworld'}
stack.states={overworld}
local game={overworld=overworld,stack=stack,data={},save={inventory={POTION=3}}}

package.preload['src.ui.BagMenu']=function()
  return {new=function(g)
    local list={items={{value='POTION',label='POTION'}},index=1,rows=7}
    list.onChoose=function(row)
      g.stack:push({items={
        {label='USE',onSelect=function() used=used+1;if g.stack:top()==list then g.stack:pop() end end},
        {label='TOSS',onSelect=function() error('shortcut must never choose TOSS') end},
      }})
    end
    return list
  end}
end
package.preload['src.core.Sound']=function() return {play=function() end} end

local saved={[1]='POTION'}
local durable=nil
local listeners={}
local mod={
  save={get=function(_,key,default) return saved or default end,set=function(_,key,value) saved=value end},
  storage={
    read=function(_,g,key) return durable end,
    write=function(_,g,key,value) durable=value;return true end,
  },
  events={on=function(_,name,fn) listeners[name]=fn;return function() listeners[name]=nil end end},
}
local Core={registerInputLayer=function(def) layer=def;return function() end end}
love={keyboard={isDown=function(k) return k=='lctrl' end}}
local factory=assert(loadfile(root..'/quick_items.lua'))()
local state=factory({mod=mod,Core=Core,Game=game})

local ok,id=state.use(1,game)
assert(ok and id=='POTION','registered shortcut must resolve the saved item')
assert(used==1,'registered shortcut must invoke USE directly, not stop at USE/TOSS')
assert(game.stack:top()==overworld,'fake successful use returns to overworld')

used=0;game.stack.states={overworld}
assert(layer and layer.active(game),'registered item input layer must be active in stable overworld')
assert(layer.keypressed(game,'1','1',false)==true,'Ctrl+1 must be consumed before Gen1Recomp speed hotkey')
assert(used==1,'Ctrl+1 must actually invoke the registered item')
used=0;game.stack.states={overworld}
assert(layer.keypressed(game,'kp1','kp1',false)==true,'Ctrl+numpad1 must be accepted')
assert(used==1,'Ctrl+numpad1 must invoke the same slot')

love.keyboard.isDown=function() return false end
assert(layer.keypressed(game,'1','1',false)==false,'bare 1 remains available to Gen1Recomp speed hotkey')

-- Registration must survive a full module/session reconstruction without waiting
-- for the next normal game save: assign writes durable per-playthrough storage.
assert(state.assign(2,'POTION'))
assert(type(durable)=='table' and type(durable.slots)=='table' and durable.slots[2]=='POTION',
  'assign must persist immediately through mod.storage')

-- Simulate a fresh process: volatile mod.save starts empty, durable storage
-- remains. The reconstructed shortcut service must restore slot 2.
saved=nil
layer=nil
local listeners2={}
local mod2={
  save={get=function(_,key,default) return default end,set=function(_,key,value) saved=value end},
  storage={read=function(_,g,key) return durable end,write=function(_,g,key,value) durable=value;return true end},
  events={on=function(_,name,fn) listeners2[name]=fn;return function() listeners2[name]=nil end end},
}
local state2=factory({mod=mod2,Core=Core,Game=game})
assert(state2.item(2)=='POTION','durable registered shortcut must survive a reconstructed game session')
-- Simulate CONTINUE rebinding the loader to the loaded save: reload must keep
-- the durable slots rather than the stale entry-chunk table.
assert(type(listeners2['save.loaded'])=='function','shortcut service must subscribe to save.loaded')
listeners2['save.loaded']({save=game.save})
assert(state2.item(2)=='POTION','save.loaded must refresh shortcut state from durable storage')
state2.unregister()

print('Registered item shortcut tests passed')
