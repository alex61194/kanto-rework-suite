local root=assert(arg[1],"root path required")
local now=0
local loaded={}
package.preload["src.render.PaletteFX"]=function()return{markTrueColor=function()end}end
love={timer={getTime=function()return now end},graphics={newImage=function(path)
  loaded[path]=(loaded[path] or 0)+1
  return{path=path,setFilter=function()end}
end}}
local Core={resolvePokemonArt=function()
  return "crystal/001.png",true,"kanto_ascendant.crystal",{animation={
    frames={"crystal/001.png","crystal/002.png","crystal/003.png"},durations={80,120,100},loop=true,
  }}
end}
local service=assert(loadfile(root.."/runtime/pokemon_art.lua"))()({Core=Core,mod={find=function() return nil end}})
now=.05;assert(service:image({},"PIKACHU","front",{}).path=="crystal/001.png","first timed frame")
now=.10;assert(service:image({},"PIKACHU","front",{}).path=="crystal/002.png","second timed frame")
now=.25;assert(service:image({},"PIKACHU","front",{}).path=="crystal/003.png","third timed frame")
now=.35;assert(service:image({},"PIKACHU","front",{}).path=="crystal/001.png","looped timed frame")
assert(loaded["crystal/001.png"]==1,"frame cache by final path")
print("KRS timed Pokémon-art animation and frame-cache tests passed")
