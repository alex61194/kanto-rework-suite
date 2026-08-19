local root=assert(arg[1],"root path required")
local function loadModule(path)local chunk,err=loadfile(root.."/"..path);assert(chunk,err);return chunk() end
local function check(value,label)if not value then error(label or "check failed",2) end end
local function eq(actual,expected,label)if actual~=expected then error((label or "value")..": expected "..tostring(expected)..", got "..tostring(actual),2) end end

local loads=0
love={graphics={newFont=function(path,px)loads=loads+1;return{path=path,px=px}end}}
local runtime={}
local Typography=loadModule("core/typography.lua")({runtime=runtime})
local unregister=Typography.registerFamily({id="test.inter",label="Inter",source="test",paths={regular="regular.ttf",bold="bold.ttf"}})
local path,weight=Typography.resolve("test.inter","semibold")
eq(path,"bold.ttf","semibold falls back to bold");eq(weight,"bold","resolved fallback weight")
local first=assert(Typography.font("test.inter","semibold",14))
local second=assert(Typography.font("test.inter","semibold",14))
check(first==second,"resolved fonts are cached");eq(loads,1,"font loaded exactly once")
local status=Typography.status();eq(status.families,1,"registered family count");eq(status.cachedFonts,1,"font cache count")
check(unregister(),"family unregisters");check(Typography.resolve("test.inter","regular")==nil,"unregistered family disappears")
print("Core typography family, fallback and cache tests passed")
