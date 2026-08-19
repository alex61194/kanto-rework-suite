local RELEASE="0.4.20"
local EXPORT_API=15

return function(mod)
  local function loadModule(relative)
    local source,readErr=mod:read(relative)
    assert(type(source)=="string",readErr or ("Unable to read "..tostring(relative)))
    local chunk,err=load(source,"@"..mod.id.."/"..relative)
    assert(chunk,err or ("Unable to compile "..tostring(relative)))
    return chunk()
  end
  local coreHandle=mod.find("core")
  local Core=coreHandle and coreHandle.exports
  assert(Core and tonumber(Core.version or 0)>=40 and Core.compatibility and Core.modIntegrations
      and type(Core.dispatchPointerEvent)=="function",
    "kanto_rework_core 0.1.40+ integration registry is required")

  local suiteId=mod.suite and mod.suite.id or "kanto_rework_suite"
  local unregister={}
  local activeVoxelAdapter
  local activeAscendantAdapter
  local activeAscendantId
  local dynamicProviders={}
  local externalSpriteProviders={}

  local Contracts=loadModule("contracts.lua")({mod=mod})

  local function registerDynamicProvider(definition)
    if dynamicProviders[definition.id] then return false end
    local off=Core.compatibility.registerProvider(definition)
    dynamicProviders[definition.id]=off
    unregister[#unregister+1]=function()
      local live=dynamicProviders[definition.id]
      if not live then return false end
      dynamicProviders[definition.id]=nil
      return live()
    end
    return true
  end

  -- Standard mod options belong to the mod that declared their options_schema,
  -- regardless of that mod's release number. This generic filter prevents a
  -- future compatible update from leaking duplicate settings back into the
  -- global OPTIONS screen. It relies on provenance/schema ownership, never on
  -- guessed labels or a hard-coded list of third-party option keys.
  local function filterStandardModOptions(game,rows)
    if type(rows)~="table" then return rows end
    local schemas=game and game.mods and game.mods.optionSchemas
    if type(schemas)~="table" then return rows end
    local ownedPrefixed={}
    local ownersByKey={}
    for modId,schema in pairs(schemas) do
      if type(modId)=="string" and type(schema)=="table" then
        for _,definition in ipairs(schema) do
          local key=type(definition)=="table" and definition.key or nil
          if type(key)=="string" and key~="" then
            ownedPrefixed[modId..":"..key]=true
            local owners=ownersByKey[key] or {}
            owners[#owners+1]={modId=modId,definition=definition}
            ownersByKey[key]=owners
          end
        end
      end
    end
    local out={}
    for _,row in ipairs(rows) do
      local remove=false
      if type(row)=="table" then
        local id=tostring(row.id or row.key or "")
        if ownedPrefixed[id] then
          remove=true
        else
          -- Declarative provenance from a row is authoritative when present.
          local owner=tostring(row.owner or row.modId or row.mod_id or row.source or "")
          local key=tostring(row.key or row.id or "")
          if owner~="" and schemas[owner] then
            for _,definition in ipairs(schemas[owner]) do
              if type(definition)=="table" and tostring(definition.key)==key then remove=true break end
            end
          else
            -- Legacy/custom rows sometimes re-expose a standard schema option
            -- through ui.options.rows using an id such as `mod_soundtrack`
            -- instead of the schema key `soundtrack`. We can still prove the
            -- ownership without a hard-coded mod list when all three facts
            -- agree: the schema label matches, the schema key is unique, and
            -- the custom row id is explicitly mod-shaped (mod_<key>) or ends
            -- in the exact key token. This is how SFXMusicReplacementMod
            -- exposes soundtrack/sfx/stereo, and it remains future-proof when
            -- that mod adds more standard schema keys.
            local function norm(v)
              return tostring(v or ""):lower():gsub("[^%w]+","")
            end
            local actualLabel=tostring(row.label or row.name or "")
            local rawId=tostring(row.id or row.key or "")
            local bareId=rawId:lower()
            for key,owners in pairs(ownersByKey) do
              if #owners==1 then
                local definition=owners[1].definition
                local expected=tostring(definition.label or definition.key or "")
                local labelMatches=expected~="" and actualLabel~="" and norm(expected)==norm(actualLabel)
                local keyNorm=norm(key)
                local idNorm=norm(rawId)
                local explicitModShape=bareId:match("^mod[_:%-]")~=nil
                local keySuffix=keyNorm~="" and idNorm:sub(-#keyNorm)==keyNorm
                if labelMatches and (rawId==key or explicitModShape and keySuffix) then
                  remove=true
                  break
                end
              end
            end

            -- Render-pipeline rows carry authoritative owner provenance in the
            -- merged registry even though Pipelines.rows() does not copy that
            -- owner onto the visible row. If the owning mod already exposes an
            -- equivalent standard schema option, the pipeline row is only a
            -- duplicate global control and belongs under MODS with that owner.
            if not remove and rawId:sub(1,9)=="pipeline:" then
              local pipelineId=rawId:sub(10)
              local defs=game and game.data and game.data.render_pipelines
              local pipelineOwner=type(defs)=="table" and type(defs._owners)=="table" and defs._owners[pipelineId] or nil
              local schema=pipelineOwner and schemas[pipelineOwner] or nil
              if type(schema)=="table" then
                for _,definition in ipairs(schema) do
                  local expected=tostring(type(definition)=="table" and (definition.label or definition.key) or "")
                  if expected~="" and actualLabel~="" and norm(expected)==norm(actualLabel) then
                    remove=true
                    break
                  end
                end
              end
            end
          end
        end
      end
      if not remove then out[#out+1]=row end
    end
    return out
  end

  -- Conflict ownership is expressed through Core's cooperative capability
  -- registry. Compatibility defines presentation capabilities which do not
  -- belong in the Foundation core itself, then exposes any real multi-provider
  -- conflict as an inline selector under this mod in MODS.
  unregister[#unregister+1]=Core.compatibility.define({
    id="battle.background",label="BATTLE BACKGROUND",mode="exclusive",
    description="Choose which active mod owns the full battle background while preserving independent sprite providers.",
  })
  unregister[#unregister+1]=Core.compatibility.registerProvider({
    id="kanto_rework_ui.battle_background",capability="battle.background",
    source="ui",modId=suiteId,label="Kanto Rework Battle Backgrounds",priority=220,
    enabled=function() return mod.find("ui")~=nil end,
  })
  unregister[#unregister+1]=Core.compatibility.registerProvider({
    id="battle_art_voxel.background",capability="battle.background",
    source="BATTLE_ART_VOXEL_FORK",modId="BATTLE_ART_VOXEL_FORK",label="Battle Art Voxel Backgrounds",priority=180,
    enabled=function() return mod.find("BATTLE_ART_VOXEL_FORK")~=nil end,
  })

  unregister[#unregister+1]=Core.compatibility.define({
    id="pokemon.sprite_art",label="POKéMON SPRITES",mode="exclusive",
    description="Select the optional external Pokémon sprite provider used when Kanto Rework Graphics is set to EXTERNAL PROVIDER. KRS menu contexts retain their own Graphics asset families.",
  })
  unregister[#unregister+1]=Core.compatibility.registerProvider({
    id="gen1recomp.pokemon_sprites",capability="pokemon.sprite_art",source="gen1recomp",modId="gen1recomp",
    label="Gen 1 Sprites",priority=100,enabled=function() return true end,
  })
  unregister[#unregister+1]=Core.compatibility.registerProvider({
    id="battle_art_voxel.pokemon_sprites",capability="pokemon.sprite_art",source="BATTLE_ART_VOXEL_FORK",modId="BATTLE_ART_VOXEL_FORK",
    label="Battle Art Voxel Sprites",priority=220,
    enabled=function() return activeVoxelAdapter~=nil and (type(activeVoxelAdapter.supportsBattleArt)~="function" or activeVoxelAdapter.supportsBattleArt()) end,
  })
  unregister[#unregister+1]=Core.compatibility.define({
    id="audio.sfx",label="SOUND EFFECT PROVIDER",mode="exclusive",
    description="Choose the active provider when multiple installed mods replace the same sound-effect domain.",
  })
  unregister[#unregister+1]=Core.compatibility.define({
    id="audio.cries",label="POKéMON CRIES",mode="exclusive",
    description="Choose the active provider when multiple installed mods replace the same Pokémon cry domain.",
  })
  -- Known audio families are discovered at game.ready from their live runtime
  -- contracts (options + hook/registry ownership), never from exact versions.
  -- This lets compatible future releases keep working while refusing a renamed
  -- or incompatible implementation that no longer exposes the audited seam.

  local conflictCapabilities={
    "battle.background","pokemon.sprite_art","ui.shell","ui.party","bag.organization","field.actions",
    "move.relearn","battle.camera","pokemon.menu_icon","audio.music","audio.sfx","audio.cries",
  }
  local selfAdapter={id="kanto_rework_compat.conflicts",modId=suiteId,label="Kanto Rework Compatibility",version=RELEASE,priority=500}
  function selfAdapter.match(manifest) return manifest and tostring(manifest.id)==suiteId end
  function selfAdapter.decorateOptions(_,rows)
    local out={}
    for _,row in ipairs(rows or {}) do out[#out+1]=row end
    -- Sprite provider compatibility remains here, but user-facing battle
    -- scaling and Real Size are owned by Kanto Rework Graphics. Keeping those
    -- rows off Compatibility prevents two authorities from writing competing
    -- presentation state. The adapter's read-only legacy settings API remains
    -- available for older callers and stored profiles.
    for _,capability in ipairs(conflictCapabilities) do
      local resolution=Core.compatibility.resolve(capability)
      if resolution and resolution.mode=="exclusive" and #resolution.providers>1 then
        local definition=Core.compatibility.definition(capability) or {}
        local function fresh() return Core.compatibility.resolve(capability) end
        local function providerLabel(r)
          if not r then return "UNAVAILABLE" end
          for _,provider in ipairs(r.providers or {}) do
            if provider.id==r.selected then return tostring(provider.label or provider.id):upper() end
          end
          return "UNAVAILABLE"
        end
        out[#out+1]={
          id="__compat:"..capability,key="__compat:"..capability,
          label=tostring(definition.label or capability):upper(),type="choice",group="CONFLICT RESOLUTION",
          displayValue=providerLabel(resolution),value=resolution.selected,
          description=tostring(definition.description or ("Choose which active provider owns "..capability..".")),
          adjust=function(_,dir)
            local r=fresh();if not r or #r.providers<1 then return false,"no active provider" end
            -- resolve() moves the preferred provider to slot 1. Re-sort the
            -- active list by intrinsic priority so cycling three or more
            -- providers is stable rather than bouncing between two choices.
            local providers={};for _,provider in ipairs(r.providers) do providers[#providers+1]=provider end
            table.sort(providers,function(a,b)local ap,bp=tonumber(a.priority) or 0,tonumber(b.priority) or 0;if ap==bp then return tostring(a.id)<tostring(b.id) end;return ap>bp end)
            local current=1;for i,provider in ipairs(providers) do if provider.id==r.selected then current=i break end end
            local step=(tonumber(dir) or 1)<0 and -1 or 1
            local target=((current-1+step)%#providers)+1
            local ok,err=Core.compatibility.setPreference(capability,providers[target].id)
            if not ok then return false,err end
            return true,providerLabel(fresh())
          end,
        }
      end
    end
    return out
  end
  unregister[#unregister+1]=Core.modIntegrations.register(selfAdapter)
  do
    unregister[#unregister+1]=Core.modIntegrations.registerDiscovery(loadModule("auto_discovery.lua")())
  end
  local function activateAscendant(handle,manifest)
    if not handle or activeAscendantAdapter or not Contracts.isAscendant(handle,manifest) then return false end
    local contracts=Contracts.ascendantContracts(handle)
    if not (contracts.crystal or contracts.menu) then return false end
    activeAscendantAdapter=loadModule("adapters/kanto_ascendant_family.lua")({ascendant=handle,Core=Core,identityMatch=Contracts.isAscendant})
    activeAscendantId=tostring(handle.id or (manifest and manifest.id) or "trainer_rematch")
    unregister[#unregister+1]=Core.modIntegrations.register(activeAscendantAdapter)
    if contracts.crystal then
      registerDynamicProvider({
        id="kanto_ascendant.crystal_sprites",capability="pokemon.sprite_art",
        source=activeAscendantId,modId=activeAscendantId,label="Kanto Ascendant Crystal Sprites",priority=190,
        enabled=function()
          local live=mod.find(activeAscendantId)
          return live~=nil and Contracts.ascendantContracts(live).crystal
        end,
      })
    end
    return true
  end

  -- The current release still uses trainer_rematch.  The export contract is
  -- strong enough to avoid confusing the older Trainer Rematch mod with
  -- Ascendant even before game.ready gives us the full manifest identity.
  local bootstrapAscendant=mod.find("trainer_rematch")
  if bootstrapAscendant then activateAscendant(bootstrapAscendant,nil) end
  local voxel=mod.find("BATTLE_ART_VOXEL_FORK")
  local voxelVersion=voxel and tostring(voxel.version) or nil
  if voxel then
    local adapterFile=voxelVersion=="1.7.9"
      and "battle_art_voxel_1_7_9.lua" or "battle_art_voxel_family.lua"
    local adapter=loadModule("adapters/"..adapterFile)({voxel=voxel,findMod=mod.find,Core=Core,hooks=mod.hooks})
    activeVoxelAdapter=adapter
    unregister[#unregister+1]=Core.modIntegrations.register(adapter)
    if type(adapter.installPointerGuard)=="function"
        and (type(adapter.supportsInputBridge)~="function" or adapter.supportsInputBridge()) then
      unregister[#unregister+1]=adapter.installPointerGuard()
    end
  end

  local function scanRuntimeProviders(game)
    local loader=game and game.mods
    if type(loader)~="table" then return false end

    -- Full manifests are available now, so a future Ascendant id can be
    -- recognized by repository identity without any version lock.
    for id,entry in pairs(type(loader.mods)=="table" and loader.mods or {}) do
      local manifest=entry and entry.manifest or nil
      local handle=mod.find(id)
      if handle and Contracts.isAscendant(handle,manifest) then activateAscendant(handle,manifest) end
    end

    for id,entry in pairs(type(loader.mods)=="table" and loader.mods or {}) do
      local manifest=entry and entry.manifest or nil
      local handle=mod.find(id)
      local ownerId=id
      local ownerManifest=manifest
      if handle and Contracts.isSfxMusicReplacement(handle,manifest) then
        local contract=Contracts.sfxMusicContracts(game,handle,manifest)
        if contract.music then
          registerDynamicProvider({
            id="sfx_music_replacement.music",capability="audio.music",source=ownerId,modId=ownerId,
            label="SFX Music Replacement",priority=180,
            enabled=function()
              local live=mod.find(ownerId);return live~=nil and Contracts.sfxMusicContracts(game,live,ownerManifest).music
            end,
          })
        end
        if contract.sfx then
          registerDynamicProvider({
            id="sfx_music_replacement.sfx",capability="audio.sfx",source=ownerId,modId=ownerId,
            label="SFX Music Replacement",priority=180,
            enabled=function()
              local live=mod.find(ownerId);return live~=nil and Contracts.sfxMusicContracts(game,live,ownerManifest).sfx
            end,
          })
        end
      end
      if handle and Contracts.dynamicCriesContract(game,handle,manifest) then
        registerDynamicProvider({
          id="stadium_dynamic_cries",capability="audio.cries",source=ownerId,modId=ownerId,
          label=tostring(manifest and manifest.name or "Dynamic Cries"),priority=200,
          enabled=function()
            local live=mod.find(ownerId);return live~=nil and Contracts.dynamicCriesContract(game,live,ownerManifest)
          end,
        })
        -- 0.4.5 used a version-shaped provider id. Preserve an explicit user
        -- choice while migrating to the stable family id.
        local prefs=game and game.save and game.save.options
          and game.save.options.kantoReworkCapabilityPreferences
        if type(prefs)=="table" and prefs["audio.cries"]=="stadium_dynamic_cries.1_4_3" then
          Core.compatibility.setPreference("audio.cries","stadium_dynamic_cries")
        end
      end
    end

    -- Generic future Pokémon-art mods require no Compatibility release when
    -- they use the public pokemon.sprite hook.  The hook owner is authoritative
    -- provenance.  When selected, Compatibility executes only that owner's
    -- wrappers against an immutable Gen-I terminal fallback.
    local skip={
      [suiteId]=true,
      BATTLE_ART_VOXEL_FORK=true,
    }
    if activeAscendantId then skip[activeAscendantId]=true end
    for _,owner in ipairs(Contracts.hookOwners("pokemon.sprite")) do
      local hookOwner=owner
      if not skip[hookOwner] and mod.find(hookOwner) then
        local providerId="external_sprite."..Contracts.slug(hookOwner)
        if not externalSpriteProviders[providerId] then
          externalSpriteProviders[providerId]=hookOwner
          local _,manifest=Contracts.manifestEntry(game,hookOwner)
          registerDynamicProvider({
            id=providerId,capability="pokemon.sprite_art",source=hookOwner,modId=hookOwner,
            label=tostring(manifest and manifest.name or hookOwner).." Sprites",priority=170,
            enabled=function() return mod.find(hookOwner)~=nil and Contracts.hasHookOwner("pokemon.sprite",hookOwner) end,
          })
        end
      end
    end
    return true
  end

  unregister[#unregister+1]=mod.events:on("game.ready",function(payload)
    scanRuntimeProviders(payload and payload.game or mod.game)
  end)

  -- One provenance-driven global-options filter covers every mod using the
  -- standard options schema. A specialized adapter may additionally remove
  -- engine-owned controls (Voxel pipelines, for example), but no ordinary mod
  -- needs a new KRS release just because its version number or schema grows.
  unregister[#unregister+1]=mod.hooks:wrap("ui.options.rows",function(next,game,rows)
    local out=filterStandardModOptions(game,next(game,rows))
    if activeVoxelAdapter and type(activeVoxelAdapter.filterGlobalOptions)=="function" then
      out=activeVoxelAdapter.filterGlobalOptions(game,out)
    end
    return out
  end,1000)

  unregister[#unregister+1]=Core.compatibility.registerDiagnostic({
    id="trainer_rematch.duplicate_id",source=mod.id,severity="critical",
    scan=function(_,loaderErrors)
      for _,entry in ipairs(loaderErrors or {}) do
        local value=tostring(type(entry)=="table" and (entry.message or entry.error or entry.reason) or entry)
        if value:find("trainer_rematch: duplicate mod id",1,true) then
          return {{
            id="trainer_rematch.duplicate_id",severity="critical",
            message="Kanto Ascendant and Trainer Rematch both declare id trainer_rematch; Gen1Recomp ignores one package.",
            remediation="Use only one until Kanto Ascendant publishes a unique manifest id.",
          }}
        end
      end
      return {}
    end,
  })

  local function active(mods,id)
    for _,candidate in ipairs(mods or {}) do
      if candidate.id==id and candidate.enabled~=false
          and candidate.state~="failed" and candidate.state~="disabled" then
        return candidate
      end
    end
  end

  unregister[#unregister+1]=Core.compatibility.registerDiagnostic({
    id="useful_bag.kanto_bag_overlap",source=mod.id,severity="warning",
    scan=function(mods)
      if mod.find("gameplay") and active(mods,"useful_bag") then
        return {{
          id="useful_bag.kanto_bag_overlap",severity="warning",
          message="Useful Bag 2.4.1 and Kanto Rework Gameplay both organize and decorate the Bag.",
          remediation="Choose one pocket system; set Kanto Gameplay BAG POCKETS to OFF when using Useful Bag.",
        }}
      end
      return {}
    end,
  })

  unregister[#unregister+1]=Core.compatibility.registerDiagnostic({
    id="quality_of_life.field_interactions_overlap",source=mod.id,severity="warning",
    scan=function(mods)
      if mod.find("gameplay") and active(mods,"quality_of_life") then
        return {{
          id="quality_of_life.field_interactions_overlap",severity="warning",
          message="Quality of Life 1.2.7 Easy Interactions overlaps Kanto contextual Field Moves when both options are active.",
          remediation="Keep only one automatic field-interaction system enabled; the two mods may otherwise offer the same CUT, SURF, STRENGTH or FLASH action.",
        }}
      end
      return {}
    end,
  })

  local function spriteResolution()
    return Core.compatibility.resolve("pokemon.sprite_art")
  end
  local function selectedSpriteProvider()
    local r=spriteResolution();return r and r.selected or "gen1recomp.pokemon_sprites"
  end

  mod.exports.prepareBattleArt=function(battle,dt)
    if activeVoxelAdapter and type(activeVoxelAdapter.prepareBattleArt)=="function" then
      local selected=selectedSpriteProvider()
      local ok,value=pcall(activeVoxelAdapter.prepareBattleArt,battle,dt,{
        pokemonSprites=selected=="battle_art_voxel.pokemon_sprites"
      })
      return ok and value==true
    end
    return false
  end
  local function immutableGen1Art(game,species,side,source)
    local def=game and game.data and game.data.pokemon and game.data.pokemon[species]
    local path=def and (side=="back" and def.spriteBack or def.spriteFront) or nil
    if type(path)~="string" or path=="" then return nil end
    return {path=path,trueColor=def.trueColor==true,source=source or "gen1recomp.pokemon_sprites",
      providerFallback=true}
  end

  mod.exports.resolvePokemonArt=function(game,species,side,opts)
    side=side=="back" and "back" or "front"
    local selected=selectedSpriteProvider()

    -- Exclusive means exclusive. Once Compatibility says Voxel, Ascendant, or
    -- Gen 1 owns pokemon.sprite_art, a failed resolver is NOT permission for
    -- Core to run the global pokemon.sprite hook chain. That chain may contain
    -- a different active sprite mod (notably Kanto Ascendant), which is how a
    -- selected Voxel provider silently reverted to Crystal art in 0.4.3/0.4.4.
    -- Each selected provider gets one neutral Gen-I terminal fallback instead.
    if selected=="battle_art_voxel.pokemon_sprites" then
      if activeVoxelAdapter and type(activeVoxelAdapter.resolvePokemonArtImage)=="function" then
        local ok,value=pcall(activeVoxelAdapter.resolvePokemonArtImage,game,species,side,opts)
        if ok and type(value)=="table" and (value.image or value.path or value.frames) then
          value.source=value.source or "battle_art_voxel.pokemon_sprites"
          return value
        end
      end
      return immutableGen1Art(game,species,side,"battle_art_voxel.pokemon_sprites:rom_fallback")
    end

    if selected=="kanto_ascendant.crystal_sprites" then
      if activeAscendantAdapter and type(activeAscendantAdapter.resolvePokemonArtImage)=="function" then
        local ok,value=pcall(activeAscendantAdapter.resolvePokemonArtImage,game,species,side,opts)
        if ok and type(value)=="table" and (value.image or value.path or value.frames) then
          value.source=value.source or "kanto_ascendant.crystal_sprites"
          return value
        end
      end
      return immutableGen1Art(game,species,side,"kanto_ascendant.crystal_sprites:rom_fallback")
    end

    local externalOwner=externalSpriteProviders[selected]
    if externalOwner then
      local fallback=immutableGen1Art(game,species,side,selected..":rom_fallback")
      if not fallback then return nil end
      local ctx={species=species,side=side,kind=type(opts)=="table" and opts.kind or "kanto_rework_menu",
        mon=type(opts)=="table" and opts.mon or nil,data=game and game.data,trueColor=fallback.trueColor==true}
      local ok,path=pcall(Contracts.callOwnedPokemonSprite,externalOwner,fallback.path,ctx)
      if ok and type(path)=="string" and path~="" then
        return {path=path,trueColor=ctx.trueColor==true,source=selected}
      end
      return fallback
    end

    return immutableGen1Art(game,species,side,"gen1recomp.pokemon_sprites")
  end
  mod.exports.pokemonVisualPolicy=function()
    local r=spriteResolution()
    return {provider=selectedSpriteProvider(),providers=r and r.providers or {}}
  end
  mod.exports.battleArtMetrics=function(image)
    if activeVoxelAdapter and type(activeVoxelAdapter.battleArtMetrics)=="function" then
      local ok,value=pcall(activeVoxelAdapter.battleArtMetrics,image)
      if ok then return value end
    end
    return nil
  end
  mod.exports.voxelBattleArtPresentation=function(game)
    if activeVoxelAdapter and type(activeVoxelAdapter.presentationSettings)=="function" then
      local ok,value=pcall(activeVoxelAdapter.presentationSettings,game or mod.game)
      if ok and type(value)=="table" then return value end
    end
    return {upscale="default",pixelScale=1,realSize="auto",nativePixels=true}
  end
  mod.exports.battleVisualPolicy=function(game,battle)
    local resolution=Core.compatibility.resolve("battle.background")
    local selected=resolution and resolution.selected or "kanto_rework_ui.battle_background"
    -- Background ownership is a live capability, not an installation choice.
    -- DramaticShape's public OverworldBattle.battle() seam names the exact
    -- BattleState for which its staged 3D environment exists. That session is
    -- exclusive and always wins for that one fight. When it is absent/stale,
    -- KRS backgrounds immediately resume without touching options or save data.
    local voxelOwns=false
    local environment={owns=false,reason="voxel_adapter_unavailable"}
    if activeVoxelAdapter and type(activeVoxelAdapter.battleEnvironmentStatus)=="function" then
      local ok,value=pcall(activeVoxelAdapter.battleEnvironmentStatus,battle)
      if ok and type(value)=="table" then environment=value;voxelOwns=value.owns==true end
    elseif activeVoxelAdapter and type(activeVoxelAdapter.ownsBattleEnvironment)=="function" then
      local ok,value=pcall(activeVoxelAdapter.ownsBattleEnvironment,battle)
      voxelOwns=ok and value==true;environment={owns=voxelOwns,reason=voxelOwns and "legacy_live_3d_battle" or "legacy_not_active"}
    end
    local provider=voxelOwns and "battle_art_voxel.background"
      or "kanto_rework_ui.battle_background"
    return {
      backgroundOwner=voxelOwns and "voxel" or "krs",
      provider=provider,
      selectedProvider=selected,
      exclusive=voxelOwns,
      voxelEnvironment=environment,
      spriteProvider=selectedSpriteProvider(),
      mode=battle and type(battle.bgMode)=="function" and battle:bgMode() or nil,
    }
  end

  mod.exports.version=EXPORT_API
  mod.exports.release=RELEASE
  mod.exports.scanRuntimeProviders=scanRuntimeProviders
  mod.exports.rules={
    auditedAt="2026-08-16",
    gen1online={id="gen1online-gamecorner",version="0.3.4.1",tag="v.3.4.1.1",status="load_verified"},
    trainerRematchCollision={id="trainer_rematch",status="critical"},
    usefulBag={id="useful_bag",version="2.4.1",status="choose_one_bag_provider"},
    qualityOfLife={id="quality_of_life",version="1.2.7",status="avoid_duplicate_field_interactions"},
    kantoAscendant={id="trainer_rematch",latestAudited="6.0.11",github="Roxas2712/kanto-ascendant",status="contract_family_ui_and_art_adapter",
      familyPolicy="repository/id identity plus live Ascendant exports; version is diagnostic only"},
    dynamicCries={github="Lockerz102/Stadium-Cries",latestAudited="1.4.3",tag="Pokemon",commit="8eaf15c409420c9a9aef0cad2bf2f4d2e598fcdd",status="contract_family_cry_provider",
      familyPolicy="repository identity plus live cry-registry ownership; version is diagnostic only"},
    sfxMusicReplacement={id="SFXMusicReplacementMod",github="AlucardTheFirstHunter/MusicReplacementMod",latestAudited="2.0.0",status="contract_family_audio_provider",
      familyPolicy="stable identity plus standard options, music.select hook and audio-registry ownership; version is diagnostic only"},
    battleArtVoxel={id="BATTLE_ART_VOXEL_FORK",version=voxelVersion or "not_loaded",latestAudited="1.9.2",tag="1.9.2",commit="55b4d6bd537e66e3c13d4717e3020ce167316423",status="contract_gated_options_pointer_field_move_battle_art_animation_metrics_and_background_ownership",
      familyPolicy="standard options and stable capability ownership survive version-only updates; behavioral seams are enabled only when their runtime contract is present",
      previous={{version="1.8.6",tag="1.8.6",commit="0649420f5e1fe5a3344f5d6b95c04f1ec012fc4f"},{version="1.8.5",tag="1.8.5",commit="bbd9f124dfb68c78a80a591a1d6f30e87e3cc24e"},{version="1.8.4",tag="1.8.4",commit="aa80239e3ef186a8e46a37577922845931ccb7cb"},{version="1.8.3",tag="1.8.3",commit="12d142a56f5c238767ac2766057ba845e35bb5c2"},{version="1.7.9",tag="1.7.9",commit="791bebc34095f49dfa157466d8d050efbb4b0e3f"}}},
  }
  mod.exports.unregister=function()
    local changed=false
    for i=#unregister,1,-1 do local fn=unregister[i];if fn then changed=fn() or changed end end
    unregister={};return changed
  end
  mod.log:info("Kanto Rework Compatibility %s loaded: native Voxel sprite arbitration, Graphics-owned presentation controls and capability routing active",RELEASE)
end
