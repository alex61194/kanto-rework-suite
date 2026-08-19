-- Player's PC integration with the validated KRS Bag organisation.
-- Only DEPOSIT ITEM consumes Bag pockets/sort/favorites because its source is
-- the live Bag inventory. Withdraw/Toss remain PC-storage lists.
return function(deps)
  local bagPockets=assert(deps.bagPockets)
  local pocketsEnabled=assert(deps.pocketsEnabled)
  local ListMenu=require('src.ui.ListMenu')
  if not _G.__KRS_PC_ITEM_INTEGRATION_030 then
    _G.__KRS_PC_ITEM_INTEGRATION_030={listNew=ListMenu.new}
  end
  local base=_G.__KRS_PC_ITEM_INTEGRATION_030.listNew
  local function wrapped(game,title,items,opts)
    local list=base(game,title,items,opts)
    if title=='DEPOSIT ITEM' or list.kind=='pc_item_deposit' then
      list.kind='pc_item_deposit'
      if pocketsEnabled() then bagPockets.decorate(game,list,true) end
    elseif title=='WITHDRAW ITEM' then list.kind='pc_item_withdraw'
    elseif title=='TOSS ITEM' then list.kind='pc_item_toss' end
    return list
  end
  ListMenu.new=wrapped
  return {
    installed=true,
    status=function() return {installed=true,depositUsesBagPockets=pocketsEnabled()} end,
    uninstall=function() if ListMenu.new==wrapped then ListMenu.new=base end end,
  }
end
