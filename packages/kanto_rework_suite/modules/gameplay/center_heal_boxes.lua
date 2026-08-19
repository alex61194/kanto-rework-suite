-- Pokémon Center storage healing.
--
-- Gen1Recomp's nurse flow heals the active party with Pokemon.heal(), then
-- creates OverworldState.healAnim.  stepHealAnim is therefore the narrowest
-- center-only seam that runs only after the player accepted Nurse Joy's heal
-- and before the machine sequence completes.  KRS extends that same heal to
-- every stored Pokémon, using the engine's own Boxes.ensure and Pokemon.heal
-- rather than duplicating HP/status/PP rules.
return function(deps)
  local Game=assert(deps and deps.Game,"Game required")
  local OverworldState=require("src.world.OverworldController")
  local Boxes=require("src.pokemon.Boxes")
  local Pokemon=require("src.pokemon.Pokemon")
  local original=OverworldState.stepHealAnim
  assert(type(original)=="function","OverworldState.stepHealAnim is required")

  local installed=true
  local healedMons=0
  local healRuns=0

  local function healStored(save)
    if type(save)~="table" then return 0 end
    local boxes=Boxes.ensure(save)
    local count=0
    for _,box in ipairs(boxes or {}) do
      if type(box)=="table" then
        for _,mon in ipairs(box) do
          if type(mon)=="table" then
            Pokemon.heal(mon)
            count=count+1
          end
        end
      end
    end
    return count
  end

  local function krsStepHealAnim(ha)
    -- healAnim is a transient machine-animation record.  Marking it avoids
    -- re-healing the boxes on every animation frame and writes nothing into
    -- the serialized save beyond the Pokémon fields the official heal mutates.
    if installed and type(ha)=="table" and not ha.krsBoxesHealed then
      ha.krsBoxesHealed=true
      local count=healStored(Game.save)
      healedMons=healedMons+count
      healRuns=healRuns+1
    end
    return original(ha)
  end

  OverworldState.stepHealAnim=krsStepHealAnim

  return {
    healStored=healStored,
    status=function()
      return {installed=installed,centerOnly=true,healRuns=healRuns,healedMons=healedMons,
        adapter="OverworldState.stepHealAnim",routine="Pokemon.heal + Boxes.ensure"}
    end,
    uninstall=function()
      if not installed then return false end
      installed=false
      if OverworldState.stepHealAnim==krsStepHealAnim then
        OverworldState.stepHealAnim=original
        return true
      end
      return false
    end,
  }
end
