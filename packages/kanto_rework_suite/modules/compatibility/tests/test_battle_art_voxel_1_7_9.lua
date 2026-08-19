local root=assert(arg[1],"root path required")
local factory=assert(loadfile(root.."/adapters/battle_art_voxel_1_7_9.lua"))()

local uiLoaded=true
local gameplayAutomatic=true
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
local voxelHandle={id="BATTLE_ART_VOXEL_FORK",version="1.7.9",exports={lib={
  require=function(name)
    if name=="FirstPerson" then return FirstPerson end
    if name=="FreeMove" then return FreeMove end
  end,
}}}
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
    krsOwnsPointerSurface=function(_,state) return state and state.kind=="main" end,
  }} end
  if id=="gameplay" then return gameplayHandle end
  if id=="BATTLE_ART_VOXEL_FORK" then return voxelHandle end
end
local adapter=factory({voxel=voxelHandle,findMod=findMod,Core=Core,hooks=hooks})

assert(adapter.match({id="BATTLE_ART_VOXEL_FORK",name="BATTLE ART VOXEL FORK",version="1.7.9"}),"exact release match")
assert(not adapter.match({id="BATTLE_ART_VOXEL_FORK",name="BATTLE ART VOXEL FORK",version="1.8.0"}),"future release must not match")

local game={mods={optionSchemas={BATTLE_ART_VOXEL_FORK={{key="grid"},{key="battleArt"}}}}}
local kept=adapter.filterGlobalOptions(game,{
  {id="textSpeed"},{id="pipeline:voxel"},{id="grid"},{id="battleArt"},
  {id="pipeline:tiltshift"},{id="battleLayout"},
})
assert(#kept==2 and kept[1].id=="textSpeed" and kept[2].id=="battleLayout","only Battle Art-owned rows are removed")

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
local utility=adapter.utilities(game)[1]
local menu=utility.open()
assert(menu.title=="BATTLE ART · RENDER MODES" and #menu.items==2,"render modes utility")
assert(menu.items[1].label=="VOXEL · OFF","live voxel label")
menu.items[1].onSelect()
assert(levels.voxel==1 and menu.items[1].label=="VOXEL · ON" and writes==1,"pipeline owner setter and persistence")

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
love={mouse={
  getRelativeMode=function() return relative end,
  setRelativeMode=function(value) relative=value end,
  setVisible=function(value) visible=value end,
},mousemoved=mousemoved,mousepressed=mousepressed,mousereleased=mousereleased}

levels.voxel=7
local uninstall=adapter.installPointerGuard()
assert(type(stepWrapper)=="function","input.step maintenance bridge installed")

-- v0.1.86 owns the physical pointer ingress. Compatibility must not monkey-
-- patch LOVE callbacks anymore; it only arbitrates relative capture once per
-- engine input step while a KRS surface is active.
stepWrapper(function()
  love.mouse.setRelativeMode(true)
  love.mouse.setVisible(false)
end,game,1/60)
assert(relative==false and visible==true,"KRS menu releases Voxel relative capture after the input step")
assert(love.mousemoved==mousemoved and love.mousepressed==mousepressed and love.mousereleased==mousereleased,
  "sandbox-safe adapter leaves LOVE pointer callbacks untouched")

-- A late visibility write is not intercepted by monkey-patching anymore; the
-- next sanctioned input.step maintenance pass reasserts KRS ownership.
love.mouse.setVisible(false)
assert(visible==false,"direct third-party visibility write is left untouched between engine steps")
stepWrapper(function() end,game,1/60)
assert(visible==true,"next input.step restores the cursor for a KRS pointer surface")

inputSnapshot={activeMode="controller",activeDevice={kind="controller"}}
love.mouse.setVisible(false);relative=true
stepWrapper(function() end,game,1/60)
assert(relative==false and visible==false,"controller navigation releases relative capture without forcing a mouse cursor")
inputSnapshot={activeMode="pointer",activeDevice={kind="mouse"}}

-- KRS automatic Cut/Surf runs before FreeMove only for a real blocked target.
game.stack.current=overworld
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

-- Passive world/freecam remains wholly Voxel-owned because UI explicitly says
-- it does not own the overworld pointer surface.
relative=false;visible=false
stepWrapper(function() love.mouse.setRelativeMode(true);love.mouse.setVisible(false) end,game,1/60)
assert(relative==true and visible==false,"Voxel free camera retains capture on the passive overworld")

assert(uninstall()==true and stepWrapper==nil,"pointer and field bridge cleanly uninstall")
assert(OverworldState.handleInput~=nil and love.mousemoved==mousemoved and love.mousepressed==mousepressed and love.mousereleased==mousereleased,
  "sandbox-safe owned seams restore without touching LOVE callbacks")
love=oldLove
print("Battle Art Voxel Fork 1.7.9 sandbox-safe pointer and contextual Field Move tests passed")
