-- Shop integration for Kanto Rework's Expanded Bag and pocket model.
-- Keeps native Shop callbacks/QuantityBox/ChoiceBox semantics and only adapts
-- the two mismatches left by the stock 0.1.76 implementation.
return function(deps)
  local mod=assert(deps.mod)
  local bagPockets=assert(deps.bagPockets)
  local expandedEnabled=assert(deps.expandedEnabled)
  local pocketsEnabled=assert(deps.pocketsEnabled)
  local ListMenu=require('src.ui.ListMenu')
  local QuantityBox=require('src.ui.QuantityBox')
  local state={installed=false}

  if not _G.__KRS_SHOP_INTEGRATION_030 then
    _G.__KRS_SHOP_INTEGRATION_030={
      listNew=ListMenu.new,
      quantityNew=QuantityBox.new,
    }
  end
  local originals=_G.__KRS_SHOP_INTEGRATION_030

  ListMenu.new=function(game,title,items,opts)
    local list=originals.listNew(game,title,items,opts)
    if title=='SELL' then
      list.kind='shop_sell'
      if pocketsEnabled() then bagPockets.decorate(game,list,true) end
    elseif title=='BUY' then
      list.kind='shop_buy'
      if expandedEnabled() and type(list.onChoose)=='function' then
        local base=list.onChoose
        list.onChoose=function(item,l,...)
          local id=item and item.value
          if id and game.save and game.save.inventory and (game.save.inventory[id] or 0)>=999 then
            list.footer="You can't carry\nany more items."
            return
          end
          return base(item,l,...)
        end
      end
    end
    return list
  end

  QuantityBox.new=function(game,opts)
    opts=opts or {}
    local top=game and game.stack and game.stack.top and game.stack:top()
    if expandedEnabled() and top and top.kind=='shop_buy' then
      local item=top.items and top.items[top.index]
      local id=item and item.value
      local price=math.max(1,tonumber(opts.unitPrice) or 1)
      if id then
        local owned=(game.save.inventory and game.save.inventory[id]) or 0
        local affordable=math.floor((tonumber(game.save.money) or 0)/price)
        opts.max=math.max(1,math.min(999-owned,affordable,999))
      end
    end
    return originals.quantityNew(game,opts)
  end

  state.installed=true
  state.status=function() return {installed=true,buyLimit=expandedEnabled() and 999 or 99,sellPockets=pocketsEnabled()} end
  return state
end
