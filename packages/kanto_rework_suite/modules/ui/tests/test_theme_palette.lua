local root=assert(arg[1],"UI root required")
local function loadAt(path)local chunk,err=loadfile(root.."/"..path);assert(chunk,err);return chunk()end
local C=loadAt("generated/tokens.lua")
local Profiles=loadAt("generated/color_profiles.lua")
local Themes=loadAt("generated/themes.lua")
local selected="graphite";local profile="standard";local fullFrame=false
local mod={options={get=function(_,key)assert(key=="ui_theme");return selected end}}
local Core={
  activeAccessibilityProfile=function()return profile end,
  fullFrameColorAccessibility=function()return fullFrame end,
  activeColorMode=function()return "standard" end,
}
local Palette=loadAt("ui/palette.lua")({C=C,Profiles=Profiles,Core=Core,Themes=Themes,mod=mod})
local function near(a,b)return math.abs(a-b)<0.00001 end
local function eq(c,r,g,b)return near(c[1],r/255) and near(c[2],g/255) and near(c[3],b/255) end
local p=Palette.resolve()
assert(p.theme=="graphite","Graphite selected")
assert(eq(p.colors.canvas,20,19,17),"Graphite canvas")
assert(eq(p.colors.focus,40,200,230),"Standard profile must preserve Graphite theme focus")
assert(eq(p.colors.hpFull,76,206,121),"Standard profile must preserve Graphite HP token")
selected="purplenight";p=Palette.resolve();assert(eq(p.colors.focus,160,140,245),"PurpleNight focus")
selected="retro";p=Palette.resolve();assert(eq(p.colors.mainCardHover,136,136,136),"Retro hover")
assert(eq(p.colors.hpFull,31,111,70),"Retro full HP keeps Figma green")
assert(eq(p.colors.hpMid,152,102,0),"Retro medium HP keeps Figma orange")
assert(eq(p.colors.hpCritical,180,54,45),"Retro critical HP keeps Figma red")
assert(eq(p.colors.exp,18,98,122),"Retro EXP keeps Figma blue")
assert(eq(p.typeColors.FIRE,255,148,76),"Retro keeps coloured type badges and icons")
assert(p.statusColors.BURNED and eq(p.statusColors.BURNED.icon,228,97,62),"Retro keeps coloured status icons")
profile="protanopia";fullFrame=false;p=Palette.resolve();assert(eq(p.colors.focus,72,111,132),"legacy per-token accessibility fallback")
fullFrame=true;p=Palette.resolve();assert(eq(p.colors.focus,8,8,8),"full-frame accessibility must not double-transform Retro focus")
print("Theme palette tests passed")
