-- Sandbox-safe, data-only persistence for modular overlay placement.
-- Gen1Recomp 0.1.84+ owns persistent filesystem access.  This module only
-- sanitizes tables; the caller supplies read/write callbacks backed by
-- mod.storage.
return function(options)
  options=options or {}
  local defaults=assert(options.defaults,"profile defaults are required")
  local allowedThemes=options.allowedThemes or {}
  local read=options.read
  local write=options.write
  local HEADER="KRS_PROFILE_V2"
  local WIDGETS={"encounters","capture"}
  local MODES={overworld=true,battle=true,both=true,none=true}
  local TAB_EDGES={left=true,right=true,top=true,bottom=true,[""]=true}

  local function copy(source)
    local out={};for k,v in pairs(source or {}) do out[k]=v end;return out
  end
  local function clamp01(v,f) v=tonumber(v);if not v then return f end;return math.max(0,math.min(1,v)) end
  local function clampScale(v,f) v=tonumber(v);if not v then return f end;return math.max(.60,math.min(1.60,v)) end
  local function validMode(v,f) v=type(v)=="string" and v:lower() or nil;return MODES[v] and v or f end
  local function validEdge(v,f) v=type(v)=="string" and v:lower() or nil;return TAB_EDGES[v] and v or f end
  local function validTheme(v)
    if type(v)~="string" or v=="" then return nil end
    return next(allowedThemes)==nil or allowedThemes[v] and v or nil
  end
  local function sanitize(data)
    local out=copy(defaults);if type(data)~="table" then return out end
    out.theme=validTheme(data.theme) or out.theme
    if type(data.overlayVisible)=="boolean" then out.overlayVisible=data.overlayVisible end
    if type(data.widgetLocked)=="boolean" then out.widgetLocked=data.widgetLocked end
    for _,id in ipairs(WIDGETS) do
      local legacy=clampScale(data[id.."Scale"],nil)
      out[id.."X"]=clamp01(data[id.."X"],out[id.."X"])
      out[id.."Y"]=clamp01(data[id.."Y"],out[id.."Y"])
      out[id.."Width"]=clampScale(data[id.."Width"],legacy or out[id.."Width"] or 1)
      out[id.."Height"]=clampScale(data[id.."Height"],legacy or out[id.."Height"] or 1)
      out[id.."Mode"]=validMode(data[id.."Mode"],out[id.."Mode"] or "none")
      if type(data[id.."Collapsed"])=="boolean" then out[id.."Collapsed"]=data[id.."Collapsed"] end
      out[id.."TabEdge"]=validEdge(data[id.."TabEdge"],out[id.."TabEdge"] or "")
      out[id.."TabPosition"]=clamp01(data[id.."TabPosition"],out[id.."TabPosition"] or .5)
    end
    return out
  end
  local function loadProfile()
    if type(read)~="function" then return copy(defaults) end
    local ok,value=pcall(read)
    if not ok then return copy(defaults),tostring(value) end
    if type(value)~="table" then return copy(defaults) end
    return sanitize(value)
  end
  local function saveProfile(profile)
    if type(write)~="function" then return false,"profile persistence unavailable" end
    local ok,a,b=pcall(write,sanitize(profile))
    if not ok then return false,tostring(a) end
    if a==false then return false,b or "profile persistence failed" end
    return true
  end
  return {load=loadProfile,save=saveProfile,sanitize=sanitize,format=HEADER}
end
