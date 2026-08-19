local root=assert(arg[1],"UI root required")
local function loadAt(path)local chunk,err=loadfile(root.."/"..path);assert(chunk,err);return chunk()end
local Specs=loadAt("generated/themes.lua")
local selected="cream"
local mod={id="kanto_rework_ui",options={get=function(_,key)assert(key=="ui_theme");return selected end}}
local setCalls=0
local Core={createModRuntime=function()
  return {enter=function()return true end,setOption=function(_,modId,key,value)
    assert(modId=="kanto_rework_ui" and key=="ui_theme" and Specs.valid(value));setCalls=setCalls+1;selected=value;return true,value
  end}
end}
local Palette={resolveAll=function()return{}end}
local Theme=loadAt("ui/theme.lua")({Palette=Palette,Specs=Specs,mod=mod,Core=Core})
assert(Theme.currentId()=="cream" and Theme.value()=="CREAM","initial theme")
local changed,id=Theme.step({},1);assert(changed and id=="graphite" and Theme.value()=="GRAPHITE","cycle to Graphite")
changed,id=Theme.step({},1);assert(changed and id=="purplenight" and Theme.value()=="PURPLE NIGHT","cycle to PurpleNight")
changed,id=Theme.step({},1);assert(changed and id=="retro" and Theme.value()=="RETRO","cycle to Retro")
changed,id=Theme.step({},1);assert(changed and id=="cream","wrap to Cream")
assert(setCalls==4,"each change persisted through Core mod runtime")

local Catalog=loadAt("runtime/options_catalog.lua")
local sessionRows={{id="uiLayout",label="UI LAYOUT",category="GRAPHICS"},{id="colors",label="COLORS",category="GRAPHICS"}}
local writeCalls=0
Core.createOptionsRuntime=function()
  return {native={},rows=sessionRows,syncVideoMode=function()end}
end
local runtime={Core=Core,Theme=Theme,Catalog=Catalog,Layout={isWide=function()return true end},
  Focus={new=function()return{}end,navigation=function()end},
  Scroll={total=function(count,pitch,rowH)return count>0 and ((count-1)*pitch+rowH) or 0 end,clamp=function(v)return v or 0 end,ensure=function(v)return v or 0 end,model=function()return nil end}}
local Factory=loadAt("screens/options_menu.lua").factory(runtime)
local game={writeOptions=function()writeCalls=writeCalls+1 end}
local screen=Factory.new(game)
local graphics=Catalog.rows(screen.session.rows,"GRAPHICS")
assert(#graphics==3 and graphics[2].id=="colors" and graphics[3].id=="krsTheme","UI Theme inserted after engine color presentation")
selected="cream";local row=graphics[3];assert(row.value()=="CREAM","row exposes current label")
assert(screen:change(row,1,false)==true and selected=="graphite","Options row cycles theme")
assert(writeCalls==0,"UI-owned theme option must not call native game.writeOptions")
print("Theme option tests passed")
