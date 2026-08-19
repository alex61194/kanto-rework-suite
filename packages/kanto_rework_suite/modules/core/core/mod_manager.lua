-- Presentation-agnostic mod runtime facade.
-- Owns ManagerState/manifest/options internals; product UIs receive models and
-- explicit actions only. It deliberately does NOT patch native ManagerState draw/update.
return function(deps)
  local mod=assert(deps.mod,"mod is required")
  local runtime=assert(deps.runtime,"runtime is required")
  local release=tostring(deps.release or "")
  local compatibility=deps.compatibility
  local integrations=deps.integrations
  local restartResume=deps.restartResume
  local service={}
  local installError
  local PERMISSIONS={"engine_internals","network","steps"}

  local function req(name) local ok,v=pcall(require,name);return ok and v or nil end
  local function clamp(v,lo,hi) if lo~=nil then v=math.max(lo,v) end;if hi~=nil then v=math.min(hi,v) end;return v end
  local function authorOf(m,card)
    local raw=m and m.raw
    local a=(card and card.author) or (raw and (raw.author or raw.authors)) or m.author
    if type(a)=="table" then a=table.concat(a,", ") end
    if type(a)=="string" and a~="" then return a end
    return m and m.github and m.github:match("^([^/]+)/") or nil
  end
  -- 0.1.86 isolates each mod's files. Metadata for another mod must come
  -- from the loader's validated manifest/model, never by opening its mod.card.
  local function loadCard(_) return nil end
  local function managerFor(game)
    local ManagerState=req("src.mods.ManagerState")
    if not (ManagerState and ManagerState.new) then return nil,"src.mods.ManagerState unavailable" end
    return ManagerState.new(game)
  end

  local Session={};Session.__index=Session
  function Session:enter()
    if self.entered then return true end
    if self.manager.enter then self.manager:enter() elseif self.manager.refresh then self.manager:refresh() end
    if integrations and integrations.refreshAutomatic then integrations.refreshAutomatic(self.game) end
    self.entered=true;return true
  end
  function Session:refresh()
    if self.manager.refresh then self.manager:refresh() end
    return self.manager.status
  end
  function Session:mods()
    self:refresh();return (self.manager.status and self.manager.status.available) or {}
  end
  function Session:models()
    local out={};for _,m in ipairs(self:mods()) do out[#out+1]=self:model(m) end;return out
  end
  function Session:modById(id)
    self:refresh();return self.manager.byId and self.manager.byId[id] or nil
  end
  function Session:card(m) return loadCard(m) end
  function Session:model(mOrId)
    local m=type(mOrId)=="table" and mOrId or self:modById(mOrId)
    if not m then return nil end
    local card=self:card(m);local declared={};for _,p in ipairs(m.permissions or {}) do declared[p]=true end
    local permissions={};for _,id in ipairs(PERMISSIONS) do permissions[#permissions+1]={id=id,declared=declared[id]==true} end
    local compat=(card and card.compat and card.compat.engine) or m.game_version
    local compatibilityIssues=compatibility and compatibility.evaluateMod and compatibility.evaluateMod(m,m.enabled~=false) or {}
    local capabilityClaims=compatibility and compatibility.providersForMod and compatibility.providersForMod(m.id) or {}
    local blocked=false
    for _,issue in ipairs(compatibilityIssues) do if issue.blocksEnable then blocked=true break end end
    local model={
      id=m.id,name=m.name or m.id,version=m.version,author=authorOf(m,card),github=m.github,
      description=(card and card.summary) or m.description or "",category=m.category,profile=m.profile,
      api=m.api,compatibility=compat,experimental=m.experimental==true,affectsLink=m.affects_link,dependencies=m.dependencies or {},
      enabled=m.enabled==true,bootEnabled=m.state~="disabled",staged=self.manager.isStaged and self.manager:isStaged(m) or false,
      state=m.state,error=m.error,permissions=permissions,
      capabilityClaims=capabilityClaims,compatibilityIssues=compatibilityIssues,compatibilityBlocked=blocked,
    }
    model=integrations and integrations.decorateModel and integrations.decorateModel(m,model) or model
    if not model.integration and integrations and integrations.hasAutomatic and integrations.hasAutomatic(self.game,m.id) then
      model.integration={id="automatic.start_menu",label=model.name,status="automatic"}
    end
    return model
  end
  function Session:schema(m)
    if not (m and self.manager.schemaFor) then return nil end
    local ok,v=pcall(self.manager.schemaFor,self.manager,m);return ok and type(v)=="table" and v or nil
  end
  function Session:options(mOrId)
    local m=type(mOrId)=="table" and mOrId or self:modById(mOrId);local schema=self:schema(m) or {};local out={}
    for _,d in ipairs(schema) do
      if type(d)=="table" and type(d.key)=="string" then
        local value=d.default
        if self.manager.optionValue then local ok,v=pcall(self.manager.optionValue,self.manager,m.id,d);if ok then value=v end end
        local choices={};for _,c in ipairs(d.choices or {}) do choices[#choices+1]={label=c[1],value=c[2]} end
        local display=value
        if d.type=="toggle" then display=value and "ON" or "OFF"
        elseif d.type=="choice" then for _,c in ipairs(choices) do if c.value==value then display=c.label break end end end
        local displayValue=tostring(display==nil and "" or display)
        if d.suffix and displayValue~="" then displayValue=displayValue..tostring(d.suffix) end
        out[#out+1]={key=d.key,id=d.key,label=d.label or d.key,description=d.description or "",type=d.type,value=value,displayValue=displayValue,default=d.default,choices=choices,min=d.min,max=d.max,step=d.step,maxLen=d.maxLen,group=d.group or d.section,suffix=d.suffix}
      end
    end
    if #out>0 then out[#out+1]={key="__reset",id="__reset",label="RESET DEFAULTS",type="action",value=""} end
    return integrations and integrations.decorateOptions and integrations.decorateOptions(m,out) or out
  end
  function Session:utilities(mOrId)
    local m=type(mOrId)=="table" and mOrId or self:modById(mOrId)
    return integrations and integrations.utilities and integrations.utilities(self.game,m) or {}
  end
  function Session:openUtility(modId,utilityId)
    local m=self:modById(modId);if not m then return false,nil,"unknown mod" end
    if not (integrations and integrations.openUtility) then return false,nil,"mod integration registry unavailable" end
    return integrations.openUtility(self.game,m,utilityId)
  end
  local function schemaDef(self,m,key)
    for _,d in ipairs(self:schema(m) or {}) do if d.key==key then return d end end
  end
  function Session:adjustOption(modId,key,dir)
    local m=self:modById(modId);if not m then return false,"unknown mod" end
    if key=="__reset" then return self:resetOptions(modId) end
    local d=schemaDef(self,m,key);if not d then return false,"unknown option" end
    local cur=d.default;if self.manager.optionValue then cur=self.manager:optionValue(modId,d) end
    local value=cur;dir=(tonumber(dir) or 1)<0 and -1 or 1
    if d.type=="toggle" then value=not not (not cur)
    elseif d.type=="choice" then
      local list=d.choices or {};if #list==0 then return false,"no choices" end
      local i=1;for n,c in ipairs(list) do if c[2]==cur then i=n break end end;i=((i-1+dir)%#list)+1;value=list[i][2]
    elseif d.type=="number" then value=clamp((tonumber(cur) or 0)+dir*(tonumber(d.step) or 1),d.min,d.max)
    elseif d.type=="text" then return false,"text input required"
    else return false,"unsupported option type" end
    self.manager:setOption(modId,key,value);self:refresh();return true,value
  end
  function Session:setOption(modId,key,value)
    local m=self:modById(modId);if not m then return false,"unknown mod" end
    local d=schemaDef(self,m,key);if not d then return false,"unknown option" end
    if d.type=="toggle" then value=value==true
    elseif d.type=="choice" then
      local valid=false;for _,choice in ipairs(d.choices or {}) do if choice[2]==value then valid=true break end end
      if not valid then return false,"invalid choice" end
    elseif d.type=="number" then
      value=tonumber(value);if not value then return false,"invalid number" end
      value=clamp(value,d.min,d.max)
    elseif d.type~="text" then return false,"unsupported option type" end
    self.manager:setOption(modId,key,value);self:refresh();return true,value
  end
  function Session:resetOptions(modId)
    local m=self:modById(modId);if not m then return false,"unknown mod" end
    for _,d in ipairs(self:schema(m) or {}) do if type(d)=="table" and d.key then self.manager:setOption(modId,d.key,d.default) end end
    self:refresh();return true
  end
  function Session:toggle(modId)
    local m=self:modById(modId);if not m then return false,"unknown mod" end
    local want=not m.enabled
    if want and compatibility and compatibility.canEnable then
      local allowed,message=compatibility.canEnable(m)
      if not allowed then return false,message or "blocked by compatibility policy" end
    end
    self.manager:beginToggle(m);self:refresh();return true,self:prompt()
  end
  function Session:prompt()
    local ov=self.manager.overlay;if not ov then return nil end
    local lines={};for _,v in ipairs(ov.lines or {}) do lines[#lines+1]=tostring(v) end
    return {kind=ov.kind or "ok",lines=lines,index=ov.index or 1}
  end
  function Session:respondPrompt(yes)
    local ov=self.manager.overlay;if not ov then return false end
    self.manager.overlay=nil
    if ov.kind=="confirm" and yes and ov.onYes then ov.onYes() end
    self:refresh();return true
  end
  function Session:profiles()
    local rows=self.manager.profileRows and self.manager:profileRows() or {};local out={}
    for _,r in ipairs(rows) do
      if r.profile then out[#out+1]={kind="profile",label=r.label,profile=r.profile}
      elseif r.saveAs then out[#out+1]={kind="saveAs",label=r.label}
      elseif r.exportProfile then out[#out+1]={kind="export",label=r.label}
      elseif r.importProfile then out[#out+1]={kind="import",label=r.label}
      elseif r.adhoc then out[#out+1]={kind="adhoc",label=r.label} end
    end
    return out
  end
  function Session:activateProfile(row)
    if not row then return false end
    if row.kind=="profile" then self.manager:applyProfile(row.profile)
    elseif row.kind=="saveAs" then self.manager:saveCurrentAs()
    elseif row.kind=="export" then self.manager:exportActiveProfile()
    elseif row.kind=="import" then self.manager:importProfiles()
    elseif row.kind=="adhoc" then self.manager:optionsTable().activeProfile=nil;self.manager:notify("AD-HOC SET ACTIVE")
    else return false end
    self:refresh();return true
  end
  function Session:errors()
    local out,seen={},{}
    local models=self:models()
    local function owner(detail,explicit)
      if explicit then
        for _,m in ipairs(models) do if m.id==explicit then return m.id,m.name end end
        return explicit,explicit
      end
      local lower=tostring(detail or ''):lower()
      for _,m in ipairs(models) do
        local id=tostring(m.id or ''):lower();local name=tostring(m.name or ''):lower()
        if (id~='' and (lower:find('mods/'..id..'/',1,true) or lower:find(id..':',1,true)))
            or (name~='' and lower:find(name,1,true)) then return m.id,m.name end
      end
      local path=lower:match('mods/([^/]+)/')
      return path or 'system',path or 'SYSTEM'
    end
    local function add(detail,source,severity,explicit,issue)
      detail=tostring(detail or '')
      if detail=='' or seen[detail] then return end
      seen[detail]=true
      local modId,modName=owner(detail,explicit)
      local label=detail:gsub('[\r\n\t]+',' '):gsub('%s+',' ')
      if #label>180 then label=label:sub(1,177)..'...' end
      out[#out+1]={label=label,detail=detail,modId=modId,modName=modName,
        source=source or 'engine',severity=severity or 'error',issue=issue}
    end
    for _,detail in ipairs((self.manager.status and self.manager.status.errors) or {}) do add(detail,'engine','error') end
    for _,m in ipairs(models) do if m.error then add(m.error,'mod','error',m.id) end end
    if compatibility and compatibility.scan then
      local errors=self.manager.status and self.manager.status.errors or {}
      for _,issue in ipairs(compatibility.scan(self:mods(),errors) or {}) do
        local prefix=tostring(issue.severity or "warning"):upper()
        local detail=prefix.." · "..tostring(issue.message or issue.id)
        add(detail,issue.source,issue.severity,issue.modId or issue.mod_id,issue)
      end
    end
    return out
  end
  function Session:restartRequired()
    local native=self.manager.stagedList and #self.manager:stagedList()>0 or false
    local internal=mod.suite and type(mod.suite.restartRequired)=="function" and mod.suite:restartRequired() or false
    return native or internal
  end
  function Session:discardChanges() if self.manager.discardChanges then self.manager:discardChanges();self:refresh();return true end return false end
  function Session:restartSafety()
    local game=self.game
    if not game or type(game.writeSave)~="function" then return false,"A writable game save is unavailable." end
    if type(game.restartWithMods)~="function" then return false,"Automatic restart is unavailable on this engine build." end
    if not(restartResume and restartResume.available and restartResume.available()) then return false,"Automatic restart with game resume is unavailable on this platform." end
    local stack=game.stack;local states=stack and stack.states
    local overworld=game.overworld;local foundOverworld=false
    if type(states)=="table" then
      for _,state in ipairs(states) do if state==overworld then foundOverworld=true break end end
    end
    if not foundOverworld then return false,"Return to the overworld before restarting." end
    local ow=overworld
    if ow and (ow.transitioning or ow.engaging or ow.emote) then return false,"Wait for the current overworld transition to finish." end
    if ow and ow.player and ow.player.moving then return false,"Wait until the player has stopped moving." end
    if ow and ow.scriptMoves and #ow.scriptMoves>0 then return false,"Wait for the scripted movement to finish." end
    if ow and ow.runner and type(ow.runner.isRunning)=="function" then
      local ok,running=pcall(ow.runner.isRunning,ow.runner)
      if ok and running then return false,"Wait for the current scene to finish." end
    end
    return true,"Overworld is stable."
  end
  local function unwindToOverworld(game)
    local stack=game and game.stack;local ow=game and game.overworld
    if not(stack and type(stack.top)=="function" and type(stack.pop)=="function" and ow) then return false,"The game state stack cannot be prepared for restart." end
    local guard=0
    while stack:top() and stack:top()~=ow do
      stack:pop();guard=guard+1
      if guard>64 then return false,"The active screen stack could not be closed safely." end
    end
    if stack:top()~=ow then return false,"The overworld is no longer active." end
    return true
  end
  function Session:saveAndRestart()
    local game=self.game
    local safe,reason=self:restartSafety();if not safe then return false,"unsafe",reason end
    local save=game.save or {}
    local expectedVersion=save.version
    local expectedPlaythrough=save.meta and save.meta.playthroughId
    -- A pre-existing save should already have a playthrough id. Older/imported
    -- saves may not; ask the engine's own identity helper before writing so the
    -- checkpoint and the normal save are verified against the same slot identity.
    if type(expectedPlaythrough)~="string" or expectedPlaythrough=="" then
      local SaveData=req("src.core.SaveData")
      if SaveData and type(SaveData.ensurePlaythroughId)=="function" then
        local okId,value=pcall(SaveData.ensurePlaythroughId,save)
        if okId then expectedPlaythrough=value end
      end
    end
    if type(expectedVersion)~="string" or type(expectedPlaythrough)~="string" or expectedPlaythrough=="" then
      return false,"save_identity_missing","The active game/playthrough could not be identified for restart."
    end
    local ok,saved=pcall(game.writeSave,game)
    if not ok or saved==false then return false,"save_failed",ok and "The game refused the save." or tostring(saved) end
    if save.version~=expectedVersion or not save.meta or save.meta.playthroughId~=expectedPlaythrough then
      return false,"save_identity_changed","The saved game identity changed while preparing the restart."
    end
    -- The official checkpoint API refuses an active menu. Restart Now owns
    -- this unwind: every state above the overworld exits normally before capture.
    local closed,closeError=unwindToOverworld(game)
    if not closed then return false,"screen_close_failed",closeError end
    local prepared,resumeOrError=restartResume.prepare(game)
    if not prepared then return false,"resume_failed","The game was saved, but automatic resume could not be prepared: "..tostring(resumeOrError) end
    local identity=type(resumeOrError)=="table" and resumeOrError.identity or nil
    if not(identity and identity.gameVersion==expectedVersion and identity.playthroughId==expectedPlaythrough) then
      restartResume.cancel(game);return false,"resume_identity_mismatch","The restart checkpoint does not match the active game/playthrough."
    end
    local restarted,restartError=restartResume.request(game)
    if not restarted then restartResume.cancel(game);return false,"restart_failed","The game was saved, but restart failed: "..tostring(restartError) end
    -- Dispatch is not proof of a restart. Success is established by the real
    -- restart event/process replacement and second-boot checkpoint restoration.
    return true,"restart_dispatched",resumeOrError
  end

  function service.create(game)
    game=game or runtime.game;local manager,err=managerFor(game);if not manager then return nil,err end
    return setmetatable({game=game,manager=manager,native=manager,entered=false},Session)
  end
  function service.modelFor(modId)
    local s=service.create(runtime.game);if not s then return nil end;s:enter();return s:model(modId or mod.id)
  end
  function service.install() installError=nil;return true end
  function service.status() return {installed=installError==nil,error=installError,release=release,presentation=false,permissions=PERMISSIONS} end
  return service
end
