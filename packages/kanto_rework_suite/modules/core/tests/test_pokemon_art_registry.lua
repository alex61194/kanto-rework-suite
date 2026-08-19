local root=assert(arg[1],"root path required")
local factory=assert(loadfile(root.."/core/mod_integration_registry.lua"))()
local registry=factory()

local fallback={path="gen1/pikachu.png",trueColor=false,source="gen1recomp"}
registry.register({id="pass",modId="pass",priority=200,
  resolvePokemonArt=function(_,_,current)return current end})
registry.register({id="claim",modId="claim",priority=100,
  resolvePokemonArt=function(_,request)return{path="crystal/"..request.species..".png",trueColor=true,source="fixture"}end})

local result=registry.resolvePokemonArt({}, {species="PIKACHU",side="front"}, fallback)
assert(result~=fallback,"a lower-priority explicit provider must run after a pass-through adapter")
assert(result.path=="crystal/PIKACHU.png","provider path")
assert(result.trueColor==true,"provider true-color flag")
assert(result.source=="fixture","provider source")
assert(registry.status().pokemonArtResolver==true,"resolver capability status")
print("Core Pokémon-art registry priority and fallback tests passed")
