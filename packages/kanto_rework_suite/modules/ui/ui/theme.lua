-- Product theme service. Theme choice is UI-owned and persisted through the
-- Core mod-runtime facade; accessibility remains Core-owned and is applied by Palette.
return function(deps)
  local Palette=assert(deps.Palette);local Specs=assert(deps.Specs);local mod=assert(deps.mod);local Core=assert(deps.Core)
  local Theme={}
  local aliases={fieldjournal="cream",field_journal="cream",sombre="purplenight",purple_night="purplenight"}
  local function normalize(value)
    local id=tostring(value or Specs.DEFAULT):lower():gsub("[%s%-]+","_")
    id=aliases[id] or id
    return Specs.valid(id) and id or Specs.DEFAULT
  end
  function Theme.currentId()
    local ok,value=pcall(mod.options.get,mod.options,"ui_theme")
    return normalize(ok and value or Specs.DEFAULT)
  end
  function Theme.current() return Specs.get(Theme.currentId()) end
  function Theme.label() return Theme.current().label end
  function Theme.fontFamily() return Theme.current().fontFamily end
  function Theme.order() local out={};for i,v in ipairs(Specs.ORDER) do out[i]=v end;return out end
  function Theme.set(game,value)
    local id=normalize(value);if id==Theme.currentId() then return false,id end
    local session,err=Core.createModRuntime(game)
    if not session then return false,err or "mod runtime unavailable" end
    local okEnter,enterErr=pcall(session.enter,session);if not okEnter then return false,enterErr end
    local ok,a,b=pcall(session.setOption,session,mod.id,"ui_theme",id)
    if not ok then return false,a end
    if not a then return false,b end
    return true,id
  end
  function Theme.step(game,dir)
    local order=Specs.ORDER;local current=Theme.currentId();local index=1
    for i,id in ipairs(order) do if id==current then index=i break end end
    local delta=(tonumber(dir) or 1)<0 and -1 or 1
    local nextId=order[((index-1+delta)%#order)+1]
    return Theme.set(game,nextId)
  end
  function Theme.value() return Theme.label() end
  function Theme.resolveAll(runtime,game) return Palette.resolveAll(runtime,game) end
  return Theme
end
