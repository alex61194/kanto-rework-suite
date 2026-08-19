local root=assert(arg[1],"root path required")
-- 1.8.3 and every later contract-compatible release route through the live
-- family adapter in Compatibility main.lua.
local factory=assert(loadfile(root.."/adapters/battle_art_voxel_family.lua"))()
local fakeTime=100
love={
  timer={getTime=function() return fakeTime end},
  filesystem={getInfo=function(path) return tostring(path):find('/front%-animated/gen5/shiny/',1,false) and {type='file'} or nil end},
  image={newImageData=function(a,b)
    if type(a)=='string' then return {path=a,getDimensions=function() return 64,64 end} end
    local cell={w=a,h=b};function cell:getDimensions() return self.w,self.h end
    function cell:paste(sheet) self.sourcePath=sheet and sheet.path end
    return cell
  end},
}

local uiLoaded=true
local gameplayAutomatic=true
local overlayVisible=false
local overlayInteractive=false
local devPointerActive=false
local inputSnapshot={activeMode="pointer",activeDevice={kind="mouse"}}
local pointerEvents={}
local fieldExecutions={}
local stepWrapper
local hooks={wrap=function(_,name,fn)
  assert(name=="input.step","adapter uses the public input.step hook")
  stepWrapper=fn
  return function() stepWrapper=nil;return true end
end}

local FirstPerson={}
function FirstPerson.driving() return true end
function FirstPerson.moveVector() return 0,1 end
function FirstPerson.moveWorld(mx,mz) return mx,mz end
local FreeMove={}
function FreeMove._blockedCell(_,_,_,_) return "tile" end
local animationSteps={}
local metricsImage={}
local artMode='static'
local frontGeneration='gen5'
local BattleArt={
  setting={get=function() return artMode end},
  frontAnimationSetting={get=function() return frontGeneration end},
  backAnimationSetting={get=function() return 'gen5' end},
  playerSide=function() return 'front' end,
  image=function(species,side) if species=='PIKACHU' and side=='front' then return metricsImage end end,
  displayMode=function() return 'gbc' end,
  prepareData=function(cell) return {__shiny=tostring(cell and cell.sourcePath):find('/shiny/',1,true)~=nil} end,
  shareFrameAnchor=function() end,
  apply=function(battle) battle.artApplied=(battle.artApplied or 0)+1 end,
  applyTrainers=function(battle) battle.trainersApplied=(battle.trainersApplied or 0)+1 end,
  metrics=function(image)
    if image==metricsImage then return {x0=8,x1=39,y0=4,y1=35,w=64,h=64,center=24,padBottom=28} end
    if type(image)=='table' and image.__shiny then return {x0=8,x1=39,y0=4,y1=35,w=64,h=64,center=24,padBottom=28} end
  end,
}
local AnimatedBattleArt={update=function(battle,dt) animationSteps[#animationSteps+1]={battle=battle,dt=dt} end}
local stagedBattle=nil
local OverworldBattle={battle=function() return stagedBattle end}
local voxelLib={
  require=function(name)
    if name=="FirstPerson" then return FirstPerson end
    if name=="FreeMove" then return FreeMove end
    if name=="BattleArt" then return BattleArt end
    if name=="AnimatedBattleArt" then return AnimatedBattleArt end
    if name=="OverworldBattle" then return OverworldBattle end
  end,
  data=function(name)
    if name=='animated_battle_sprites_gen5' then
      return {PIKACHU={front={image='battle/front-animated/gen5/pikachu.png',autoColumns=1,durations={100},stableAnchor=true}}}
    end
  end,
  mod={assets={path=function(_,path) return 'VOXEL/assets/'..tostring(path) end}},
}
local voxelHandle={id="BATTLE_ART_VOXEL_FORK",version="1.8.3",exports={lib=voxelLib}}
local gameplayHandle={id="kanto_rework_gameplay",exports={
  fieldMoveStatus=function() return {automatic=gameplayAutomatic,mode=gameplayAutomatic and "automatic" or "vanilla"} end,
}}
local Core={
  inputMode=function() return inputSnapshot end,
  dispatchPointerEvent=function(_,event)
    pointerEvents[#pointerEvents+1]=event
    return true
  end,
  fieldActions={execute=function(id,context)
    fieldExecutions[#fieldExecutions+1]={id=id,context=context}
    return id=="kanto.cut"
  end},
}
local function findMod(id)
  if id=="ui" and uiLoaded then return {id=id,exports={
    krsOwnsPointerSurface=function(currentGame,state)
      return state and (state.kind=="main" or (state==currentGame.overworld and overlayVisible and overlayInteractive))
    end,
  }} end
  if id=="dev_tools" then return {id=id,exports={pointerSurfaceActive=function() return devPointerActive end}} end
  if id=="gameplay" then return gameplayHandle end
  if id=="BATTLE_ART_VOXEL_FORK" then return voxelHandle end
end
local adapter=factory({voxel=voxelHandle,findMod=findMod,Core=Core,hooks=hooks})

assert(adapter.match({id="BATTLE_ART_VOXEL_FORK",name="BATTLE ART VOXEL FORK",version="1.8.3"}),"exact release match")
assert(not adapter.match({id="BATTLE_ART_VOXEL_FORK",name="BATTLE ART VOXEL FORK",version="1.8.4"}),"future release must not match")

-- Battle Art remains animated even when Voxel 3D-BTL has no staged session.
local flatBattle={}
stagedBattle=nil
assert(adapter.prepareBattleArt(flatBattle,1/30)==true,"Battle Art applies outside staged 3D battle")
assert(#animationSteps==1 and math.abs(animationSteps[1].dt-1/60)<0.0001,"3D-BTL OFF starts animated sprite timeline at base real-time cadence")
fakeTime=100.05
adapter.prepareBattleArt(flatBattle,2.0) -- huge logic-speed dt must be ignored
assert(#animationSteps==2 and math.abs(animationSteps[2].dt-0.05)<0.0001,"battle speed does not accelerate Voxel sprite animation")
assert(flatBattle.artApplied==1 and flatBattle.trainersApplied==1,
  "render ticks advance animation without re-applying provider art")
flatBattle.player={mon={species="PIKACHU"}}
fakeTime=100.06
adapter.prepareBattleArt(flatBattle,1/30)
assert(flatBattle.artApplied==2 and flatBattle.trainersApplied==2,
  "a changed live battler invalidates the art attachment exactly once")
-- When Voxel itself stages this battle, its own call still enters the same real-time wrapper.
stagedBattle=flatBattle
adapter.prepareBattleArt(flatBattle,1/30)
assert(#animationSteps==3,"staged Voxel battle is not double-stepped by Compatibility")
fakeTime=100.11
AnimatedBattleArt.update(flatBattle,8.0)
assert(#animationSteps==4 and math.abs(animationSteps[4].dt-0.05)<0.0001,"staged 3D-BTL uses normal sprite cadence even at accelerated battle logic speed")
local metric=adapter.battleArtMetrics(metricsImage)
assert(metric and metric.x0==8 and metric.x1==39 and metric.center==24,"public BattleArt opaque metrics are exposed read-only")
local front=adapter.resolvePokemonArtImage({},'PIKACHU','front',{kind='party'})
assert(front and front.image==metricsImage and front.source=='battle_art_voxel.pokemon_sprites','selected Voxel art is resolvable for KRS menu surfaces')
artMode='animated'
local shiny=adapter.resolvePokemonArtImage({},'PIKACHU','front',{kind='battle',mon={species='PIKACHU',shiny=true}})
assert(shiny and shiny.forcedShiny==true and shiny.image and shiny.image.__shiny==true,
  'explicit Gen1Recomp shiny state resolves Voxel assets/battle/front-animated/gen5/shiny without mutating Voxel')
artMode='static'
local playerSide=adapter.resolvePokemonArtImage({},'PIKACHU','back',{kind='battle',player=true})
assert(playerSide and playerSide.image==metricsImage,'Voxel PLAYER FRONT choice is mirrored by KRS battle sprite resolution')
stagedBattle=nil

local game={mods={optionSchemas={BATTLE_ART_VOXEL_FORK={{key="voxelGrid"},{key="battleArt"}}}}}
local kept=adapter.filterGlobalOptions(game,{
  {id="textSpeed"},{id="pipeline:voxel"},{id="voxelGrid"},{id="BATTLE_ART_VOXEL_FORK:voxelGrid"},
  {id="battleArt"},{id="BATTLE_ART_VOXEL_FORK:battleArt"},{id="pipeline:tiltshift"},{id="battleLayout"},
})
assert(#kept==2 and kept[1].id=="textSpeed" and kept[2].id=="battleLayout","bare and prefixed Battle Art-owned rows are removed from global Options")

local levels={voxel=0,tiltshift=0}
local writes=0
local Pipelines={}
function Pipelines.levelLabel(id) return ({[0]="OFF",[1]="ON"})[levels[id]] end
function Pipelines.level(id) return levels[id] end
function Pipelines.cycle(id) levels[id]=(levels[id]+1)%2 end
function Pipelines.syncOptions(options) options.pipelines={voxel=levels.voxel,tiltshift=levels.tiltshift} end
local Tilt={setLevel=function() end}
package.loaded["src.render.Pipelines"]=Pipelines
package.loaded["src.render.Tilt"]=Tilt
game.save={options={tilt=0}}
game.writeOptions=function() writes=writes+1 end
local rows=adapter.decorateOptions(nil,{{id="voxelGrid",label="VOXEL GRID"},{id="battleArt",label="BATTLE ART"},{id="__reset",label="RESET"}})
assert(#adapter.utilities(game)==0,"Voxel settings no longer open a detached utility")
assert(rows[1].id=="__pipeline_voxel" and rows[2].id=="__pipeline_tiltshift","render pipelines are inline under the Voxel mod")
local byId={};for _,row in ipairs(rows) do byId[row.id]=row end
assert(byId.voxelGrid and byId.voxelGrid.group=="WORLD RENDERING" and byId.battleArt and byId.battleArt.group=="BATTLE ART","native Voxel options receive semantic subgroups")
assert(not byId.__krs_compat_sprite_upscale and not byId.__krs_compat_pokemon_real_size,"KRS scaling controls stay off the third-party Voxel card")
local ok,newLabel=rows[1].adjust(game,1)
assert(ok and levels.voxel==1 and newLabel=="ON" and writes==1,"inline pipeline control uses the engine owner setter and persists")

local player={cellX=10,cellY=12,facing="down",moving=false,inputLocked=false}
local overworld={kind="overworld",player=player,map={id="ROUTE_1"}}
local menuState={kind="main"}
game.overworld=overworld
game.stack={current=menuState,top=function(self)return self.current end}
local OverworldState={dramaticShapeFreeMoveHook=true}
local voxelWalks=0
function OverworldState:handleInput() voxelWalks=voxelWalks+1;return "voxel_walk" end
package.loaded["src.world.OverworldController"]=OverworldState

local relative=false
local visible=false
local oldLove=love
local mousemoved=function() end
local mousepressed=function() end
local mousereleased=function() end
-- Keep image/timer services that earlier art tests installed, while adding only
-- the allowed mouse methods used by the sandbox-safe arbitration pass.
love.mouse={
  getRelativeMode=function() return relative end,
  setRelativeMode=function(value) relative=value end,
  setVisible=function(value) visible=value end,
}
love.mousemoved=mousemoved;love.mousepressed=mousepressed;love.mousereleased=mousereleased

levels.voxel=7
local uninstall=adapter.installPointerGuard()
assert(type(stepWrapper)=="function","input.step maintenance bridge installed")

stepWrapper(function()
  love.mouse.setRelativeMode(true)
  love.mouse.setVisible(false)
end,game,1/60)
assert(relative==false and visible==true,"KRS menu releases relative mode and restores cursor")
assert(love.mousemoved==mousemoved and love.mousepressed==mousepressed and love.mousereleased==mousereleased,
  "v0.1.86 compatibility never replaces LOVE pointer callbacks")

-- Late writes are allowed between input steps; the next engine step reasserts
-- the surface owner instead of wrapping setVisible/setRelativeMode.
love.mouse.setVisible(false)
assert(visible==false,"no forbidden LOVE monkey-patch intercepts late Voxel writes")
stepWrapper(function() end,game,1/60)
assert(visible==true,"maintenance tick reasserts KRS cursor visibility")

inputSnapshot={activeMode="controller",activeDevice={kind="controller"}}
relative=true;visible=false
stepWrapper(function() end,game,1/60)
assert(relative==false and visible==false,"controller-owned menu releases look capture without forcing cursor visibility")
inputSnapshot={activeMode="pointer",activeDevice={kind="mouse"}}

-- Passive F8 overlays are visual only and preserve Voxel free-camera look.
game.stack.current=overworld;overlayVisible=true;overlayInteractive=false
relative=false;visible=false
stepWrapper(function() love.mouse.setRelativeMode(true);love.mouse.setVisible(false) end,game,1/60)
assert(relative==true and visible==false,"passive overlay does not claim the overworld pointer surface")

-- Interactive F8 overlay uses the UI module's public export through mod.find.
overlayInteractive=true
relative=true;visible=false
stepWrapper(function() end,game,1/60)
assert(relative==false and visible==true,"interactive overworld overlay temporarily owns Voxel pointer capture")
overlayVisible=false;overlayInteractive=false

-- Dev F3 surface is another explicit public owner; no shared _G bridge exists.
devPointerActive=true;relative=true;visible=false
stepWrapper(function() end,game,1/60)
assert(relative==false and visible==true,"interactive Dev overlay owns Voxel pointer capture through mod.find exports")
devPointerActive=false

-- KRS automatic Cut/Surf runs before FreeMove only for a real blocked target.
stepWrapper(function() end,game,1/60)
local result=OverworldState.handleInput(overworld)
assert(result=="field_move" and #fieldExecutions==1 and fieldExecutions[1].id=="kanto.cut",
  "Voxel world vector reaches Gameplay's registered automatic field action")
assert(fieldExecutions[1].context.direction=="down" and fieldExecutions[1].context.source=="battle_art_voxel_free_move",
  "field action context preserves Voxel world direction and provenance")
assert(voxelWalks==0,"successful contextual field move owns the frame before FreeMove")

gameplayAutomatic=false
result=OverworldState.handleInput(overworld)
assert(result=="voxel_walk" and voxelWalks==1,"Vanilla Field Move mode leaves FreeMove untouched")

-- Returning to passive world restores Voxel free-camera ownership.
relative=false;visible=false
stepWrapper(function() love.mouse.setRelativeMode(true);love.mouse.setVisible(false) end,game,1/60)
assert(relative==true and visible==false,"DramaticShape retains capture over the passive world")

assert(uninstall()==true and stepWrapper==nil,"pointer and field bridge cleanly uninstall")
assert(OverworldState.handleInput~=nil and love.mousemoved==mousemoved and love.mousepressed==mousepressed and love.mousereleased==mousereleased,
  "owned seams restore without forbidden callback mutation")
love=oldLove
print("Battle Art Voxel Fork 1.8.3 sandbox-safe pointer and contextual Field Move tests passed")
