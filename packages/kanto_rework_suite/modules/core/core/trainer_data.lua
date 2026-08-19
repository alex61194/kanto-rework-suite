-- Runtime trainer/progression model for presentation modules.
-- No drawing occurs here; asset paths and ownership metadata are returned as data.
return function(deps)
  local runtime=assert(deps.runtime,"runtime is required")
  local service={}
  local function countSet(t) local n=0;for _ in pairs(t or {}) do n=n+1 end;return n end
  local function safeRequire(name) local ok,v=pcall(require,name);return ok and v or nil end

  function service.model(game)
    game=game or runtime.game
    if not game then return nil end
    local save=game.save or {};local dex=save.pokedex or {};local player=save.player or {}
    local spritePath,trueColor,portraitMeta
    if runtime.graphicsRegistry and type(runtime.graphicsRegistry.resolve)=="function" then
      local owned=runtime.graphicsRegistry.resolve("player.presentation.front",{
        game=game,data=game.data,player=player,kind="trainer_card",
        version=game.version or (game.data and game.data.version),
      },nil)
      if type(owned)=="table" and (owned.path or owned.image) then
        spritePath=owned.path;trueColor=owned.trueColor==true;portraitMeta=owned
      end
    end
    local Sprites=safeRequire("src.pokemon.Sprites")
    if not spritePath and Sprites and Sprites.playerPath then
      local ok,p,tc=pcall(Sprites.playerPath,game.data,"front",{kind="trainer_card"})
      if ok then spritePath,trueColor=p,tc==true end
    end
    local ownedBadges={};local badgeCount=0
    local Badges=safeRequire("src.inventory.Badges")
    if Badges and Badges.list and Badges.itemFor then
      local ok,list=pcall(Badges.list,game.data)
      if ok and type(list)=="table" then
        for i,badge in ipairs(list) do
          local okItem,item=pcall(Badges.itemFor,badge)
          local owned=okItem and item and save.inventory and save.inventory[item]~=nil or false
          ownedBadges[i]=owned;if owned then badgeCount=badgeCount+1 end
        end
      end
    end
    return {
      name=player.name or "RED", id=player.id, money=save.money or 0, playTime=math.floor(save.playTime or 0), partyCount=#(type(save.party)=="table" and save.party or {}),
      pokedex={seen=countSet(dex.seen),owned=countSet(dex.owned)},
      badges={owned=ownedBadges,count=badgeCount,sheetPath="assets/generated/trainer_card/badges.png"},
      portrait={path=spritePath,trueColor=trueColor==true,meta=portraitMeta},
    }
  end
  return service
end
