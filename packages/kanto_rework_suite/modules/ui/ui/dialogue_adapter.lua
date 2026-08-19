-- Presentation adapter for official Gen1Recomp dialogue surfaces.
-- Native TextBox / ChoiceBox / ListMenu states retain update, input and callback
-- ownership. Kanto UI mirrors only the presentation of recognized Wide cases.
return function(deps)
  local TextBox=assert(deps.TextBox,"TextBox dependency required")
  local ChoiceBox=assert(deps.ChoiceBox,"ChoiceBox dependency required")
  local ListMenu=assert(deps.ListMenu,"ListMenu dependency required")
  local QuantityBox=assert(deps.QuantityBox,"QuantityBox dependency required")
  local Font=assert(deps.Font,"Font dependency required")
  local Layout=assert(deps.Layout,"Layout dependency required")
  local CharacterNames=deps.CharacterNames
  local Adapter={}
  local inferredSpeakerCache={}
  local eligibility=setmetatable({},{__mode="k"})

  local function isNativeTextBox(state)
    return type(state)=="table" and getmetatable(state)==TextBox
  end
  local function isNativeChoiceBox(state)
    return type(state)=="table" and getmetatable(state)==ChoiceBox
  end
  local function isNativeListMenu(state)
    return type(state)=="table" and getmetatable(state)==ListMenu
  end
  local function isNativeQuantityBox(state)
    return type(state)=="table" and getmetatable(state)==QuantityBox
  end

  local function stackStates(game)
    local stack=game and game.stack
    return stack and stack.states or nil
  end

  -- A manual TextBox belongs to the overworld either as the top state, or as
  -- the state immediately under the anchored YES/NO ChoiceBox it spawned.
  local function overworldTextOwner(game,state)
    local states=stackStates(game)
    if type(states)~="table" or #states<2 then return false end
    if states[#states]==state then return states[#states-1]==game.overworld end
    if #states>=3 and states[#states-1]==state and states[#states-2]==game.overworld then
      local choice=states[#states]
      return isNativeChoiceBox(choice) and choice.anchor=="bottom" and type(state.choice)=="function"
    end
    return false
  end

  local function initialEligibility(state)
    local cached=eligibility[state]
    if cached~=nil then return cached end
    -- Every official overworld TextBox can use KRS chrome. Automatic/stay
    -- boxes keep their exact native pagination/timing and are presentation-
    -- mirrored only; manual boxes may additionally be repaginated for Wide.
    local ok=isNativeTextBox(state)
    eligibility[state]=ok
    return ok
  end

  function Adapter.canRepaginate(state)
    return isNativeTextBox(state) and state.auto==nil and state.stay==nil
  end

  function Adapter.isSupported(game,state,viewport)
    if not Layout.isWide(viewport) then return false end
    if not initialEligibility(state) then return false end
    return overworldTextOwner(game,state)
  end

  function Adapter.choicePair(game,viewport)
    if not Layout.isWide(viewport) then return nil,nil end
    local states=stackStates(game)
    if type(states)~="table" or #states<3 then return nil,nil end
    local choice,text,owner=states[#states],states[#states-1],states[#states-2]
    if owner~=game.overworld or not isNativeChoiceBox(choice) or choice.anchor~="bottom"
        or not isNativeTextBox(text) or type(text.choice)~="function"
        or not initialEligibility(text) then return nil,nil end
    return text,choice
  end

  -- A Poké Mart dialogue footer can stay visible while the native quantity
  -- selector or the final YES/NO confirmation sits above its ListMenu. Keep
  -- the ListMenu as the semantic text owner and expose only recognized direct
  -- overlays; arbitrary deeper stacks remain native local fallback.
  function Adapter.shopContext(game,viewport)
    if not Layout.isWide(viewport) then return nil,nil end
    local states=stackStates(game)
    if type(states)~="table" or #states<1 then return nil,nil end
    local top=states[#states]
    if Adapter.shopFooterSupported(top,viewport) then return top,nil end
    if #states>=2 then
      local list=states[#states-1]
      if Adapter.shopFooterSupported(list,viewport) then
        -- The two official overlays used by ShopMenu are recognized exactly.
        -- Quantity stays native while the KRS clerk line remains visible;
        -- ChoiceBox is mirrored into the same KRS confirmation panel.
        if isNativeChoiceBox(top) or isNativeQuantityBox(top) then return list,top end
      end
    end
    return nil,nil
  end

  function Adapter.isMirroredChoice(game,state,viewport)
    local _,choice=Adapter.choicePair(game,viewport)
    if choice~=nil and choice==state then return true end
    local _,shopOverlay=Adapter.shopContext(game,viewport)
    return isNativeChoiceBox(shopOverlay) and shopOverlay==state
  end

  function Adapter.choiceNavigation(game,state,viewport)
    if Adapter.isMirroredChoice(game,state,viewport) then return "horizontal" end
    return nil
  end

  local function partialByGlyphs(text,count)
    text=tostring(text or "")
    count=math.max(0,tonumber(count) or 0)
    if count==0 or text=="" then return "" end
    local spans=Font.split(text)
    if type(spans)~="table" or #spans==0 then return "" end
    if count>=#spans then return text end
    local span=spans[count]
    return span and text:sub(1,span.to) or ""
  end

  local function cleanSegment(text)
    text=tostring(text or ""):gsub("\r\n","\n"):gsub("\r","\n")
    text=text:gsub("^[ \t]+",""):gsub("[ \t]+$","")
    return text
  end

  local function appendReflow(out,segment)
    segment=cleanSegment(segment)
    if segment=="" then return end
    if #out>0 then
      local sep=" "
      if tostring(out[#out]):sub(-1)=="-" and segment:match("^[%l%d]") then sep="" end
      out[#out+1]=sep
    end
    out[#out+1]=segment
  end

  -- Reconstruct native narrow text as prose. Newlines, CONT and page breaks
  -- exist mainly for the 18-column Game Boy window; Wide owns its wrapping.
  function Adapter.fullText(state)
    if not isNativeTextBox(state) then return "" end
    local out={}
    for _,page in ipairs(type(state.pages)=="table" and state.pages or {}) do
      if type(page)=="table" then for _,segment in ipairs(page) do appendReflow(out,segment) end end
    end
    return table.concat(out)
  end

  function Adapter.prose(text)
    local out={}
    text=tostring(text or ""):gsub("\r\n","\n"):gsub("\r","\n")
    -- Text passed directly by ListMenu footer may still contain the same three
    -- source separators. Treat them as layout whitespace for the Wide panel.
    text=text:gsub("\11","\n"):gsub("\12","\n")
    for segment in (text.."\n"):gmatch("(.-)\n") do appendReflow(out,segment) end
    return table.concat(out)
  end

  -- Replace only TextBox presentation pagination before typing starts.
  function Adapter.repaginate(state,wrappedLines,maxLines)
    if not isNativeTextBox(state) then return false end
    if (tonumber(state.pageIndex) or 1)~=1 or (tonumber(state.lineIndex) or 1)~=1
        or (tonumber(state.charIndex) or 0)~=0 then return false end
    maxLines=math.max(1,math.floor(tonumber(maxLines) or 3))
    local lines={}
    for _,line in ipairs(type(wrappedLines)=="table" and wrappedLines or {}) do lines[#lines+1]=tostring(line or "") end
    if #lines==0 then lines[1]="" end
    local pages={};pages.contBefore={};local page,conts={},{}
    for _,line in ipairs(lines) do
      page[#page+1]=line;conts[#conts+1]=false
      if #page>=maxLines then
        pages[#pages+1]=page;pages.contBefore[#pages.contBefore+1]=conts;page,conts={},{}
      end
    end
    if #page>0 then pages[#pages+1]=page;pages.contBefore[#pages.contBefore+1]=conts end
    state.pages=pages
    state.pageIndex=1;state.lineIndex=1;state.charIndex=0
    state.shown={};state.waiting=false;state.contAdvance=false;state.done=false
    state.preWait=nil;state.holdFrames=nil;state.scrollPx=nil;state.charTimer=0
    state:beginLine()
    return true
  end

  function Adapter.visibleText(state)
    if not isNativeTextBox(state) then return "" end
    local pages=state.pages
    local page=type(pages)=="table" and pages[state.pageIndex or 1] or nil
    if type(page)~="table" then return "" end
    local last=math.max(1,math.min(tonumber(state.lineIndex) or 1,#page))
    local out={}
    for i=1,last do
      local segment=page[i]
      if i==last then segment=partialByGlyphs(segment,state.charIndex) end
      appendReflow(out,segment)
    end
    return table.concat(out):gsub(" +\n","\n"):gsub("\n +","\n")
  end

  local function sameProse(a,b)
    a=Adapter.prose(a);b=Adapter.prose(b)
    return a~="" and b~="" and (a:find(b,1,true)~=nil or b:find(a,1,true)~=nil)
  end

  local function cleanSpeakerName(value)
    local name=tostring(value or ""):gsub("^%s+",""):gsub("%s+$",""):gsub("%s+"," ")
    if name=="" or #name>32 or not name:match("%a") then return nil end
    -- Dialogue labels in the ROM are uppercase semantic speaker names.
    -- Requiring uppercase prevents ordinary prose such as "Note: ..." from
    -- becoming a speaker chip by accident.
    if name:upper()~=name then return nil end
    return name
  end

  local metadataLabels={
    TRAINER_RANK=true,TRAINER_STATUS=true,REMATCH=true,REMATCH_STATUS=true,
    CHALLENGE=true,BATTLE_STATUS=true,
    TRAINER_RANG=true,TRAINERSTATUS=true,REVANCHE=true,HERAUSFORDERUNG=true,
  }

  local function metadataPrefix(value)
    local key=tostring(value or ""):upper():gsub("[^%w]+","_"):gsub("^_+",""):gsub("_+$","")
    return metadataLabels[key]==true
  end

  function Adapter.explicitSpeaker(text)
    local full=Adapter.prose(text)
    local prefix,body=full:match("^([^:]+):%s*(.+)$")
    local name=cleanSpeakerName(prefix)
    if not name then return nil,full end
    -- Ascendant-style rematch dialogue prefixes describe UI metadata, not a
    -- person. Strip the label and let the authoritative NPC hint own the chip.
    if metadataPrefix(name) then return nil,body,true end
    return name,body,false
  end

  local function knownSpeaker(state,game,full)
    if type(state._krsSpeakerHint)=="string" then
      local hint=cleanSpeakerName(state._krsSpeakerHint)
      if hint then return hint end
    end
    local t=game and game.data and game.data.text or nil
    if type(t)=="table" then
      local known={
        _PokemonCenterWelcomeText="NURSE JOY",
        _ShallWeHealYourPokemonText="NURSE JOY",
        _NeedYourPokemonText="NURSE JOY",
        _PokemonCenterFarewellText="NURSE JOY",
        _PokemartGreetingText="CLERK",
      }
      for key,name in pairs(known) do
        if type(t[key])=="string" and sameProse(full,t[key]) then return name end
      end
      -- When the ROM/source gives no explicit speaker prefix, derive a stable
      -- presentation identity from the semantic text label. This never edits
      -- game text or trainer data; it only supplies the KRS speaker chip.
      if CharacterNames and type(CharacterNames.fromTextKey)=="function" then
        local cacheKey=Adapter.prose(full)
        local cached=inferredSpeakerCache[cacheKey]
        if cached~=nil then return cached~=false and cached or nil end
        for key,value in pairs(t) do
          if type(key)=="string" and type(value)=="string" and sameProse(full,value) then
            local ok,name=pcall(CharacterNames.fromTextKey,game,key)
            if ok and name then inferredSpeakerCache[cacheKey]=name;return name end
          end
        end
        inferredSpeakerCache[cacheKey]=false
      end
    end
    -- Invent identities only for an interaction that the overworld has
    -- authoritatively classified as an NPC.  System messages, item text,
    -- narration and other non-sign TextBoxes must never become a fake
    -- "TRAINER <name>" merely because they lack an explicit speaker.
    if state._krsInteractionKind=='npc' and CharacterNames and type(CharacterNames.dialogue)=='function' then
      local ok,name=pcall(CharacterNames.dialogue,game,full,{})
      if ok and type(name)=='string' and name~='' then return name end
    end
    return nil
  end
  -- Resolve the semantic presentation before Wide repagination. An explicit
  -- ROM prefix such as "KOGA:" becomes the speaker chip and is removed from
  -- the message. Sign interactions are deliberately excluded so labels such
  -- as "TRAINER TIPS:" remain sign content rather than invented speakers.
  function Adapter.presentationText(state,game)
    if not isNativeTextBox(state) then return "",nil end
    local full=Adapter.fullText(state)
    local speaker=type(state._krsSpeaker)=="string" and cleanSpeakerName(state._krsSpeaker) or nil
    if not speaker and state._krsInteractionKind~="sign" then
      local explicit,body,isMetadata=Adapter.explicitSpeaker(full)
      if explicit then speaker=explicit;full=body
      elseif isMetadata then full=body end
    end
    if not speaker then speaker=knownSpeaker(state,game,full) end
    if speaker then state._krsSpeaker=speaker end
    return full,speaker
  end

  -- Speaker metadata is presentation-only. Explicit canonical identities win;
  -- unnamed NPCs/trainers receive a deterministic Kanto-appropriate identity
  -- derived from class, map/object context or the semantic ROM text label.
  function Adapter.speaker(state,game)
    if not isNativeTextBox(state) then return nil end
    if type(state._krsSpeaker)=="string" and state._krsSpeaker~="" then return state._krsSpeaker end
    local _,speaker=Adapter.presentationText(state,game)
    return speaker
  end

  function Adapter.model(state,choice,game)
    local model={
      text=Adapter.visibleText(state),waiting=state.waiting==true,done=state.done==true,
      pageIndex=tonumber(state.pageIndex) or 1,speaker=Adapter.speaker(state,game),
    }
    if choice and isNativeChoiceBox(choice) then
      model.choice={count=2,index=tonumber(choice.index) or 1,pending=choice.pending,labels={"YES","NO"}}
    end
    return model
  end

  -- Gen1Recomp's mart BUY/SELL ListMenu does not push a TextBox. Its clerk
  -- line is an embedded `footer` when `dialogue=true`; expose that semantic
  -- string so Kanto can replace only the footer chrome while the native shop
  -- list, money, navigation and callbacks remain untouched.
  function Adapter.shopFooterSupported(state,viewport)
    return Layout.isWide(viewport) and isNativeListMenu(state)
      and state.dialogue==true and type(state.footer)=="string" and state.footer~=""
  end

  function Adapter.shopFooterModel(state,choice)
    local model={text=Adapter.prose(state and state.footer or ""),shopFooter=true,speaker="CLERK"}
    if choice and isNativeChoiceBox(choice) then
      model.choice={count=2,index=tonumber(choice.index) or 1,pending=choice.pending,labels={"YES","NO"}}
    end
    return model
  end

  function Adapter.clear(state) eligibility[state]=nil end
  return Adapter
end
