local root=assert(arg[1],"root path required")
local factory=assert(loadfile(root.."/components/modular_overlays.lua"))()
local Overlay=factory({runtime={},Core={},Palette={},Models={},mod={options={get=function() return nil end}}})
local ids=Overlay.enabledIds()
assert(#ids==2 and ids[1]=="encounters" and ids[2]=="capture","only the two useful overlays remain registered")
local function checkFit(count,w,h)
  local f=Overlay._fitGrid(count,{x=0,y=0,w=w,h=h},132,58,8,6)
  assert(f and f.rows*f.cols>=count,"responsive grid must retain every row")
  local usedW=f.cols*f.cardW+(f.cols-1)*f.gap
  local usedH=f.rows*f.cardH+(f.rows-1)*f.gap
  assert(usedW<=w+.001 and usedH<=h+.001,"responsive grid must fit inside both dimensions")
  return f
end
local small=checkFit(12,320,220)
local medium=checkFit(12,640,440)
local large=checkFit(12,960,660)
assert(medium.scale>small.scale and large.scale>medium.scale,"content must grow when the overlay grows")
local f=assert(io.open(root.."/components/modular_overlays.lua","rb"));local source=f:read("*a");f:close()
assert(not source:find("RESIZE TO VIEW",1,true) and not source:find("setScissor",1,true),"overlay resize may not clip or hide content")
assert(source:find("local function drawAreaSummary",1,true) and source:find("local function drawSpeciesCard",1,true) and source:find("local function drawTargetCard",1,true) and source:find("local function drawBallCard",1,true),"useful overlays must use the redesigned KRS editorial/card composition")
assert(not source:find('"player"',1,true) and not source:find('"party"',1,true) and not source:find('"type_chart"',1,true) and not source:find('"session"',1,true),"retired overlays must not remain in the renderer")
print("Responsive overlay tests passed")
