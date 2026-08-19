local root=assert(arg[1],"root path required")
local Layout=assert(loadfile(root.."/ui/mod_info_layout.lua"))()
local info={x=1282,y=120,w=574,h=856}

local short=Layout.build(info,5,false,false)
assert(short.card.h==516,"short metadata keeps the canonical compact card")
assert(short.gapToOuterBottom>=8,"compact card respects outer white panel gap")
assert(short.model.descriptionY+short.model.descriptionH<short.model.stateY,"short description cannot overlap runtime state")

local long=Layout.build(info,31,false,false)
assert(long.card.h>516 and long.card.h<=long.maxCardH,"long metadata grows only inside the white panel")
assert(long.gapToOuterBottom==8,"maximum responsive card keeps exactly the required 8 px floor")
assert(long.model.descriptionY+long.model.descriptionH<long.model.stateY,"long description pushes metadata down without overlap")

local preview=Layout.build(info,8,false,false,{topInset=312})
assert(preview.card.y==info.y+312,"preview metadata starts directly below the preview region")
assert(preview.card.h<=preview.maxCardH,"preview cannot force the info card beyond available height")
assert(preview.gapToOuterBottom>=8,"preview + info card remain inside the shared outer container")

local extreme=Layout.build(info,80,true,true,{topInset=312})
assert(extreme.card.h==extreme.maxCardH,"extreme preview metadata is capped by the safe boundary")
assert(extreme.model.contentH>extreme.view.h,"extreme metadata requires internal scrolling")
assert(extreme.view.w==extreme.card.w-60,"scrollbar reserves content width")
assert(extreme.gapToOuterBottom==8,"scrollable card never crosses the white frame")

print("Responsive mod info layout tests passed")
