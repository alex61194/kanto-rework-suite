local root=assert(arg[1],"root path required")
local function check(v,msg)if not v then error(msg or'check failed',2)end end
local function approx(a,b,eps,msg)if math.abs((a or 0)-(b or 0))>(eps or 1e-9)then error((msg or'value')..': expected '..tostring(b)..', got '..tostring(a),2)end end
local Models=assert(loadfile(root..'/components/overlay_models.lua'))()(function(v)return tostring(v)end)

local battle={kind='wild',enemy={name='PIKACHU',mon={species='PIKACHU',hp=50,stats={hp=100}},def={name='PIKACHU',catchRate=45}},data={statuses={}}}
function battle:ballDef(id)
  if id=='MASTER_BALL'then return{autoCatch=true}end
  if id=='ULTRA_BALL'then return{randMax=150,hpFactor=12}end
  if id=='POKE_BALL'then return{randMax=255,hpFactor=12}end
  return{randMax=255,hpFactor=12}
end
local stack={states={battle}};function stack:top()return self.states[#self.states]end
local game={stack=stack,save={inventory={MASTER_BALL=1,ULTRA_BALL=7,POKE_BALL=12,GREAT_BALL=0}},data={}}
local model=Models.capture(game)
check(model and #model.rows==3,'capture odds exposes all and only available balls')
local by={};for _,row in ipairs(model.rows)do by[row.id]=row end
check(by.MASTER_BALL and by.ULTRA_BALL and by.POKE_BALL,'multiple Ball choices are modeled')
check(not by.GREAT_BALL,'unavailable zero-quantity Ball is omitted')
check(by.ULTRA_BALL.quantity==7 and by.POKE_BALL.quantity==12,'Ball quantities are preserved')
approx(by.MASTER_BALL.chance,100,1e-9,'Master Ball displays 100%')
local function expected(randMax,hpFactor)
  local maxhp,hp,rate=100,50,45
  local hpQuarter=math.max(1,math.floor(hp/4))
  local f=math.min(255,math.floor(math.floor(maxhp*255/hpFactor)/hpQuarter))
  local rolls=randMax+1
  local secondStage=rate+1
  return (secondStage/rolls*((f+1)/256))*100
end
approx(by.ULTRA_BALL.chance,expected(150,12),1e-9,'Ultra Ball chance uses current battle formula')
approx(by.POKE_BALL.chance,expected(255,12),1e-9,'Poké Ball chance uses current battle formula')
check(model.rows[1].id=='MASTER_BALL','Ball list remains sorted by best current chance')

local f=assert(io.open(root..'/components/modular_overlays.lua','rb'));local source=f:read('*a');f:close()
local a=assert(source:find('local function drawCapture',1,true));local b=assert(source:find('local function collapsedTabIcon',a,true));local capture=source:sub(a,b-1)
check(capture:find('drawBallCard',1,true),'Capture Odds renderer remains Ball-centric')
check(not capture:find('drawTargetCard',1,true),'Capture Odds no longer renders redundant target Pokémon card/details')
check(capture:find('CURRENT ODDS',1,true) and capture:find('NO BALL AVAILABLE',1,true),'Capture Odds keeps useful comparison/availability states')
print('Capture Odds Ball -> chance model/presentation tests passed')
