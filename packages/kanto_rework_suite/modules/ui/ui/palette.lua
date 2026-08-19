-- Single Kanto Rework UI semantic palette resolver.
-- Product theme selects visual tokens first; Core accessibility is layered on top.
return function(deps)
  local C=assert(deps.C);local Profiles=assert(deps.Profiles);local Core=assert(deps.Core);local Themes=assert(deps.Themes);local mod=assert(deps.mod)
  local P={}
  local aliases={fieldjournal="cream",field_journal="cream",sombre="purplenight",purple_night="purplenight"}
  local function copy(t) local o={};for k,v in pairs(t or {}) do o[k]=v end;return o end
  local function themeId()
    local ok,v=pcall(mod.options.get,mod.options,"ui_theme");v=ok and v or Themes.DEFAULT
    local id=tostring(v or Themes.DEFAULT):lower():gsub("[%s%-]+","_");id=aliases[id] or id
    return Themes.valid(id) and id or Themes.DEFAULT
  end
  local function profileName()
    local v="standard";if type(Core.activeAccessibilityProfile)=="function" then local ok,r=pcall(Core.activeAccessibilityProfile);if ok and r then v=tostring(r):lower() end end
    return Profiles[v] and v or "standard"
  end
  local function fullFrameFilter()
    if type(Core.fullFrameColorAccessibility)~="function" then return false end
    local ok,value=pcall(Core.fullFrameColorAccessibility);return ok and value==true
  end
  function P.resolve(game)
    local id=themeId();local spec=Themes.get(id);local selected=profileName()
    local tokenProfile=fullFrameFilter() and "standard" or selected
    local prof=Profiles[tokenProfile] or Profiles.standard
    -- Keep non-theme utility roles from the foundation token table (for
    -- example letterbox/debug) then let the Figma theme own every semantic
    -- surface/text/interaction token it defines.
    local colors=copy(C.colors)
    for k,v in pairs(spec.colors or {}) do colors[k]=v end
    -- Color-accessibility profiles override functional roles only. Surface and
    -- typography identity stay owned by the selected product theme.
    if tokenProfile~="standard" then
      for k,v in pairs(prof.colors or {}) do
        if k~="canvas" and k~="panel" and k~="elevated" and k~="subtle" and k~="header" and k~="ink" and k~="muted" and k~="faint" and k~="border" and k~="borderStrong" and k~="white" and k~="textInverse" then colors[k]=v end
      end
    end
    colors.text=colors.ink;colors.textSecondary=colors.muted;colors.textInverse=colors.textInverse or colors.white
    colors.inverse=colors.header;colors.inverseRaised=colors.structureRaised or colors.inverseRaised;colors.disabled=colors.faint
    colors.selected=colors.interactiveSelected or colors.header;colors.success=colors.hpFull;colors.warning=colors.hpMid;colors.hpWarn=colors.hpMid;colors.danger=colors.hpCritical
    for k,v in pairs(spec.screen or {}) do colors[k]=v end
    colors.themeId=id;colors.themeLabel=spec.label
    return {colors=colors,typeColors=copy(prof.typeColors or C.typeColors),statusColors=copy(prof.statusColors or {}),profile=selected,theme=id,colorMode=type(Core.activeColorMode)=="function" and Core.activeColorMode() or nil,advancedOnly=false,fullFrame=fullFrameFilter()}
  end
  function P.resolveAll(_,game) local r=P.resolve(game);local out=copy(r.colors);out.typeColors=r.typeColors;out.statusColors=r.statusColors;out.profile=r.profile;out.theme=r.theme;return out end
  function P.profile(_,game) return P.resolve(game).profile end
  function P.theme(_,game) return P.resolve(game).theme end
  function P.role(_,game,role) local r=P.resolve(game);return r.colors[role] or r.typeColors[role] or r.colors.ink end
  return P
end
