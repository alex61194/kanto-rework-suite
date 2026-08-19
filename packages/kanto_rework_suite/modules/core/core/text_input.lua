-- Sandbox-safe device-aware text entry for Gen1Recomp NamingScreen.
-- Physical keyboard events are observed through Core's Game input bridge.
-- The 0.1.86 mod API has no raw textinput hook, so printable keys are mapped
-- directly while controller/touch keeps the native Gen 1 grid.
return function(deps)
  local runtime=assert(deps.runtime,"runtime is required")
  local inputDevice=deps.inputDevice
  local adapter={installed=false,error=nil}
  local function topState()
    local game=runtime.game;local stack=game and game.stack
    return stack and type(stack.top)=="function" and stack:top() or nil
  end
  local function namingState()
    local s=topState()
    if type(s)~="table" or type(s.glyphs)~="table" or type(s.maxLen)~="number"
        or type(s.confirm)~="function" or type(s.grid)~="function" then return nil end
    return s
  end
  local function isDesktopSource(source) return source==nil or source=="keyboard" or source=="mouse" end
  function adapter.mode() if not namingState() then return "inactive" end;return isDesktopSource(runtime.lastInput) and "text" or "classic" end
  local function sound(state)
    if state and state.game and state.game.data then pcall(function() require("src.core.Sound").play(state.game.data,"Press_AB") end) end
  end
  local SHIFTED={ ["1"]="!",["9"]="(",["0"]=")",["semicolon"]=":",["comma"]="?",["period"]=".",["slash"]="/",["minus"]="-" }
  local PLAIN={space=" ",minus="-",comma=",",period=".",slash="/",semicolon=";",apostrophe="'"}
  local function printable(key)
    key=tostring(key or "")
    local shift=love and love.keyboard and love.keyboard.isDown and love.keyboard.isDown("lshift","rshift") or false
    if #key==1 and key:match("^[a-z]$") then return shift and key:upper() or key end
    if #key==1 and key:match("^[0-9]$") then return shift and SHIFTED[key] or key end
    return shift and SHIFTED[key] or PLAIN[key]
  end
  function adapter.keypressed(key,_,isrepeat)
    local state=namingState();if not state then return false end
    runtime.lastInput="keyboard"
    if key=="escape" and state.presets and #state.presets>0 and not isrepeat then
      -- KRS player/rival naming can return to the engine-owned preset chooser
      -- without recreating or skipping the OakSpeech state.
      state:enter()
    elseif key=="backspace" then
      if #state.glyphs>0 then table.remove(state.glyphs);sound(state) end
    elseif (key=="return" or key=="kpenter") and not isrepeat then
      state:confirm()
    elseif not isrepeat or true then
      local ch=printable(key)
      if ch and #state.glyphs<state.maxLen then
        state.glyphs[#state.glyphs+1]=ch;sound(state)
        if #state.glyphs>=state.maxLen and type(state.jumpToEnd)=="function" then state:jumpToEnd() end
      end
    end
    return true
  end
  function adapter.textinput() return namingState()~=nil and adapter.mode()=="text" end
  function adapter.install()
    -- Core's single physical-key listener calls keypressed before any KRS
    -- hotkey handling, so a NamingScreen owns the whole keyboard event.
    adapter.installed=true;adapter.error=nil;return true
  end
  function adapter.status() return {installed=adapter.installed,error=adapter.error,active=namingState()~=nil,mode=adapter.mode(),source=runtime.lastInput} end
  return adapter
end
