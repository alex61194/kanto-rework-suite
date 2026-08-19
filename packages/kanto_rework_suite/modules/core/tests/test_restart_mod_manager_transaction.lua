local root=assert(arg[1],'root required')
local factory=assert(loadfile(root..'/core/mod_manager.lua'))()
local order={}
local ow={map={},player={moving=false},scriptMoves={},runner={isRunning=function() return false end}}
local stack={states={ow,{screenId='StartMenu'},{screenId='ModsMenu'}}}
function stack:top() return self.states[#self.states] end
function stack:pop() order[#order+1]='pop:'..tostring(self:top().screenId);return table.remove(self.states) end
local game={overworld=ow,stack=stack,save={version='red',meta={playthroughId='pt-red-1'}}}
function game:writeSave() order[#order+1]='save';return true end
function game:restartWithMods() order[#order+1]='engine-restart' end
local manager={status={available={}},refresh=function() end}
package.preload['src.mods.ManagerState']=function() return {new=function(g) return manager end} end
local prepared,cancelled=false,false
local restartResume={available=function() return true end}
function restartResume.prepare(g)
  assert(g.stack:top()==ow,'checkpoint must be prepared with overworld on top')
  order[#order+1]='prepare';prepared=true
  return true,{identity={gameVersion='red',playthroughId='pt-red-1',engineVersion='0.1.94'}}
end
function restartResume.request(g) order[#order+1]='request';return true,'engine_restart_requested' end
function restartResume.cancel() cancelled=true end
local service=factory({mod={id='kanto_rework_core'},runtime={game=game},release='0.1.40',restartResume=restartResume})
local session=assert(service.create(game))
local ok,code= session:saveAndRestart()
assert(ok and code=='restart_dispatched','restart transaction dispatches after a valid checkpoint')
assert(prepared and not cancelled,'valid restart checkpoint is retained for second boot')
assert(game.stack:top()==ow and #stack.states==1,'Restart Now closes every active menu itself')
assert(table.concat(order,',')=='save,pop:ModsMenu,pop:StartMenu,prepare,request','transaction order is save -> close screens -> checkpoint -> restart request')
-- Identity mismatch must abort and clear the checkpoint without requesting restart.
stack.states={ow,{screenId='ModsMenu'}};order={};cancelled=false
restartResume.prepare=function(g) order[#order+1]='prepare';return true,{identity={gameVersion='blue',playthroughId='other'}} end
local ok2,code2=session:saveAndRestart()
assert(not ok2 and code2=='resume_identity_mismatch' and cancelled,'mismatched version/playthrough checkpoint is rejected and cancelled')
for _,v in ipairs(order) do assert(v~='request','restart must not dispatch after checkpoint identity mismatch') end
print('Restart Mods transaction tests passed')
