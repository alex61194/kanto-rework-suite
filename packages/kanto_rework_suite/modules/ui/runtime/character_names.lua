-- Stable semantic identities for Gen 1 NPCs/trainers that never received a
-- personal name in the ROM. Presentation metadata only: no save, trainer
-- class, party, battle rule or map object is mutated.
return function(deps)
  deps=deps or {}
  local mod=deps.mod
  local Names={}

  local SPECIAL={
    BROCK='BROCK',MISTY='MISTY',LT_SURGE='LT. SURGE',ERIKA='ERIKA',KOGA='KOGA',
    SABRINA='SABRINA',BLAINE='BLAINE',GIOVANNI='GIOVANNI',LORELEI='LORELEI',
    BRUNO='BRUNO',AGATHA='AGATHA',LANCE='LANCE',PROF_OAK='PROFESOR OAK',
    OAK='PROFESOR OAK',MOM='MAMÁ',NURSE='ENFERMERA JOY',NURSE_JOY='ENFERMERA JOY',
    DAISY='DAISY',BILL='BILL',FUJI='SR. FUJI',MR_FUJI='SR. FUJI',
  }
  local LABEL={
    YOUNGSTER='JOVEN',BUG_CATCHER='CAZABICHOS',LASS='CHICA',
    JR_TRAINER_M='ENTRENADOR JR.',JR_TRAINER_F='ENTRENADORA JR.',
    POKEMANIAC='POKÉMANIACO',SUPER_NERD='SÚPER NECIO',HIKER='MONTAÑERO',BIKER='MOTORISTA',
    BURGLAR='LADRÓN',ENGINEER='INGENIERO',FISHER='PESCADOR',SWIMMER='NADADOR',
    CUE_BALL='CALVO',GAMBLER='JUGADOR',BEAUTY='BELLA',PSYCHIC='MÉDIUM',
    ROCKER='ROCKERO',JUGGLER='MALABARISTA',TAMER='DOMADOR',BIRD_KEEPER='ORNITÓLOGO',
    BLACKBELT='KARATEKA',SCIENTIST='CIENTÍFICO',ROCKET='RECLUTA ROCKET',
    COOLTRAINER_M='ENTR. GUAY',COOLTRAINER_F='ENTR. GUAY',SAILOR='MARINERO',
    CHANNELER='EXORCISTA',GENTLEMAN='CABALLERO',POKE_MAN='POKÉMANIACO',
  }
  local POOLS={
    YOUNGSTER={'BEN','JOEY','TIM','NATE','SAM','EDDIE','CAL'},
    BUG_CATCHER={'RICK','DOUG','WADE','NED','COLT','ARI','TODD'},
    LASS={'JAN','MIA','LISA','KATE','ELLIE','NINA','AMY'},
    JR_TRAINER_M={'ALEX','IAN','EVAN','MARK','JOSH','DEAN'},
    JR_TRAINER_F={'MAYA','JEN','KIM','TARA','ANNA','LEAH'},
    POKEMANIAC={'BRENT','ERIC','MILES','DON','JARED'},SUPER_NERD={'MIGUEL','GLENN','LESLIE','TOM','DEXTER'},
    HIKER={'CLARK','ANTHONY','RUSSELL','DEREK','ALLEN','BRYCE'},BIKER={'JAX','RICO','AXEL','VINCE','DUKE'},
    BURGLAR={'QUINN','RAMON','EDDIE','LOU','CHASE'},ENGINEER={'BERNIE','TED','GREG','HUGO','MARTIN'},
    FISHER={'DALE','NOLAN','HANK','PETE','WADE','LUIS'},SWIMMER={'SEAN','LUKE','DYLAN','KAI','MATT'},
    CUE_BALL={'MILO','RAY','TONY','VIN','BRUNO'},GAMBLER={'GUS','DIRK','ROMAN','MORGAN','REED'},
    BEAUTY={'LANA','RINA','SOPHIE','MAY','VIVI','TESS'},PSYCHIC={'ELI','ORION','SAGE','NOEL','SOREN'},
    ROCKER={'ZACK','TREY','ACE','MICK','RYAN'},JUGGLER={'KAI','DREW','TOBY','NILS','REMI'},
    TAMER={'VIC','OWEN','BRAD','REX','GABE'},BIRD_KEEPER={'ABE','PERRY','HUGH','DAN','ROBIN'},
    BLACKBELT={'KEN','KOJI','RYU','MASA','LEE'},SCIENTIST={'ELLIOT','ROSS','IVAN','NEIL','MARC','CEDRIC','ALAN','HUGH'},
    ROCKET={'MASON','COLE','REX','NASH','KIRK','LEON','DAX','ROAN','VITO'},
    COOLTRAINER_M={'ACE','JULIAN','LUKE','SIMON','ERIC'},COOLTRAINER_F={'SKYE','JULIA','CLAIRE','ERIN','NORA'},
    SAILOR={'DUNCAN','HUGH','MARTY','FINN','ROSS'},CHANNELER={'HOPE','RUTH','MIRIAM','ADA','EVA'},
    GENTLEMAN={'ARTHUR','EDGAR','WALTER','HENRY','OSCAR'},
    RESIDENT_M={'ADAM','PAUL','JACK','MILO','NOAH','LEO'},RESIDENT_F={'ANNA','MIA','LILY','EMMA','NORA','JUNE'},
    CHILD_M={'TIM','BEN','SAM','LEO','NICO'},CHILD_F={'MAY','LILY','ELLIE','NINA','AMY'},
    CLERK={'MARTIN','ELLIS','OWEN','CEDRIC'},AIDE={'CALEB','SIMON','ELLIOT','MARCUS','NOLAN','THEO'},
  }

  -- A global reserve prevents two unnamed people from receiving the same
  -- personal name. Class-specific pools are preferred; the larger gendered
  -- pools provide deterministic collision fallbacks as the player explores
  -- the whole region. Canonical characters are reserved up front.
  local MASTER_M={
    'AARON','ADRIAN','ALBERT','ANDREW','ARLO','BLAKE','BRIAN','CAMERON','CARL','CEDRIC','CHARLIE','COLIN','CONNOR','CRAIG','DAMIEN','DANIEL','DARIUS','DAVID','DENNIS','DEREK','DOMINIC','DYLAN','EDWIN','ELIAS','ELIOT','ETHAN','FELIX','FINN','FRANK','GABRIEL','GAVIN','GEORGE','GRANT','HARVEY','HAYDEN','HENRY','HUGO','IAN','ISAAC','JAMIE','JASON','JEREMY','JESSE','JONAH','JORDAN','JULIAN','KEITH','KYLE','LIAM','LOGAN','LOUIS','LUCAS','MARCUS','MARTIN','MASON','MAX','MILES','NATHAN','NEIL','NICHOLAS','NOLAN','OLIVER','OSCAR','OWEN','PARKER','PETER','PHILIP','QUENTIN','REED','RILEY','ROBIN','RYAN','SAMUEL','SCOTT','SETH','SIMON','THEO','THOMAS','TOBIAS','TRAVIS','VICTOR','WESLEY','WYATT','ZANE'
  }
  local MASTER_F={
    'ABIGAIL','ADA','ALICE','ALINA','AMBER','AMELIA','AMY','ANNA','AUDREY','AVA','BELLA','BETH','BIANCA','BONNIE','CARA','CASSIE','CELIA','CLAIRE','CORA','DANA','DIANA','ELENA','ELISE','ELLIE','EMMA','ERIN','EVA','EVELYN','FAYE','FIONA','GRACE','HANNAH','HAZEL','HEIDI','HOLLY','HOPE','IRIS','ISABEL','IVY','JANE','JENNA','JESS','JULIA','KARA','KATE','KIRA','LANA','LAURA','LEAH','LENA','LILY','LUCY','MARA','MAYA','MIA','NAOMI','NINA','NORA','OLIVIA','PAIGE','RACHEL','RINA','ROSE','RUBY','RUTH','SADIE','SARA','SKYE','SOPHIE','STELLA','TARA','TESS','VERA','VIVIAN','WENDY','ZOE'
  }
  local GENDER={
    LASS='F',JR_TRAINER_F='F',BEAUTY='F',COOLTRAINER_F='F',CHANNELER='F',
    RESIDENT_F='F',CHILD_F='F',NURSE_JOY='F',DAISY='F',MOM='F',
  }
  local SAVE_KEY='character_names_v3'
  local assigned,usedFirst={},{}
  local saved=mod and mod.save and mod.save.get and mod.save:get(SAVE_KEY,nil) or nil
  if type(saved)=='table' then
    for key,name in pairs(saved) do
      if type(key)=='string' and type(name)=='string' and name~='' then assigned[key]=name;usedFirst[name]=true end
    end
  end
  for _,name in pairs(SPECIAL) do
    local first=tostring(name):match('([A-Z]+)$')
    if first then usedFirst[first]=true end
  end
  local function persistAssignments()
    if mod and mod.save and mod.save.set then mod.save:set(SAVE_KEY,assigned) end
  end

  local function norm(v)
    return tostring(v or ''):upper():gsub('^OPP_',''):gsub('[^A-Z0-9]+','_'):gsub('^_+',''):gsub('_+$','')
  end
  local function hash(s)
    local h=5381;s=tostring(s or '')
    for i=1,#s do h=(h*33+s:byte(i))%2147483647 end
    return h
  end
  local function candidates(preferred,gender)
    local out,seen={},{ }
    for _,pool in ipairs({preferred or {},gender=='F' and MASTER_F or MASTER_M}) do
      for _,v in ipairs(pool) do if not seen[v] then seen[v]=true;out[#out+1]=v end end
    end
    return out
  end
  local function fallbackName(key,gender,attempt)
    local a=gender=='F' and {'EL','MA','LI','NA','SA','VI','RA','TA'} or {'AL','CA','DA','EL','JO','MA','RO','TE'}
    local b=gender=='F' and {'RIA','LIA','NIA','MIE','SSA','VIA','RAH','NNE'} or {'DEN','RIC','LAN','VIN','REN','TON','MON','RAN'}
    local h=hash(tostring(key)..':'..tostring(attempt or 0))
    return a[(h%#a)+1]..b[(math.floor(h/#a)%#b)+1]
  end
  local function uniquePick(preferred,key,gender)
    key=tostring(key or '')
    if assigned[key] then return assigned[key] end
    local pool=candidates(preferred,gender);local start=#pool>0 and (hash(key)%#pool)+1 or 1
    for off=0,#pool-1 do
      local name=pool[((start+off-2)%#pool)+1]
      if not usedFirst[name] then assigned[key]=name;usedFirst[name]=true;persistAssignments();return name end
    end
    local attempt=0
    while attempt<1024 do
      local name=fallbackName(key,gender,attempt)
      if not usedFirst[name] then assigned[key]=name;usedFirst[name]=true;persistAssignments();return name end
      attempt=attempt+1
    end
    return gender=='F' and 'KANTO GIRL' or 'KANTO TRAINER'
  end
  function Names.resetAssignments()
    assigned={};usedFirst={}
    for _,name in pairs(SPECIAL) do local first=tostring(name):match('([A-Z]+)$');if first then usedFirst[first]=true end end
  end

  local function playerRival(game)
    local p=game and game.save and game.save.player
    return tostring(p and (p.rival or p.rivalName) or 'BLUE'):upper()
  end
  local function canonicalClass(cls)
    cls=norm(cls)
    if cls:match('^RIVAL[123]?$') then return 'RIVAL' end
    if cls=='LT_SURGE' or cls=='SURGE' then return 'LT_SURGE' end
    if cls=='PROFESSOR_OAK' then return 'PROF_OAK' end
    return cls
  end
  function Names.trainer(game,cls,ctx)
    ctx=ctx or {};local key=canonicalClass(cls)
    if key=='RIVAL' then return playerRival(game) end
    if SPECIAL[key] then return SPECIAL[key] end
    local label=LABEL[key] or key:gsub('_',' ');if label=='' then label='TRAINER' end
    local gender=GENDER[key] or 'M';local pool=POOLS[key] or (gender=='F' and POOLS.RESIDENT_F or POOLS.RESIDENT_M)
    local seed='trainer:'..table.concat({tostring(ctx.mapId or ctx.map or ''),tostring(ctx.npcId or ctx.index or ''),tostring(ctx.partyIndex or ''),key},':')
    local first=uniquePick(pool,seed,gender)
    return first and (label..' '..first) or label
  end

  -- Gen 1 sprite identifiers encode gender more reliably than free-form text
  -- for many NPCs (notably SILPH_WORKER_F and COOLTRAINER_F). Use the
  -- authored sprite/class token before falling back to prose heuristics.
  local FEMALE_SPRITES={
    SPRITE_COOLTRAINER_F=true,SPRITE_LITTLE_GIRL=true,SPRITE_GIRL=true,
    SPRITE_BEAUTY=true,SPRITE_DAISY=true,SPRITE_CHANNELER=true,
    SPRITE_SILPH_WORKER_F=true,SPRITE_MIDDLE_AGED_WOMAN=true,
    SPRITE_BRUNETTE_GIRL=true,SPRITE_GRANNY=true,SPRITE_NURSE=true,
    SPRITE_LINK_RECEPTIONIST=true,SPRITE_MOM=true,SPRITE_AGATHA=true,
    SPRITE_LORELEI=true,SPRITE_OFFICER_JENNY=true,SPRITE_JESSIE=true,
  }
  local MALE_SPRITES={
    SPRITE_RED=true,SPRITE_BLUE=true,SPRITE_OAK=true,SPRITE_YOUNGSTER=true,
    SPRITE_COOLTRAINER_M=true,SPRITE_MIDDLE_AGED_MAN=true,SPRITE_GAMBLER=true,
    SPRITE_SUPER_NERD=true,SPRITE_HIKER=true,SPRITE_GENTLEMAN=true,
    SPRITE_BIKER=true,SPRITE_SAILOR=true,SPRITE_COOK=true,SPRITE_MR_FUJI=true,
    SPRITE_GIOVANNI=true,SPRITE_ROCKET=true,SPRITE_SILPH_WORKER_M=true,
    SPRITE_SCIENTIST=true,SPRITE_ROCKER=true,SPRITE_SWIMMER=true,
    SPRITE_GYM_GUIDE=true,SPRITE_GRAMPS=true,SPRITE_SILPH_PRESIDENT=true,
    SPRITE_WARDEN=true,SPRITE_CAPTAIN=true,SPRITE_FISHER=true,SPRITE_KOGA=true,
    SPRITE_GUARD=true,SPRITE_BALDING_GUY=true,SPRITE_LITTLE_BOY=true,
    SPRITE_GAMEBOY_KID=true,SPRITE_BRUNO=true,SPRITE_LANCE=true,SPRITE_JAMES=true,
  }
  local function spriteGender(def)
    local sprite=norm(def and def.sprite or '')
    if FEMALE_SPRITES[sprite] then return 'F' end
    if MALE_SPRITES[sprite] then return 'M' end
    -- Modded object definitions often preserve the Gen 1 `_F` / `_M` suffix
    -- even when they use a custom sprite namespace.
    if sprite:match('_F$') or sprite:find('_FEMALE',1,true) then return 'F' end
    if sprite:match('_M$') or sprite:find('_MALE',1,true) then return 'M' end
    return nil
  end
  local function npcRole(def)
    local sprite=norm(def and def.sprite or '')
    local token=norm(table.concat({tostring(def and def.sprite or ''),tostring(def and def.name or ''),tostring(def and def.id or ''),tostring(def and def.text or '')},'_'))
    if token:find('DAISY',1,true) or token:find('BLUESHOUSE_DAISY',1,true) then return 'DAISY' end
    if token:find('NURSE',1,true) then return 'NURSE_JOY' end
    if token:find('MOM',1,true) then return 'MOM' end
    if token:find('CLERK',1,true) then return 'CLERK' end
    if token:find('SCIENTIST',1,true) then return 'SCIENTIST' end
    if sprite=='SPRITE_BEAUTY' then return 'BEAUTY' end
    if sprite=='SPRITE_CHANNELER' then return 'CHANNELER' end
    if sprite=='SPRITE_COOLTRAINER_F' then return 'COOLTRAINER_F' end
    if sprite=='SPRITE_COOLTRAINER_M' then return 'COOLTRAINER_M' end
    -- Map/object identifiers such as OAKSLAB_SCIENTIST1 contain OAK as a
    -- location prefix; only a standalone OAK token denotes the professor.
    if ('_'..token..'_'):find('_OAK_',1,true) or token:find('PROF_OAK',1,true) then return 'OAK' end
    if token:find('AIDE',1,true) then return 'AIDE' end
    local sg=spriteGender(def)
    if sg=='F' then
      if sprite=='SPRITE_LITTLE_GIRL' then return 'CHILD_F' end
      return 'RESIDENT_F'
    elseif sg=='M' and sprite=='SPRITE_LITTLE_BOY' then return 'CHILD_M' end
    if token:find('LITTLE_GIRL',1,true) or token:find('GIRL',1,true) or token:find('WOMAN',1,true)
        or token:find('FEMALE',1,true) or token:find('LADY',1,true) then return 'RESIDENT_F' end
    if token:find('LITTLE_BOY',1,true) then return 'CHILD_M' end
    if token:find('BOY',1,true) or token:find('MAN',1,true) then return 'RESIDENT_M' end
    if token:find('FISHER',1,true) then return 'FISHER' end
    return 'RESIDENT_M'
  end
  function Names.npc(game,target,ctx)
    ctx=ctx or {};local def=target and target.def or target or {}
    if type(def.trainerClass)=='string' and def.trainerClass~='' then
      return Names.trainer(game,def.trainerClass,{mapId=ctx.mapId,npcId=(target and target.id) or def.index or def.name,partyIndex=def.trainerParty})
    end
    local role=npcRole(def);if SPECIAL[role] then return SPECIAL[role] end
    local label=({RESIDENT_M='',RESIDENT_F='',CHILD_M='',CHILD_F='',CLERK='CLERK',AIDE='LAB AIDE'})[role]
      or (LABEL[role] or role:gsub('_',' '))
    local gender=GENDER[role] or 'M';local pool=POOLS[role] or (gender=='F' and POOLS.RESIDENT_F or POOLS.RESIDENT_M)
    local identity=def.name or def.text or (target and target.id) or def.index or ''
    -- Prefer the ROM's semantic object name when available. Text keys are
    -- normally TEXT_<object-name>, which lets an early text-key fallback and
    -- a later authoritative world.interacted event converge on one identity.
    local semantic=norm(identity)
    local seed=semantic~='' and ('npc:'..semantic..':'..role)
      or ('npc:'..table.concat({tostring(ctx.mapId or ''),tostring(target and target.id or def.index or ''),role},':'))
    local first=uniquePick(pool,seed,gender)
    if not first then return label~='' and label or 'KANTO RESIDENT' end
    return label~='' and (label..' '..first) or first
  end

  -- Script text keys encode event ownership but are CamelCase in the source,
  -- so normalization cannot recover token boundaries. Keep an explicit,
  -- ordered list: more specific/collision-prone roles (RIVAL, NURSE_JOY,
  -- MR_FUJI) must win before shorter names. In particular, every Oak's Lab
  -- key contains the location prefix OAKSLAB; that prefix is never evidence
  -- that Professor Oak spoke the line.
  local KEY_SPECIAL_ORDERED={
    {'RIVAL','RIVAL'},{'NURSEJOY','NURSE JOY'},{'MRFUJI','MR. FUJI'},
    {'LTSURGE','LT. SURGE'},{'SURGE','LT. SURGE'},{'GIOVANNI','GIOVANNI'},{'SABRINA','SABRINA'},
    {'LORELEI','LORELEI'},{'AGATHA','AGATHA'},{'BLAINE','BLAINE'},
    {'MISTY','MISTY'},{'BROCK','BROCK'},{'ERIKA','ERIKA'},{'KOGA','KOGA'},
    {'LANCE','LANCE'},{'BRUNO','BRUNO'},{'DAISY','DAISY'},
    {'NURSE','NURSE JOY'},{'MOM','MOM'},{'FUJI','MR. FUJI'},{'JOY','NURSE JOY'},
    {'BILL','BILL'},
  }

  local function oakLabSemantic(u)
    return tostring(u or ''):gsub('^TEXT_',''):gsub('^OAKSLAB','')
  end

  -- Returns (speaker, handled). handled=true with a nil speaker denotes
  -- authored narration/system text and deliberately clears any earlier NPC
  -- hint. This prevents a ball interaction or a previous cutscene actor from
  -- leaking into the next script-owned TextBox.
  function Names.eventSpeaker(game,key)
    local u=norm(key)
    if u=='' then return nil,false end
    local lab=u:find('OAKSLAB',1,true)~=nil
    local semantic=lab and oakLabSemantic(u) or u

    -- Receipt/gift lines describe an action rather than speech. The speaker
    -- chip stays absent even when the key also contains RIVAL or OAK.
    if semantic:find('RECEIVEDMON',1,true)
        or semantic:find('RECEIVEDTEXT',1,true)
        or semantic:find('RECEIVEDPOKEBALL',1,true)
        or semantic:find('GOTPOKEDEX',1,true)
        or semantic:find('GOTPOKEBALL',1,true) then return nil,true end

    -- Oak's starter balls are script objects, not people. Their prompt and
    -- explanatory lines are nevertheless spoken by Oak in the authored event.
    if lab and (semantic:find('YOUWANTCHARMANDER',1,true)
        or semantic:find('YOUWANTSQUIRTLE',1,true)
        or semantic:find('YOUWANTBULBASAUR',1,true)
        or semantic:find('THOSEAREPOKEBALLS',1,true)
        or semantic:find('THATSAPOKEBALL',1,true)
        or semantic:find('GIVEPOKEBALLSEXPLANATION',1,true)) then
      return 'PROFESSOR OAK',true
    end

    -- RIVAL precedes every location/person rule. This resolves
    -- _OaksLabRivalIPicked... and every following Blue line deterministically.
    for _,entry in ipairs(KEY_SPECIAL_ORDERED) do
      if semantic:find(entry[1],1,true) then
        return entry[2]=='RIVAL' and playerRival(game) or entry[2],true
      end
    end
    if semantic:find('PROFOAK',1,true) or semantic:find('PROFESSOROAK',1,true)
        or semantic:find('OAK',1,true) then return 'PROFESSOR OAK',true end
    return nil,false
  end

  function Names.fromTextKey(game,key)
    local u=norm(key)
    local event,handled=Names.eventSpeaker(game,key)
    if handled then return event end
    for cls in pairs(LABEL) do
      if u:find(cls,1,true) then return Names.trainer(game,cls,{mapId=u,npcId=u}) end
    end
    if u:find('ROCKET',1,true) then return Names.trainer(game,'ROCKET',{mapId=u,npcId=u}) end
    if u:find('SCIENTIST',1,true) then return Names.trainer(game,'SCIENTIST',{mapId=u,npcId=u}) end

    -- Some interactions reach the dialogue adapter before an authoritative
    -- world.interacted target is available. The ROM text key still embeds the
    -- object role, including Gen 1's `_F` worker suffix, so use it as a gender
    -- fallback instead of assigning a male generic resident by map alone.
    local semantic=u:gsub('^TEXT_','')
    if u:find('SILPH_WORKER_F',1,true) or u:find('WORKER_F',1,true)
        or u:find('LITTLE_GIRL',1,true) or u:find('BRUNETTE_GIRL',1,true)
        or u:find('GIRL',1,true) or u:find('WOMAN',1,true)
        or u:find('RECEPTIONIST',1,true) then
      return uniquePick(POOLS.RESIDENT_F,'npc:'..semantic..':RESIDENT_F','F')
    end
    if u:find('COOLTRAINER_F',1,true) then
      local first=uniquePick(POOLS.COOLTRAINER_F,'npc:'..semantic..':COOLTRAINER_F','F')
      return first and ('COOLTRAINER '..first) or 'COOLTRAINER'
    end
    if u:find('BEAUTY',1,true) then
      local first=uniquePick(POOLS.BEAUTY,'npc:'..semantic..':BEAUTY','F')
      return first and ('BEAUTY '..first) or 'BEAUTY'
    end
    if u:find('CHANNELER',1,true) then
      local first=uniquePick(POOLS.CHANNELER,'npc:'..semantic..':CHANNELER','F')
      return first and ('CHANNELER '..first) or 'CHANNELER'
    end
    return nil
  end

  function Names.dialogue(game,text,ctx)
    ctx=ctx or {}
    local mapId=tostring(ctx.mapId or (game and game.overworld and game.overworld.map and game.overworld.map.id) or ''):upper()
    local role,label
    if mapId:find('MART',1,true) then role,label='CLERK','CLERK'
    elseif mapId:find('LAB',1,true) then role,label='AIDE','LAB AIDE'
    elseif mapId:find('GYM',1,true) then role,label='RESIDENT_M','GYM TRAINER'
    elseif mapId:find('POKEMON_CENTER',1,true) or mapId:find('POKECENTER',1,true) then role,label='RESIDENT_F','POKéMON CENTER STAFF'
    else role,label='RESIDENT_M','' end
    local gender=GENDER[role] or 'M';local pool=POOLS[role] or (gender=='F' and POOLS.RESIDENT_F or POOLS.RESIDENT_M)
    local seed='dialogue:'..table.concat({mapId,tostring(ctx.identityKey or ctx.textKey or ''),tostring(text or ''),role},':')
    local first=uniquePick(pool,seed,gender)
    if not first then return label~='' and label or 'KANTO RESIDENT' end
    return label~='' and (label..' '..first) or first
  end

  function Names.battleOpponent(game,battle)
    if not battle then return 'OPPONENT' end
    if battle.kind=='wild' then
      local b=battle.enemy;return tostring(b and (b.name or (b.mon and b.mon.nickname)) or 'WILD POKéMON'):upper()
    end
    local origin=battle.checkpointOrigin or {}
    local cls=origin.trainerClass or battle.oppClass or battle.trainerClass
    if not cls and battle.trainer then
      local name=tostring(battle.trainer.name or ''):upper()
      if name~='' and name~='ROCKET' and name~='YOUNGSTER' and name~='TRAINER' then return name end
      cls=name
    end
    return Names.trainer(game,cls or 'TRAINER',{mapId=origin.map,npcId=origin.npcId,partyIndex=origin.partyIndex or battle.partyIndex})
  end

  return Names
end
