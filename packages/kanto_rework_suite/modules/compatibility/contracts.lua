-- Runtime contract discovery for third-party providers.
-- Release numbers are diagnostic metadata only. A provider is activated only
-- when its observable contract is present in the live Gen1Recomp runtime.
return function(deps)
  local api={}

  local function normRepo(value)
    value=tostring(value or ""):lower():gsub("^https?://github%.com/",""):gsub("%.git$","")
    value=value:gsub("^github%.com/",""):gsub("^/+",""):gsub("/+$","")
    return value
  end
  api.normRepo=normRepo

  local function slug(value)
    value=tostring(value or "provider"):lower():gsub("[^%w]+","_"):gsub("^_+",""):gsub("_+$","")
    return value~="" and value or "provider"
  end
  api.slug=slug

  function api.manifestEntry(game,id)
    local loader=game and game.mods
    local entry=loader and type(loader.mods)=="table" and loader.mods[id] or nil
    return entry,entry and entry.manifest or nil
  end

  function api.manifestRepo(manifest)
    return normRepo(type(manifest)=="table" and (manifest.github or manifest.repository or manifest.repo) or nil)
  end

  function api.isAscendant(handle,manifest)
    local id=tostring((manifest and manifest.id) or (handle and handle.id) or "")
    local name=tostring((manifest and manifest.name) or ""):lower()
    local repo=api.manifestRepo(manifest)
    return repo=="roxas2712/kanto-ascendant"
      or (id=="trainer_rematch" and (name=="" or name=="kanto ascendant"))
  end

  function api.ascendantContracts(handle)
    local exports=handle and handle.exports
    local crystal=type(exports)=="table" and exports.crystalAnimation or nil
    return {
      crystal=type(crystal)=="table" and type(crystal.staticFrameOne)=="function",
      menu=type(exports)=="table" and type(exports.ascendantMenu)=="table",
    }
  end

  function api.isSfxMusicReplacement(handle,manifest)
    local id=tostring((manifest and manifest.id) or (handle and handle.id) or "")
    local repo=api.manifestRepo(manifest)
    return id=="SFXMusicReplacementMod" or repo=="alucardthefirsthunter/musicreplacementmod"
  end

  function api.isDynamicCries(handle,manifest)
    return api.manifestRepo(manifest)=="lockerz102/stadium-cries"
  end

  local function runtimeHooks()
    local ok,Runtime=pcall(require,"src.mods.Runtime")
    if ok and Runtime and Runtime.hooks and type(Runtime.hooks.chains)=="table" then
      return Runtime.hooks.chains
    end
    return nil
  end

  function api.hookEntries(name,owner)
    local chains=runtimeHooks()
    local chain=chains and chains[name] or nil
    local out={}
    for _,entry in ipairs(type(chain)=="table" and chain or {}) do
      if owner==nil or tostring(entry.owner or "")==tostring(owner) then out[#out+1]=entry end
    end
    return out
  end

  function api.hasHookOwner(name,owner)
    return #api.hookEntries(name,owner)>0
  end

  function api.hookOwners(name)
    local out,seen={},{}
    for _,entry in ipairs(api.hookEntries(name)) do
      local owner=tostring(entry.owner or "")
      if owner~="" and not seen[owner] then seen[owner]=true;out[#out+1]=owner end
    end
    table.sort(out)
    return out
  end

  function api.hasOption(game,owner,key)
    local schemas=game and game.mods and game.mods.optionSchemas
    for _,row in ipairs(type(schemas)=="table" and type(schemas[owner])=="table" and schemas[owner] or {}) do
      if type(row)=="table" and tostring(row.key or "")==tostring(key) then return true end
    end
    return false
  end

  function api.audioOwnerCount(game,owner,bucket)
    local owners=game and game.data and game.data.audio and game.data.audio._owners
    local map=type(owners)=="table" and owners[bucket] or nil
    local n=0
    for _,value in pairs(type(map)=="table" and map or {}) do if tostring(value)==tostring(owner) then n=n+1 end end
    return n
  end

  function api.sfxMusicContracts(game,handle,manifest)
    local owner=tostring((manifest and manifest.id) or (handle and handle.id) or "")
    if owner=="" or not api.isSfxMusicReplacement(handle,manifest) then return {music=false,sfx=false} end
    return {
      music=api.hasOption(game,owner,"soundtrack") and api.hasHookOwner("music.select",owner),
      sfx=api.hasOption(game,owner,"sfx_pack") and api.audioOwnerCount(game,owner,"sfx")>0,
    }
  end

  function api.dynamicCriesContract(game,handle,manifest)
    local owner=tostring((manifest and manifest.id) or (handle and handle.id) or "")
    return owner~="" and api.isDynamicCries(handle,manifest) and api.audioOwnerCount(game,owner,"cries")>0
  end

  -- Execute only the selected owner's pokemon.sprite wrappers. The terminal
  -- function is the immutable ROM path supplied by Compatibility, never the
  -- global hook chain, so an unselected provider cannot leak through fallback.
  function api.callOwnedPokemonSprite(owner,path,ctx)
    local entries=api.hookEntries("pokemon.sprite",owner)
    if #entries==0 then return path end
    local unpack=table.unpack or unpack
    local function pack(...) return {n=select("#",...),...} end
    local args=pack(path,ctx)
    local function run(index)
      if index>#entries then return unpack(args,1,args.n) end
      local entry=entries[index]
      local downstream
      local function nextFn(...)
        if select("#",...)==0 then downstream=pack(run(index+1))
        else
          local saved=args;args=pack(...);downstream=pack(run(index+1));args=saved
        end
        return unpack(downstream,1,downstream.n)
      end
      local res=pack(pcall(entry.callback,nextFn,unpack(args,1,args.n)))
      if res[1] then return unpack(res,2,res.n) end
      if downstream then return unpack(downstream,1,downstream.n) end
      return run(index+1)
    end
    return run(1)
  end

  function api.declaredCapabilities(handle)
    local exports=handle and handle.exports
    local declaration=type(exports)=="table" and (exports.krsCompatibility or exports.kantoCompatibility) or nil
    local raw=type(declaration)=="table" and declaration.capabilities or nil
    local out={}
    if type(raw)~="table" then return out end
    if #raw>0 then
      for _,claim in ipairs(raw) do if type(claim)=="table" then out[#out+1]=claim end end
    else
      for capability,claim in pairs(raw) do
        if type(claim)=="table" then
          local copy={};for k,v in pairs(claim) do copy[k]=v end
          copy.capability=copy.capability or capability;out[#out+1]=copy
        elseif claim==true then out[#out+1]={capability=capability} end
      end
    end
    return out
  end

  return api
end
