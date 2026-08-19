-- KRS overworld dialogue presentation for Wide layouts.
-- Geometry mirrors the validated Figma Dialogue family:
-- optional speaker -> message -> compact choices.
return function(deps)
  local Draw=assert(deps.Draw,"Draw dependency required")
  local Panel={}

  local PANEL_W=1120
  local PAD_X=32
  local PAD_Y=28
  local INNER_W=PANEL_W-PAD_X*2 -- 1056
  local TEXT_SIZE=18
  local LINE_H=24
  local BOTTOM_MARGIN=64
  local MAX_LINES_PER_PAGE=3

  local SPEAKER_SIZE=14
  local SPEAKER_LINE_H=20
  local SPEAKER_PAD_X=12
  local SPEAKER_PAD_Y=7
  local SPEAKER_H=SPEAKER_LINE_H+SPEAKER_PAD_Y*2 -- 34
  local SPEAKER_MAX_W=320
  local SPEAKER_GAP=16

  local CHOICE_GAP=10
  local CHOICE_H=64
  local CHOICE_MIN_W=180
  local CHOICE_MAX_W=320
  local CHOICE_PAD_X=20
  local CHOICE_TOP_GAP=16

  local function appendWrapped(lines,font,text,maxPx)
    local source=tostring(text or "")
    if source=="" then return end
    local first=true
    for paragraph in (source.."\n"):gmatch("(.-)\n") do
      if not first and paragraph=="" then lines[#lines+1]="" end
      first=false
      local _,wrapped=font:getWrap(paragraph,maxPx)
      if type(wrapped)~="table" or #wrapped==0 then wrapped={paragraph} end
      for _,line in ipairs(wrapped) do lines[#lines+1]=line end
    end
    if #lines>1 and lines[#lines]=="" and source:sub(-1)~="\n" then table.remove(lines) end
  end

  local function cleanSpeaker(value)
    local speaker=tostring(value or ""):gsub("^%s+",""):gsub("%s+$","")
    if speaker=="" then return nil end
    return speaker
  end

  function Panel.wrap(runtime,m,text)
    local font=Draw.font(runtime,m,TEXT_SIZE,"semibold")
    local lines={};appendWrapped(lines,font,text,INNER_W*m.scale)
    if #lines==0 then lines[1]="" end
    return lines
  end

  function Panel.maxLinesPerPage() return MAX_LINES_PER_PAGE end

  local function measuredChoiceWidth(runtime,m,label)
    local font=Draw.font(runtime,m,TEXT_SIZE,"semibold")
    local px=font.getWidth and font:getWidth(tostring(label or "")) or 0
    local logical=(px/(m.scale>0 and m.scale or 1))+CHOICE_PAD_X*2
    return math.max(CHOICE_MIN_W,math.min(CHOICE_MAX_W,math.ceil(logical)))
  end

  function Panel.layout(runtime,m,model)
    model=model or {}
    local lines=Panel.wrap(runtime,m,model.text)
    local textH=math.max(LINE_H,#lines*LINE_H)
    local speaker=cleanSpeaker(model.speaker)
    local speakerH=speaker and (SPEAKER_H+SPEAKER_GAP) or 0

    local choice=model.choice
    local choiceRects=nil
    local choiceH=0
    if choice then
      local labels=choice.labels or {"SÍ","NO"}
      local count=math.max(1,math.min(4,tonumber(choice.count) or #labels))
      choiceRects={}
      local cx=0
      for i=1,count do
        local w=measuredChoiceWidth(runtime,m,labels[i] or tostring(i))
        choiceRects[i]={x=cx,y=0,w=w,h=CHOICE_H}
        cx=cx+w+(i<count and CHOICE_GAP or 0)
      end
      -- Battle actions such as CHANGE / DON'T CHANGE belong at the lower
      -- right edge of the same responsive dialogue panel. Text retains the
      -- full inner width; controls consume a separate row and never force an
      -- early prose wrap.
      if choice.align=='right' then
        local shift=math.max(0,INNER_W-cx)
        for _,r in ipairs(choiceRects) do r.x=r.x+shift end
      end
      choiceH=CHOICE_TOP_GAP+CHOICE_H
    end

    local h=PAD_Y*2+speakerH+textH+choiceH
    local x=(1920-PANEL_W)/2
    local bottomMargin=tonumber(model.bottomMargin) or BOTTOM_MARGIN
    local y=1080-bottomMargin-h
    local textY=y+PAD_Y+speakerH
    local layout={
      x=x,y=y,w=PANEL_W,h=h,innerX=x+PAD_X,innerY=y+PAD_Y,innerW=INNER_W,
      textW=INNER_W,textH=textH,lines=lines,textY=textY,
      speaker=speaker,speakerRect=nil,choiceRects=nil,
    }

    if speaker then
      local font=Draw.font(runtime,m,SPEAKER_SIZE,"semibold")
      local px=font.getWidth and font:getWidth(speaker) or 0
      local sw=math.min(SPEAKER_MAX_W,math.max(72,math.ceil(px/(m.scale>0 and m.scale or 1))+SPEAKER_PAD_X*2))
      layout.speakerRect={x=layout.innerX,y=layout.innerY,w=sw,h=SPEAKER_H}
    end
    if choiceRects then
      local cy=textY+textH+CHOICE_TOP_GAP
      for _,r in ipairs(choiceRects) do
        r.x=layout.innerX+r.x;r.y=cy
      end
      layout.choiceRects=choiceRects
    end
    return layout
  end

  local function drawChoice(runtime,m,colors,r,label,focused)
    Draw.roundRect(m,"fill",r.x,r.y,r.w,r.h,12,colors.panel)
    Draw.roundRect(m,"line",r.x,r.y,r.w,r.h,12,focused and colors.focus or colors.border,focused and 3 or 1)
    Draw.text(runtime,m,label,r.x+CHOICE_PAD_X,r.y+20,TEXT_SIZE,colors.text,
      {weight="semibold",width=r.w-CHOICE_PAD_X*2})
  end

  function Panel.draw(runtime,m,colors,model)
    local l=Panel.layout(runtime,m,model)
    -- render.hud is after Renderer:endFrame; isolate every graphics property so
    -- dialogue ink, font, shader, scissor or transform cannot leak next frame.
    local g=love.graphics;g.push("all");g.origin()
    local ok,err=pcall(function()
      Draw.roundRect(m,"fill",l.x,l.y,l.w,l.h,18,colors.panel)
      Draw.roundRect(m,"line",l.x,l.y,l.w,l.h,18,colors.borderStrong or colors.faint or colors.border,2)

      if l.speakerRect then
        local r=l.speakerRect
        Draw.roundRect(m,"fill",r.x,r.y,r.w,r.h,10,colors.inverse or colors.header)
        Draw.text(runtime,m,l.speaker,r.x+SPEAKER_PAD_X,r.y+SPEAKER_PAD_Y,SPEAKER_SIZE,colors.textInverse,
          {weight="semibold",width=r.w-SPEAKER_PAD_X*2})
      end

      for i,line in ipairs(l.lines) do
        Draw.text(runtime,m,line,l.innerX,l.textY+(i-1)*LINE_H,TEXT_SIZE,colors.text,{weight="semibold",width=l.innerW})
      end

      if model and model.choice and l.choiceRects then
        local labels=model.choice.labels or {"YES","NO"}
        for i,r in ipairs(l.choiceRects) do
          drawChoice(runtime,m,colors,r,labels[i] or tostring(i),(model.choice.index or 1)==i)
        end
      end
    end)
    g.pop();if not ok then error(err,0) end
    return l
  end
  return Panel
end
