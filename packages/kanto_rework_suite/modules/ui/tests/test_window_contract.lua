local root=assert(arg[1],"root path required")
local function check(v,msg)if not v then error(msg or"check failed",2)end end
local function eq(a,b,msg)if a~=b then error((msg or"value")..": expected "..tostring(b)..", got "..tostring(a),2)end end
local Layout=assert(loadfile(root..'/ui/menu_layout.lua'))()
local make=assert(loadfile(root..'/ui/window_contract.lua'))()

local modeW,modeH=1920,1080
local flags={fullscreen=false,borderless=false,resizable=true,vsync=1}
local calls={}
love={window={
  getMode=function()return modeW,modeH,flags end,
  updateMode=function(w,h,newFlags)calls[#calls+1]={w=w,h=h,flags=newFlags};return true end,
}}
local W=make({Layout=Layout})

local r=W.reconcile({width=1920,height=1080});check(r.valid and not r.fallback,'fullscreen-sized 16:9 surface stays KRS')
eq(#calls,0,'valid 16:9 does not resize')
check(Layout.isWide({width=1600,height=900}),'1600x900 accepted')
check(Layout.isWide({width=1280,height=720}),'1280x720 minimum accepted')
check(Layout.isWide({width=2560,height=1440}),'larger 16:9 accepted')
check(not Layout.isWide({width=1600,height=1200}),'4:3 rejected by KRS wide layout')
check(not Layout.isWide({width=2560,height=1080}),'ultrawide rejected by KRS wide layout')

-- Windowed resize: the independent Y stretch is corrected by snapping the
-- complementary axis rather than scaling KRS non-uniformly.
modeW,modeH=1600,1000;flags={fullscreen=false,borderless=false,resizable=true}
r=W.reconcile({width=1600,height=1000});check(r.fallback and r.snapped,'windowed non-16:9 requests a snap')
eq(calls[#calls].w,1600,'window resize keeps the controlling width')
eq(calls[#calls].h,900,'window resize recalculates height to 16:9')
local firstCalls=#calls
r=W.reconcile({width=1600,height=1000});check(r.fallback and r.pending and not r.snapped,'same stale swapchain waits for pending snap')
eq(#calls,firstCalls,'pending snap is not reissued every frame')
modeW,modeH=1600,900
r=W.reconcile({width=1600,height=900});check(r.valid and not r.fallback,'KRS recovers automatically after snapped surface becomes valid')
check(W.status().pendingWidth==nil,'valid recovery clears pending window request')

-- A height-led drag after a known 16:9 frame preserves the changed height and
-- derives width. (900 -> 1000 is the larger delta here.)
modeW,modeH=1600,1000
r=W.reconcile({width=1600,height=1000});check(r.snapped,'second windowed resize snaps')
eq(calls[#calls].w,1778,'height-led resize derives 16:9 width with integer rounding')
eq(calls[#calls].h,1000,'height-led resize preserves requested height')
modeW,modeH=1778,1000
r=W.reconcile({width=1778,height=1000});check(r.valid,'rounded 16:9 target is accepted within pixel tolerance')

-- Fullscreen/borderless modes are not forcibly resized: invalid display modes
-- expose Vanilla for that frame and become KRS again when 16:9 returns.
flags={fullscreen=true,borderless=false,resizable=false};modeW,modeH=1024,768
local before=#calls;r=W.reconcile({width=1024,height=768});check(r.fallback and r.reason=='non_16_9_fullscreen','4:3 fullscreen falls back to Vanilla')
eq(#calls,before,'fullscreen fallback does not fight the OS mode')
modeW,modeH=2560,1080;r=W.reconcile({width=2560,height=1080});check(r.fallback and r.reason=='non_16_9_fullscreen','ultrawide fullscreen falls back to Vanilla')
modeW,modeH=1920,1080;r=W.reconcile({width=1920,height=1080});check(r.valid and not r.fallback,'return to 16:9 restores KRS without persistence changes')

flags={fullscreen=false,borderless=false,resizable=true};modeW,modeH=1400,900
love.window.updateMode=function()return false end
r=W.reconcile({width=1400,height=900});check(r.fallback and r.reason=='window_snap_failed','backend resize rejection leaves clean Vanilla fallback')

print('KRS 16:9 fullscreen/windowed contract tests passed')
