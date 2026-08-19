local root=assert(arg[1],"root path required")
local function check(value,label) if not value then error(label or "check failed",2) end end

package.preload["src.pokemon.Sprites"]=function()
  return {iconPath=function(_,_,path) return path end}
end
package.preload["src.render.Assets"]=function()
  return {resolve=function(path) return path end}
end
package.preload["src.render.PaletteFX"]=function()
  return {markTrueColor=function() end}
end
package.preload["src.core.Sound"]=function()
  return {play=function() end,playCry=function() end}
end

local fakeImage={}
function fakeImage:getDimensions() return 1920,1080 end
function fakeImage:setFilter() end

love={graphics={}}
local g=love.graphics
for _,name in ipairs({"setColor","setLineWidth","circle","push","origin","pop","setScissor","draw","rectangle","line"}) do
  g[name]=function() end
end
g.getScissor=function() return nil end
g.newImage=function() return fakeImage end
g.newQuad=function() return {} end

local reachedAreaPanel=false
local areaPanelRadius
local footerText={}
local removedFieldRecordsTextRendered=false
local Draw={}
for _,name in ipairs({"roundRect","line","clipText"}) do Draw[name]=function() end end
Draw.text=function(_,_,value,x,y)
  if value=="Field records confirm this species in each listed habitat." then
    removedFieldRecordsTextRendered=true
  end
  if y==1037 or y==1038 then footerText[value]={x=x,y=y} end
end
Draw.panel=function(_,x,y,w,h,radius)
  if x==1312 and y==88 and w==608 and h==928 then
    reachedAreaPanel=true
    areaPanelRadius=radius
  end
end

local colors={
  canvas={1,1,1,1},inverse={0,0,0,1},panel={1,1,1,1},elevated={1,1,1,1},
  border={.8,.8,.8,1},borderStrong={.5,.5,.5,1},focus={0,.4,.5,1},
  text={0,0,0,1},textSecondary={.4,.4,.4,1},textInverse={1,1,1,1},
  faint={.6,.6,.6,1},disabled={.7,.7,.7,1},typeColors={ELECTRIC={1,.8,0,1}},
}
local runtime={assetPath=function(relative) return root.."/"..relative end,
  mod={path=root},Draw=Draw,PokemonName=function(name) return name end,
  Core={journalContext=function() return {location="SAFFRON CITY",playTime=1793} end},
  Layout={isWide=function() return true end,metrics=function() return {scale=1,ox=0,oy=0} end},
  Theme={resolveAll=function() return colors end},
  PokemonArt={image=function() return nil end},
  TypeChip={draw=function() end},TypeIcon={draw=function() end},
}
local screen={
  kind="krs_pokedex",view="area",status="caught",index=25,species="PIKACHU",
  entry={id="PIKACHU",def={name="PIKACHU",types={"ELECTRIC"}}},
  area={nests={{name="VIRIDIAN FOREST"}}},areaIndex=1,areaScale=1.12,
  areaPanX=-200,areaPanY=0,max=151,seen=1,caught=1,dex={},oakOpen=false,
}
function screen:areaViewport() return {x=0,y=88,w=1312,h=928} end
function screen:areaMapPoint(x,y) return self.areaPanX+x*self.areaScale,self.areaPanY+y*self.areaScale end
local game={
  stack={top=function() return screen end},save={pokedex={seen={PIKACHU=true},owned={PIKACHU=true}}},
  data={pokemon={PIKACHU={name="PIKACHU",dex=25,types={"ELECTRIC"},icon="PIKACHU"}},icons={icons={PIKACHU="icon.png"},bySpecies={PIKACHU="PIKACHU"}}},
}

local factory=assert(loadfile(root.."/ui/pokedex_presenter.lua"))()
local presenter=factory(runtime)
local ok,err=presenter.draw(game,{width=1920,height=1080})
check(ok==true,"AREA presenter must complete: "..tostring(err))
check(reachedAreaPanel,"AREA presenter must fill the complete right-hand column")
check(areaPanelRadius==0,"AREA outer card must have square corners")
check(not removedFieldRecordsTextRendered,"AREA must not render the redundant field-records sentence")
check(footerText.ARROWS and footerText.HABITATS,"AREA footer prompts must render")
check(footerText.HABITATS.x-footerText.ARROWS.x==72,"ARROWS and HABITATS must keep their dedicated spacing")
print("Pokédex AREA presenter render-completion test passed")
