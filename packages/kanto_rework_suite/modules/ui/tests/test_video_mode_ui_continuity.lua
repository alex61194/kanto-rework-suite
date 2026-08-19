local root=assert(arg[1],"root path required")
local oldLove=love

-- Simulate the short SDL swapchain mismatch observed while toggling
-- fullscreen/windowed: the live graphics query has already changed, while
-- render.hud is presenting a valid 16:9 KRS frame.
love={graphics={getDimensions=function() return 1600,900 end}}
local Layout=assert(loadfile(root.."/ui/menu_layout.lua"))()
local frame={width=1920,height=1080}
assert(Layout.isWide(frame)==true,
  "the explicit render frame must keep KRS ownership during a video-mode transition")
local w,h=Layout.dimensions(frame)
assert(w==1920 and h==1080,"frame dimensions win over a transitioning live swapchain")

-- Without a frame payload, first-boot/update callers retain the safe live
-- window fallback.
w,h=Layout.dimensions(nil)
assert(w==1600 and h==900 and Layout.isWide(nil)==true,
  "live dimensions remain the fallback before render.hud provides a frame")

-- A genuinely unsupported explicit frame still uses the native boundary; the
-- transition fix must not silently broaden KRS to arbitrary layouts.
assert(Layout.isWide({width=1024,height=768})==false,
  "non-Wide explicit frames retain the vanilla fallback boundary")

love=oldLove
print("Video-mode KRS continuity tests passed")
