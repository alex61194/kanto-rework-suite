local RELEASE="0.2.5"
local EXPORT_API=3

return function(mod)
  local coreHandle=mod.find("core")
  local Core=coreHandle and coreHandle.exports
  assert(Core and Core.inputActions and type(Core.inputActions.register)=="function"
      and type(Core.registerInputLayer)=="function",
    "kanto_rework_core 0.1.37+ is required")

  mod.options:define({
    {key="dev_overlay",label="INTERACTIVE DEV OVERLAY",type="toggle",default=true,group="DEV OVERLAY",
      description="Enable the temporary KRS developer control overlay. F3 opens or closes it."},
    {key="move_preview_overlay",label="BATTLE MOVE PREVIEW",type="toggle",default=true,group="DEV OVERLAY",
      description="While the developer overlay is open in battle, show every loaded move and play its battle animation on click."},
  })

  -- Gen1Recomp 0.1.86 gives every mod a private sandbox. Runtime state is
  -- therefore local to this mod; intentional cross-mod access is exported below.
  local runtime={}
  runtime.game=runtime.game or nil
  runtime.open=runtime.open==true
  runtime.flyUnlocked=false -- deliberately session-only; never read/write save data
  runtime.pointerSurfaceActive=false
  runtime.level=tonumber(runtime.level) or 13
  runtime.shiny=runtime.shiny==true
  runtime.speciesIndex=tonumber(runtime.speciesIndex) or 1
  runtime.trainerIndex=tonumber(runtime.trainerIndex) or 1
  runtime.moveScroll=tonumber(runtime.moveScroll) or 0
  runtime.movePanel=type(runtime.movePanel)=='table' and runtime.movePanel or {}
  runtime.movePanel.collapsed=runtime.movePanel.collapsed==true
  runtime.movePanelDrag=nil
  runtime.drop=nil;runtime.dropScroll=0;runtime.hover=nil;runtime.viewport=runtime.viewport or {width=1920,height=1080}
  runtime.hits={}
  local caches={pokemonData=nil,pokemon=nil,trainerData=nil,trainers=nil,moveData=nil,moves=nil}
  local fonts={}

  local FALLBACK_COLORS={
    panel={1,1,1,1},inverse={20/255,19/255,17/255,1},inverseRaised={36/255,35/255,31/255,1},
    text={20/255,19/255,17/255,1},textInverse={247/255,241/255,223/255,1},textSecondary={97/255,92/255,79/255,1},
    subtle={247/255,241/255,223/255,1},border={219/255,209/255,181/255,1},borderStrong={129/255,123/255,107/255,1},
    focus={0,116/255,140/255,1},success={31/255,111/255,70/255,1},danger={180/255,54/255,45/255,1},warning={152/255,102/255,0,1},
  }

  local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
  local function readOption(key,default)
    local options=mod and mod.options
    if options and type(options.get)=="function" then
      local ok,value=pcall(options.get,options,key)
      if ok and value~=nil then return value end
    end
    return default
  end
  -- Keep explicit live option state so a Mods-menu change is authoritative on
  -- the same frame. The Suite facade forwards `mod.options_changed` with the
  -- internal module id/key stripped from the native namespace.
  runtime.optionState=runtime.optionState or {
    dev_overlay=readOption("dev_overlay",true),
    move_preview_overlay=readOption("move_preview_overlay",true),
  }
  local function option(key,default)
    local value=runtime.optionState and runtime.optionState[key]
    if value~=nil then return value end
    value=readOption(key,default)
    runtime.optionState[key]=value
    return value
  end
  if mod.events and type(mod.events.on)=="function" then
    mod.events:on("mod.options_changed",function(payload)
      if type(payload)~="table" or payload.mod~=mod.id or type(payload.key)~="string" then return end
      if payload.key=="dev_overlay" or payload.key=="move_preview_overlay" then
        runtime.optionState[payload.key]=payload.value==true
        if payload.key=="dev_overlay" and payload.value~=true then runtime.open=false end
        if payload.key=="move_preview_overlay" and payload.value~=true then
          runtime.movePanelDrag=nil;runtime.moveScroll=0;runtime.hover=nil
        end
      end
    end)
  end
  local function top(game) return game and game.stack and game.stack.top and game.stack:top() or nil end
  local function stackDepth(game) local s=game and game.stack and game.stack.states;return type(s)=="table" and #s or 0 end
  local function uiExports()
    local handle=mod.find("ui")
    return handle and handle.exports or nil
  end
  local function colors(game)
    local ui=uiExports()
    if ui and type(ui.themeColors)=="function" then
      local ok,c=pcall(ui.themeColors,game)
      if ok and type(c)=="table" and c.panel then return c end
    end
    return FALLBACK_COLORS
  end
  local function font(size,weight)
    size=math.max(9,math.floor((tonumber(size) or 12)+.5));weight=weight or "regular"
    local key=size..":"..weight;if fonts[key] then return fonts[key] end
    -- Fonts remain intentionally local. UI is optional and the v0.1.86 sandbox
    -- no longer permits reaching another mod's private Draw table.
    fonts[key]=love.graphics.newFont(size)
    return fonts[key]
  end
  local function set(c,a) c=c or {1,1,1,1};love.graphics.setColor(c[1] or 1,c[2] or 1,c[3] or 1,a or c[4] or 1) end
  local function inside(x,y,r) return r and x>=r.x and y>=r.y and x<=r.x+r.w and y<=r.y+r.h end
  local function addHit(kind,x,y,w,h,data)
    local r={kind=kind,x=x,y=y,w=w,h=h,data=data};runtime.hits[#runtime.hits+1]=r;return r
  end
  local function notify(message,kind)
    if Core.notifications and type(Core.notifications.emit)=="function" then
      pcall(Core.notifications.emit,{id="krs_dev",source=mod.id,kind=kind or "info",priority=999,
        replaceKey="krs_dev",duration=2.5,message=tostring(message)})
    end
  end

  local function pokemonList(game)
    local data=game and game.data and game.data.pokemon or {}
    if caches.pokemonData==data and caches.pokemon then return caches.pokemon end
    local out={}
    for id,def in pairs(data) do if type(def)=="table" then
      out[#out+1]={id=id,label=tostring(def.name or id):upper(),dex=tonumber(def.dex) or 99999}
    end end
    table.sort(out,function(a,b) if a.dex~=b.dex then return a.dex<b.dex end;if a.label~=b.label then return a.label<b.label end;return tostring(a.id)<tostring(b.id) end)
    caches.pokemonData,caches.pokemon=data,out
    if #out>0 then
      local wanted=runtime.species
      if wanted then for i,row in ipairs(out) do if row.id==wanted then runtime.speciesIndex=i;break end end end
      runtime.speciesIndex=clamp(runtime.speciesIndex,1,#out);runtime.species=out[runtime.speciesIndex].id
    end
    return out
  end
  local function trainerList(game)
    local data=game and game.data and game.data.trainers or {}
    if caches.trainerData==data and caches.trainers then return caches.trainers end
    local out={}
    for classId,def in pairs(data) do
      if type(def)=="table" and type(def.parties)=="table" then
        for index,party in ipairs(def.parties) do if party then
          local base=tostring(def.name or classId):upper();local partySize=type(party)=="table" and #party or 0
          out[#out+1]={classId=classId,partyIndex=index,label=("%s  ·  #%d%s"):format(base,index,partySize>0 and ("  ·  "..partySize.." PKMN") or "")}
        end end
      end
    end
    table.sort(out,function(a,b) if a.label~=b.label then return a.label<b.label end;return tostring(a.classId)<tostring(b.classId) end)
    caches.trainerData,caches.trainers=data,out
    runtime.trainerIndex=#out>0 and clamp(runtime.trainerIndex,1,#out) or 1
    return out
  end
  local function moveList(game)
    local data=game and game.data and game.data.moves or {}
    if caches.moveData==data and caches.moves then return caches.moves end
    local out={}
    for id,def in pairs(data) do if type(def)=="table" then
      out[#out+1]={id=id,label=tostring(def.name or id):upper(),type=tostring(def.type or ""):gsub("_TYPE$","")}
    end end
    table.sort(out,function(a,b) if a.label~=b.label then return a.label<b.label end;return tostring(a.id)<tostring(b.id) end)
    caches.moveData,caches.moves=data,out;return out
  end

  local function canStartBattle(game)
    if not game or not game.overworld or not game.stack then return false,"overworld unavailable" end
    if top(game)~=game.overworld then return false,"return to the overworld before triggering a developer battle" end
    return true
  end
  local function attachFinish(game,battle)
    battle.onFinish=function(result)
      if game.overworld and game.overworld.afterBattle then game.overworld:afterBattle(result,battle) end
    end
  end
  local function startWild(game)
    local ok,why=canStartBattle(game);if not ok then notify("DEV BATTLE: "..tostring(why):upper(),"warning");return false,why end
    local list=pokemonList(game);local row=list[runtime.speciesIndex];if not row then return false,"no species" end
    local level=clamp(math.floor(tonumber(runtime.level) or 13),1,100);local BattleState=require("src.battle.BattleState")
    local worked,battle=pcall(BattleState.newWild,game,row.id,level)
    if not worked or not battle then local err=worked and "BattleState.newWild returned nil" or tostring(battle);mod.log:error("DEV wild battle creation failed: %s",err);notify("DEV BATTLE FAILED","danger");return false,err end
    if battle.enemy and battle.enemy.mon then battle.enemy.mon.shiny=runtime.shiny==true end
    attachFinish(game,battle);runtime.drop=nil
    if game.overworld and type(game.overworld.pushBattle)=="function" then game.overworld:pushBattle(battle) else game.stack:push(battle) end
    notify(("DEV WILD · %s Lv.%d%s"):format(row.label,level,runtime.shiny and " · SHINY" or ""))
    return true,battle
  end
  local function startTrainer(game)
    local ok,why=canStartBattle(game);if not ok then notify("DEV BATTLE: "..tostring(why):upper(),"warning");return false,why end
    local list=trainerList(game);local row=list[runtime.trainerIndex];if not row then return false,"no trainer" end
    local BattleState=require("src.battle.BattleState");local worked,battle=pcall(BattleState.newTrainer,game,row.classId,row.partyIndex)
    if not worked or not battle then local err=worked and "BattleState.newTrainer returned nil" or tostring(battle);mod.log:error("DEV trainer battle creation failed: %s",err);notify("DEV TRAINER FAILED","danger");return false,err end
    attachFinish(game,battle);runtime.drop=nil
    if game.overworld and type(game.overworld.pushBattle)=="function" then game.overworld:pushBattle(battle) else game.stack:push(battle) end
    notify("DEV TRAINER · "..row.label);return true,battle
  end
  local function battleState(game)
    local ok,BattleState=pcall(require,"src.battle.BattleState");if not ok then return nil end
    local states=game and game.stack and game.stack.states or {}
    for i=#states,1,-1 do if getmetatable(states[i])==BattleState then return states[i] end end
    local t=top(game);return getmetatable(t)==BattleState and t or nil
  end
  local function playMoveAnimation(game,moveId)
    local battle=battleState(game);if not battle then return false,"no battle" end
    if not battle.animPlayer then
      local ok,AnimPlayer=pcall(require,"src.battle.AnimPlayer")
      if ok and game.data and game.data.battle_anims then battle.animPlayer=AnimPlayer.new(game.data.battle_anims) end
    end
    if not (battle.animPlayer and type(battle.animPlayer.start)=="function") then notify("MOVE ANIMATION PLAYER UNAVAILABLE","warning");return false,"animation player unavailable" end
    local ok,err=pcall(battle.animPlayer.start,battle.animPlayer,moveId,true)
    if not ok then mod.log:error("DEV animation %s failed: %s",tostring(moveId),tostring(err));notify("ANIMATION FAILED","danger");return false,err end
    battle.animName=moveId;battle.animAttackerIsPlayer=true
    if type(battle.resetPicFx)=="function" then pcall(battle.resetPicFx,battle) end
    local done=type(battle.animPlayer.isDone)=="function" and battle.animPlayer:isDone() or false
    battle.animPlaying=not done
    if battle.animPlayer.pollEffects and battle.applyAnimEffect then
      local okEffects,effects=pcall(battle.animPlayer.pollEffects,battle.animPlayer)
      if okEffects and type(effects)=="table" then for _,ev in ipairs(effects) do pcall(battle.applyAnimEffect,battle,ev) end end
    end
    notify("ANIMATION · "..tostring(moveId):gsub("_"," "));return true
  end

  local function oneShotEnemy(game)
    local battle=battleState(game)
    if not battle then notify("ONE-SHOT: NO ACTIVE BATTLE","warning");return false,"no battle" end
    if battle.kind=="link" then
      notify("ONE-SHOT DISABLED IN LINK BATTLES","warning")
      return false,"link battle"
    end
    local enemy=battle.enemy
    if not (enemy and enemy.mon) then return false,"enemy unavailable" end
    if (tonumber(enemy.mon.hp) or 0)<=0 or enemy.faintQueued then
      notify("ENEMY ALREADY FAINTED","warning");return false,"already fainted"
    end
    local hp=math.max(1,math.floor(tonumber(enemy.mon.hp) or 1))
    -- Use BattleState's own damage + faint pipeline. This keeps the HP-bar
    -- drain, faint animation, EXP, trainer replacement and victory handling
    -- identical to a legitimate KO instead of mutating battle phase/result.
    local ok,err=pcall(function()
      if type(battle.applyDamage)=="function" then battle:applyDamage(enemy,hp)
      else enemy.mon.hp=0 end
      if enemy.mon.hp>0 then enemy.mon.hp=0 end
      if type(battle.onFaint)=="function" then battle:onFaint(enemy)
      else enemy.faintQueued=true end
    end)
    if not ok then
      mod.log:error("DEV one-shot failed: %s",tostring(err));notify("ONE-SHOT FAILED","danger")
      return false,err
    end
    notify("ONE-SHOT ENEMY · KO QUEUED")
    return true
  end

  local function dumpState(game,reason)
    game=game or runtime.game;local state=top(game);local save=game and game.save;local player=save and save.player;local party=save and save.party
    local line=table.concat({"KRS_DEV_STATE","reason="..tostring(reason or "manual"),"depth="..tostring(stackDepth(game)),
      "kind="..tostring(state and state.kind),"screenId="..tostring(state and state.screenId),"phase="..tostring(state and state.phase),
      "location="..tostring(player and (player.location or player.map or player.mapId)),"party="..tostring(type(party)=="table" and #party or 0),
      "flyOverride="..tostring(runtime.flyUnlocked)}," ")
    print(line);mod.log:info("%s",line);notify("DEV STATE WRITTEN TO LOG");return true,line
  end

  local function panel(x,y,w,h,c,title)
    set(c.panel,.98);love.graphics.rectangle("fill",x,y,w,h,14,14);set(c.borderStrong);love.graphics.setLineWidth(2);love.graphics.rectangle("line",x,y,w,h,14,14)
    set(c.inverse);love.graphics.rectangle("fill",x,y,w,58,14,14);love.graphics.rectangle("fill",x,y+14,w,44)
    set(c.focus);love.graphics.rectangle("fill",x,y,6,58,14,0);love.graphics.setFont(font(16,"bold"));set(c.textInverse);love.graphics.print(title,x+20,y+18)
  end
  local function label(text,x,y,c) love.graphics.setFont(font(10,"bold"));set(c.textSecondary);love.graphics.print(text,x,y) end
  local function button(text,x,y,w,h,c,kind,data,active)
    local hover=runtime.hover and runtime.hover.kind==kind and runtime.hover.data==data
    set(active and c.focus or hover and c.inverseRaised or c.subtle);love.graphics.rectangle("fill",x,y,w,h,8,8)
    set(active and c.focus or c.border);love.graphics.setLineWidth(active and 2 or 1);love.graphics.rectangle("line",x,y,w,h,8,8)
    love.graphics.setFont(font(11,"bold"));set(active and c.textInverse or c.text);love.graphics.printf(text,x,y+(h-14)/2,w,"center")
    addHit(kind,x,y,w,h,data)
  end
  local function selector(text,x,y,w,c,kind)
    button("‹",x,y,40,42,c,kind.."_prev");button(tostring(text),x+46,y,w-92,42,c,kind.."_open");button("›",x+w-40,y,40,42,c,kind.."_next")
  end
  local function drawDropdown(game,c,anchor,kind,list,index)
    if runtime.drop~=kind then return end
    local vh=runtime.viewport.height or 1080;local rowH=34;local maxRows=math.max(5,math.min(13,math.floor((vh-anchor.y-30)/rowH)))
    local h=maxRows*rowH+10;local x,y,w=anchor.x,anchor.y+anchor.h+4,anchor.w
    if y+h>vh-20 then y=math.max(20,anchor.y-h-4) end
    set(c.panel,1);love.graphics.rectangle("fill",x,y,w,h,9,9);set(c.borderStrong);love.graphics.rectangle("line",x,y,w,h,9,9)
    local maxScroll=math.max(0,#list-maxRows);runtime.dropScroll=clamp(runtime.dropScroll,0,maxScroll)
    for i=1,maxRows do local actual=runtime.dropScroll+i;local row=list[actual];if not row then break end
      local ry=y+5+(i-1)*rowH;local selected=actual==index;local hover=runtime.hover and runtime.hover.kind==kind.."_pick" and runtime.hover.data==actual
      if selected or hover then set(selected and c.focus or c.subtle,selected and .18 or 1);love.graphics.rectangle("fill",x+5,ry,w-10,rowH-2,5,5) end
      love.graphics.setFont(font(10,selected and "bold" or "medium"));set(selected and c.focus or c.text);love.graphics.printf(row.label,x+12,ry+10,w-24,"left")
      addHit(kind.."_pick",x+5,ry,w-10,rowH-2,actual)
    end
    runtime.dropRect={x=x,y=y,w=w,h=h,kind=kind,maxScroll=maxScroll}
  end

  local function drawMain(game,viewport,c)
    local vw,vh=viewport.width or 1920,viewport.height or 1080;local w=math.min(650,vw-72);local h=math.min(720,vh-128);local x=36;local y=64
    panel(x,y,w,h,c,"KANTO REWORK · DEV TOOLS");addHit("panel",x,y,w,h)
    local innerX=x+24;local innerW=w-48;local cy=y+82
    local mons=pokemonList(game);local mon=mons[runtime.speciesIndex]
    label("WILD BATTLE",innerX,cy,c);cy=cy+22
    selector(mon and ((mon.dex<99999 and ("#%03d  "):format(mon.dex) or "")..mon.label) or "NO SPECIES",innerX,cy,innerW,c,"species")
    runtime.speciesAnchor={x=innerX+46,y=cy,w=innerW-92,h=42};cy=cy+58
    label("LEVEL",innerX,cy,c);label("SHINY",innerX+240,cy,c);cy=cy+20
    button("−",innerX,cy,42,42,c,"level_minus");button(("Lv. %d"):format(runtime.level),innerX+48,cy,120,42,c,"level_value");button("+",innerX+174,cy,42,42,c,"level_plus")
    button(runtime.shiny and "ON" or "OFF",innerX+240,cy,128,42,c,"shiny",nil,runtime.shiny);button("START WILD BATTLE",innerX+382,cy,innerW-382,42,c,"wild_start")
    cy=cy+70;set(c.border);love.graphics.rectangle("fill",innerX,cy,innerW,1);cy=cy+24
    label("TRAINER BATTLE",innerX,cy,c);cy=cy+22
    local trainers=trainerList(game);local trainer=trainers[runtime.trainerIndex]
    selector(trainer and trainer.label or "NO TRAINERS",innerX,cy,innerW,c,"trainer");runtime.trainerAnchor={x=innerX+46,y=cy,w=innerW-92,h=42};cy=cy+58
    button("START TRAINER BATTLE",innerX,cy,innerW,42,c,"trainer_start");cy=cy+70
    set(c.border);love.graphics.rectangle("fill",innerX,cy,innerW,1);cy=cy+24
    label("TEMPORARY PROGRESSION",innerX,cy,c);cy=cy+22
    button(runtime.flyUnlocked and "FLY UNLOCKED FOR THIS SESSION" or "FLY USES SAVE PROGRESSION",innerX,cy,innerW,46,c,"fly",nil,runtime.flyUnlocked);cy=cy+60
    love.graphics.setFont(font(9,"medium"));set(c.textSecondary);love.graphics.printf("This toggle never writes HM02, Thunder Badge or any flag to the save.",innerX,cy,innerW,"left")
    local footerY=y+h-50;set(c.border);love.graphics.rectangle("fill",innerX,footerY-12,innerW,1);love.graphics.setFont(font(9,"bold"));set(c.textSecondary);love.graphics.print("F3  CLOSE",innerX,footerY);love.graphics.printf("INSERT  DUMP STATE",innerX,footerY,innerW,"right")
    drawDropdown(game,c,runtime.speciesAnchor,"species",mons,runtime.speciesIndex)
    drawDropdown(game,c,runtime.trainerAnchor,"trainer",trainers,runtime.trainerIndex)
  end

  local function movePanelGeometry(viewport)
    local p=runtime.movePanel;local vw=math.max(360,tonumber(viewport and viewport.width) or 1920);local vh=math.max(280,tonumber(viewport and viewport.height) or 1080)
    local minW,minH=300,220;local maxW=math.max(minW,vw-24);local maxH=math.max(minH,vh-24)
    if not tonumber(p.w) then p.w=math.min(420,math.max(minW,vw*.24)) end
    if not tonumber(p.h) then p.h=math.min(560,math.max(minH,vh*.56)) end
    p.w=clamp(tonumber(p.w) or 420,minW,maxW);p.h=clamp(tonumber(p.h) or 560,minH,maxH)
    if not tonumber(p.x) then p.x=vw-p.w-28 end;if not tonumber(p.y) then p.y=72 end
    p.x=clamp(tonumber(p.x) or 12,12,math.max(12,vw-p.w-12))
    local actualH=p.collapsed and 58 or p.h
    p.y=clamp(tonumber(p.y) or 12,12,math.max(12,vh-actualH-12))
    return p.x,p.y,p.w,actualH,p
  end
  local function clampMovePanel(viewport) movePanelGeometry(viewport or runtime.viewport or {width=1920,height=1080}) end

  local function drawBattleTools(game,viewport,c,battle)
    local vw=tonumber(viewport and viewport.width) or 1920
    local x=math.max(18,vw-318);local y=18;local w=300;local h=54
    set(c.panel,.98);love.graphics.rectangle("fill",x,y,w,h,10,10)
    set(c.borderStrong);love.graphics.setLineWidth(2);love.graphics.rectangle("line",x,y,w,h,10,10)
    button("ONE-SHOT ENEMY",x+10,y+8,w-20,38,c,"one_shot_enemy",nil,false)
    runtime.battleToolsRect={x=x,y=y,w=w,h=h}
  end

  local function drawMoves(game,viewport,c,battle)
    local moves=moveList(game);local x,y,w,h,p=movePanelGeometry(viewport)
    panel(x,y,w,h,c,"MOVE ANIMATION PREVIEW");addHit("panel",x,y,w,h)
    -- Header is a drag surface. The explicit collapse control is registered
    -- afterwards so reverse-order hit testing gives it priority over dragging.
    addHit("move_panel_drag",x,y,w,58)
    set(c.inverseRaised);love.graphics.rectangle("fill",x+w-48,y+11,34,34,7,7)
    love.graphics.setFont(font(16,"bold"));set(c.textInverse);love.graphics.printf(p.collapsed and "+" or "−",x+w-48,y+17,34,"center")
    addHit("move_panel_collapse",x+w-48,y+11,34,34)
    runtime.movePanelRect={x=x,y=y,w=w,h=h}
    if p.collapsed then runtime.moveListRect=nil;return end
    local rowH=38;local startY=y+72;local bottom=y+h-28;local visible=math.max(1,math.floor((bottom-startY)/rowH));local maxScroll=math.max(0,#moves-visible)
    runtime.moveScroll=clamp(runtime.moveScroll,0,maxScroll);runtime.moveListRect={x=x+14,y=startY,w=w-28,h=visible*rowH,maxScroll=maxScroll}
    for i=1,visible do local actual=runtime.moveScroll+i;local row=moves[actual];if not row then break end
      local ry=startY+(i-1)*rowH;local hover=runtime.hover and runtime.hover.kind=="move" and runtime.hover.data==actual
      if hover then set(c.subtle);love.graphics.rectangle("fill",x+14,ry,w-28,rowH-3,6,6) end
      love.graphics.setFont(font(10,"bold"));set(c.text);love.graphics.print(row.label,x+24,ry+8)
      love.graphics.setFont(font(8,"semibold"));set(c.textSecondary);love.graphics.printf(row.type,x+w-118,ry+10,92,"right")
      addHit("move",x+14,ry,w-28,rowH-3,actual)
    end
    if maxScroll>0 then
      local trackH=visible*rowH;local thumbH=math.max(28,trackH*(visible/#moves));local thumbY=startY+(trackH-thumbH)*(runtime.moveScroll/maxScroll)
      set(c.border);love.graphics.rectangle("fill",x+w-8,startY,3,trackH,2,2);set(c.focus);love.graphics.rectangle("fill",x+w-8,thumbY,3,thumbH,2,2)
    end
    love.graphics.setFont(font(8,"medium"));set(c.textSecondary);love.graphics.printf("CLICK ANY MOVE · ANIMATION ONLY · NO DAMAGE / PP",x+16,y+47,w-78,"right")
    -- Bottom-right resize grip. Minimum/maximum dimensions are enforced from
    -- pointer movement, so shrinking recomputes the visible list instead of
    -- clipping the old fixed-height browser.
    set(c.borderStrong);love.graphics.setLineWidth(2)
    love.graphics.line(x+w-22,y+h-8,x+w-8,y+h-22);love.graphics.line(x+w-15,y+h-8,x+w-8,y+h-15)
    addHit("move_panel_resize",x+w-34,y+h-34,34,34)
  end

  local function overlayState(game)
    if option("dev_overlay",true)~=true or runtime.open~=true then return false,false,false,nil end
    -- The Live Graphics Editor is a modal editor above the active BattleState.
    -- battleState() deliberately scans the whole stack so Dev battle tools can
    -- follow ordinary battle overlays, but that would let this priority-9000
    -- layer steal pointer/keyboard events from graphics_editor. Keep the Dev
    -- overlay open in session, yet suspend both its rendering and input
    -- ownership until the editor is closed.
    local current=top(game)
    if current and current.kind=="graphics_editor" then return false,false,false,nil end
    local battle=battleState(game);local main=current==game.overworld
    local battleTools=battle~=nil
    local moves=battleTools and option("move_preview_overlay",true)==true
    return main,battleTools,moves,battle
  end
  local function refreshPointerOwnership(game)
    local main,battleTools,moves=overlayState(game)
    runtime.pointerSurfaceActive=main or battleTools or moves
    return runtime.pointerSurfaceActive
  end
  local function toggleOverlay(game)
    if option("dev_overlay",true)~=true then return false end
    runtime.open=not runtime.open;runtime.drop=nil;runtime.dropScroll=0;runtime.hover=nil
    refreshPointerOwnership(game or runtime.game)
    return true
  end

  local function hitAt(x,y)
    for i=#runtime.hits,1,-1 do local r=runtime.hits[i];if inside(x,y,r) then return r end end
    return nil
  end
  local function pickIndex(kind,index,game)
    if kind=="species" then local list=pokemonList(game);if list[index] then runtime.speciesIndex=index;runtime.species=list[index].id end
    else local list=trainerList(game);if list[index] then runtime.trainerIndex=index end end
    runtime.drop=nil;runtime.dropScroll=0
  end
  local function cycle(kind,delta,game)
    if kind=="species" then local list=pokemonList(game);if #list>0 then runtime.speciesIndex=((runtime.speciesIndex-1+delta)%#list)+1;runtime.species=list[runtime.speciesIndex].id end
    else local list=trainerList(game);if #list>0 then runtime.trainerIndex=((runtime.trainerIndex-1+delta)%#list)+1 end end
  end
  local function activateHit(hit,game)
    if not hit then runtime.drop=nil;return true end
    local k=hit.kind
    if k=="species_prev" then cycle("species",-1,game)
    elseif k=="species_next" then cycle("species",1,game)
    elseif k=="species_open" then runtime.drop=runtime.drop=="species" and nil or "species";runtime.dropScroll=math.max(0,runtime.speciesIndex-4)
    elseif k=="species_pick" then pickIndex("species",hit.data,game)
    elseif k=="trainer_prev" then cycle("trainer",-1,game)
    elseif k=="trainer_next" then cycle("trainer",1,game)
    elseif k=="trainer_open" then runtime.drop=runtime.drop=="trainer" and nil or "trainer";runtime.dropScroll=math.max(0,runtime.trainerIndex-4)
    elseif k=="trainer_pick" then pickIndex("trainer",hit.data,game)
    elseif k=="level_minus" then runtime.level=clamp(runtime.level-1,1,100)
    elseif k=="level_plus" then runtime.level=clamp(runtime.level+1,1,100)
    elseif k=="level_value" then runtime.level=runtime.level>=100 and 1 or runtime.level+1
    elseif k=="shiny" then runtime.shiny=not runtime.shiny
    elseif k=="wild_start" then startWild(game)
    elseif k=="trainer_start" then startTrainer(game)
    elseif k=="one_shot_enemy" then oneShotEnemy(game)
    elseif k=="fly" then runtime.flyUnlocked=not runtime.flyUnlocked;notify(runtime.flyUnlocked and "DEV FLY UNLOCKED · SESSION ONLY" or "DEV FLY OVERRIDE OFF")
    elseif k=="move_panel_collapse" then runtime.movePanel.collapsed=not runtime.movePanel.collapsed;runtime.movePanelDrag=nil;clampMovePanel(runtime.viewport)
    elseif k=="move" then local row=moveList(game)[hit.data];if row then playMoveAnimation(game,row.id) end
    elseif k~="panel" then runtime.drop=nil end
    return true
  end

  if runtime.unregisterOverlayAction then pcall(runtime.unregisterOverlayAction) end
  if runtime.unregisterDump then pcall(runtime.unregisterDump) end
  runtime.unregisterOverlayAction=Core.inputActions.register({
    id="KRS_DEV_OVERLAY",label="DEV: TOGGLE INTERACTIVE OVERLAY",source=mod.id,group="KANTO REWORK DEV",
    description="Open the interactive wild/trainer/Fly developer overlay; in battle it becomes the move-animation browser.",defaults={key="f3"},priority=40})
  runtime.unregisterDump=Core.inputActions.register({
    id="KRS_DEV_DUMP_STATE",label="DEV: DUMP RUNTIME STATE",source=mod.id,group="KANTO REWORK DEV",
    description="Write the current stack/state summary to the log.",defaults={key="insert"},priority=28})

  if runtime.unregisterInputLayer then pcall(runtime.unregisterInputLayer) end
  runtime.unregisterInputLayer=Core.registerInputLayer({
    id="kanto_rework_dev.overlay",priority=9000,
    -- Stay registered while closed so the physical F3 event can open the tool.
    -- Pointer/wheel handlers explicitly decline ownership until a Dev surface is
    -- visible, so this layer cannot interfere with Voxel mouse-look.
    active=function() return option("dev_overlay",true)==true end,
    pointer=function(game,event)
      if not refreshPointerOwnership(game) then return false end
      local x,y=tonumber(event.x) or -1,tonumber(event.y) or -1
      if event.phase=="moved" then
        local drag=runtime.movePanelDrag
        if drag then
          local p=runtime.movePanel
          if drag.mode=="move" then p.x=x-drag.offsetX;p.y=y-drag.offsetY
          elseif drag.mode=="resize" then p.w=drag.startW+(x-drag.startX);p.h=drag.startH+(y-drag.startY) end
          clampMovePanel(runtime.viewport);return true
        end
        runtime.hover=hitAt(x,y);return true
      end
      if event.phase=="released" or event.phase=="cancelled" then runtime.movePanelDrag=nil;return true end
      if event.phase=="pressed" then
        if event.source=="mouse" and event.button==2 then runtime.movePanelDrag=nil;runtime.drop=nil;runtime.open=false;refreshPointerOwnership(game);return true end
        if event.source=="touch" or event.button==1 then
          local hit=hitAt(x,y)
          if hit and hit.kind=="move_panel_drag" then
            local p=runtime.movePanel;runtime.movePanelDrag={mode="move",offsetX=x-(tonumber(p.x) or 0),offsetY=y-(tonumber(p.y) or 0)};return true
          elseif hit and hit.kind=="move_panel_resize" and not runtime.movePanel.collapsed then
            local p=runtime.movePanel;runtime.movePanelDrag={mode="resize",startX=x,startY=y,startW=tonumber(p.w) or 420,startH=tonumber(p.h) or 560};return true
          end
          return activateHit(hit,game)
        end
        return true
      end
      return false
    end,
    wheel=function(game,dx,dy,x,y)
      if not refreshPointerOwnership(game) then return false end
      local delta=dy>0 and -1 or dy<0 and 1 or 0;if delta==0 then return true end
      if runtime.drop and runtime.dropRect and inside(x or -1,y or -1,runtime.dropRect) then runtime.dropScroll=clamp(runtime.dropScroll+delta,0,runtime.dropRect.maxScroll or 0);return true end
      if runtime.moveListRect and inside(x or -1,y or -1,runtime.moveListRect) then runtime.moveScroll=clamp(runtime.moveScroll+delta*3,0,runtime.moveListRect.maxScroll or 0);return true end
      return true
    end,
    keypressed=function(game,key,scancode,isrepeat)
      if key=="f3" and not isrepeat then
        runtime.skipLogicalToggle=true -- the same physical edge also feeds Core.inputActions
        return toggleOverlay(game)
      end
      if not refreshPointerOwnership(game) then return false end
      if key=="escape" then if runtime.drop then runtime.drop=nil else runtime.open=false end;refreshPointerOwnership(game);return true end
      return false
    end,
  })

  mod.events:on("game.ready",function(payload) runtime.game=payload and payload.game or runtime.game;runtime.flyUnlocked=false end)

  mod.hooks:wrap("input.step",function(next,game,dt)
    runtime.game=game or runtime.game
    if Core.inputActions.wasPressed("KRS_DEV_DUMP_STATE") then dumpState(game,"binding") end
    if Core.inputActions.wasPressed("KRS_DEV_OVERLAY") and option("dev_overlay",true)==true then
      if runtime.skipLogicalToggle then runtime.skipLogicalToggle=false else toggleOverlay(game) end
    elseif runtime.skipLogicalToggle then
      -- If a platform delivered keypressed without the Core physical edge, do
      -- not let the de-duplication flag leak into a later custom binding press.
      runtime.skipLogicalToggle=false
    end
    refreshPointerOwnership(game)
    return next(game,dt)
  end,60)

  mod.hooks:wrap("render.hud",function(next,game,viewport)
    runtime.game=game or runtime.game;runtime.viewport=viewport or runtime.viewport
    local result=next(game,viewport);runtime.hits={};runtime.hover=runtime.hover
    local main,battleTools,moves,battle=overlayState(game)
    runtime.pointerSurfaceActive=main or battleTools or moves
    if not runtime.pointerSurfaceActive or not(love and love.graphics) then
      runtime.dropRect=nil;runtime.moveListRect=nil;runtime.battleToolsRect=nil;return result
    end
    local c=colors(game);love.graphics.push("all");love.graphics.origin()
    if main then runtime.moveListRect=nil;runtime.movePanelRect=nil;runtime.battleToolsRect=nil;drawMain(game,runtime.viewport,c)
    else runtime.drop=nil;runtime.dropRect=nil end
    if battleTools then drawBattleTools(game,runtime.viewport,c,battle) else runtime.battleToolsRect=nil end
    if moves then drawMoves(game,runtime.viewport,c,battle) else runtime.moveListRect=nil;runtime.movePanelRect=nil;runtime.movePanelDrag=nil end
    love.graphics.pop();return result
  end,6000)

  mod.exports.version=EXPORT_API
  mod.exports.release=RELEASE
  mod.exports.open=function(value) if value~=nil then runtime.open=value==true end;refreshPointerOwnership(runtime.game);return runtime.open end
  mod.exports.triggerWild=function(game,species,level,shiny)
    game=game or runtime.game;local list=pokemonList(game)
    if species then for i,row in ipairs(list) do if row.id==species then runtime.speciesIndex=i;runtime.species=row.id;break end end end
    if level then runtime.level=clamp(math.floor(tonumber(level) or runtime.level),1,100) end;if shiny~=nil then runtime.shiny=shiny==true end
    return startWild(game)
  end
  mod.exports.triggerTrainer=function(game,classId,partyIndex)
    game=game or runtime.game;local list=trainerList(game)
    if classId then for i,row in ipairs(list) do if row.classId==classId and (not partyIndex or row.partyIndex==partyIndex) then runtime.trainerIndex=i;break end end end
    return startTrainer(game)
  end
  mod.exports.playMoveAnimation=function(game,moveId) return playMoveAnimation(game or runtime.game,moveId) end
  mod.exports.oneShotEnemy=function(game) return oneShotEnemy(game or runtime.game) end
  mod.exports.pointerSurfaceActive=function() return runtime.pointerSurfaceActive==true end
  mod.exports.setFlyUnlocked=function(value) runtime.flyUnlocked=value==true;return runtime.flyUnlocked end
  mod.exports.flyUnlocked=function() return runtime.flyUnlocked==true end
  mod.exports.dumpState=function(game,reason) return dumpState(game or runtime.game,reason) end
  mod.exports.status=function()
    return {release=RELEASE,open=runtime.open==true,pointerSurfaceActive=runtime.pointerSurfaceActive==true,
      species=runtime.species,level=runtime.level,shiny=runtime.shiny,flyUnlocked=runtime.flyUnlocked==true,
      movePreview=option("move_preview_overlay",true)==true,
      movePanel={x=runtime.movePanel.x,y=runtime.movePanel.y,w=runtime.movePanel.w,h=runtime.movePanel.h,collapsed=runtime.movePanel.collapsed==true},
      binding=Core.inputActions.binding("KRS_DEV_OVERLAY","key")}
  end

  mod.log:info("Kanto Rework Dev Tools %s ready (F3 interactive overlay, Insert state dump)",RELEASE)
end
