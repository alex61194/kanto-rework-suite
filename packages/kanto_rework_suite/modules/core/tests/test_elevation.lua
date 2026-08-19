local root=assert(arg[1],"root path required")
local function loadModule(path)local chunk,err=loadfile(root.."/"..path);assert(chunk,err);return chunk()end
local function check(value,label)if not value then error(label or "check failed",2)end end
local function near(actual,expected,label)if math.abs(actual-expected)>.0001 then error((label or "value")..": expected "..expected..", got "..actual,2)end end

local Elevation=loadModule("core/elevation.lua")()
local profile=Elevation.cardShadow()
check(profile.offsetX==0 and profile.offsetY==4,"canonical offset")
check(profile.blur==4 and profile.spread==0,"canonical blur and spread")
near(profile.color[4],.4,"canonical opacity")
local samples=Elevation.shadowSamples(profile)
check(#samples==5,"four-pixel blur produces five deterministic samples")
check(samples[1].spread==4 and samples[#samples].spread==0,"samples resolve outer to inner")
local composite=1
for _,sample in ipairs(samples) do composite=composite*(1-sample.color[4]) end
near(1-composite,.4,"sample opacity composites to requested opacity")
print("Core elevation profile tests passed")
