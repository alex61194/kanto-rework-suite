-- Runtime options facade. The UI receives normalized descriptors/callbacks,
-- never src.ui.OptionsMenu or window APIs directly.
return function(deps)
  local runtime=assert(deps.runtime,"runtime is required")
  local videoMode=assert(deps.videoMode,"video mode service is required")
  local service={}
  local function req(name) local ok,v=pcall(require,name);return ok and v or nil end

  local function proxy(game,row)
    local out={id=row.id,label=row.label,description=row.description,type=row.type,category=row.category}
    out.value=function()
      if row.id=="videoMode" then return videoMode.modeLabel(videoMode.current(game)) end
      if type(row.value)=="function" then local ok,v=pcall(row.value,game);if ok then return v end end
      return ""
    end
    out.step=function(_,dir)
      if row.id=="videoMode" then return videoMode.step(game,dir) end
      if type(row.step)=="function" then return row.step(game,dir) end
      return false
    end
    if type(row.activate)=="function" then out.activate=function() return row.activate(game) end end
    return out
  end

  function service.create(game,opts)
    game=game or runtime.game
    local OptionsMenu=assert(req("src.ui.OptionsMenu"),"src.ui.OptionsMenu unavailable")
    videoMode.reconcile(game)
    local native=OptionsMenu.new(game,opts)
    local rows={};for _,row in ipairs(native.rows or {}) do rows[#rows+1]=proxy(game,row) end
    local session={game=game,native=native,rows=rows}
    function session:refresh()
      videoMode.reconcile(self.game)
      local rebuilt=OptionsMenu.new(self.game,opts);self.native=rebuilt;self.rows={}
      for _,row in ipairs(rebuilt.rows or {}) do self.rows[#self.rows+1]=proxy(self.game,row) end
      return self.rows
    end
    function session:syncVideoMode() return videoMode.reconcile(self.game) end
    return session
  end
  return service
end
