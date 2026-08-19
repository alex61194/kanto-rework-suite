local e=assert(io.open('screens/graphics_editor.lua','rb')):read('*a')
for _,token in ipairs({
  "trainerPhaseLabels={intro='INTRO',battle='BATTLE / PERSISTENT',post='POST-BATTLE'}",
  "target='trainer_'..phaseId",
  "label='TRAINER '..trainerPhaseLabels[phaseId]..' POSITION'",
  "label='TRAINER SCALE'",
  "label='TRAINER ANIMATION SPEED'",
  'trainerPreviewPhase'
}) do
  assert(e:find(token,1,true),token..' missing')
end
assert(e:find("if trainer then return {minX=0,maxX=1920,minY=86,maxY=1016} end",1,true),'trainer positions use absolute scene bounds')
local b=assert(io.open('ui/battle_presenter.lua','rb')):read('*a')
assert(b:find("uiBounds['trainer_'..trainerPhase]",1,true),'trainer preview must publish real drag bounds')
assert(b:find('krsTrainerForcePreview',1,true),'editor preview must not mutate live battle to inspect trainer phases')
local layout=assert(b:find('local uiLayout=battleLayout(game)',1,true),'battle ui layout declaration missing')
local sprites=assert(b:find('local visualBounds=drawSprites(game,m,s,groundAnchors,backdrop,uiLayout)',1,true),'sprite draw must receive battle ui layout')
assert(layout < sprites,'real trainer layout must be resolved before sprite draw')
print('trainer live editor: PASS')
