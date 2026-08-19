-- Theme-aware Wide presentation for Gen1Recomp's native LinkState and
-- Tournament state machines. Network, handshake, trade and bracket logic stay
-- entirely native; this module reads their public state and maps pointer input
-- back to the same A/B/directional actions their update methods consume.
return function(runtime)
  local okLink,LinkState=pcall(require,'src.link.LinkState')
  local okTournament,Tournament=pcall(require,'src.link.Tournament')
  local okCode,CodeEntry=pcall(require,'src.link.CodeEntry')
  local okNet,Net=pcall(require,'src.link.Net')
  local P={}

  local function ismt(state,value) return state and value and getmetatable(state)==value end
  function P.handles(_,state)
    return (okLink and ismt(state,LinkState)) or (okTournament and ismt(state,Tournament))
  end
  function P.kind(state)
    if okTournament and ismt(state,Tournament) then return 'tournament' end
    if okLink and ismt(state,LinkState) then return 'link' end
  end

  local function addRect(id,x,y,w,h,meta)
    local row=meta or {};row.id=id;row.x=x;row.y=y;row.w=w;row.h=h
    runtime.linkRects[#runtime.linkRects+1]=row;return row
  end
  local function panelButton(D,m,c,id,label,description,x,y,w,h,selected,meta)
    local hover=runtime.linkHover==id
    D.panel(m,x,y,w,h,12,selected and c.inverse or (hover and c.subtle or c.panel),selected and c.focus or (hover and c.focus or c.border))
    if selected then D.roundRect(m,'fill',x+14,y+18,5,h-36,2.5,c.focus) end
    D.text(runtime,m,label,x+30,y+22,18,selected and c.textInverse or c.text,{weight='bold',width=w-60})
    if description then D.text(runtime,m,description,x+30,y+54,12,selected and c.faint or c.textSecondary,{width=w-60}) end
    addRect(id,x,y,w,h,meta)
  end
  local function shell(game,m,c,eyebrow,title,stage)
    local D=runtime.Draw
    D.roundRect(m,'fill',0,0,1920,1080,0,c.canvas)
    D.roundRect(m,'fill',0,0,1920,88,0,c.inverse)
    D.text(runtime,m,'KANTO JOURNAL',32,18,22,c.textInverse,{weight='bold'})
    D.text(runtime,m,'LINK HUB',32,53,10,c.faint,{weight='bold'})
    D.text(runtime,m,eyebrow or 'CONNECTION',650,24,10,c.faint,{weight='bold',width=620,align='center'})
    D.text(runtime,m,title or 'LINK',650,44,18,c.textInverse,{weight='bold',width=620,align='center'})
    D.text(runtime,m,tostring(stage or ''):gsub('_',' '):upper(),1500,20,10,c.faint,{weight='bold',width=388,align='right'})
    D.text(runtime,m,runtime.Theme and runtime.Theme.label() or 'KRS',1500,47,11,c.textInverse,{weight='semibold',width=388,align='right'})
    D.roundRect(m,'fill',0,1016,1920,64,0,c.inverse)
  end
  local function footer(m,c,prompts)
    local D=runtime.Draw;local x=32
    for _,p in ipairs(prompts or {}) do
      D.text(runtime,m,p[1],x,1037,11,c.textInverse,{weight='bold'})
      D.text(runtime,m,p[2],x+92,1038,10,c.faint,{weight='semibold'});x=x+286
    end
    D.text(runtime,m,'KEYBOARD + MOUSE',1640,1038,11,c.textInverse,{weight='semibold',width=248,align='right'})
  end
  local function statusPanel(D,m,c,title,body,detail)
    D.panel(m,356,226,1208,596,20,c.panel,c.border)
    D.text(runtime,m,title,420,294,34,c.text,{weight='bold',width=1080,align='center'})
    D.text(runtime,m,body,500,386,20,c.text,{weight='semibold',width=920,align='center'})
    if detail and detail~='' then D.text(runtime,m,detail,520,468,14,c.textSecondary,{width=880,align='center'}) end
    local cx,cy=960,626
    for i=1,3 do local r=22+i*8;D.roundRect(m,'line',cx-r,cy-r,r*2,r*2,r,c.focus,2) end
  end
  local function clean(value) return tostring(value or ''):gsub('[\v\f]',' '):gsub('%s+',' ') end
  local function monName(game,mon)
    local def=mon and game.data and game.data.pokemon and game.data.pokemon[mon.species]
    return tostring(mon and (mon.nickname or (def and def.name) or mon.species) or '—'):upper()
  end
  local function codeText(entry,pos)
    if not (okCode and CodeEntry and entry and entry.chars and entry.chars[pos]) then return '—' end
    local index=entry.chars[pos];return CodeEntry.CHARSET:sub(index,index)
  end
  local function drawCodeEntry(D,m,c,state,kind)
    local tournament=kind=='tournament';local entry=state.codeEntry;local count=(okCode and CodeEntry.LENGTH) or 6
    D.text(runtime,m,tournament and 'JOIN TOURNAMENT' or 'JOIN ONLINE',356,178,11,c.textSecondary,{weight='bold'})
    D.text(runtime,m,'ENTER CONNECTION CODE',356,210,32,c.text,{weight='bold'})
    D.text(runtime,m,'Use the code created by the host. Select a character, then change it with Up / Down or the mouse wheel.',356,264,15,c.textSecondary,{width=1208})
    local cellW,gap=132,18;local total=count*cellW+(count-1)*gap;local x0=(1920-total)/2
    for i=1,count do
      local x=x0+(i-1)*(cellW+gap);local active=entry and i==entry.pos;local id='code_'..i
      D.panel(m,x,382,cellW,142,14,active and c.inverse or c.panel,active and c.focus or (runtime.linkHover==id and c.focus or c.border))
      D.text(runtime,m,codeText(entry,i),x,414,48,active and c.textInverse or c.text,{weight='bold',width=cellW,align='center'})
      D.text(runtime,m,active and 'ACTIVE' or ('SLOT '..i),x,486,9,active and c.faint or c.textSecondary,{weight='bold',width=cellW,align='center'})
      addRect(id,x,382,cellW,142,{codePos=i})
    end
    panelButton(D,m,c,'connect','CONNECT','Open the session using this code.',716,616,488,104,false,{action='a'})
  end
  local function ipString(state)
    local out={};for octet=1,4 do local b=(octet-1)*3;out[#out+1]=tostring((state.addr[b+1] or 0)*100+(state.addr[b+2] or 0)*10+(state.addr[b+3] or 0)) end
    return table.concat(out,'.')
  end
  local function drawAddressEntry(D,m,c,state)
    D.text(runtime,m,'LOCAL NETWORK',356,178,11,c.textSecondary,{weight='bold'})
    D.text(runtime,m,'ENTER HOST ADDRESS',356,210,32,c.text,{weight='bold'})
    D.text(runtime,m,'Select a digit and change it with Up / Down or the mouse wheel.',356,264,15,c.textSecondary,{width=1208})
    local x=300
    for i=1,12 do
      local octet=math.floor((i-1)/3);local px=x+(i-1)*82+octet*30;local active=i==state.addrPos;local id='addr_'..i
      D.panel(m,px,382,68,116,10,active and c.inverse or c.panel,active and c.focus or (runtime.linkHover==id and c.focus or c.border))
      D.text(runtime,m,tostring(state.addr[i] or 0),px,408,34,active and c.textInverse or c.text,{weight='bold',width=68,align='center'})
      addRect(id,px,382,68,116,{addrPos=i})
      if i%3==0 and i<12 then D.text(runtime,m,'.',px+72,420,30,c.textSecondary,{weight='bold',width=26,align='center'}) end
    end
    local port=okNet and Net.defaultPort and Net.defaultPort() or '—'
    D.text(runtime,m,'HOST PREVIEW',540,544,10,c.textSecondary,{weight='bold'});D.text(runtime,m,ipString(state)..'  ·  UDP '..tostring(port),540,570,18,c.text,{weight='semibold',width=840,align='center'})
    panelButton(D,m,c,'connect','CONNECT','Call the selected LAN host.',716,650,488,96,false,{action='a'})
  end
  local function forceLevelLabel(value)
    if value==nil or value=='ANY' then return 'ANY' end
    return 'AUTO '..tostring(value)
  end

  local function drawLink(game,state,m,c)
    local D=runtime.Draw;local stage=state.stage or 'menu'
    local titleByStage={menu='CONNECTION TYPE',lanMenu='LINK CABLE (LAN)',onlineMenu='ONLINE MATCH',onlineHosting='HOST ONLINE',codeEntry='ENTER CODE',onlineJoining='CONNECTING',hosting='HOST LAN GAME',addrEntry='HOST ADDRESS',joining='CONNECTING',modeSelect='SESSION MODE',battleOptions='BATTLE OPTIONS',waitMode='CONNECTED',waitHello='COMPATIBILITY CHECK',notice='LINK NOTICE',trade='TRADE CENTER',battleWait='LINK BATTLE',battleRunning='LINK BATTLE'}
    shell(game,m,c,'BOIS CLUB LIVE',titleByStage[stage] or 'LINK SESSION',stage)
    if stage=='menu' then
      D.text(runtime,m,'CONNECTIVITY',224,154,10,c.textSecondary,{weight='bold'});D.text(runtime,m,'CHOOSE HOW TO CONNECT',224,186,30,c.text,{weight='bold'})
      local rows={{'lan','LINK CABLE (LAN)','Host or join directly on the local network.'},{'online','ONLINE MATCH','Use a short relay code to connect over the internet.'},{'tournament','TOURNAMENT','Host, join or watch a server-managed bracket.'}}
      for i,row in ipairs(rows) do panelButton(D,m,c,row[1],row[2],row[3],224,260+(i-1)*174,1472,136,state.index==i,{index=i,action='a'}) end
      footer(m,c,{{'UP / DOWN','SELECT'},{'ENTER / A','OPEN'},{'B / RMB','BACK'}})
    elseif stage=='lanMenu' or stage=='onlineMenu' then
      local online=stage=='onlineMenu';D.text(runtime,m,online and 'RELAY SESSION' or 'DIRECT PEER-TO-PEER',304,184,10,c.textSecondary,{weight='bold'})
      D.text(runtime,m,online and 'ONLINE MATCH' or 'LOCAL NETWORK',304,216,32,c.text,{weight='bold'})
      panelButton(D,m,c,'host',online and 'HOST ONLINE' or 'HOST A GAME',online and 'Create a relay code for the other player.' or 'Listen on this computer and show its LAN address.',304,310,620,220,state.index==1,{index=1,action='a'})
      panelButton(D,m,c,'join',online and 'JOIN ONLINE' or 'JOIN A GAME',online and 'Enter the host relay code.' or 'Enter the host computer address.',996,310,620,220,state.index==2,{index=2,action='a'})
      if not online then D.text(runtime,m,'UDP PORT',304,596,10,c.textSecondary,{weight='bold'});D.text(runtime,m,tostring(okNet and Net.defaultPort and Net.defaultPort() or '—'),304,626,20,c.text,{weight='semibold'}) end
      footer(m,c,{{'UP / DOWN','SELECT'},{'ENTER / A','OPEN'},{'B / RMB','BACK'}})
    elseif stage=='codeEntry' then
      drawCodeEntry(D,m,c,state,'link');footer(m,c,{{'ARROWS','EDIT'},{'WHEEL','CHANGE'},{'ENTER / A','CONNECT'},{'B / RMB','BACK'}})
    elseif stage=='addrEntry' then
      drawAddressEntry(D,m,c,state);footer(m,c,{{'ARROWS','EDIT'},{'WHEEL','CHANGE'},{'ENTER / A','CONNECT'},{'B / RMB','BACK'}})
    elseif stage=='onlineHosting' then
      statusPanel(D,m,c,'HOSTING ONLINE','SHARE THIS CODE',tostring(state.net and state.net.code or '??????'))
      D.text(runtime,m,tostring(state.net and state.net.code or '??????'),600,498,54,c.focus,{weight='bold',width=720,align='center'})
      footer(m,c,{{'B / RMB','CANCEL'}})
    elseif stage=='hosting' then
      statusPanel(D,m,c,'HOSTING LAN GAME','YOUR FRIEND JOINS AT',tostring(state.net and state.net.address or '?'))
      D.text(runtime,m,tostring(state.net and state.net.address or '?'),600,498,38,c.focus,{weight='bold',width=720,align='center'})
      footer(m,c,{{'B / RMB','CANCEL'}})
    elseif stage=='onlineJoining' or stage=='joining' then
      statusPanel(D,m,c,'CONNECTING','CALLING HOST…',tostring(state.net and state.net.target or ''))
      footer(m,c,{{'B / RMB','CANCEL'}})
    elseif stage=='modeSelect' then
      D.text(runtime,m,'PEER CONNECTED',304,184,10,c.success,{weight='bold'});D.text(runtime,m,'CHOOSE SESSION MODE',304,216,32,c.text,{weight='bold'})
      panelButton(D,m,c,'trade','TRADE','Exchange one compatible party Pokémon.',304,310,620,220,state.index==1,{index=1,action='a'})
      panelButton(D,m,c,'battle','BATTLE','Start a deterministic Link Battle.',996,310,620,220,state.index==2,{index=2,action='a'})
      footer(m,c,{{'UP / DOWN','SELECT'},{'ENTER / A','CONTINUE'},{'B / RMB','CANCEL'}})
    elseif stage=='battleOptions' then
      D.text(runtime,m,'HOST RULE',420,226,10,c.textSecondary,{weight='bold'});D.text(runtime,m,'NORMALIZE LEVELS',420,258,32,c.text,{weight='bold'})
      local value=forceLevelLabel(state.levelChoice)
      D.panel(m,420,340,1080,148,14,c.panel,c.border);D.text(runtime,m,'LEVELS',452,374,10,c.textSecondary,{weight='bold'});D.text(runtime,m,value,452,408,30,c.text,{weight='bold'})
      panelButton(D,m,c,'level_prev','‹','Previous rule',420,526,220,104,false,{action='left'})
      panelButton(D,m,c,'continue','CONTINUE','Exchange parties and start.',716,526,488,104,false,{action='a'})
      panelButton(D,m,c,'level_next','›','Next rule',1280,526,220,104,false,{action='right'})
      footer(m,c,{{'LEFT / RIGHT','LEVEL RULE'},{'ENTER / A','CONTINUE'},{'B / RMB','CANCEL'}})
    elseif stage=='waitMode' or stage=='waitHello' then
      statusPanel(D,m,c,'CONNECTED',stage=='waitHello' and 'CHECKING THE OTHER GAME…' or 'WAITING FOR THE HOST TO CHOOSE…',state.peerName and ('PEER  ·  '..tostring(state.peerName)) or nil)
      footer(m,c,{{'B / RMB','CANCEL'}})
    elseif stage=='notice' then
      local title=state.verdict=='engine_skew' and 'UPDATE YOUR GAME' or 'CHECK YOUR MODS'
      D.panel(m,260,154,1400,744,18,c.panel,c.border);D.text(runtime,m,'COMPATIBILITY NOTICE',308,194,10,c.danger,{weight='bold'});D.text(runtime,m,title,308,230,34,c.text,{weight='bold'})
      local y=300;for i,line in ipairs(state.noticeLines or {}) do if i>12 then break end;D.text(runtime,m,clean(line),308,y,15,c.textSecondary,{width=1304});y=y+34 end
      panelButton(D,m,c,'notice_action',state.noticeExits and 'BACK' or 'TRADE ANYWAY',state.noticeExits and 'Close this session safely.' or 'Continue with the negotiated compatible subset.',1110,790,502,76,false,{action='a'})
      footer(m,c,{{'ENTER / A',state.noticeExits and 'BACK' or 'TRADE ANYWAY'},{'B / RMB','CANCEL'}})
    elseif stage=='trade' then
      local trade=state.trade or {};D.text(runtime,m,'CONNECTED TRADE',128,132,10,c.success,{weight='bold'});D.text(runtime,m,'CHOOSE A PARTNER',128,164,30,c.text,{weight='bold'})
      local function partyColumn(label,party,x,localSide)
        D.text(runtime,m,label,x,226,12,c.textSecondary,{weight='bold'});for i=1,6 do local mon=party and party[i];local y=264+(i-1)*104;local selected=localSide and state.index==i;local remote=(not localSide) and trade.theirPick==i;local allowed=not localSide or not trade.canPick or trade:canPick(i);local id=(localSide and 'mine_' or 'theirs_')..i
          D.panel(m,x,y,760,88,10,(selected or remote) and c.inverse or c.panel,(selected or remote) and c.focus or c.border)
          D.text(runtime,m,('%02d'):format(i),x+20,y+18,10,(selected or remote) and c.faint or c.textSecondary,{weight='bold'})
          D.text(runtime,m,mon and monName(game,mon) or '—',x+70,y+16,16,(selected or remote) and c.textInverse or c.text,{weight='semibold',width=430})
          D.text(runtime,m,mon and ('Lv. '..tostring(mon.level or '—')) or '',x+560,y+18,11,(selected or remote) and c.faint or c.textSecondary,{weight='semibold',width=150,align='right'})
          if mon and not allowed then D.text(runtime,m,'NOT COMPATIBLE',x+70,y+48,9,c.danger,{weight='bold'}) end
          if localSide and mon then addRect(id,x,y,760,88,{index=i,action='a'}) end
        end
      end
      partyColumn('YOUR PARTY',game.save.party or {},128,true);partyColumn('THEIR PARTY',trade.theirParty or {},1032,false)
      local hints={waitRecords='COMPARING GAMES…',waitParty='EXCHANGING DATA…',picking='SELECT ONE TO TRADE',waitPick='WAITING FOR PEER…',confirming=state.confirmed and 'WAITING FOR PEER…' or 'CONFIRM TRADE'}
      D.text(runtime,m,hints[trade.stage] or 'TRADE SESSION',128,930,13,c.textSecondary,{weight='bold',width=1664,align='center'})
      footer(m,c,{{'UP / DOWN','SELECT'},{'ENTER / A','PICK · CONFIRM'},{'B / RMB','CANCEL'}})
    elseif stage=='battleWait' or stage=='battleRunning' then
      statusPanel(D,m,c,'LINK BATTLE',stage=='battleRunning' and 'BATTLE IN PROGRESS…' or 'EXCHANGING PARTY DATA…',state.peerName and ('OPPONENT  ·  '..tostring(state.peerName)) or nil)
      footer(m,c,{{'B / RMB','CANCEL'}})
    else
      statusPanel(D,m,c,'LINK SESSION','PREPARING INTERFACE…',stage);footer(m,c,{{'B / RMB','BACK'}})
    end
  end

  local function tournamentValue(state,index)
    local s=state.settings or {};local values={s.requiredPartySize,s.minLevel,s.maxLevel,s.turnLimit and (s.turnLimit..'s') or '—',forceLevelLabel(s.forceLevel),s.participating==false and 'NO' or 'YES'}
    local value=values[index];if value==nil or value=='ANY' then return 'ANY' end;return tostring(value)
  end
  local function drawTournament(game,state,m,c)
    local D=runtime.Draw;local stage=state.stage or 'menu';shell(game,m,c,'BOIS CLUB LIVE','TOURNAMENT',stage)
    if stage=='menu' then
      D.text(runtime,m,'BRACKET PLAY',304,184,10,c.textSecondary,{weight='bold'});D.text(runtime,m,'TOURNAMENT LOBBY',304,216,32,c.text,{weight='bold'})
      panelButton(D,m,c,'host','HOST TOURNAMENT','Choose the rules and create a relay code.',304,310,620,220,state.index==1,{index=1,action='a'})
      panelButton(D,m,c,'join','JOIN TOURNAMENT','Enter an existing tournament code.',996,310,620,220,state.index==2,{index=2,action='a'})
      footer(m,c,{{'UP / DOWN','SELECT'},{'ENTER / A','OPEN'},{'B / RMB','BACK'}})
    elseif stage=='hostSettings' then
      local labels={'POKÉMON','MIN LEVEL','MAX LEVEL','TURN TIMER','LEVELS','HOST PLAYING'}
      D.text(runtime,m,'CREATE TOURNAMENT',250,132,10,c.textSecondary,{weight='bold'});D.text(runtime,m,'MATCH RULES',250,164,30,c.text,{weight='bold'})
      for i,label in ipairs(labels) do local col=(i-1)%2;local row=math.floor((i-1)/2);local x=250+col*730;local y=238+row*176;local active=state.settingsIndex==i;local id='setting_'..i
        D.panel(m,x,y,650,140,12,active and c.inverse or c.panel,active and c.focus or c.border);D.text(runtime,m,label,x+24,y+22,10,active and c.faint or c.textSecondary,{weight='bold'});D.text(runtime,m,tournamentValue(state,i),x+24,y+54,28,active and c.textInverse or c.text,{weight='bold'});D.text(runtime,m,'‹',x+520,y+52,24,active and c.textInverse or c.textSecondary,{weight='bold'});D.text(runtime,m,'›',x+588,y+52,24,active and c.textInverse or c.textSecondary,{weight='bold'});addRect(id,x,y,650,140,{settingsIndex=i})
        addRect(id..'_left',x+494,y+36,64,68,{settingsIndex=i,action='left'});addRect(id..'_right',x+566,y+36,64,68,{settingsIndex=i,action='right'})
      end
      panelButton(D,m,c,'create','CREATE TOURNAMENT','Register these rules and open the lobby.',716,812,488,88,false,{action='start'})
      footer(m,c,{{'ARROWS','SELECT · ADJUST'},{'ENTER / START','CREATE'},{'B / RMB','BACK'}})
    elseif stage=='codeEntry' then
      drawCodeEntry(D,m,c,state,'tournament');footer(m,c,{{'ARROWS','EDIT'},{'WHEEL','CHANGE'},{'ENTER / A','JOIN'},{'B / RMB','BACK'}})
    elseif stage=='registering' then
      statusPanel(D,m,c,'CONNECTING','REGISTERING TOURNAMENT…',state.code and ('CODE  ·  '..state.code) or nil);footer(m,c,{{'B / RMB','CANCEL'}})
    elseif stage=='bracket' or stage=='matchHello' or stage=='matchWaitParty' or stage=='spectateWait' then
      local code=tostring(state.code or '??????');D.text(runtime,m,'TOURNAMENT '..code,112,130,10,c.textSecondary,{weight='bold'});D.text(runtime,m,state.bracket and 'LIVE BRACKET' or 'WAITING ROOM',112,162,30,c.text,{weight='bold'})
      D.panel(m,112,222,1120,700,16,c.panel,c.border);D.panel(m,1260,222,548,700,16,c.panel,c.border)
      if state.bracket and state.bracket.rounds then
        local y=252;for _,round in ipairs(state.bracket.rounds) do D.text(runtime,m,'ROUND '..tostring(round.round),140,y,11,c.focus,{weight='bold'});y=y+34;for _,match in ipairs(round.matches or {}) do if y>870 then break end;local a=tostring(match.a or '?');local b=tostring(match.b or '?');local status=match.bye and 'BYE' or match.state=='live' and 'LIVE' or match.winner and 'FINAL' or 'PENDING';D.panel(m,140,y,1064,54,8,c.elevated,c.border);D.text(runtime,m,a..'  VS  '..b,158,y+17,12,c.text,{weight='semibold',width=730});D.text(runtime,m,status,1020,y+17,9,status=='LIVE' and c.success or c.textSecondary,{weight='bold',width=150,align='right'});y=y+64 end;y=y+12 end
      else
        D.text(runtime,m,state.participating==false and 'ORGANIZER · NOT PLAYING' or 'PLAYERS',140,252,10,c.textSecondary,{weight='bold'});local y=296
        for i,name in ipairs(state.roster or {}) do D.panel(m,140,y,500,48,8,c.elevated,c.border);D.text(runtime,m,('%02d  %s'):format(i,tostring(name)),158,y+15,11,c.text,{weight='semibold'});y=y+58 end
        for _,name in ipairs(state.spectatorRoster or {}) do D.panel(m,674,y,500,48,8,c.elevated,c.border);D.text(runtime,m,tostring(name)..'  ·  WATCH',692,y+15,11,c.textSecondary,{weight='semibold'});y=y+58 end
      end
      D.text(runtime,m,'SESSION',1292,252,10,c.textSecondary,{weight='bold'});D.text(runtime,m,'CODE',1292,298,10,c.textSecondary,{weight='bold'});D.text(runtime,m,code,1292,326,34,c.focus,{weight='bold'});D.line(m,1292,390,1776,390,c.border,1);D.text(runtime,m,'STATUS',1292,424,10,c.textSecondary,{weight='bold'});D.text(runtime,m,stage=='matchHello' and 'CHECKING OPPONENT' or stage=='matchWaitParty' and 'EXCHANGING PARTIES' or stage=='spectateWait' and 'PREPARING SPECTATOR' or state.bracket and 'BRACKET ACTIVE' or 'WAITING FOR PLAYERS',1292,454,16,c.text,{weight='semibold',width=450})
      if state.isCreator and #(state.roster or {})>=2 and not state.bracket then panelButton(D,m,c,'start_tournament','START TOURNAMENT','Lock the roster and begin the bracket.',1292,786,450,82,false,{action='a'}) end
      footer(m,c,{{'ENTER / A','START WHEN READY'},{'B / RMB','CANCEL'}})
    elseif stage=='done' then
      statusPanel(D,m,c,'TOURNAMENT OVER',state.champion and (tostring(state.champion):upper()..' IS THE CHAMPION!') or 'BRACKET COMPLETE','All reported matches have finished.')
      panelButton(D,m,c,'continue','CONTINUE','Return to the game.',716,714,488,88,false,{action='a'});footer(m,c,{{'ENTER / A','CONTINUE'},{'B / RMB','BACK'}})
    else
      statusPanel(D,m,c,'TOURNAMENT',stage=='matchRunning' and 'MATCH IN PROGRESS…' or stage=='spectateRunning' and 'WATCHING MATCH…' or 'PREPARING BRACKET…',stage);footer(m,c,{{'B / RMB','CANCEL'}})
    end
  end

  function P.draw(game,viewport)
    local state=game and game.stack and game.stack.top and game.stack:top()
    if not state or not runtime.Layout.isWide(viewport) or not P.handles(game,state) then return false end
    local m=runtime.Layout.metrics(viewport);local c=runtime.Theme.resolveAll(runtime,game);runtime.linkRects={}
    love.graphics.push('all');love.graphics.origin()
    local ok,err=pcall(function()
      if P.kind(state)=='tournament' then drawTournament(game,state,m,c) else drawLink(game,state,m,c) end
    end)
    love.graphics.pop();if not ok then return nil,err end;return true
  end

  local function hit(lx,ly)
    for i=#(runtime.linkRects or {}),1,-1 do local r=runtime.linkRects[i];if runtime.Layout.contains(lx,ly,r) then return r end end
  end
  local function tap(game,action) if action and runtime.mod and runtime.mod.input then runtime.mod.input:tap(game,action);return true end end
  function P.pointer(game,event,lx,ly)
    local state=game and game.stack and game.stack:top();if not P.handles(game,state) then return false end
    local r=hit(lx,ly)
    if event.phase=='moved' then runtime.linkHover=r and r.id or nil;return true end
    if event.phase=='pressed' then
      if event.source=='mouse' and event.button==2 then return tap(game,'b') end
      if not (event.source=='touch' or event.button==1) then return true end
      if not r then return true end
      if r.index then state.index=r.index end;if r.settingsIndex then state.settingsIndex=r.settingsIndex end
      if r.codePos and state.codeEntry then state.codeEntry.pos=r.codePos end;if r.addrPos then state.addrPos=r.addrPos end
      if r.action then return tap(game,r.action) end
      return true
    end
    return event.phase=='released' or event.phase=='cancelled'
  end
  function P.wheel(game,dy,lx,ly)
    if dy==0 then return false end;local state=game and game.stack and game.stack:top();if not P.handles(game,state) then return false end
    local r=hit(lx,ly);if not r then return true end
    if r.codePos and state.codeEntry then state.codeEntry.pos=r.codePos;return tap(game,dy>0 and 'up' or 'down') end
    if r.addrPos then state.addrPos=r.addrPos;return tap(game,dy>0 and 'up' or 'down') end
    if r.settingsIndex then state.settingsIndex=r.settingsIndex;return tap(game,dy>0 and 'right' or 'left') end
    return true
  end
  return P
end
