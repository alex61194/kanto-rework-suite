local root=assert(arg[1],'root required')
local DATA=assert(loadfile(root..'/data/gen1_anims.lua'))()

-- Minimal Gen1Recomp/LÖVE unit stubs. This executes the production installer and
-- production draw paths; it is not an interactive Gen1Recomp runtime test.
local AnimPlayer={}
function AnimPlayer:start() self.nativeStarted=true end
function AnimPlayer:update() end
function AnimPlayer:isDone() return false end
function AnimPlayer:pollEffects() return {} end
function AnimPlayer:draw() end
function AnimPlayer:release() end
function AnimPlayer:finalSprites() end
local BattleState={drawPicsLayer=function() end}
local Sound={playStereo=function() return nil end}
package.preload['src.battle.AnimPlayer']=function() return AnimPlayer end
package.preload['src.battle.BattleState']=function() return BattleState end
package.preload['src.core.Sound']=function() return Sound end

local draws={}
local fakeImage={}
function fakeImage:getWidth() return 8192 end
function fakeImage:getHeight() return 8192 end
function fakeImage:getDimensions() return 8192,8192 end
function fakeImage:setFilter() end
function fakeImage:release() end
local fakeQuad={release=function() end}
local blendMode,blendAlpha='alpha','alphamultiply'
love={graphics={}}
local g=love.graphics
function g.newImage() return fakeImage end
function g.newQuad() return fakeQuad end
function g.getBlendMode() return blendMode,blendAlpha end
function g.setBlendMode(m,a) blendMode,blendAlpha=m,a end
function g.newShader() return nil end
function g.setShader() end
function g.setColor() end
function g.draw(img,q,x,y,r,sx,sy,ox,oy)
  draws[#draws+1]={x=x,y=y,r=r,sx=sx,sy=sy,ox=ox,oy=oy}
end
function g.rectangle() end
function g.push() end
function g.pop() end
function g.intersectScissor() end
function g.translate() end
function g.rotate() end
function g.scale() end
function g.shear() end
function g.getScissor() return nil end
function g.setScissor() end

local mod={
  options={get=function(_,key) assert(key=='attack_animations'); return true end},
  assets={path=function(_,p) return p end},
  log={warn=function() end},
  hooks={wrap=function() end},
  exports={},
}
function mod.find(id)
  if id=='ui' then return {exports={battleAnimationLayerContract=2}} end
  return nil
end

local install=assert(loadfile(root..'/scripts/essentials_player.lua'))()
install(mod,DATA)

local function player()
  return setmetatable({}, {__index=AnimPlayer})
end
local function visibleCell(anim, pass)
  for fi,frame in ipairs(anim.frames) do
    for _,c in ipairs(frame) do
      local pattern=c[9]
      local pr=c[20] or 1
      local back=(pr==0 or pr==2)
      if pattern and pattern>=0 and c[8]==1 and (c[10] or 0)>0
         and ((pass=='back' and back) or (pass=='front' and not back)) then
        return c,fi-1
      end
    end
  end
  error('no visible '..pass..' cel')
end
local function advanceTo(p,frameIndex)
  for _=1,frameIndex*3 do p:update() end
end
local function near(a,b,msg)
  assert(math.abs(a-b)<1e-6,(msg or 'mismatch')..': '..tostring(a)..' vs '..tostring(b))
end
local SCALE=160/512
local WIDE_X=1920/512
local WIDE_EFFECT=190/128
local SUX,SUY,STX,STY=128,224,384,96
local anchors={
  player={center={x=420,y=690}},
  opponent={center={x=1460,y=245}},
  attacker={center={x=1460,y=245}},
  defender={center={x=420,y=690}},
}
local function clear() draws={} end
local function firstDraw() assert(#draws>0,'expected draw'); return draws[1] end

-- Target-local: production Wide path must preserve local target offset directly.
do
  local p=player(); p:start('WRAP',false,{})
  local c,fi=visibleCell(DATA.moves.WRAP.player,'front'); advanceTo(p,fi)
  clear(); assert(mod.exports.drawKrsWideLayer('front',{},anchors)==true)
  local d=firstDraw()
  near(d.x,anchors.defender.center.x+(c[1]-STX)*WIDE_EFFECT,'WRAP wide target x')
  near(d.y,anchors.defender.center.y+(c[2]-STY)*WIDE_EFFECT,'WRAP wide target y')
  -- Native/fallback path uses the contributor-equivalent canonical translation.
  clear(); p:draw(); d=firstDraw()
  near(d.x,(c[1]+SUX-STX)*SCALE,'WRAP native target x')
  near(d.y,(c[2]+SUY-STY)*SCALE,'WRAP native target y')
end

-- User-local: effect remains local to the live enemy attacker.
do
  local p=player(); p:start('RECOVER',false,{})
  local c,fi=visibleCell(DATA.moves.RECOVER.player,'front'); advanceTo(p,fi)
  clear(); assert(mod.exports.drawKrsWideLayer('front',{},anchors)==true)
  local d=firstDraw()
  near(d.x,anchors.attacker.center.x+(c[1]-SUX)*WIDE_EFFECT,'RECOVER wide user x')
  near(d.y,anchors.attacker.center.y+(c[2]-SUY)*WIDE_EFFECT,'RECOVER wide user y')
end

local function projected(c)
  local user,target=anchors.attacker.center,anchors.defender.center
  local dx,dy=STX-SUX,STY-SUY
  local len2=dx*dx+dy*dy
  local qx,qy=c[1]-SUX,c[2]-SUY
  local t=(qx*dx+qy*dy)/len2
  local perp=(qx*(-dy)+qy*dx)/math.sqrt(len2)
  local adx,ady=target.x-user.x,target.y-user.y
  local alen=math.sqrt(adx*adx+ady*ady)
  local nx,ny=0,0
  if alen>0 then nx,ny=-ady/alen,adx/alen end
  return user.x+adx*t+nx*perp*WIDE_EFFECT,
         user.y+ady*t+ny*perp*WIDE_EFFECT
end

-- Mixed/directional fallback: retain 0.1.6 affine live projection (no pre-reflect).
do
  local p=player(); p:start('EMBER',false,{})
  local c,fi=visibleCell(DATA.moves.EMBER.player,'front'); advanceTo(p,fi)
  clear(); assert(mod.exports.drawKrsWideLayer('front',{},anchors)==true)
  local d=firstDraw(); local ex,ey=projected(c)
  near(d.x,ex,'EMBER reflect x'); near(d.y,ey,'EMBER reflect y')
end

-- Dedicated opponent sequence: same 0.1.6 projection, no fallback classification.
do
  assert(DATA.moves.ABSORB.opp,'ABSORB fixture needs dedicated opp')
  local p=player(); p:start('ABSORB',false,{})
  local c,fi=visibleCell(DATA.moves.ABSORB.opp,'front'); advanceTo(p,fi)
  clear(); assert(mod.exports.drawKrsWideLayer('front',{},anchors)==true)
  local d=firstDraw(); local ex,ey=projected(c)
  near(d.x,ex,'ABSORB dedicated opp x'); near(d.y,ey,'ABSORB dedicated opp y')
end

-- Stage-spanning Wide sequence: preserve 0.1.6 full-stage coordinates.
do
  local p=player(); p:start('EARTHQUAKE',false,{})
  local pass='front'; local ok,c,fi=pcall(visibleCell,DATA.moves.EARTHQUAKE.player,pass)
  if not ok then pass='back'; c,fi=visibleCell(DATA.moves.EARTHQUAKE.player,pass) end
  advanceTo(p,fi)
  clear(); assert(mod.exports.drawKrsWideLayer(pass,{},anchors)==true)
  local d=firstDraw()
  near(d.x,c[1]*WIDE_X,'EARTHQUAKE stage x')
  -- vertical stage scale uses the source field height inherited by production;
  -- x is sufficient here to prove the local-anchor override is bypassed.
end

print('Production enemy fallback unit paths passed: target/user/reflect/dedicated/stage')
