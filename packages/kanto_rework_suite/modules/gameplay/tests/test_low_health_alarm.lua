local root=assert(arg[1],"root path required")
local wrapper
local unregistered=false
local hooks={wrap=function(_,name,fn,priority)
  assert(name=='battle.low_health_alarm','public low-health hook only')
  assert(priority==120,'priority remains deterministic')
  wrapper=fn
  return function() unregistered=true return true end
end}
local now=0
local oldLove=love
love={timer={getTime=function() return now end}}
local factory=assert(loadfile(root..'/low_health_alarm.lua'))()
local unregister=factory({hooks=hooks})
assert(type(wrapper)=='function' and type(unregister)=='function','alarm hook installs')
local battle={}
local function run(on)
  local ctx={on=on,battle=battle}
  local result=wrapper(function(c) return c end,ctx)
  return result.on
end
now=0; assert(run(true)==true,'danger alarm begins')
now=2.99; assert(run(true)==true,'danger alarm remains enabled before three seconds')
now=3.01; assert(run(true)==false,'danger alarm is force-stopped after three real seconds')
now=4; assert(run(false)==false,'engine-off state resets the continuous alarm budget')
now=10; assert(run(true)==true,'a later independent danger period gets a fresh budget')
assert(unregister()==true and unregistered,'alarm hook unregisters')
love=oldLove
print('Low health alarm cap tests passed')
