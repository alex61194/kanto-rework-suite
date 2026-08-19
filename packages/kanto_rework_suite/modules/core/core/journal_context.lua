-- Shared non-visual context shown by Kanto Journal headers.
return function(deps)
  local runtime=assert(deps.runtime,"runtime is required")
  local service={}
  function service.model(game)
    game=game or runtime.game;if not game then return {location="KANTO",playTime=0} end
    local save=game.save or {};local player=save.player or {};local map=game.overworld and game.overworld.map;local name
    if type(map)=="table" then name=map.name or map.displayName or (map.def and map.def.name) or map.id end
    if not name and player.map and game.data and game.data.maps then local d=game.data.maps[player.map];name=d and d.name or player.map end
    local objective=save.objective or player.objective
    if type(objective)=="table" then objective=objective.label or objective.text or objective.description end
    if type(objective)~="string" or objective=="" then objective="Continue your journey through Kanto." end
    return {location=tostring(name or "KANTO"),playTime=math.max(0,math.floor(tonumber(save.playTime) or 0)),objective=objective}
  end
  return service
end
