-- Kanto Rework Battle Animations
-- Gen1Recomp 0.1.80 / Mod API 2
return function(mod)
  mod.options:define({
    {key="attack_animations",label="KRS ATTACK ANIMATIONS",type="toggle",default=true,group="BATTLE VISUALS",
      description="Use the KRS Gen 3–9 move-animation bridge. When disabled, new moves use Gen1Recomp's native animation path."},
  })

  local function loadLocal(path)
    local src = assert(mod:read(path), "unable to read " .. path)
    local chunk, err = loadstring(src, "@" .. mod.path .. "/" .. path)
    assert(chunk, err)
    return chunk()
  end

  local data = loadLocal("data/gen1_anims.lua")

  for id, file in pairs(data.sfx or {}) do
    mod.content.sfx:register(id, { file = mod.assets:path("assets/sfx/" .. file) })
  end

  local installer = loadLocal("scripts/essentials_player.lua")
  installer(mod, data)

  mod.exports.coverage = 165
  mod.exports.source = "Gen 9 Move Animation Project / PkmnAnimations.rxdata"
  mod.exports.enabled = function() return mod.options:get("attack_animations") ~= false end
  mod.exports.status = function() return {installed=true,enabled=mod.options:get("attack_animations") ~= false,coverage=165,layering="KRS_BG -> KRS_POKEMON -> ANIM_BACK -> ANIM_FRONT -> KRS_HUD -> KRS_CHROME"} end
  mod.log:info("installed Essentials move animation bridge (%d Gen 1 moves)", 165)
end
