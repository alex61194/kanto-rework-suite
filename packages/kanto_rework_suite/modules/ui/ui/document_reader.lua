-- Presentation-neutral normalization for legacy TextBox pages.
-- The engine remains authoritative for substitution and pagination; this
-- module only turns its narrow pages into ordered Wide document blocks.
return function()
  local Reader={}

  local function clean(value)
    local text=tostring(value or "")
    text=text:gsub("\r\n","\n"):gsub("\r","\n")
    text=text:gsub("^%s+",""):gsub("%s+$","")
    return text
  end

  local function joinLines(lines)
    local out=""
    for _,raw in ipairs(lines or {}) do
      local line=clean(raw):gsub("%s+"," ")
      if line~="" then
        if out=="" then out=line
        elseif out:sub(-1)=="-" and line:match("^[%l%d]") then out=out..line
        else out=out.." "..line end
      end
    end
    return out:gsub("%s+"," "):gsub("^%s+",""):gsub("%s+$","")
  end

  local function preserveLines(lines)
    local out={}
    for _,raw in ipairs(lines or {}) do out[#out+1]=clean(raw) end
    return table.concat(out,"\n"):gsub("\n+$","")
  end

  function Reader.build(pages,policy)
    policy=type(policy)=="table" and policy or {}
    local blocks={};local sourceLines=0;local sourceChars=0
    for pageIndex,page in ipairs(type(pages)=="table" and pages or {}) do
      if type(page)=="table" then
        sourceLines=sourceLines+#page
        local text=policy.preserveLines==true and preserveLines(page) or joinLines(page)
        if text~="" then
          sourceChars=sourceChars+#text
          blocks[#blocks+1]={id="source:"..pageIndex,sourcePage=pageIndex,text=text}
        end
      end
    end
    if #blocks==0 then blocks[1]={id="source:1",sourcePage=1,text=""} end
    return {
      blocks=blocks,
      sourcePageCount=type(pages)=="table" and #pages or 0,
      sourceLineCount=sourceLines,
      sourceCharacterCount=sourceChars,
      policy=policy,
    }
  end

  return Reader
end
