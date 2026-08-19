-- Pokémon Essentials PBAnimation -> Gen1Recomp bridge.
-- This intentionally patches the engine AnimPlayer: Gen1Recomp 0.1.80 has a public
-- battle_anims registry for its native 8x8 format, but PBAnimation needs 192x192 cels,
-- true-colour blending, per-frame transforms, BG/FG planes and per-timing SFX.
return function(mod, DATA)
  local AnimPlayer = require("src.battle.AnimPlayer")
  local BattleState = require("src.battle.BattleState")
  local Sound = require("src.core.Sound")

  local SCALE = 160 / 512 -- source 512x384 -> 160x120; battle text begins at y=96
  local FIELD_H = 96
  local SRC_USER_X, SRC_USER_Y = 128, 224
  local SRC_TARGET_X, SRC_TARGET_Y = 384, 96
  local DST_USER_X, DST_USER_Y = SRC_USER_X * SCALE, SRC_USER_Y * SCALE
  local DST_TARGET_X, DST_TARGET_Y = SRC_TARGET_X * SCALE, SRC_TARGET_Y * SCALE

  -- KRS Wide battle composition. Canonical BattleBackGround assets are authored at
  -- 1920x950. The native bridge still renders into Gen1Recomp's battle canvas for
  -- vanilla/fallback layouts; when Kanto Rework UI owns the Wide battle presenter,
  -- a render.hud seam re-composites the Essentials layers around that presenter.
  local KRS_BG_W, KRS_BG_H = 1920, 950
  local WIDE_POS_X = KRS_BG_W / 512
  -- The 0.1.0 native bridge clips the 512x384 Essentials design to the 160x96
  -- Gen1 battle field. Preserve the same vertical framing in Wide instead of
  -- suddenly exposing the source's lower 77 pixels over KRS's footer area.
  local WIDE_SOURCE_FIELD_H = FIELD_H / SCALE
  local WIDE_POS_Y = KRS_BG_H / WIDE_SOURCE_FIELD_H
  -- UI 0.8.29+ fits battle art into a 190x190 box. The original bridge maps an
  -- Essentials 128px battler to 40 native pixels; 190/128 keeps effect size in
  -- the same visual relationship to the KRS battler art at the 1920x1080 base.
  local WIDE_EFFECT_SCALE = 190 / 128
  local activeSession = nil
  local function enabled()
    return mod.options:get("attack_animations") ~= false
  end

  local function norm(id)
    return tostring(id or ""):upper():gsub("[^A-Z0-9]", "")
  end

  -- Imported Essentials moves sometimes provide only the player-side sequence.
  -- A directional reflection is appropriate for projectiles/travel, but it is
  -- wrong for effects authored locally around a single battler because it also
  -- flips their local Y offset (the enemy Wrap-above-the-player bug). Classify
  -- each missing-opponent sequence from its authored visible effect geometry.
  local enemyFallbackClassCache=setmetatable({}, {__mode="k"})
  local function classifyEnemyFallback(anim)
    if not (anim and type(anim.frames)=="table") then return "reflect" end
    local cached=enemyFallbackClassCache[anim]
    if cached then return cached end
    local visible,targetLocal,userLocal=0,0,0
    for _,frame in ipairs(anim.frames) do
      for _,c in ipairs(frame) do
        local pattern=c[9]
        if pattern and pattern>=0 and c[8]==1 and (c[10] or 0)>0 then
          visible=visible+1
          local x,y=c[1] or 0,c[2] or 0
          local dt=(x-SRC_TARGET_X)^2+(y-SRC_TARGET_Y)^2
          local du=(x-SRC_USER_X)^2+(y-SRC_USER_Y)^2
          if dt<du then targetLocal=targetLocal+1
          elseif du<dt then userLocal=userLocal+1 end
        end
      end
    end
    local mode="reflect"
    if visible>0 and targetLocal==visible then mode="target"
    elseif visible>0 and userLocal==visible then mode="user" end
    enemyFallbackClassCache[anim]=mode
    return mode
  end

  -- Canonical 512x384 fallback used only when KRS live battler anchors are not
  -- available. Target/user preserve local screen-space offsets; mixed effects
  -- keep the established directional 180-degree point reflection.
  local function enemyFallbackPoint(mode,x,y)
    x,y=x or 0,y or 0
    if mode=="target" then
      return x+(SRC_USER_X-SRC_TARGET_X),y+(SRC_USER_Y-SRC_TARGET_Y)
    elseif mode=="user" then
      return x+(SRC_TARGET_X-SRC_USER_X),y+(SRC_TARGET_Y-SRC_USER_Y)
    end
    return (SRC_USER_X+SRC_TARGET_X)-x,(SRC_USER_Y+SRC_TARGET_Y)-y
  end

  local function needsWideStageCelScale(anim)
    if not (anim and anim.position == 4 and type(anim.frames) == "table") then return false end
    for _, frame in ipairs(anim.frames) do
      local count, left, right = 0, nil, nil
      for _, c in ipairs(frame) do
        local pattern = c[9]
        if pattern and pattern >= 0 and c[8] == 1 and (c[10] or 0) > 0 then
          local scale = (c[3] or 100) / 100
          local l = (c[1] or 0) - 96 * scale
          local r = (c[1] or 0) + 96 * scale
          count = count + 1
          if not left or l < left then left = l end
          if not right or r > right then right = r end
        end
      end
      if count >= 2 and left and right and left < 0 and right > 512 and (right - left) > 600 then
        return true
      end
    end
    return false
  end

  local original = {
    start = AnimPlayer.start, update = AnimPlayer.update, isDone = AnimPlayer.isDone,
    pollEffects = AnimPlayer.pollEffects, draw = AnimPlayer.draw,
    release = AnimPlayer.release, finalSprites = AnimPlayer.finalSprites,
  }
  local originalDrawPicsLayer = BattleState.drawPicsLayer

  local shader
  local function getShader()
    if shader ~= nil then return shader or nil end
    local g = love and love.graphics
    if not (g and g.newShader) then shader = false; return nil end
    local code = [[
      extern vec4 krs_overlay;
      extern vec4 krs_tone;
      extern float krs_hue;
      vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
        vec4 px = Texel(tex, tc) * color;
        float c = cos(krs_hue), s = sin(krs_hue);
        mat3 toYIQ = mat3(0.299,0.587,0.114, 0.596,-0.274,-0.322, 0.211,-0.523,0.312);
        mat3 toRGB = mat3(1.0,0.956,0.621, 1.0,-0.272,-0.647, 1.0,-1.106,1.703);
        vec3 yiq = toYIQ * px.rgb;
        float I = yiq.y * c - yiq.z * s;
        float Q = yiq.y * s + yiq.z * c;
        px.rgb = clamp(toRGB * vec3(yiq.x, I, Q), 0.0, 1.0);
        px.rgb = clamp(px.rgb + krs_tone.rgb, 0.0, 1.0);
        float gray = dot(px.rgb, vec3(0.299,0.587,0.114));
        px.rgb = mix(px.rgb, vec3(gray), clamp(krs_tone.a,0.0,1.0));
        px.rgb = mix(px.rgb, krs_overlay.rgb, clamp(krs_overlay.a,0.0,1.0));
        return px;
      }
    ]]
    local ok, sh = pcall(g.newShader, code)
    shader = ok and sh or false
    return shader or nil
  end

  local function withFieldScissor(fn)
    local g = love.graphics
    if not (g and g.getScissor and g.intersectScissor and g.setScissor) then return fn() end
    local x,y,w,h = g.getScissor()
    g.intersectScissor(0,0,160,FIELD_H)
    local ok, err = pcall(fn)
    if x then g.setScissor(x,y,w,h) else g.setScissor() end
    if not ok then error(err,0) end
  end

  local function newSession(owner, anim, moveId, attackerIsPlayer, enemyFallbackMode)
    local s = {
      owner=owner, anim=anim, moveId=moveId, attackerIsPlayer=attackerIsPlayer,
      enemyFallbackMode=enemyFallbackMode,
      wideStageCelScale=needsWideStageCelScale(anim),
      tick=0, frame=0, done=false, images={}, quads={}, sources={},
      bg={ file=nil, x=0,y=0,opacity=0,r=0,g=0,b=0,a=0 },
      fg={ file=nil, x=0,y=0,opacity=0,r=0,g=0,b=0,a=0 },
      bgTween=nil, fgTween=nil,
    }

    function s:image(file)
      if not file then return nil end
      local cached=self.images[file]
      if cached ~= nil then return cached or nil end
      local ok,img=pcall(love.graphics.newImage, mod.assets:path("assets/animations/"..file))
      if ok and img then
        if img.setFilter then img:setFilter("nearest","nearest") end
        self.images[file]=img
      else
        self.images[file]=false
        mod.log:warn("animation image unavailable: %s", tostring(file))
      end
      return self.images[file] or nil
    end

    function s:quad(file, pattern)
      local img=self:image(file); if not img then return nil end
      local by=self.quads[file]; if not by then by={}; self.quads[file]=by end
      local q=by[pattern]
      if q==nil then
        local iw,ih=img:getWidth(),img:getHeight()
        local x=(pattern % 5)*192; local y=math.floor(pattern/5)*192
        if x+192<=iw and y+192<=ih then q=love.graphics.newQuad(x,y,192,192,iw,ih) else q=false end
        by[pattern]=q
      end
      return q or nil
    end

    function s:playSound(t)
      if not t.sfxId then return end
      local game=mod.game; local d=game and game.data
      if not d then return end
      local src=Sound.playStereo(d,t.sfxId)
      if not src then return end
      if src.setPitch then pcall(src.setPitch,src,(t.pitch or 100)/100) end
      if src.getVolume and src.setVolume then
        local ok,v=pcall(src.getVolume,src)
        if ok then pcall(src.setVolume,src,v*((t.volume or 100)/100)) end
      end
      self.sources[#self.sources+1]=src
    end

    local function copyPlane(p)
      return {file=p.file,x=p.x,y=p.y,opacity=p.opacity,r=p.r,g=p.g,b=p.b,a=p.a}
    end
    local function setPlane(p,t)
      p.file=t.file or nil
      p.x=t.bgX or 0; p.y=t.bgY or 0; p.opacity=t.opacity or 0
      p.r=t.colorRed or 0; p.g=t.colorGreen or 0; p.b=t.colorBlue or 0; p.a=t.colorAlpha or 0
    end
    local function startTween(self, which, t)
      local p=self[which]; local from=copyPlane(p); local to=copyPlane(p)
      if t.bgX~=nil then to.x=t.bgX end; if t.bgY~=nil then to.y=t.bgY end
      if t.opacity~=nil then to.opacity=t.opacity end
      if t.colorRed~=nil then to.r=t.colorRed end; if t.colorGreen~=nil then to.g=t.colorGreen end
      if t.colorBlue~=nil then to.b=t.colorBlue end; if t.colorAlpha~=nil then to.a=t.colorAlpha end
      self[which.."Tween"]={from=from,to=to,start=t.frame or self.frame,duration=math.max(1,t.duration or 5)}
    end
    local function advanceTween(self,which)
      local tw=self[which.."Tween"]; if not tw then return end
      local p=self[which]; local f=math.max(0,math.min(1,(self.frame-tw.start)/tw.duration))
      for _,k in ipairs({"x","y","opacity","r","g","b","a"}) do p[k]=tw.from[k]+(tw.to[k]-tw.from[k])*f end
      if f>=1 then self[which.."Tween"]=nil end
    end

    function s:applyTimings(frame)
      for _,t in ipairs(self.anim.timings or {}) do
        if (t.frame or 0)==frame then
          local typ=t.timingType or 0
          if typ==0 then self:playSound(t)
          elseif typ==1 then setPlane(self.bg,t)
          elseif typ==2 then startTween(self,"bg",t)
          elseif typ==3 then setPlane(self.fg,t)
          elseif typ==4 then startTween(self,"fg",t) end
        end
      end
      advanceTween(self,"bg"); advanceTween(self,"fg")
    end

    function s:update()
      if self.done then return end
      self.tick=self.tick+1
      local nf=math.floor(self.tick/3)
      if nf~=self.frame then
        self.frame=nf
        if self.frame>=#self.anim.frames then self.done=true; return end
        self:applyTimings(self.frame)
      end
    end

    function s:currentCells()
      return self.anim.frames[self.frame+1] or {}
    end
    function s:roleCell(pattern)
      for _,c in ipairs(self:currentCells()) do if c[9]==pattern then return c end end
      return nil
    end

    local function blendMode(v)
      if v==1 then return "add" end
      if v==2 then return "subtract" end
      return "alpha"
    end

    function s:drawCell(c)
      local pattern=c[9]; if pattern<0 or c[8]~=1 or (c[10] or 0)<=0 then return end
      local img=self:image(self.anim.graphic); local q=img and self:quad(self.anim.graphic,pattern)
      if not (img and q) then return end
      local g=love.graphics
      local oldMode,oldAlpha=g.getBlendMode()
      pcall(g.setBlendMode,blendMode(c[7]),"alphamultiply")
      local sh=getShader(); if sh then
        g.setShader(sh)
        pcall(sh.send,sh,"krs_overlay",{(c[11] or 0)/255,(c[12] or 0)/255,(c[13] or 0)/255,(c[14] or 0)/255})
        pcall(sh.send,sh,"krs_tone",{(c[15] or 0)/255,(c[16] or 0)/255,(c[17] or 0)/255,(c[18] or 0)/255})
        pcall(sh.send,sh,"krs_hue",math.rad(self.anim.hue or 0))
      end
      g.setColor(1,1,1,(c[10] or 255)/255)
      local sx=(c[3] or 100)/100*SCALE; local sy=(c[4] or 100)/100*SCALE
      if (c[6] or 0)~=0 then sx=-sx end
      local cx,cy=c[1] or 0,c[2] or 0
      if self.enemyFallbackMode then cx,cy=enemyFallbackPoint(self.enemyFallbackMode,cx,cy) end
      g.draw(img,q,cx*SCALE,cy*SCALE,math.rad(c[5] or 0),sx,sy,96,96)
      if sh then g.setShader() end
      g.setColor(1,1,1,1)
      pcall(g.setBlendMode,oldMode,oldAlpha)
    end

    function s:drawParticles(pass)
      withFieldScissor(function()
        for _,c in ipairs(self:currentCells()) do
          local pr=c[20] or 1
          local back=(pr==0 or pr==2)
          if (pass=="back" and back) or (pass=="front" and not back) then self:drawCell(c) end
        end
      end)
    end

    function s:drawPlane(p)
      if (p.opacity or 0)<=0 then return end
      withFieldScissor(function()
        local g=love.graphics
        if p.file then
          local img=self:image(p.file); if not img then return end
          local iw,ih=img:getWidth()*SCALE,img:getHeight()*SCALE
          if iw<1 or ih<1 then return end
          g.setColor(1,1,1,(p.opacity or 0)/255)
          local ox=(p.x or 0)*SCALE; local oy=(p.y or 0)*SCALE
          local startX=ox-math.ceil((ox+160)/iw)*iw
          local startY=oy-math.ceil((oy+FIELD_H)/ih)*ih
          for y=startY,FIELD_H,ih do for x=startX,160,iw do g.draw(img,x,y,0,SCALE,SCALE) end end
        else
          g.setColor((p.r or 0)/255,(p.g or 0)/255,(p.b or 0)/255,(p.opacity or 0)/255)
          g.rectangle("fill",0,0,160,FIELD_H)
        end
        g.setColor(1,1,1,1)
      end)
    end

    function s:drawBackground() self:drawPlane(self.bg) end
    function s:drawForeground() self:drawPlane(self.fg) end

    -- Draw one Essentials cel in KRS's canonical 1920x950 battle-background
    -- coordinate space. Positions are remapped to the Wide battle anchors, while
    -- sprite scale stays uniform so circles/beams are not stretched horizontally.
    function s:drawCellWide(c)
      local pattern=c[9]; if pattern<0 or c[8]~=1 or (c[10] or 0)<=0 then return end
      local img=self:image(self.anim.graphic); local q=img and self:quad(self.anim.graphic,pattern)
      if not (img and q) then return end
      local g=love.graphics
      local oldMode,oldAlpha=g.getBlendMode()
      pcall(g.setBlendMode,blendMode(c[7]),"alphamultiply")
      local sh=getShader(); if sh then
        g.setShader(sh)
        pcall(sh.send,sh,"krs_overlay",{(c[11] or 0)/255,(c[12] or 0)/255,(c[13] or 0)/255,(c[14] or 0)/255})
        pcall(sh.send,sh,"krs_tone",{(c[15] or 0)/255,(c[16] or 0)/255,(c[17] or 0)/255,(c[18] or 0)/255})
        pcall(sh.send,sh,"krs_hue",math.rad(self.anim.hue or 0))
      end
      g.setColor(1,1,1,(c[10] or 255)/255)
      -- Most move cels should stay visually relative to the battler art in Wide.
      -- A small subset of Essentials animations instead lays out multiple cels
      -- across the entire 512px battle stage (for example Surf, Earthquake and
      -- Fissure). Those source cels must use the stage scale in Wide or they no
      -- longer cover the full screen area they were authored to span.
      local wideScale = self.wideStageCelScale and WIDE_POS_X or WIDE_EFFECT_SCALE
      local sx=(c[3] or 100)/100*wideScale
      local sy=(c[4] or 100)/100*wideScale
      if (c[6] or 0)~=0 then sx=-sx end
      local cx,cy=c[1] or 0,c[2] or 0
      local px,py=cx*WIDE_POS_X,cy*WIDE_POS_Y
      if not self.wideStageCelScale then
        local user,target=nil,nil
        if type(self.krsAnchors)=='table' then
          local function center(box)
            if not box then return nil end
            if type(box.center)=='table' then return {x=box.center.x,y=box.center.y} end
            return {x=(box.x or 0)+(box.w or 0)/2,y=(box.y or 0)+(box.h or 0)/2-86}
          end
          local player=center(self.krsAnchors.player);local opponent=center(self.krsAnchors.opponent)
          user=center(self.krsAnchors.attacker or self.krsAnchors.source)
            or (self.attackerIsPlayer and player or opponent)
          target=center(self.krsAnchors.defender or self.krsAnchors.target)
            or (self.attackerIsPlayer and opponent or player)
        end
        if user and target then
          if self.enemyFallbackMode=="target" then
            -- Target-local enemy fallbacks must keep their authored local X/Y
            -- offset instead of rotating that offset through the user→target axis.
            px=target.x+(cx-SRC_TARGET_X)*WIDE_EFFECT_SCALE
            py=target.y+(cy-SRC_TARGET_Y)*WIDE_EFFECT_SCALE
          elseif self.enemyFallbackMode=="user" then
            -- Same rule for self/user-local effects around the live attacker.
            px=user.x+(cx-SRC_USER_X)*WIDE_EFFECT_SCALE
            py=user.y+(cy-SRC_USER_Y)*WIDE_EFFECT_SCALE
          else
            -- Dedicated opponent sequences and mixed/directional fallbacks use
            -- the existing 0.1.6 live attacker→defender projection. This is the
            -- reflect semantic in Wide mode; pre-reflecting would transform twice.
            local dx,dy=SRC_TARGET_X-SRC_USER_X,SRC_TARGET_Y-SRC_USER_Y
            local len2=dx*dx+dy*dy
            local qx,qy=cx-SRC_USER_X,cy-SRC_USER_Y
            local t=(qx*dx+qy*dy)/len2
            local perp=(qx*(-dy)+qy*dx)/math.sqrt(len2)
            local adx,ady=target.x-user.x,target.y-user.y;local alen=math.sqrt(adx*adx+ady*ady)
            local nx,ny=0,0;if alen>0 then nx,ny=-ady/alen,adx/alen end
            px=user.x+adx*t+nx*perp*WIDE_EFFECT_SCALE
            py=user.y+ady*t+ny*perp*WIDE_EFFECT_SCALE
          end
        elseif self.enemyFallbackMode then
          -- No live anchor contract: fall back to the canonical Essentials
          -- opponent transform used by the native 160x96 path.
          local fx,fy=enemyFallbackPoint(self.enemyFallbackMode,cx,cy)
          px,py=fx*WIDE_POS_X,fy*WIDE_POS_Y
        end
      end
      g.draw(img,q,px,py,math.rad(c[5] or 0),sx,sy,96,96)
      if sh then g.setShader() end
      g.setColor(1,1,1,1)
      pcall(g.setBlendMode,oldMode,oldAlpha)
    end

    function s:drawParticlesWide(pass)
      for _,c in ipairs(self:currentCells()) do
        local pr=c[20] or 1
        local back=(pr==0 or pr==2)
        if (pass=="back" and back) or (pass=="front" and not back) then
          self:drawCellWide(c)
        end
      end
    end

    function s:drawPlaneWide(p)
      if (p.opacity or 0)<=0 then return end
      local g=love.graphics
      if p.file then
        local img=self:image(p.file); if not img then return end
        local iw,ih=img:getWidth()*WIDE_POS_X,img:getHeight()*WIDE_POS_Y
        if iw<1 or ih<1 then return end
        g.setColor(1,1,1,(p.opacity or 0)/255)
        local ox=(p.x or 0)*WIDE_POS_X; local oy=(p.y or 0)*WIDE_POS_Y
        local startX=ox-math.ceil((ox+KRS_BG_W)/iw)*iw
        local startY=oy-math.ceil((oy+KRS_BG_H)/ih)*ih
        for y=startY,KRS_BG_H,ih do
          for x=startX,KRS_BG_W,iw do
            g.draw(img,x,y,0,WIDE_POS_X,WIDE_POS_Y)
          end
        end
      else
        g.setColor((p.r or 0)/255,(p.g or 0)/255,(p.b or 0)/255,(p.opacity or 0)/255)
        g.rectangle("fill",0,0,KRS_BG_W,KRS_BG_H)
      end
      g.setColor(1,1,1,1)
    end

    local function withWideStage(drawTransform, fn)
      local g=love.graphics
      if not (g and g.push and g.pop) then return fn() end
      local t=drawTransform or {}
      local x,y=t.x or 0,t.y or 0
      local r,sx,sy=t.r or 0,t.sx or 1,t.sy or t.sx or 1
      local ox,oy=t.ox or 0,t.oy or 0
      local kx,ky=t.kx or 0,t.ky or 0
      g.push("all")
      -- KRS backgrounds are unrotated today. Preserve clipping for that normal
      -- path; if another presenter rotates/shears the battle, its own clip stays
      -- authoritative rather than applying a wrong axis-aligned rectangle.
      if r==0 and kx==0 and ky==0 and g.intersectScissor then
        local left=x-ox*sx; local top=y-oy*sy
        local right=left+KRS_BG_W*sx; local bottom=top+KRS_BG_H*sy
        if right<left then left,right=right,left end
        if bottom<top then top,bottom=bottom,top end
        g.intersectScissor(left,top,right-left,bottom-top)
      end
      if g.translate then g.translate(x,y) end
      if r~=0 and g.rotate then g.rotate(r) end
      if g.scale then g.scale(sx,sy) end
      if (kx~=0 or ky~=0) and g.shear then g.shear(kx,ky) end
      if (ox~=0 or oy~=0) and g.translate then g.translate(-ox,-oy) end
      local ok,err=pcall(fn)
      g.pop()
      if not ok then error(err,0) end
    end

    function s:drawWideBack(drawTransform)
      withWideStage(drawTransform,function()
        self:drawPlaneWide(self.bg)
        self:drawParticlesWide("back")
      end)
    end

    function s:drawWideFront(drawTransform)
      withWideStage(drawTransform,function()
        self:drawParticlesWide("front")
        self:drawPlaneWide(self.fg)
      end)
    end

    function s:release()
      for _,img in pairs(self.images) do if img and img.release then pcall(img.release,img) end end
      for _,by in pairs(self.quads) do for _,q in pairs(by) do if q and q.release then pcall(q.release,q) end end end
      self.images={}; self.quads={}
      self.sources={}
    end

    s:applyTimings(0)
    return s
  end

  function AnimPlayer:start(moveId, attackerIsPlayer, opts)
    if not enabled() then
      self._krs=nil
      return original.start(self,moveId,attackerIsPlayer,opts)
    end
    local rec=DATA.moves[norm(moveId)]
    if rec then
      local anim=(not attackerIsPlayer and rec.opp) or rec.player
      if anim then
        local enemyFallbackMode=nil
        if attackerIsPlayer==false and rec.opp==nil and rec.player~=nil then
          enemyFallbackMode=classifyEnemyFallback(rec.player)
        end
        self._krs=newSession(self,anim,moveId,attackerIsPlayer,enemyFallbackMode)
        activeSession=self._krs
        self.steps,self.events={},{}
        self.stepIndex,self.stepLeft,self.elapsed,self.eventCursor=1,0,0,1
        return
      end
    end
    self._krs=nil
    return original.start(self,moveId,attackerIsPlayer,opts)
  end

  function AnimPlayer:update()
    if self._krs then return self._krs:update() end
    return original.update(self)
  end
  function AnimPlayer:isDone()
    if self._krs then return self._krs.done end
    return original.isDone(self)
  end
  function AnimPlayer:pollEffects()
    if self._krs then return {} end
    return original.pollEffects(self)
  end
  function AnimPlayer:draw(colorFn)
    if self._krs then
      self._krs:drawParticles("front")
      self._krs:drawForeground()
      return
    end
    return original.draw(self,colorFn)
  end
  function AnimPlayer:finalSprites()
    if self._krs then return nil end
    return original.finalSprites(self)
  end
  function AnimPlayer:release()
    if self._krs then
      if activeSession==self._krs then activeSession=nil end
      self._krs:release(); self._krs=nil
    end
    return original.release(self)
  end

  local function drawSideTransformed(state, side, c, slide, sx, sy, skipMenuClip)
    if c and (c[8]~=1 or (c[10] or 255)<=0) then return end
    local g=love.graphics
    if not (g.newCanvas and g.getCanvas and g.setCanvas) then
      return originalDrawPicsLayer(state,slide,sx,sy,side,skipMenuClip)
    end
    state._krsSideCanvases=state._krsSideCanvases or {}
    local cv=state._krsSideCanvases[side]
    if not cv then
      cv=g.newCanvas(160,144); if cv.setFilter then cv:setFilter("nearest","nearest") end
      state._krsSideCanvases[side]=cv
    end
    local prev=g.getCanvas(); local sr,sg,sb,sa=g.getColor()
    g.setCanvas(cv); g.clear(0,0,0,0); g.setColor(1,1,1,1)
    originalDrawPicsLayer(state,slide,sx,sy,side,skipMenuClip)
    g.setCanvas(prev)
    local roleUser = (side=="player") == (state.animAttackerIsPlayer==true)
    local px,py=roleUser and DST_USER_X or DST_TARGET_X, roleUser and DST_USER_Y or DST_TARGET_Y
    local srcx,srcy=roleUser and SRC_USER_X or SRC_TARGET_X, roleUser and SRC_USER_Y or SRC_TARGET_Y
    local dx,dy=0,0; local zx,zy=1,1; local ang=0; local mir=false; local alpha=1
    if c then
      dx=((c[1] or srcx)-srcx)*SCALE; dy=((c[2] or srcy)-srcy)*SCALE
      zx=(c[3] or 100)/100; zy=(c[4] or 100)/100; ang=math.rad(c[5] or 0); mir=(c[6] or 0)~=0; alpha=(c[10] or 255)/255
    end
    if mir then zx=-zx end
    g.push(); g.translate(px+dx,py+dy); g.rotate(ang); g.scale(zx,zy); g.translate(-px,-py)
    g.setColor(1,1,1,alpha); g.draw(cv,0,0); g.pop(); g.setColor(sr,sg,sb,sa)
  end

  function BattleState:drawPicsLayer(slide,sx,sy,onlySide,skipMenuClip)
    local sess=self.animPlayer and self.animPlayer._krs
    if not sess then return originalDrawPicsLayer(self,slide,sx,sy,onlySide,skipMenuClip) end
    -- During the SGB wavy pre-pass, preserve the engine's native path; drawing
    -- true-colour Essentials planes into the grayscale source canvas would corrupt them.
    if self.grayPics then return originalDrawPicsLayer(self,slide,sx,sy,onlySide,skipMenuClip) end
    if not onlySide then
      sess:drawBackground(); sess:drawParticles("back")
    end
    local u=sess:roleCell(-1); local t=sess:roleCell(-2)
    local playerCell = self.animAttackerIsPlayer and u or t
    local enemyCell  = self.animAttackerIsPlayer and t or u
    if onlySide=="player" then
      drawSideTransformed(self,"player",playerCell,slide,sx,sy,skipMenuClip)
    elseif onlySide=="enemy" then
      drawSideTransformed(self,"enemy",enemyCell,slide,sx,sy,skipMenuClip)
    else
      drawSideTransformed(self,"enemy",enemyCell,slide,sx,sy,skipMenuClip)
      drawSideTransformed(self,"player",playerCell,slide,sx,sy,skipMenuClip)
      -- In SGB colour mode the HUD was composited before the pic pass; a source
      -- BG is inserted here to stay behind battlers, so redraw HUD chrome above it.
      if self.colorMode and self:colorMode() and self.drawHUDs then self:drawHUDs(slide) end
    end
  end

  -- KRS Wide compositor compatibility -------------------------------------------------
  -- Kanto Rework UI draws its high-resolution battle presenter in render.hud, after
  -- BattleState's native canvas. A native-only animation therefore ends up below the
  -- canonical BattleBackGround. Install an OUTER hook so we can:
  --   1. observe the exact 1920x950 background draw;
  --   2. inject Essentials BG/back-priority particles immediately after that draw;
  --   3. let KRS continue with its Pokémon/HUD;
  --   4. inject front-priority particles/FG after KRS returns.
  -- The draw monkey-patch exists only for the duration of one active KRS battle HUD
  -- call and is restored even if the downstream presenter raises.
  local unpackFn=table.unpack or unpack
  local function pack(...) return {n=select("#",...),...} end

  local function drawableSize(drawable)
    if not drawable then return nil,nil end
    local gw=drawable.getWidth; local gh=drawable.getHeight
    if type(gw)~="function" or type(gh)~="function" then return nil,nil end
    local okW,w=pcall(gw,drawable); local okH,h=pcall(gh,drawable)
    if not (okW and okH) then return nil,nil end
    return w,h
  end

  local function quadViewportSize(q)
    if not q then return nil,nil end
    local gv=q.getViewport
    if type(gv)~="function" then return nil,nil end
    local ok,x,y,w,h=pcall(gv,q)
    if not ok then return nil,nil end
    return w,h
  end

  local function parseDrawTransform(...)
    local a={...}; local i=1
    -- love.graphics.draw(drawable, quad, x, y, ...) overload: after removing
    -- drawable in our wrapper, a[1] is Quad instead of x.
    if type(a[1])~="number" and a[1]~=nil then i=2 end
    return {
      x=tonumber(a[i]) or 0, y=tonumber(a[i+1]) or 0,
      r=tonumber(a[i+2]) or 0, sx=tonumber(a[i+3]) or 1,
      sy=tonumber(a[i+4]) or tonumber(a[i+3]) or 1,
      ox=tonumber(a[i+5]) or 0, oy=tonumber(a[i+6]) or 0,
      kx=tonumber(a[i+7]) or 0, ky=tonumber(a[i+8]) or 0,
    }
  end

  local function canonicalWideBackgroundTransform(drawable,...)
    local args={...}
    local baseW,baseH=nil,nil
    if args[1]~=nil and type(args[1])~="number" then
      baseW,baseH=quadViewportSize(args[1])
    end
    if not (baseW and baseH) then
      baseW,baseH=drawableSize(drawable)
    end
    if not (baseW and baseH) then return nil end
    local t=parseDrawTransform(...)
    if t.r~=0 or t.kx~=0 or t.ky~=0 then return nil end
    local outW=math.abs(baseW*(t.sx or 1))
    local outH=math.abs(baseH*(t.sy or 1))
    local tol=4
    if math.abs(outW-KRS_BG_W)<=tol and math.abs(outH-KRS_BG_H)<=tol then
      return t
    end
    return nil
  end

  local function krsUiHandle()
    local ok,handle=pcall(mod.find,"ui")
    return ok and handle or nil
  end
  local function krsGraphicsHandle()
    local ok,handle=pcall(mod.find,"graphics")
    return ok and handle or nil
  end
  local function graphicsLiveBounds()
    local handle=krsGraphicsHandle();local ex=handle and handle.exports;local service=ex and ex.battleVisuals
    if not (service and type(service.snapshot)=='function') then return nil end
    local ok,value=pcall(service.snapshot);return ok and type(value)=='table' and value.bounds or nil
  end
  local function krsUiActive() return krsUiHandle()~=nil end
  local function krsUiLayerSeam()
    local handle=krsUiHandle();local ex=handle and handle.exports
    return type(ex)=='table' and tonumber(ex.battleAnimationLayerContract or 0)>=2
  end

  -- Explicit KRS compositor seam. UI 0.8.54+ calls both authored animation
  -- sub-layers after the Pokémon, matching the KRS battle contract:
  -- BACKGROUND -> POKEMON -> MOVE/BUFF/DEBUFF/STATUS -> HUD -> HEADER/FOOTER.
  -- Anchors are the actual per-frame rendered battler bounds, so moving a sprite
  -- in Live Graphics immediately moves projectile/self/target effects too.
  mod.exports.drawKrsWideLayer=function(layer,drawTransform,anchors)
    local sess=activeSession
    if not (sess and not sess.done and krsUiLayerSeam()) then return false end
    sess.krsAnchors=anchors or graphicsLiveBounds() or sess.krsAnchors
    if layer=='back' then sess:drawWideBack(drawTransform);sess._krsBackConsumed=true;return true end
    if layer=='front' then sess:drawWideFront(drawTransform);sess._krsFrontConsumed=true;return true end
    return false
  end

  mod.hooks:wrap("render.hud",function(next,game,viewport)
    local sess=activeSession
    if not (sess and not sess.done and krsUiActive()) then
      return next(game,viewport)
    end
    -- New KRS UI owns both Wide animation layers explicitly inside its battle
    -- compositor. Do not monkey-inject a second copy after global chrome.
    if krsUiLayerSeam() then
      sess._krsBackConsumed=false;sess._krsFrontConsumed=false
      return next(game,viewport)
    end
    local g=love and love.graphics
    if not (g and type(g.draw)=="function") then return next(game,viewport) end

    local oldDraw=g.draw
    local bgTransform=nil
    local injecting=false
    local patched
    patched=function(drawable,...)
      local result=pack(oldDraw(drawable,...))
      if not injecting and not bgTransform then
        local detected=canonicalWideBackgroundTransform(drawable,...)
        if detected then
          bgTransform=detected
          injecting=true
          -- Never let our own sprites re-enter this detector.
          g.draw=oldDraw
          local ok,err=pcall(sess.drawWideBack,sess,bgTransform)
          g.draw=patched
          injecting=false
          if not ok then error(err,0) end
        end
      end
      return unpackFn(result,1,result.n)
    end

    g.draw=patched
    local downstream=pack(pcall(next,game,viewport))
    g.draw=oldDraw
    if not downstream[1] then error(downstream[2],0) end

    -- Only overlay when the canonical background was actually observed. This
    -- keeps third-party battle renderers and unsupported layouts on the native
    -- fallback instead of guessing their geometry.
    if bgTransform and activeSession==sess and not sess.done then
      sess:drawWideFront(bgTransform)
    end
    return unpackFn(downstream,2,downstream.n)
  end,10000)

  mod.exports.playerInstalled=true
  mod.exports.attackAnimationsEnabled=enabled
  mod.exports.enemyFallbackPlacement=true
  mod.exports.enemyFallbackPlacementContract=1
  mod.exports.wideLayeringFix=true
  mod.exports.wideLayeringContract=2
end
