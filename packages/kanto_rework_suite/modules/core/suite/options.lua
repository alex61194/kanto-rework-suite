-- One native Suite option schema, partitioned by internal module namespace.
return function(host, suite)
  local service={schemas={},rootRows={},game=nil}
  local GROUPS={core="GENERAL",ui="INTERFACE",graphics="GRAPHICS",gameplay="GAMEPLAY",battle_animations="BATTLE ANIMATIONS",compatibility="COMPATIBILITY",dev_tools="DEVELOPER"}
  local DISPLAY_ORDER={"core","ui","graphics","gameplay","battle_animations","compatibility","dev_tools"}
  local function clone(v)
    if type(v)~="table" then return v end
    local o={};for k,x in pairs(v) do o[k]=clone(x) end;return o
  end
  local function key(mid,k) return tostring(mid).."."..tostring(k) end
  service.key=key
  local function mapRow(mid,row)
    local r=clone(row);r.key=key(mid,row.key)
    if type(r.visible_if)=="table" and type(r.visible_if.key)=="string" then r.visible_if.key=key(mid,r.visible_if.key) end
    local base=GROUPS[mid] or tostring(mid):upper();local sub=r.group or r.section
    r.group=(type(sub)=="string" and sub~="" and sub~=base) and (base.." / "..sub) or base;r.section=nil
    return r
  end
  function service:combined()
    local out={}
    -- Presentation order is a UI/settings concern, not lifecycle order.
    for _,mid in ipairs(DISPLAY_ORDER) do for _,r in ipairs(self.schemas[mid] or {}) do
      if type(r)=="table" and type(r.key)=="string" and r.key~="" then out[#out+1]=mapRow(mid,r) end
    end end
    -- Suite-owned rows (currently Developer Tools enablement) come last so
    -- their declared group remains contiguous with the corresponding module.
    for _,r in ipairs(self.rootRows or {}) do out[#out+1]=clone(r) end
    return out
  end
  function service:refresh() if host.options and host.options.define then host.options:define(self:combined()) end end
  function service:setRoot(rows) self.rootRows=clone(rows or {});self:refresh() end
  function service:define(mid,rows) assert(type(rows)=="table","options schema must be table");self.schemas[mid]=clone(rows);self:refresh();return rows end
  function service:get(mid,k) return host.options and host.options.get and host.options:get(key(mid,k)) or nil end
  function service:attachGame(game) self.game=game end
  function service:set(mid,k,value,opts)
    opts=opts or {};local game=opts.game or self.game or suite.game;local skey=key(mid,k)
    local saveOpts=game and game.save and game.save.options;local loader=game and game.mods
    if saveOpts then saveOpts.modOptions=type(saveOpts.modOptions)=="table" and saveOpts.modOptions or {};saveOpts.modOptions[suite.id]=type(saveOpts.modOptions[suite.id])=="table" and saveOpts.modOptions[suite.id] or {};saveOpts.modOptions[suite.id][skey]=value end
    if loader then loader.modOptions=type(loader.modOptions)=="table" and loader.modOptions or {};loader.modOptions[suite.id]=type(loader.modOptions[suite.id])=="table" and loader.modOptions[suite.id] or {};loader.modOptions[suite.id][skey]=value end
    if saveOpts and opts.persist~=false and game and type(game.writeOptions)=="function" then pcall(game.writeOptions,game) end
    if opts.emit~=false and loader and loader.events and type(loader.events.emit)=="function" then pcall(loader.events.emit,loader.events,"mod.options_changed",{mod=suite.id,key=skey,value=value,internalModule=mid}) end
    return value
  end
  function service:schemaFor(mid) return clone(self.schemas[mid] or {}) end
  return service
end
