local Header={}

local function context(Core)
  if Core and type(Core.journalContext)=="function" then
    local ok,v=pcall(Core.journalContext)
    if ok and type(v)=="table" then return v end
  end
  return {location="KANTO",playTime=0}
end

local function chrome(runtime,m,Draw,colors,game,subtitle)
  local c=context(runtime.Core);local t=math.floor(c.playTime or 0)
  Draw.roundRect(m,"fill",0,0,1920,88,0,colors.inverse)
  Draw.text(runtime,m,"KANTO JOURNAL",32,18,24,colors.textInverse,{weight="bold"})
  Draw.text(runtime,m,tostring(subtitle or "START MENU"):upper(),32,54,11,colors.textInverse,{weight="bold",alpha=.72})
  Draw.text(runtime,m,tostring(c.location or "KANTO"):gsub("_"," "):upper(),1570,22,14,colors.textInverse,{weight="semibold",width=318,align="right"})
  local timeText=c.worldTime or (runtime.worldTimeLabel and runtime.worldTimeLabel(game,t)) or ("%02d:%02d • DAY"):format(math.floor(t/3600),math.floor(t/60)%60)
  Draw.text(runtime,m,timeText,1570,48,12,colors.textInverse,{weight="medium",width=318,align="right",alpha=.76})
end

local function alpha(color,a)
  if type(color)~="table" then return color end
  return {color[1] or 0,color[2] or 0,color[3] or 0,a}
end

function Header.drawGeneric(runtime,m,Draw,colors,game,subtitle,category)
  chrome(runtime,m,Draw,colors,game,subtitle)
  local upper=tostring(category or subtitle or "MENU"):upper()
  Draw.text(runtime,m,upper,830,32,16,colors.textInverse,{weight="medium",width=260,align="center"})
  -- Canonical generic header uses the same theme-owned positional rail as all
  -- hierarchy headers. Retro therefore stays monochrome instead of inheriting
  -- the global cyan focus role.
  Draw.roundRect(m,"fill",880,65,160,3,1.5,colors.headerAccent or colors.focus)
end
function Header.draw(runtime,m,Draw,colors,game,title)
  Header.drawGeneric(runtime,m,Draw,colors,game,title,title)
end

-- Figma canonical geometry: KRS / Fullscreen / Party Navigation +
-- KRS / Fullscreen / Header Hierarchy Item (nodes 442:1263 / 441:1268).
-- Default, Hover, Focused, Selected, Pressed and Disabled are intentionally
-- distinct. Selected is a positional rail; Focused is a 2 px outline; Hover
-- is a 1 px rail. Pointer hover never masquerades as keyboard focus.
function Header.drawHierarchy(runtime,m,Draw,colors,game,opts)
  opts=opts or {}
  chrome(runtime,m,Draw,colors,game,opts.subtitle or opts.parentLabel or "START MENU")
  local items=opts.items or {}
  local count=#items
  if count==0 then return {},nil end
  local active=math.max(1,math.min(count,tonumber(opts.activeIndex) or 1))
  local focusIndex=math.max(1,math.min(count,tonumber(opts.focusIndex) or active))
  local parentW,itemW,gap=140,124,8
  -- Root Auto Layout has 14 px horizontal padding. The interactive content is
  -- centred independently, exactly as in the Figma component.
  local inner=parentW+1+count*itemW+(count+1)*gap
  local x=960-inner/2
  local parent=tostring(opts.parentLabel or "MENU"):upper()
  if opts.backArrow~=false then parent="← "..parent end
  local parentRect={x=x,y=24,w=parentW,h=40}
  Draw.text(runtime,m,parent,parentRect.x,parentRect.y+10,14,colors.textInverse,{weight="semibold",width=parentRect.w,align="center",alpha=.88})
  x=x+parentW+gap
  Draw.roundRect(m,"fill",x,32,1,24,0,colors.textInverse)
  x=x+1+gap
  local rects={}
  local accent=colors.headerAccent or colors.focus
  local headerFocus=colors.headerFocus or colors.textInverse or colors.focus
  for i,label in ipairs(items) do
    local r={x=x,y=24,w=itemW,h=40};rects[i]=r
    local disabled=opts.disabled and opts.disabled[i]==true
    local selected=i==active
    local hovered=not disabled and opts.hoverIndex==i
    local focused=not disabled and opts.focused==true and i==focusIndex
    local pressed=not disabled and opts.pressedIndex==i
    if pressed then
      Draw.roundRect(m,"fill",r.x,r.y,r.w,r.h,8,alpha(accent,.16))
    end
    -- Selected tabs are rail-only in the canonical Options/Mods hierarchy.
    -- Keyboard focus keeps its full outline only while it is on an inactive
    -- destination; selected+focused never grows a surrounding box.
    if focused and not selected then
      Draw.roundRect(m,"line",r.x+1,r.y+1,r.w-2,r.h-2,8,headerFocus,2)
    end
    local textAlpha=disabled and .36 or selected and 1 or .72
    Draw.text(runtime,m,tostring(label):upper(),r.x,r.y+10,13,colors.textInverse,{weight="semibold",width=r.w,align="center",alpha=textAlpha})
    if selected or pressed then
      Draw.roundRect(m,"fill",r.x+14,r.y+37,96,3,1.5,accent)
    elseif hovered then
      Draw.roundRect(m,"fill",r.x+14,r.y+39,96,1,.5,alpha(accent,.72))
    end
    x=x+itemW+gap
  end
  return rects,parentRect
end
return Header
