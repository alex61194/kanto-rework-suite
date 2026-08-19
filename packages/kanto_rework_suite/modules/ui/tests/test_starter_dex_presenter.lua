local root=assert(arg[1],"UI root required")
local DexEntryMenu={};DexEntryMenu.__index=DexEntryMenu
package.preload["src.ui.DexEntryMenu"]=function() return DexEntryMenu end
package.preload["src.pokemon.Sprites"]=function() return {} end
package.preload["src.render.Assets"]=function() return {} end
package.preload["src.render.PaletteFX"]=function() return {} end
package.preload["src.core.Sound"]=function() return {} end
local runtime={}
local factory=assert(loadfile(root.."/ui/pokedex_presenter.lua"))()
local presenter=factory(runtime)
local native=setmetatable({def={id="BULBASAUR",dex=1},forceOwned=true},DexEntryMenu)
assert(presenter.handles({},native)==true,"native starter DexEntry is presented by KRS")
assert(presenter.handles({}, {kind="krs_pokedex"})==true,"KRS Pokédex remains handled")
assert(presenter.handles({}, {kind="main"})==false,"unrelated menus remain outside the presenter")
local game={save={pokedex={owned={},seen={}}}}
local first=presenter._nativeEntryState(game,native)
local second=presenter._nativeEntryState(game,native)
assert(first==second,"native starter presentation state stays stable across redraws")
assert(first.mon==second.mon,"animated provider receives the same synthetic Pokémon identity")
assert(first.mon.species=="BULBASAUR" and first.artKind=="starter_preview","starter preview semantics preserved")
print("Starter DexEntry presentation routing tests passed")
