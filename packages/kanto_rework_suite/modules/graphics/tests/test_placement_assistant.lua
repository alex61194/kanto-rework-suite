local root=assert(arg[1],'graphics root required')
local A=assert(loadfile(root..'/placement_assistant.lua'))()
local outdoor={horizonY=330,perspectiveStrength=.62,scaleReference=1}
local player={depth=.20,circleWidth=350,perspectiveStrength=.62}
local enemy={depth=.64,circleWidth=270,perspectiveStrength=.62}
local small=A.suggest{role='player',heightM=.2,nativeWidth=96,nativeHeight=96,scene=outdoor,sideMeta=player,anchor={x=600,y=760}}
local large=A.suggest{role='player',heightM=6,nativeWidth=96,nativeHeight=96,scene=outdoor,sideMeta=player,anchor={x=600,y=760}}
assert(large.suggested.size>small.suggested.size,'intrinsic height must influence suggestion without species table')
local near=A.suggest{role='player',heightM=1,nativeWidth=96,nativeHeight=96,scene=outdoor,sideMeta=player,anchor={x=600,y=760}}
local far=A.suggest{role='opponent',heightM=1,nativeWidth=96,nativeHeight=96,scene=outdoor,sideMeta=enemy,anchor={x=1400,y=560}}
assert(near.suggested.size>far.suggested.size,'farther opponent should project smaller than equivalent near player')
local narrow=A.suggest{role='opponent',heightM=1,nativeWidth=96,nativeHeight=96,scene=outdoor,sideMeta={depth=.5,circleWidth=220,perspectiveStrength=.5},anchor={x=1400,y=560}}
local wide=A.suggest{role='opponent',heightM=1,nativeWidth=96,nativeHeight=96,scene=outdoor,sideMeta={depth=.5,circleWidth=380,perspectiveStrength=.5},anchor={x=1400,y=560}}
assert(wide.suggested.size>=narrow.suggested.size,'larger battle circle should not suggest smaller equivalent sprite')
local atypical=A.suggest{role='opponent',heightM=2,nativeWidth=300,nativeHeight=80,scene=outdoor,sideMeta=enemy,anchor={x=1400,y=560}}
assert(atypical.predictedBounds.w<=380.001,'atypically wide sprite must obey role width limit')
local interior=A.suggest{role='player',heightM=1,nativeWidth=96,nativeHeight=96,scene={horizonY=350,perspectiveStrength=.44,scaleReference=.98},sideMeta={depth=.23,circleWidth=330,perspectiveStrength=.44},anchor={x=620,y=790}}
assert(type(interior.suggested.position.x)=='number' and type(interior.suggested.size)=='number','interior scenario must resolve')
local collision=A.suggest{role='player',heightM=1,nativeWidth=96,nativeHeight=96,scene=outdoor,sideMeta=player,anchor={x=600,y=760},uiRects={{x=500,y=550,w=250,h=250}}}
assert(type(collision.flags.uiAdjusted)=='boolean','UI-collision correction must report whether it was applied')
print('PASS test_placement_assistant')
