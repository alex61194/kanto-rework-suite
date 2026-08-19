-- Sandbox-safe restart/resume bridge for Gen1Recomp 0.1.94.
-- The engine owns persistence, checkpoint reconstruction and process restart.
-- No filesystem, environment, debug, FFI or love.event access is required.
return function(deps)
  local runtime=assert(deps.runtime,"runtime is required")
  local mod=assert(deps.mod,"mod is required")
  local service={}
  local KEY="restart_resume/checkpoint"
  local pendingChecked=false

  local function titleSession(game)
    local states=game and game.stack and game.stack.states
    if type(states)~="table" then return false end
    for _,state in ipairs(states) do if type(state)=="table" and state.screenId=="TitleState" then return true end end
    return false
  end
  function service.available()
    return type(mod.storage)=="table" and type(mod.checkpoints)=="table"
  end
  function service.prepare(game)
    if not service.available() or not game then return false,"Restart/resume API is unavailable." end
    local capability=mod.checkpoints:inspect(game)
    if not (type(capability)=="table" and capability.canCapture) then
      return false,(capability and capability.message) or "The current state cannot be checkpointed."
    end
    local checkpoint,code,message=mod.checkpoints:capture(game)
    if not checkpoint then return false,message or code or "Checkpoint capture failed." end
    -- Ensure a durable selected playthrough exists so storage can be resolved
    -- again after the process restart, without turning later checkpoints into
    -- hidden normal saves.
    local saved,saveCode,saveMessage=mod.checkpoints:ensureNormalSave(game,checkpoint)
    if saved==false and saveCode~="already_exists" then return false,saveMessage or saveCode or "Could not establish a resumable save." end
    local ok,writeCode,writeMessage=mod.storage:write(game,KEY,{checkpoint=checkpoint})
    if ok~=true then return false,writeMessage or writeCode or "Could not persist restart checkpoint." end
    local identity=type(checkpoint.identity)=="table" and checkpoint.identity or {}
    runtime.restartResume={prepared=true,kind=checkpoint.kind,identity={
      gameVersion=identity.gameVersion,playthroughId=identity.playthroughId,
      engineVersion=identity.engineVersion,
    }}
    pendingChecked=false
    return true,{kind=checkpoint.kind,identity=runtime.restartResume.identity}
  end
  function service.request(game)
    if not (game and type(game.restartWithMods)=="function") then return false,"Automatic restart is unavailable on this engine build." end
    local ok,err=pcall(game.restartWithMods,game)
    if not ok then return false,tostring(err) end
    return true,"engine_restart_requested"
  end
  function service.cancel(game)
    game=game or runtime.game
    if game then pcall(function() mod.storage:delete(game,KEY) end) end
    runtime.restartResume=nil;pendingChecked=true;return true
  end
  function service.step(game)
    if not game or not titleSession(game) then return false end
    if pendingChecked then return false end
    pendingChecked=true
    local selected,code,message=mod.storage:selected(game)
    if not selected then return false,code or message end
    local record=selected:read(KEY)
    if type(record)~="table" or type(record.checkpoint)~="table" then return false,"no_pending_checkpoint" end
    selected:delete(KEY)
    local ok,resumeCode,resumeMessage=mod.checkpoints:resume(game,record.checkpoint)
    if ok then
      runtime.restartResume={restored=true,kind=record.checkpoint.kind}
      return true
    end
    runtime.restartResume={restored=false,error=resumeMessage or resumeCode}
    return false,resumeMessage or resumeCode
  end
  function service.status() return {available=service.available(),pending=not pendingChecked,last=runtime.restartResume,storageKey=KEY,sandboxSafe=true} end
  return service
end
