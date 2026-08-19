local root=assert(arg[1],"root path required")
local external=false
local selected=setmetatable({},{__mode="k"})
local ascendant={id="trainer_rematch",version="6.0.11",exports={
  crystalAnimation={
    selected=selected,
    externalKantoActive=function()return external end,
    staticFrameOne=function(ctx,side,variant)
      assert(side=="front" or side=="back","supported side")
      return "crystal/"..ctx.species.."/"..side.."/"..variant.."/001.png"
    end,
    select=function(ctx)
      selected[ctx.mon]={durations={80,120,100}}
      return "crystal/"..ctx.species.."/"..(ctx.mon.shiny and "shiny" or "normal").."/001.png"
    end,
  },
  shinySystem={isShiny=function(mon)return mon and mon.shiny==true end},
}}
local factory=assert(loadfile(root.."/adapters/kanto_ascendant_family.lua"))()
local adapter=factory({ascendant=ascendant})
local game={mods={modOptions={trainer_rematch={kanto_crystal_art=true,legend_art="crystal"}}},data={pokemon={
  PIKACHU={dex=25},CHIKORITA={dex=152},
}}}
local fallback={path="gen1.png",trueColor=false,source="gen1recomp"}

local art=adapter.resolvePokemonArt(game,{species="PIKACHU",side="front",mon={shiny=true}},fallback)
assert(art~=fallback and art.path=="crystal/PIKACHU/front/shiny/001.png","Kanto shiny Crystal art")
assert(art.trueColor==true and art.source=="kanto_ascendant.crystal_sprites","Ascendant provider metadata")
assert(art.animation and #art.animation.frames==3 and art.animation.frames[3]:match("003%.png$"),"menu animation descriptor")

game.mods.modOptions.trainer_rematch.kanto_crystal_art=false
assert(adapter.resolvePokemonArt(game,{species="PIKACHU",side="front"},fallback)==fallback,"disabled Kanto art preserves engine fallback")
game.mods.modOptions.trainer_rematch.kanto_crystal_art=true;external=true
assert(adapter.resolvePokemonArt(game,{species="PIKACHU",side="front"},fallback)==fallback,"external Kanto visual provider retains ownership")
external=false

local johto=adapter.resolvePokemonArt(game,{species="CHIKORITA",side="front"},fallback)
assert(johto.path=="crystal/CHIKORITA/front/normal/001.png","Johto Crystal art")
game.mods.modOptions.trainer_rematch.legend_art="original"
assert(adapter.resolvePokemonArt(game,{species="CHIKORITA",side="front"},fallback)==fallback,"Johto original-art preference")
local back=adapter.resolvePokemonArt(game,{species="PIKACHU",side="back"},fallback)
assert(back~=fallback and back.path=="crystal/PIKACHU/back/normal/001.png","selected Ascendant provider supplies back sprites too")
print("Kanto Ascendant contract-family Pokémon-art adapter tests passed")
