-- Developer-only runtime glyph board.
-- Displays every canonical Type Token and Status Token using the exact same
-- components used by Party/Summary/Moves. Enabled only by the explicit mod
-- option `glyph_test_board`; default is false.
return function(deps)
  local TypeChip=assert(deps.TypeChip)
  local TypeIcon=assert(deps.TypeIcon)
  local StatusToken=assert(deps.StatusToken)
  local Board={}
  local fonts={}
  local TYPES={"NORMAL","FIRE","WATER","ELECTRIC","GRASS","ICE","FIGHTING","POISON","GROUND","FLYING","PSYCHIC","BUG","ROCK","GHOST","DRAGON","DARK","STEEL","FAIRY"}
  local STATUSES={"POISONED","BADLY_POISONED","BURNED","PARALYZED","ASLEEP","FROZEN","FAINTED"}

  local function font(px)
    px=math.max(8,math.floor(px+.5));if not fonts[px] then fonts[px]=love.graphics.newFont(px) end;return fonts[px]
  end
  local function set(c,a) c=c or {1,1,1,1};love.graphics.setColor(c[1],c[2],c[3],(c[4] or 1)*(a or 1)) end
  local function transform(viewport)
    local w=math.max(1,tonumber(viewport and viewport.width) or 1920)
    local h=math.max(1,tonumber(viewport and viewport.height) or 1080)
    local s=math.min(w/1920,h/1080)
    return s,(w-1920*s)/2,(h-1080*s)/2,w,h
  end

  function Board.draw(theme,viewport)
    local s,ox,oy,w,h=transform(viewport)
    if s<=0 then return false end
    love.graphics.push("all");love.graphics.origin()
    set({20/255,19/255,17/255,1});love.graphics.rectangle("fill",0,0,w,h)
    set({240/255,232/255,209/255,1});love.graphics.rectangle("fill",ox,oy,1920*s,1080*s)

    local function px(x) return ox+x*s end
    local function py(y) return oy+y*s end
    set(theme.colors.ink);love.graphics.setFont(font(28*s));love.graphics.print("KRS GLYPH RUNTIME BOARD",px(64),py(48))
    set(theme.colors.muted);love.graphics.setFont(font(14*s));love.graphics.print("PROFILE: "..tostring(theme.profile or "standard"):upper(),px(64),py(88))

    set(theme.colors.ink);love.graphics.setFont(font(18*s));love.graphics.print("18 TYPE TOKENS — FIGMA 618:2865",px(64),py(132))
    for i,kind in ipairs(TYPES) do
      local col=(i-1)%6;local row=math.floor((i-1)/6)
      TypeChip.draw(kind,px(64+col*288),py(174+row*76),s,theme,1)
    end

    set(theme.colors.ink);love.graphics.setFont(font(18*s));love.graphics.print("7 STATUS TOKENS — FIGMA 149:116 / 405:3994",px(64),py(438))
    for i,status in ipairs(STATUSES) do
      local col=(i-1)%4;local row=math.floor((i-1)/4)
      StatusToken.drawToken(status,nil,px(64+col*420),py(480+row*88),s,theme,1)
    end

    set(theme.colors.ink);love.graphics.setFont(font(18*s));love.graphics.print("COMPACT ICONS — 32×32 SOURCE GEOMETRY",px(64),py(690))
    for i,kind in ipairs(TYPES) do
      local col=(i-1)%9;local row=math.floor((i-1)/9)
      local cx=px(92+col*112);local cy=py(748+row*82)
      TypeIcon.draw(kind,cx,cy,32*s,theme.typeColors[kind],1)
    end
    for i,status in ipairs(STATUSES) do
      local cx=px(1128+(i-1)*96);local cy=py(748)
      StatusToken.drawIcon(status,nil,cx,cy,32*s,theme,1)
    end

    set(theme.colors.muted);love.graphics.setFont(font(13*s));love.graphics.print("Linear filtering • same glyph files for Standard / Protanopia / Deuteranopia / Tritanopia",px(64),py(1000))
    love.graphics.pop();return true
  end
  return Board
end
