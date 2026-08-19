local root=assert(arg[1],"root path required")
local frameIndex=1
local released=0
package.preload["src.render.PaletteFX"]=function() return {markTrueColor=function() end} end
local image={setFilter=function() end,getDimensions=function() return 800,800 end}
local currentCanvas=nil
love={
  timer={getTime=function() return frameIndex/1000 end},
  graphics={
    newImage=function() return image end,
    newCanvas=function(w,h)
      return {w=w,h=h,setFilter=function() end,release=function() released=released+1 end}
    end,
    newQuad=function() return {} end,
    getCanvas=function() return currentCanvas end,
    setCanvas=function(c) currentCanvas=c end,
    clear=function() end,
    getBlendMode=function() return "alpha",nil end,
    setBlendMode=function() end,
    getColor=function() return 1,1,1,1 end,
    setColor=function() end,
    getShader=function() return nil end,
    setShader=function() end,
    getScissor=function() return nil end,
    setScissor=function() end,
    draw=function() end,
  }
}
local Core={resolvePokemonArt=function()
  return "atlas.png",true,"kanto_rework_graphics",{atlas={
    path="atlas.png",frameWidth=40,frameHeight=40,columns=20,frameCount=100,frameIndex=frameIndex,
  }}
end}
local service=assert(loadfile(root.."/runtime/pokemon_art.lua"))()({Core=Core,mod={find=function() return nil end}})
assert(service.atlasFrameLimit==32,"rolling GPU atlas cache must stay bounded at 32 frames")
for i=1,100 do
  frameIndex=i
  local art=assert(service:image({},"CHARIZARD","front",{}),"atlas frame should materialize")
  assert(art.metrics and art.metrics.frame==i,"selected atlas frame must stay exact")
  assert(#service.atlasFrameOrder<=32,"atlas cache order exceeded limit")
end
local count=0 for _ in pairs(service.atlasFrames) do count=count+1 end
assert(count==32,"only the rolling 32-frame window should remain cached")
assert(released==0,"rolling eviction must not explicitly release canvases that a live draw may still reference")
service:invalidate()
assert(released==32,"invalidate must explicitly release only the canvases still owned by the cache")
print("KRS bounded animated-atlas GPU cache tests passed")
