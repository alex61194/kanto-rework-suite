local root=assert(arg[1],"root path required")
local DexEntryMenu={};DexEntryMenu.__index=DexEntryMenu
package.preload['src.ui.DexEntryMenu']=function() return DexEntryMenu end
local factory=assert(loadfile(root.."/ui/menu_pointer_guard.lua"))()
local mode={activeMode="pointer",activeDevice={kind="mouse"}}
local overlayState={visible=false,contextMode=false,editMode=false}
local battleHandled=false
local linkState={kind='native_link'}
local runtime={viewport={width=1920,height=1080},
  LinkPresenter={handles=function(_,state)return state==linkState end},
  BattlePresenter={handles=function() return battleHandled end},
}
local Guard=factory({
  Core={inputMode=function() return mode end,overlayState=function() return overlayState end},
  Layout={isWide=function() return true end},
  runtime=runtime,
})

local relative=true
local visibilityCalls=0
local visible=false
local oldLove=love
love={mouse={
  getRelativeMode=function() return relative end,
  setRelativeMode=function(value) relative=value end,
  setVisible=function(value) visibilityCalls=visibilityCalls+1;visible=value end,
}}

assert(Guard.restore({}, {kind="mods"})==true,"KRS menu is pointer-owned")
assert(relative==false and visible==true and visibilityCalls==1,"menu releases relative capture and restores mouse cursor")

relative=true;visible=false;visibilityCalls=0
mode={activeMode="navigation",activeDevice={kind="keyboard"}}
assert(Guard.restore({}, {kind="main"})==true,"keyboard-opened KRS menu is pointer-owned")
assert(relative==false and visible==true and visibilityCalls==1,
  "releasing camera capture restores the cursor for keyboard and mouse play")

relative=true;visible=false;visibilityCalls=0
mode={activeMode="navigation",activeDevice={kind="controller"}}
assert(Guard.restore({}, {kind="options"})==true,"controller can open KRS menu")
assert(relative==false and visibilityCalls==0 and visible==false,"controller navigation stays cursor-free while relative capture is released")

relative=true;visibilityCalls=0
local overworld={kind="overworld"};local game={overworld=overworld}
assert(Guard.restore(game,overworld)==false,"uncovered overworld remains owned by camera mod")
assert(relative==true and visibilityCalls==0,"overworld capture is untouched")

overlayState.visible=true;relative=true;visible=false;visibilityCalls=0
mode={activeMode='pointer',activeDevice={kind='mouse'}}
assert(Guard.restore(game,overworld)==false,"passive F8 overlays must not steal Voxel camera ownership")
assert(relative==true and visible==false and visibilityCalls==0,
  "passive overlay display preserves first/third-person relative mouse look")
overlayState.contextMode=true
assert(Guard.restore(game,overworld)==true,"interactive overlay mode owns the pointer")
assert(relative==false and visible==true and visibilityCalls==1,
  "interactive overlay releases Voxel capture and restores the cursor")
overlayState.visible=false;overlayState.contextMode=false

relative=true;visible=false;visibilityCalls=0;battleHandled=true
assert(Guard.restore({}, {kind='battle'})==true,"interactive wide battle owns the pointer")
assert(relative==false and visible==true,"battle transition restores the mouse cursor")
battleHandled=false

relative=true;visibilityCalls=0;mode={activeMode='pointer',activeDevice={kind='mouse'}}
local dex=setmetatable({},DexEntryMenu)
assert(Guard.restore({},dex)==true,'Oak starter DexEntry is a KRS pointer-owned transition surface')
assert(relative==false,'starter DexEntry releases Voxel relative mouse capture')

relative=true;visible=false;visibilityCalls=0
assert(Guard.restore({},linkState)==true,'the themed native Link flow is a KRS pointer-owned surface')
assert(relative==false and visible==true,'Link menus release Voxel capture and show the cursor')

love=oldLove
print("KRS menu pointer guard tests passed")
