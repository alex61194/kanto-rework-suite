-- Start-menu runtime facade. Owns engine routes/data, never their presentation.
return function(deps)
  local runtime=assert(deps.runtime,"runtime is required")
  local trainer=assert(deps.trainer,"trainer service is required")
  local integrations=deps.integrations
  local service={}
  local function req(name) local ok,v=pcall(require,name);return ok and v or nil end
  local function same(a,b) return tostring(a or "")==tostring(b or "") end

  local function labels()
    local Strings=req("src.core.Strings") or function(s)return s end
    return {pokedex=Strings("POKéDEX"),pokemon=Strings("POKéMON"),bag=Strings("ITEM"),save=Strings("SAVE"),options=Strings("OPTION"),link=Strings("LINK"),mods=Strings("MODS"),quit=Strings("QUIT")}
  end

  function service.create(game)
    game=game or runtime.game
    local StartMenu=assert(req("src.ui.StartMenu"),"src.ui.StartMenu unavailable")
    local native
    if integrations and type(integrations.traceStartMenu)=="function" then
      native=integrations.traceStartMenu(game,function() return StartMenu.new(game) end)
    else native=StartMenu.new(game) end
    local l=labels();local by,unknown={},{}
    local playerName=game.save and game.save.player and game.save.player.name or "RED"
    for _,item in ipairs(native.items or {}) do
      local id
      if same(item.label,l.pokedex) then id="pokedex" elseif same(item.label,l.pokemon) then id="pokemon"
      elseif same(item.label,l.bag) then id="bag" elseif same(item.label,l.save) then id="save"
      elseif same(item.label,l.options) then id="options" elseif same(item.label,l.link) then id="link"
      elseif same(item.label,l.mods) then id="mods" elseif same(item.label,l.quit) then id="quit"
      elseif same(item.label,playerName) then id="trainer" end
      if id then by[id]=item
      else
        local claimed=integrations and integrations.claimStartMenuItem and integrations.claimStartMenuItem(game,item)
        if not claimed then unknown[#unknown+1]=item end
      end
    end
    local externalById={}
    local externalEntries={}
    for index,item in ipairs(unknown) do
      if type(item)=="table" then
        local id="external:"..tostring(index)
        externalById[id]=item
        externalEntries[#externalEntries+1]={
          id=id,
          label=tostring(item.label or "MOD ACTION"),
          description="Open this utility provided by an installed mod.",
          enabled=type(item.onSelect)=="function",
          external=true,
        }
      end
    end
    local party=game.save and game.save.party or {}
    local entries={
      {id="pokedex",enabled=by.pokedex~=nil},{id="pokemon",enabled=by.pokemon~=nil and #party>0},
      {id="bag",enabled=by.bag~=nil},{id="pc",enabled=req("src.ui.BoxMenu")~=nil},
      {id="link",enabled=by.link~=nil},{id="save",enabled=by.save~=nil},
      {id="options",enabled=by.options~=nil},{id="mods",enabled=by.mods~=nil},{id="close",enabled=true},
    }
    for _,entry in ipairs(externalEntries) do entries[#entries+1]=entry end
    -- Mod-authored Start-menu rows are valid extension points, not a reason to
    -- abandon Kanto UI. Keep the original item callbacks and expose them to the
    -- presenter as external actions. Native fallback remains layout-based.
    local session={game=game,native=native,entries=entries,supported=true,unknown=unknown,external=externalEntries,externalById=externalById,byNative=by}
    function session:trainerModel() return trainer.model(self.game) end
    function session:activate(id)
      local Screens=req("src.ui.Screens")
      if id=="close" then if type(self.game.returnToTitle)=="function" then self.game:returnToTitle();return true end return false end
      if id=="pokedex" and Screens then Screens.push(self.game,"PokedexMenu");return true end
      if id=="pokemon" and #((self.game.save and self.game.save.party) or {})>0 and Screens then Screens.push(self.game,"PartyMenu");return true end
      if id=="bag" and Screens then Screens.push(self.game,"BagMenu");return true end
      if id=="options" and Screens then Screens.push(self.game,"OptionsMenu");return true end
      if id=="mods" and Screens then Screens.push(self.game,"ManagerState");return true end
      if id=="pc" and Screens and req("src.ui.BoxMenu") then Screens.push(self.game,"BoxMenu");return true end
      if id=="link" then local Link=req("src.link.LinkState");if Link and Link.new then self.game.stack:push(Link.new(self.game));return true end end
      local external=self.externalById[id]
      if external and type(external.onSelect)=="function" then external.onSelect();return true end
      -- SAVE's native callback only pushes the canonical confirmation flow; it
      -- does not depend on the native StartMenu having been popped first.
      if id=="save" and self.byNative.save and self.byNative.save.onSelect then self.byNative.save.onSelect();return true end
      return false
    end
    return session
  end
  return service
end
