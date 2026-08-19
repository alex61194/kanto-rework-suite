-- Generic provenance bridge for standard Start Menu extensions.
-- It instruments the one real ui.start_menu.items call, preserving the
-- engine's hook order and callbacks while recording which mod introduced each
-- final item. No label, mod id, or release-specific heuristic is used.
return function()
  local owners=setmetatable({},{__mode="k"})
  local unpack=table.unpack or unpack
  local function pack(...) return {n=select("#",...),...} end

  local provider={id="gen1recomp.start_menu.provenance.v1"}

  function provider.capture(game,factory)
    local Runtime=require("src.mods.Runtime")
    local hooks=Runtime and Runtime.hooks
    local chain=hooks and hooks.chains and hooks.chains["ui.start_menu.items"]
    if type(chain)~="table" or #chain==0 then return factory() end

    local originals={}
    for i,entry in ipairs(chain) do
      originals[i]=entry.callback
      local original=entry.callback
      entry.callback=function(nextFn,...)
        local args=pack(...);local input=args[2];local before={}
        if type(input)=="table" then for _,item in ipairs(input) do before[item]=true end end
        local result=pack(original(nextFn,unpack(args,1,args.n)))
        local output=result[1]
        if type(output)=="table" then
          for _,item in ipairs(output) do
            if type(item)=="table" and not before[item] and owners[item]==nil then owners[item]=entry.owner end
          end
        end
        return unpack(result,1,result.n)
      end
    end

    local result=pack(xpcall(factory,tostring))
    for i,entry in ipairs(chain) do if originals[i] then entry.callback=originals[i] end end
    if not result[1] then error(result[2],0) end
    return unpack(result,2,result.n)
  end

  function provider:ownerOf(_,item) return owners[item] end
  return provider
end
