-- Kanto Rework expanded Pokémon storage target: 20 boxes × 180 Pokémon.
-- This deliberately patches the engine's central Boxes module rather than
-- changing the serialized mon shape. Existing boxes are preserved and new
-- boxes are appended lazily by Boxes.ensure.
return function(deps)
  local Boxes=require('src.pokemon.Boxes')
  local TARGET_COUNT=20
  local TARGET_CAPACITY=180
  local originalEnsure=Boxes.ensure
  local state={installed=false,count=TARGET_COUNT,capacity=TARGET_CAPACITY}

  Boxes.COUNT=TARGET_COUNT
  Boxes.CAPACITY=TARGET_CAPACITY
  Boxes.ensure=function(save)
    local boxes=originalEnsure(save)
    boxes=save.boxes or boxes or {}
    for i=1,TARGET_COUNT do
      if type(boxes[i])~='table' then boxes[i]={} end
    end
    save.boxes=boxes
    save.currentBox=math.max(1,math.min(TARGET_COUNT,tonumber(save.currentBox) or 1))
    return boxes
  end
  state.installed=true
  state.ensure=function(save) return Boxes.ensure(save) end
  state.status=function(save)
    local boxes=save and Boxes.ensure(save) or nil
    local total=0
    if boxes then for i=1,TARGET_COUNT do total=total+#boxes[i] end end
    return {installed=true,count=TARGET_COUNT,capacity=TARGET_CAPACITY,total=total,maxTotal=TARGET_COUNT*TARGET_CAPACITY}
  end
  return state
end
