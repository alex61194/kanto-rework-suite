-- Wide presentation adapter for native Gen1Recomp menus whose update/callback
-- ownership remains native. It paints over the classic 160x144 chrome in HUD.
return function(runtime)
  local P={}
  local ListMenu=require('src.ui.ListMenu')
  local Menu=require('src.ui.Menu')
  local QuantityBox=require('src.ui.QuantityBox')
  local ChoiceBox=require('src.ui.ChoiceBox')
  local PartyMenu=require('src.ui.PartyMenu')
  local MoveLearnMenu=require('src.ui.MoveLearnMenu')
  local TextBox=require('src.render.TextBox')
  local BattleState=require('src.battle.BattleState')
  local StatBox=BattleState.StatBox
  local Boxes=require('src.pokemon.Boxes')
  local function ismt(s,t) return s and getmetatable(s)==t end
  local function stack(game) return game and game.stack and game.stack.states or {} end
  local function below(game,n)
    local ss=stack(game); local idx
    for i=#ss,1,-1 do if ss[i]==n then idx=i break end end
    return idx and ss[idx-1] or nil
  end
  local function ancestor(game,pred)
    local ss=stack(game);for i=#ss,1,-1 do if pred(ss[i]) then return ss[i] end end
  end
  local function cacheImage(game,species,side,kind,mon)
    return runtime.PokemonArt:image(game,species,side or 'front',{kind=kind or 'native_menu',mon=mon})
  end
  local function pokemonName(game,mon)
    local def=mon and game.data and game.data.pokemon and game.data.pokemon[mon.species]
    return mon and runtime.PokemonName(mon.nickname or (def and def.name) or mon.species,mon.species,def,mon.nickname~=nil) or 'POKéMON'
  end
  local function drawImage(m,img,x,y,w,h)
    if not img then return end;local iw,ih=img:getDimensions();local k=math.min(w*m.scale/iw,h*m.scale/ih);local px=m.ox+x*m.scale+(w*m.scale-iw*k)/2;local py=m.oy+y*m.scale+(h*m.scale-ih*k)/2;love.graphics.setColor(1,1,1,1);love.graphics.draw(img,px,py,0,k,k);return px,py,iw*k,ih*k
  end
  local function shell(game,m,c,title,tabs,active)
    local D=runtime.Draw;D.roundRect(m,'fill',0,0,1920,1080,0,c.canvas);D.roundRect(m,'fill',0,0,1920,88,0,c.inverse)
    D.text(runtime,m,'KANTO JOURNAL',32,18,22,c.textInverse,{weight='bold'});D.text(runtime,m,title:upper(),32,52,10,c.textInverse,{weight='bold',alpha=.72})
    runtime.nativePcTabRects=nil
    if tabs then local total=#tabs*150;local x=960-total/2;if title=='PC' then runtime.nativePcTabRects={} end;for i,t in ipairs(tabs) do local tx=x+(i-1)*150;local sel=t.id==active;D.text(runtime,m,t.label,tx,27,13,sel and c.textInverse or c.faint,{weight='semibold',width=142,align='center'});if sel then D.roundRect(m,'fill',tx+30,62,82,3,1.5,c.headerAccent or c.focus) end;if runtime.nativePcTabRects and (t.id=='bill' or t.id=='player' or t.id=='oak') then runtime.nativePcTabRects[t.id]={x=tx,y=12,w=142,h=64} end end else D.text(runtime,m,title:upper(),840,29,14,c.textInverse,{weight='semibold',width=240,align='center'});D.roundRect(m,'fill',900,62,120,3,1.5,c.headerAccent or c.focus) end
    local jc=type(runtime.Core.journalContext)=='function' and runtime.Core.journalContext() or {};D.text(runtime,m,tostring(jc.location or 'KANTO'):gsub('_',' '):upper(),1570,20,12,c.textInverse,{weight='semibold',width=318,align='right'});local sec=math.floor(tonumber(jc.playTime) or 0);local worldLabel=(runtime.worldTimeLabel and runtime.worldTimeLabel(game,sec)) or ('%02d:%02d • DAY'):format(math.floor(sec/3600),math.floor(sec/60)%60);D.text(runtime,m,worldLabel,1570,46,10,c.faint,{width=318,align='right'})
    D.roundRect(m,'fill',0,1016,1920,64,0,c.inverse)
  end
  local function footer(m,c,prompts)
    local D=runtime.Draw;local x=32;for _,p in ipairs(prompts or {}) do D.text(runtime,m,p[1],x,1037,12,c.textInverse,{weight='bold'});D.text(runtime,m,p[2],x+82,1038,11,c.textInverse,{alpha=.7});x=x+238 end;D.text(runtime,m,'KEYBOARD + MOUSE',1640,1038,12,c.textInverse,{weight='semibold',width=248,align='right'})
  end
  local function drawMoney(m,value,x,y,size,color,opts)
    local D=runtime.Draw;opts=opts or {};local weight=opts.weight or "bold"
    local label=tostring(math.floor(tonumber(value) or 0))
    D.pokedollar(m,x,y+1,size,color)
    D.text(runtime,m,label,x+size*.78,y,size,color,{weight=weight})
  end
  local function focusRect(m,c,r,focused,selected)
    local D=runtime.Draw;D.roundRect(m,'fill',r.x,r.y,r.w,r.h,10,selected and c.subtle or c.panel);D.roundRect(m,'line',r.x,r.y,r.w,r.h,10,focused and c.focus or c.border,focused and 3 or 1);if selected and not focused then D.roundRect(m,'fill',r.x+10,r.y+r.h/2-12,4,24,2,c.focus) end
  end
  local function cleanLabel(value) return tostring(value or ''):gsub('^%*%s*','') end
  local function resolveText(game,value)
    if type(value)~='string' or value=='' then return nil end
    local data=game and game.data and game.data.text
    if data and type(data[value])=='string' then value=data[value] end
    return tostring(value):gsub('[\v\f]',' '):gsub('%s+',' ')
  end
  local function itemDef(game,row) return row and row.value and game.data.items and game.data.items[row.value] end
  -- Generated from the user-supplied, item-named icon archive.
  -- Keys are semantic item-name tokens; PNGs are never recolored.
  local ITEM_ICON_PATH={
    ['ABILITY_CAPSULE']='assets/item_icons/named/0645_Ability_Capsule.png',
    ['ABILITY_URGE']='assets/item_icons/named/0611_Ability_Urge.png',
    ['ABOMASITE']='assets/item_icons/named/0674_Abomasite.png',
    ['ABSOLITE']='assets/item_icons/named/0677_Absolite.png',
    ['ABSORB_BULB']='assets/item_icons/named/0545_Absorb_Bulb.png',
    ['ACRO_BIKE']='assets/item_icons/named/0719_Acro_Bike.png',
    ['ADAMANT_ORB']='assets/item_icons/named/0135_Adamant_Orb.png',
    ['ADRENALINE_ORB']='assets/item_icons/named/0846_Adrenaline_Orb.png',
    ['ADVENTURE_GUIDE']='assets/item_icons/named/0703_Adventure_Guide.png',
    ['AERODACTYLITE']='assets/item_icons/named/0672_Aerodactylite.png',
    ['AGGRONITE']='assets/item_icons/named/0667_Aggronite.png',
    ['AGUAV_BERRY']='assets/item_icons/named/0162_Aguav_Berry.png',
    ['AIR_BALLOON']='assets/item_icons/named/0541_Air_Balloon.png',
    ['ALAKAZITE']='assets/item_icons/named/0679_Alakazite.png',
    ['ALORAICHIUM_Z']='assets/item_icons/named/0803_Aloraichium_Z.png',
    ['ALTARIANITE']='assets/item_icons/named/0755_Altarianite.png',
    ['AMAZE_MULCH']='assets/item_icons/named/0655_Amaze_Mulch.png',
    ['AMPHAROSITE']='assets/item_icons/named/0658_Ampharosite.png',
    ['AMULET_COIN']='assets/item_icons/named/0223_Amulet_Coin.png',
    ['ANTIDOTE']='assets/item_icons/named/0018_Antidote.png',
    ['APICOT_BERRY']='assets/item_icons/named/0205_Apicot_Berry.png',
    ['APRICORN_BOX']='assets/item_icons/named/0468_Apricorn_Box.png',
    ['AQUA_SUIT']='assets/item_icons/named/0742_Aqua_Suit.png',
    ['ARMOR_FOSSIL']='assets/item_icons/named/0104_Armor_Fossil.png',
    ['ASPEAR_BERRY']='assets/item_icons/named/0153_Aspear_Berry.png',
    ['ASSAULT_VEST']='assets/item_icons/named/0640_Assault_Vest.png',
    ['AUDINITE']='assets/item_icons/named/0757_Audinite.png',
    ['AUTOGRAPH']='assets/item_icons/named/0115_Autograph.png',
    ['AWAKENING']='assets/item_icons/named/0021_Awakening.png',
    ['AZURE_FLUTE']='assets/item_icons/named/0455_Azure_Flute.png',
    ['BABIRI_BERRY']='assets/item_icons/named/0199_Babiri_Berry.png',
    ['BALM_MUSHROOM']='assets/item_icons/named/0580_Balm_Mushroom.png',
    ['BANETTITE']='assets/item_icons/named/0668_Banettite.png',
    ['BASEMENT_KEY']='assets/item_icons/named/0476_Basement_Key.png',
    ['BATTLE_POCKET']='assets/item_icons/named/0128_Battle_Pocket.png',
    ['BEAST_BALL']='assets/item_icons/named/0851_Beast_Ball.png',
    ['BEEDRILLITE']='assets/item_icons/named/0770_Beedrillite.png',
    ['BELUE_BERRY']='assets/item_icons/named/0183_Belue_Berry.png',
    ['BERRY_JUICE']='assets/item_icons/named/0043_Berry_Juice.png',
    ['BERRY_POTS']='assets/item_icons/named/0470_Berry_Pots.png',
    ['BICYCLE']='assets/item_icons/named/0450_Bike.png',
    ['BIG_MALASADA']='assets/item_icons/named/0852_Big_Malasada.png',
    ['BIG_MUSHROOM']='assets/item_icons/named/0087_Big_Mushroom.png',
    ['BIG_NUGGET']='assets/item_icons/named/0581_Big_Nugget.png',
    ['BIG_PEARL']='assets/item_icons/named/0089_Big_Pearl.png',
    ['BIG_ROOT']='assets/item_icons/named/0296_Big_Root.png',
    ['BIKE']='assets/item_icons/named/0450_Bike.png',
    ['BINDING_BAND']='assets/item_icons/named/0544_Binding_Band.png',
    ['BLACK_APRICORN']='assets/item_icons/named/0491_Black_Apricorn.png',
    ['BLACK_BELT']='assets/item_icons/named/0241_Black_Belt.png',
    ['BLACK_FLUTE']='assets/item_icons/named/0068_Black_Flute.png',
    ['BLACK_GLASSES']='assets/item_icons/named/0240_Black_Glasses.png',
    ['BLACK_SLUDGE']='assets/item_icons/named/0281_Black_Sludge.png',
    ['BLASTOISINITE']='assets/item_icons/named/0661_Blastoisinite.png',
    ['BLAZIKENITE']='assets/item_icons/named/0664_Blazikenite.png',
    ['BLUE_APRICORN']='assets/item_icons/named/0486_Blue_Apricorn.png',
    ['BLUE_CARD']='assets/item_icons/named/0472_Blue_Card.png',
    ['BLUE_FLUTE']='assets/item_icons/named/0065_Blue_Flute.png',
    ['BLUE_ORB']='assets/item_icons/named/0535_Blue_Orb.png',
    ['BLUE_SCARF']='assets/item_icons/named/0261_Blue_Scarf.png',
    ['BLUE_SHARD']='assets/item_icons/named/0073_Blue_Shard.png',
    ['BLUK_BERRY']='assets/item_icons/named/0165_Bluk_Berry.png',
    ['BLUNDER_POLICY']='assets/item_icons/named/1121_Blunder_Policy.png',
    ['BOOST_MULCH']='assets/item_icons/named/0654_Boost_Mulch.png',
    ['BOTTLE_CAP']='assets/item_icons/named/0795_Bottle_Cap.png',
    ['BRIDGE_MAIL_D']='assets/item_icons/named/0145_Bridge_Mail_D.png',
    ['BRIDGE_MAIL_M']='assets/item_icons/named/0148_Bridge_Mail_M.png',
    ['BRIDGE_MAIL_S']='assets/item_icons/named/0144_Bridge_Mail_S.png',
    ['BRIDGE_MAIL_T']='assets/item_icons/named/0146_Bridge_Mail_T.png',
    ['BRIDGE_MAIL_V']='assets/item_icons/named/0147_Bridge_Mail_V.png',
    ['BRIGHT_POWDER']='assets/item_icons/named/0213_Bright_Powder.png',
    ['BUGINIUM_Z']='assets/item_icons/named/0787_Buginium_Z.png',
    ['BUG_GEM']='assets/item_icons/named/0558_Bug_Gem.png',
    ['BUG_MEMORY']='assets/item_icons/named/0909_Bug_Memory.png',
    ['BURN_DRIVE']='assets/item_icons/named/0118_Burn_Drive.png',
    ['BURN_HEAL']='assets/item_icons/named/0019_Burn_Heal.png',
    ['CALCIUM']='assets/item_icons/named/0049_Calcium.png',
    ['CAMERUPTITE']='assets/item_icons/named/0767_Cameruptite.png',
    ['CANDY_JAR']='assets/item_icons/named/0124_Candy_Jar.png',
    ['CARBOS']='assets/item_icons/named/0048_Carbos.png',
    ['CARD_KEY']='assets/item_icons/named/0475_Card_Key.png',
    ['CASTELIACONE']='assets/item_icons/named/0591_Casteliacone.png',
    ['CATCHING_POCKET']='assets/item_icons/named/0127_Catching_Pocket.png',
    ['CELL_BATTERY']='assets/item_icons/named/0546_Cell_Battery.png',
    ['CHARCOAL']='assets/item_icons/named/0249_Charcoal.png',
    ['CHARIZARDITE_X']='assets/item_icons/named/0660_Charizardite_X.png',
    ['CHARIZARDITE_Y']='assets/item_icons/named/0678_Charizardite_Y.png',
    ['CHARTI_BERRY']='assets/item_icons/named/0195_Charti_Berry.png',
    ['CHERISH_BALL']='assets/item_icons/named/0016_Cherish_Ball.png',
    ['CHERI_BERRY']='assets/item_icons/named/0149_Cheri_Berry.png',
    ['CHESTO_BERRY']='assets/item_icons/named/0150_Chesto_Berry.png',
    ['CHILAN_BERRY']='assets/item_icons/named/0200_Chilan_Berry.png',
    ['CHILL_DRIVE']='assets/item_icons/named/0119_Chill_Drive.png',
    ['CHOICE_BAND']='assets/item_icons/named/0220_Choice_Band.png',
    ['CHOICE_SCARF']='assets/item_icons/named/0287_Choice_Scarf.png',
    ['CHOICE_SPECS']='assets/item_icons/named/0297_Choice_Specs.png',
    ['CHOPLE_BERRY']='assets/item_icons/named/0189_Chople_Berry.png',
    ['CLAW_FOSSIL']='assets/item_icons/named/0100_Claw_Fossil.png',
    ['CLEANSE_TAG']='assets/item_icons/named/0224_Cleanse_Tag.png',
    ['CLEAR_BELL']='assets/item_icons/named/0474_Clear_Bell.png',
    ['CLEVER_FEATHER']='assets/item_icons/named/0569_Clever_Feather.png',
    ['CLOTHING_TRUNK']='assets/item_icons/named/0126_Clothing_Trunk.png',
    ['CLOVER_SWEET']='assets/item_icons/named/1112_Clover_Sweet.png',
    ['COBA_BERRY']='assets/item_icons/named/0192_Coba_Berry.png',
    ['COIN_CASE']='assets/item_icons/named/0444_Coin_Case.png',
    ['COLBUR_BERRY']='assets/item_icons/named/0198_Colbur_Berry.png',
    ['COLRESS_MACHINE']='assets/item_icons/named/0635_Colress_Machine.png',
    ['COMET_SHARD']='assets/item_icons/named/0583_Comet_Shard.png',
    ['COMMON_STONE']='assets/item_icons/named/0698_Common_Stone.png',
    ['CONTEST_COSTUME']='assets/item_icons/named/0739_Contest_Costume.png',
    ['CONTEST_PASS']='assets/item_icons/named/0457_Contest_Pass.png',
    ['CORNN_BERRY']='assets/item_icons/named/0175_Cornn_Berry.png',
    ['COUPON_1']='assets/item_icons/named/0460_Coupon_1.png',
    ['COUPON_2']='assets/item_icons/named/0461_Coupon_2.png',
    ['COUPON_3']='assets/item_icons/named/0462_Coupon_3.png',
    ['COVER_FOSSIL']='assets/item_icons/named/0572_Cover_Fossil.png',
    ['CUSTAP_BERRY']='assets/item_icons/named/0210_Custap_Berry.png',
    ['DAMP_MULCH']='assets/item_icons/named/0096_Damp_Mulch.png',
    ['DAMP_ROCK']='assets/item_icons/named/0285_Damp_Rock.png',
    ['DARKINIUM_Z']='assets/item_icons/named/0791_Darkinium_Z.png',
    ['DARK_GEM']='assets/item_icons/named/0562_Dark_Gem.png',
    ['DARK_MEMORY']='assets/item_icons/named/0919_Dark_Memory.png',
    ['DARK_STONE']='assets/item_icons/named/0617_Dark_Stone.png',
    ['DATA_CARD_01']='assets/item_icons/named/0505_Data_Card_01.png',
    ['DATA_CARD_02']='assets/item_icons/named/0506_Data_Card_02.png',
    ['DATA_CARD_03']='assets/item_icons/named/0507_Data_Card_03.png',
    ['DATA_CARD_04']='assets/item_icons/named/0508_Data_Card_04.png',
    ['DATA_CARD_05']='assets/item_icons/named/0509_Data_Card_05.png',
    ['DATA_CARD_06']='assets/item_icons/named/0510_Data_Card_06.png',
    ['DATA_CARD_07']='assets/item_icons/named/0511_Data_Card_07.png',
    ['DATA_CARD_08']='assets/item_icons/named/0512_Data_Card_08.png',
    ['DATA_CARD_09']='assets/item_icons/named/0513_Data_Card_09.png',
    ['DATA_CARD_10']='assets/item_icons/named/0514_Data_Card_10.png',
    ['DATA_CARD_11']='assets/item_icons/named/0515_Data_Card_11.png',
    ['DATA_CARD_12']='assets/item_icons/named/0516_Data_Card_12.png',
    ['DATA_CARD_13']='assets/item_icons/named/0517_Data_Card_13.png',
    ['DATA_CARD_14']='assets/item_icons/named/0518_Data_Card_14.png',
    ['DATA_CARD_15']='assets/item_icons/named/0519_Data_Card_15.png',
    ['DATA_CARD_16']='assets/item_icons/named/0520_Data_Card_16.png',
    ['DATA_CARD_17']='assets/item_icons/named/0521_Data_Card_17.png',
    ['DATA_CARD_18']='assets/item_icons/named/0522_Data_Card_18.png',
    ['DATA_CARD_19']='assets/item_icons/named/0523_Data_Card_19.png',
    ['DATA_CARD_20']='assets/item_icons/named/0524_Data_Card_20.png',
    ['DATA_CARD_21']='assets/item_icons/named/0525_Data_Card_21.png',
    ['DATA_CARD_22']='assets/item_icons/named/0526_Data_Card_22.png',
    ['DATA_CARD_23']='assets/item_icons/named/0527_Data_Card_23.png',
    ['DATA_CARD_24']='assets/item_icons/named/0528_Data_Card_24.png',
    ['DATA_CARD_25']='assets/item_icons/named/0529_Data_Card_25.png',
    ['DATA_CARD_26']='assets/item_icons/named/0530_Data_Card_26.png',
    ['DATA_CARD_27']='assets/item_icons/named/0531_Data_Card_27.png',
    ['DAWN_STONE']='assets/item_icons/named/0109_Dawn_Stone.png',
    ['DECIDIUM_Z']='assets/item_icons/named/0798_Decidium_Z.png',
    ['DEEP_SEA_SCALE']='assets/item_icons/named/0227_Deep_Sea_Scale.png',
    ['DEEP_SEA_TOOTH']='assets/item_icons/named/0226_Deep_Sea_Tooth.png',
    ['DESTINY_KNOT']='assets/item_icons/named/0280_Destiny_Knot.png',
    ['DEVON_PARTS']='assets/item_icons/named/0721_Devon_Parts.png',
    ['DEVON_SCOPE']='assets/item_icons/named/0735_Devon_Scope.png',
    ['DEVON_SCUBA_GEAR']='assets/item_icons/named/0738_Devon_Scuba_Gear.png',
    ['DIANCITE']='assets/item_icons/named/0764_Diancite.png',
    ['DIRE_HIT']='assets/item_icons/named/0056_Dire_Hit.png',
    ['DIRE_HIT_2']='assets/item_icons/named/0592_Dire_Hit_2.png',
    ['DIRE_HIT_3']='assets/item_icons/named/0615_Dire_Hit_3.png',
    ['DISCOUNT_COUPON']='assets/item_icons/named/0699_Discount_Coupon.png',
    ['DIVE_BALL']='assets/item_icons/named/0007_Dive_Ball.png',
    ['DNA_SPLICERS']='assets/item_icons/named/0628_DNA_Splicers.png',
    ['DOME_FOSSIL']='assets/item_icons/named/0102_Dome_Fossil.png',
    ['DOUSE_DRIVE']='assets/item_icons/named/0116_Douse_Drive.png',
    ['DOWSING_MACHINE']='assets/item_icons/named/0471_Dowsing_Machine.png',
    ['DRACO_PLATE']='assets/item_icons/named/0311_Draco_Plate.png',
    ['DRAGONIUM_Z']='assets/item_icons/named/0790_Dragonium_Z.png',
    ['DRAGON_FANG']='assets/item_icons/named/0250_Dragon_Fang.png',
    ['DRAGON_GEM']='assets/item_icons/named/0561_Dragon_Gem.png',
    ['DRAGON_MEMORY']='assets/item_icons/named/0918_Dragon_Memory.png',
    ['DRAGON_SCALE']='assets/item_icons/named/0235_Dragon_Scale.png',
    ['DRAGON_SKULL']='assets/item_icons/named/0579_Dragon_Skull.png',
    ['DREAD_PLATE']='assets/item_icons/named/0312_Dread_Plate.png',
    ['DREAM_BALL']='assets/item_icons/named/0576_Dream_Ball.png',
    ['DROPPED_ITEM']='assets/item_icons/named/0636_Dropped_Item.png',
    ['DUBIOUS_DISC']='assets/item_icons/named/0324_Dubious_Disc.png',
    ['DURIN_BERRY']='assets/item_icons/named/0182_Durin_Berry.png',
    ['DUSK_BALL']='assets/item_icons/named/0013_Dusk_Ball.png',
    ['DUSK_STONE']='assets/item_icons/named/0108_Dusk_Stone.png',
    ['DYNAMAX_CANDY']='assets/item_icons/named/1129_Dynamax_Candy.png',
    ['EARTH_PLATE']='assets/item_icons/named/0305_Earth_Plate.png',
    ['EEVIUM_Z']='assets/item_icons/named/0805_Eevium_Z.png',
    ['EJECT_BUTTON']='assets/item_icons/named/0547_Eject_Button.png',
    ['EJECT_PACK']='assets/item_icons/named/1119_Eject_Pack.png',
    ['ELECTIRIZER']='assets/item_icons/named/0322_Electirizer.png',
    ['ELECTRIC_GEM']='assets/item_icons/named/0550_Electric_Gem.png',
    ['ELECTRIC_MEMORY']='assets/item_icons/named/0915_Electric_Memory.png',
    ['ELECTRIC_SEED']='assets/item_icons/named/0881_Electric_Seed.png',
    ['ELECTRIUM_Z']='assets/item_icons/named/0779_Electrium_Z.png',
    ['ELEVATOR_KEY']='assets/item_icons/named/0700_Elevator_Key.png',
    ['ELIXIR']='assets/item_icons/named/0040_Elixir.png',
    ['ENERGY_POWDER']='assets/item_icons/named/0034_Energy_Powder.png',
    ['ENERGY_ROOT']='assets/item_icons/named/0035_Energy_Root.png',
    ['ENIGMATIC_CARD']='assets/item_icons/named/0860_Enigmatic_Card.png',
    ['ENIGMA_BERRY']='assets/item_icons/named/0208_Enigma_Berry.png',
    ['ENIGMA_STONE']='assets/item_icons/named/0536_Enigma_Stone.png',
    ['EON_FLUTE']='assets/item_icons/named/0775_Eon_Flute.png',
    ['EON_TICKET']='assets/item_icons/named/0726_Eon_Ticket.png',
    ['ESCAPE_ROPE']='assets/item_icons/named/0078_Escape_Rope.png',
    ['ETHER']='assets/item_icons/named/0038_Ether.png',
    ['EVERSTONE']='assets/item_icons/named/0229_Everstone.png',
    ['EVIOLITE']='assets/item_icons/named/0538_Eviolite.png',
    ['EXPERT_BELT']='assets/item_icons/named/0268_Expert_Belt.png',
    ['EXPLORER_KIT']='assets/item_icons/named/0428_Explorer_Kit.png',
    ['EXP_CANDY_L']='assets/item_icons/named/1127_Exp_Candy_L.png',
    ['EXP_CANDY_M']='assets/item_icons/named/1126_Exp_Candy_M.png',
    ['EXP_CANDY_S']='assets/item_icons/named/1125_Exp_Candy_S.png',
    ['EXP_CANDY_XL']='assets/item_icons/named/1128_Exp_Candy_XL.png',
    ['EXP_CANDY_XS']='assets/item_icons/named/1124_Exp_Candy_XS.png',
    ['EXP_SHARE']='assets/item_icons/named/0216_Exp_Share.png',
    ['FAIRIUM_Z']='assets/item_icons/named/0793_Fairium_Z.png',
    ['FAIRY_GEM']='assets/item_icons/named/0715_Fairy_Gem.png',
    ['FAIRY_MEMORY']='assets/item_icons/named/0920_Fairy_Memory.png',
    ['FASHION_CASE']='assets/item_icons/named/0435_Fashion_Case.png',
    ['FAST_BALL']='assets/item_icons/named/0492_Fast_Ball.png',
    ['FAVORED_MAIL']='assets/item_icons/named/0138_Favored_Mail.png',
    ['FESTIVAL_TICKET']='assets/item_icons/named/0844_Festival_Ticket.png',
    ['FIGHTING_GEM']='assets/item_icons/named/0553_Fighting_Gem.png',
    ['FIGHTING_MEMORY']='assets/item_icons/named/0904_Fighting_Memory.png',
    ['FIGHTINIUM_Z']='assets/item_icons/named/0782_Fightinium_Z.png',
    ['FIGY_BERRY']='assets/item_icons/named/0159_Figy_Berry.png',
    ['FIRE_GEM']='assets/item_icons/named/0548_Fire_Gem.png',
    ['FIRE_MEMORY']='assets/item_icons/named/0912_Fire_Memory.png',
    ['FIRE_STONE']='assets/item_icons/named/0082_Fire_Stone.png',
    ['FIRIUM_Z']='assets/item_icons/named/0777_Firium_Z.png',
    ['FISHING_ROD']='assets/item_icons/named/0842_Fishing_Rod.png',
    ['FIST_PLATE']='assets/item_icons/named/0303_Fist_Plate.png',
    ['FLAME_ORB']='assets/item_icons/named/0273_Flame_Orb.png',
    ['FLAME_PLATE']='assets/item_icons/named/0298_Flame_Plate.png',
    ['FLOAT_STONE']='assets/item_icons/named/0539_Float_Stone.png',
    ['FLOWER_SWEET']='assets/item_icons/named/1113_Flower_Sweet.png',
    ['FLUFFY_TAIL']='assets/item_icons/named/0064_Fluffy_Tail.png',
    ['FLYING_GEM']='assets/item_icons/named/0556_Flying_Gem.png',
    ['FLYING_MEMORY']='assets/item_icons/named/0905_Flying_Memory.png',
    ['FLYINIUM_Z']='assets/item_icons/named/0785_Flyinium_Z.png',
    ['FOCUS_BAND']='assets/item_icons/named/0230_Focus_Band.png',
    ['FOCUS_SASH']='assets/item_icons/named/0275_Focus_Sash.png',
    ['FORAGE_BAG']='assets/item_icons/named/0841_Forage_Bag.png',
    ['FRESH_WATER']='assets/item_icons/named/0030_Fresh_Water.png',
    ['FRIEND_BALL']='assets/item_icons/named/0497_Friend_Ball.png',
    ['FULL_HEAL']='assets/item_icons/named/0027_Full_Heal.png',
    ['FULL_INCENSE']='assets/item_icons/named/0316_Full_Incense.png',
    ['FULL_RESTORE']='assets/item_icons/named/0023_Full_Restore.png',
    ['GALACTIC_KEY']='assets/item_icons/named/0440_Galactic_Key.png',
    ['GALLADITE']='assets/item_icons/named/0756_Galladite.png',
    ['GANLON_BERRY']='assets/item_icons/named/0202_Ganlon_Berry.png',
    ['GARCHOMPITE']='assets/item_icons/named/0683_Garchompite.png',
    ['GARDEVOIRITE']='assets/item_icons/named/0657_Gardevoirite.png',
    ['GB_SOUNDS']='assets/item_icons/named/0502_GB_Sounds.png',
    ['GENGARITE']='assets/item_icons/named/0656_Gengarite.png',
    ['GENIUS_FEATHER']='assets/item_icons/named/0568_Genius_Feather.png',
    ['GHOSTIUM_Z']='assets/item_icons/named/0789_Ghostium_Z.png',
    ['GHOST_GEM']='assets/item_icons/named/0560_Ghost_Gem.png',
    ['GHOST_MEMORY']='assets/item_icons/named/0910_Ghost_Memory.png',
    ['GLALITITE']='assets/item_icons/named/0763_Glalitite.png',
    ['GOLDEN_NANAB_BERRY']='assets/item_icons/named/0864_Golden_Nanab_Berry.png',
    ['GOLDEN_PINAP_BERRY']='assets/item_icons/named/0866_Golden_Pinap_Berry.png',
    ['GOLD_BOTTLE_CAP']='assets/item_icons/named/0796_Gold_Bottle_Cap.png',
    ['GOOD_ROD']='assets/item_icons/named/0446_Good_Rod.png',
    ['GOOEY_MULCH']='assets/item_icons/named/0098_Gooey_Mulch.png',
    ['GO_GOGGLES']='assets/item_icons/named/0728_Go-Goggles.png',
    ['GRACIDEA']='assets/item_icons/named/0466_Gracidea.png',
    ['GRAM_1']='assets/item_icons/named/0623_Gram_1.png',
    ['GRAM_2']='assets/item_icons/named/0624_Gram_2.png',
    ['GRAM_3']='assets/item_icons/named/0625_Gram_3.png',
    ['GRASSIUM_Z']='assets/item_icons/named/0780_Grassium_Z.png',
    ['GRASSY_SEED']='assets/item_icons/named/0884_Grassy_Seed.png',
    ['GRASS_GEM']='assets/item_icons/named/0551_Grass_Gem.png',
    ['GRASS_MEMORY']='assets/item_icons/named/0914_Grass_Memory.png',
    ['GREAT_BALL']='assets/item_icons/named/0003_Great_Ball.png',
    ['GREEN_APRICORN']='assets/item_icons/named/0488_Green_Apricorn.png',
    ['GREEN_SCARF']='assets/item_icons/named/0263_Green_Scarf.png',
    ['GREEN_SHARD']='assets/item_icons/named/0075_Green_Shard.png',
    ['GREET_MAIL']='assets/item_icons/named/0137_Greet_Mail.png',
    ['GREPA_BERRY']='assets/item_icons/named/0173_Grepa_Berry.png',
    ['GRIP_CLAW']='assets/item_icons/named/0286_Grip_Claw.png',
    ['GRISEOUS_ORB']='assets/item_icons/named/0112_Griseous_Orb.png',
    ['GROUNDIUM_Z']='assets/item_icons/named/0784_Groundium_Z.png',
    ['GROUND_GEM']='assets/item_icons/named/0555_Ground_Gem.png',
    ['GROUND_MEMORY']='assets/item_icons/named/0907_Ground_Memory.png',
    ['GROWTH_MULCH']='assets/item_icons/named/0095_Growth_Mulch.png',
    ['GRUBBY_HANKY']='assets/item_icons/named/0634_Grubby_Hanky.png',
    ['GUARD_SPEC']='assets/item_icons/named/0055_Guard_Spec.png',
    ['GUIDEBOOK']='assets/item_icons/named/0433_Guidebook.png',
    ['GYARADOSITE']='assets/item_icons/named/0676_Gyaradosite.png',
    ['HABAN_BERRY']='assets/item_icons/named/0197_Haban_Berry.png',
    ['HARD_STONE']='assets/item_icons/named/0238_Hard_Stone.png',
    ['HEALTH_FEATHER']='assets/item_icons/named/0565_Health_Feather.png',
    ['HEAL_BALL']='assets/item_icons/named/0014_Heal_Ball.png',
    ['HEAL_POWDER']='assets/item_icons/named/0036_Heal_Powder.png',
    ['HEART_SCALE']='assets/item_icons/named/0093_Heart_Scale.png',
    ['HEAT_ROCK']='assets/item_icons/named/0284_Heat_Rock.png',
    ['HEAVY_BALL']='assets/item_icons/named/0495_Heavy_Ball.png',
    ['HEAVY_DUTY_BOOTS']='assets/item_icons/named/1120_Heavy-Duty_Boots.png',
    ['HELIX_FOSSIL']='assets/item_icons/named/0101_Helix_Fossil.png',
    ['HERACRONITE']='assets/item_icons/named/0680_Heracronite.png',
    ['HM01']='assets/item_icons/named/0420_HM01.png',
    ['HM02']='assets/item_icons/named/0421_HM02.png',
    ['HM03']='assets/item_icons/named/0422_HM03.png',
    ['HM04']='assets/item_icons/named/0423_HM04.png',
    ['HM05']='assets/item_icons/named/0424_HM05.png',
    ['HM06']='assets/item_icons/named/0425_HM06.png',
    ['HM07']='assets/item_icons/named/0426_HM07.png',
    ['HM08']='assets/item_icons/named/0427_HM08.png',
    ['HOLO_CASTER']='assets/item_icons/named/0641_Holo_Caster.png',
    ['HONDEW_BERRY']='assets/item_icons/named/0172_Hondew_Berry.png',
    ['HONEY']='assets/item_icons/named/0094_Honey.png',
    ['HONOR_OF_KALOS']='assets/item_icons/named/0702_Honor_of_Kalos.png',
    ['HOUNDOOMINITE']='assets/item_icons/named/0666_Houndoominite.png',
    ['HP_UP']='assets/item_icons/named/0045_HP_Up.png',
    ['HYPER_POTION']='assets/item_icons/named/0025_Hyper_Potion.png',
    ['IAPAPA_BERRY']='assets/item_icons/named/0163_Iapapa_Berry.png',
    ['ICE_GEM']='assets/item_icons/named/0552_Ice_Gem.png',
    ['ICE_HEAL']='assets/item_icons/named/0020_Ice_Heal.png',
    ['ICE_MEMORY']='assets/item_icons/named/0917_Ice_Memory.png',
    ['ICE_STONE']='assets/item_icons/named/0849_Ice_Stone.png',
    ['ICICLE_PLATE']='assets/item_icons/named/0302_Icicle_Plate.png',
    ['ICIUM_Z']='assets/item_icons/named/0781_Icium_Z.png',
    ['ICY_ROCK']='assets/item_icons/named/0282_Icy_Rock.png',
    ['INCINIUM_Z']='assets/item_icons/named/0799_Incinium_Z.png',
    ['INQUIRY_MAIL']='assets/item_icons/named/0141_Inquiry_Mail.png',
    ['INSECT_PLATE']='assets/item_icons/named/0308_Insect_Plate.png',
    ['INTRIGUING_STONE']='assets/item_icons/named/0697_Intriguing_Stone.png',
    ['IRON']='assets/item_icons/named/0047_Iron.png',
    ['IRON_BALL']='assets/item_icons/named/0278_Iron_Ball.png',
    ['IRON_PLATE']='assets/item_icons/named/0313_Iron_Plate.png',
    ['ITEMFINDER']='assets/item_icons/named/0471_Dowsing_Machine.png',
    ['ITEM_DROP']='assets/item_icons/named/0612_Item_Drop.png',
    ['ITEM_URGE']='assets/item_icons/named/0613_Item_Urge.png',
    ['JABOCA_BERRY']='assets/item_icons/named/0211_Jaboca_Berry.png',
    ['JADE_ORB']='assets/item_icons/named/0532_Jade_Orb.png',
    ['JAW_FOSSIL']='assets/item_icons/named/0710_Jaw_Fossil.png',
    ['KANGASKHANITE']='assets/item_icons/named/0675_Kangaskhanite.png',
    ['KASIB_BERRY']='assets/item_icons/named/0196_Kasib_Berry.png',
    ['KEBIA_BERRY']='assets/item_icons/named/0190_Kebia_Berry.png',
    ['KEE_BERRY']='assets/item_icons/named/0687_Kee_Berry.png',
    ['KELPSY_BERRY']='assets/item_icons/named/0170_Kelpsy_Berry.png',
    ['KEY_STONE']='assets/item_icons/named/0773_Key_Stone.png',
    ['KEY_TO_ROOM_1']='assets/item_icons/named/0730_Key_to_Room_1.png',
    ['KEY_TO_ROOM_2']='assets/item_icons/named/0731_Key_to_Room_2.png',
    ['KEY_TO_ROOM_4']='assets/item_icons/named/0732_Key_to_Room_4.png',
    ['KEY_TO_ROOM_6']='assets/item_icons/named/0733_Key_to_Room_6.png',
    ['KINGS_ROCK']='assets/item_icons/named/0221_Kings_Rock.png',
    ['LAGGING_TAIL']='assets/item_icons/named/0279_Lagging_Tail.png',
    ['LANSAT_BERRY']='assets/item_icons/named/0206_Lansat_Berry.png',
    ['LATIASITE']='assets/item_icons/named/0684_Latiasite.png',
    ['LATIOSITE']='assets/item_icons/named/0685_Latiosite.png',
    ['LAVA_COOKIE']='assets/item_icons/named/0042_Lava_Cookie.png',
    ['LAX_INCENSE']='assets/item_icons/named/0255_Lax_Incense.png',
    ['LEAF_STONE']='assets/item_icons/named/0085_Leaf_Stone.png',
    ['LEEK']='assets/item_icons/named/0259_Leek.png',
    ['LEFTOVERS']='assets/item_icons/named/0234_Leftovers.png',
    ['LEMONADE']='assets/item_icons/named/0032_Lemonade.png',
    ['LENS_CASE']='assets/item_icons/named/0705_Lens_Case.png',
    ['LEPPA_BERRY']='assets/item_icons/named/0154_Leppa_Berry.png',
    ['LETTER']='assets/item_icons/named/0725_Letter.png',
    ['LEVEL_BALL']='assets/item_icons/named/0493_Level_Ball.png',
    ['LIBERTY_PASS']='assets/item_icons/named/0574_Liberty_Pass.png',
    ['LIECHI_BERRY']='assets/item_icons/named/0201_Liechi_Berry.png',
    ['LIFE_ORB']='assets/item_icons/named/0270_Life_Orb.png',
    ['LIGHT_BALL']='assets/item_icons/named/0236_Light_Ball.png',
    ['LIGHT_CLAY']='assets/item_icons/named/0269_Light_Clay.png',
    ['LIGHT_STONE']='assets/item_icons/named/0616_Light_Stone.png',
    ['LIKE_MAIL']='assets/item_icons/named/0142_Like_Mail.png',
    ['LOCK_CAPSULE']='assets/item_icons/named/0533_Lock_Capsule.png',
    ['LOOKER_TICKET']='assets/item_icons/named/0712_Looker_Ticket.png',
    ['LOOT_SACK']='assets/item_icons/named/0429_Loot_Sack.png',
    ['LOPUNNITE']='assets/item_icons/named/0768_Lopunnite.png',
    ['LOST_ITEM']='assets/item_icons/named/0479_Lost_Item.png',
    ['LOVE_BALL']='assets/item_icons/named/0496_Love_Ball.png',
    ['LUCARIONITE']='assets/item_icons/named/0673_Lucarionite.png',
    ['LUCKY_EGG']='assets/item_icons/named/0231_Lucky_Egg.png',
    ['LUCKY_PUNCH']='assets/item_icons/named/0256_Lucky_Punch.png',
    ['LUCK_INCENSE']='assets/item_icons/named/0319_Luck_Incense.png',
    ['LUMINOUS_MOSS']='assets/item_icons/named/0648_Luminous_Moss.png',
    ['LUMIOSE_GALETTE']='assets/item_icons/named/0708_Lumiose_Galette.png',
    ['LUM_BERRY']='assets/item_icons/named/0157_Lum_Berry.png',
    ['LUNAR_FEATHER']='assets/item_icons/named/0453_Lunar_Feather.png',
    ['LURE_BALL']='assets/item_icons/named/0494_Lure_Ball.png',
    ['LUSTROUS_ORB']='assets/item_icons/named/0136_Lustrous_Orb.png',
    ['LUXURY_BALL']='assets/item_icons/named/0011_Luxury_Ball.png',
    ['MACHINE_PART']='assets/item_icons/named/0481_Machine_Part.png',
    ['MACHO_BRACE']='assets/item_icons/named/0215_Macho_Brace.png',
    ['MACH_BIKE']='assets/item_icons/named/0718_Mach_Bike.png',
    ['MAGMARIZER']='assets/item_icons/named/0323_Magmarizer.png',
    ['MAGMA_STONE']='assets/item_icons/named/0458_Magma_Stone.png',
    ['MAGMA_SUIT']='assets/item_icons/named/0741_Magma_Suit.png',
    ['MAGNET']='assets/item_icons/named/0242_Magnet.png',
    ['MAGOST_BERRY']='assets/item_icons/named/0176_Magost_Berry.png',
    ['MAGO_BERRY']='assets/item_icons/named/0161_Mago_Berry.png',
    ['MAKEUP_BAG']='assets/item_icons/named/0706_Makeup_Bag.png',
    ['MANECTITE']='assets/item_icons/named/0682_Manectite.png',
    ['MARANGA_BERRY']='assets/item_icons/named/0688_Maranga_Berry.png',
    ['MARSHADIUM_Z']='assets/item_icons/named/0802_Marshadium_Z.png',
    ['MASTER_BALL']='assets/item_icons/named/0001_Master_Ball.png',
    ['MAWILITE']='assets/item_icons/named/0681_Mawilite.png',
    ['MAX_ELIXIR']='assets/item_icons/named/0041_Max_Elixir.png',
    ['MAX_ETHER']='assets/item_icons/named/0039_Max_Ether.png',
    ['MAX_POTION']='assets/item_icons/named/0024_Max_Potion.png',
    ['MAX_REPEL']='assets/item_icons/named/0077_Max_Repel.png',
    ['MAX_REVIVE']='assets/item_icons/named/0029_Max_Revive.png',
    ['MEADOW_PLATE']='assets/item_icons/named/0301_Meadow_Plate.png',
    ['MEDAL_BOX']='assets/item_icons/named/0627_Medal_Box.png',
    ['MEDICHAMITE']='assets/item_icons/named/0665_Medichamite.png',
    ['MEDICINE_POCKET']='assets/item_icons/named/0122_Medicine_Pocket.png',
    ['MEGA_ANCHOR']='assets/item_icons/named/0747_Mega_Anchor.png',
    ['MEGA_ANKLET']='assets/item_icons/named/0750_Mega_Anklet.png',
    ['MEGA_BRACELET']='assets/item_icons/named/0744_Mega_Bracelet.png',
    ['MEGA_CHARM']='assets/item_icons/named/0716_Mega_Charm.png',
    ['MEGA_CUFF']='assets/item_icons/named/0766_Mega_Cuff.png',
    ['MEGA_GLASSES']='assets/item_icons/named/0746_Mega_Glasses.png',
    ['MEGA_GLOVE']='assets/item_icons/named/0717_Mega_Glove.png',
    ['MEGA_PENDANT']='assets/item_icons/named/0745_Mega_Pendant.png',
    ['MEGA_RING']='assets/item_icons/named/0696_Mega_Ring.png',
    ['MEGA_STICKPIN']='assets/item_icons/named/0748_Mega_Stickpin.png',
    ['MEGA_TIARA']='assets/item_icons/named/0749_Mega_Tiara.png',
    ['MEMBER_CARD']='assets/item_icons/named/0454_Member_Card.png',
    ['MENTAL_HERB']='assets/item_icons/named/0219_Mental_Herb.png',
    ['METAGROSSITE']='assets/item_icons/named/0758_Metagrossite.png',
    ['METAL_COAT']='assets/item_icons/named/0233_Metal_Coat.png',
    ['METAL_POWDER']='assets/item_icons/named/0257_Metal_Powder.png',
    ['METEORITE']='assets/item_icons/named/0729_Meteorite.png',
    ['METEORITE_SHARD']='assets/item_icons/named/0774_Meteorite_Shard.png',
    ['METRONOME']='assets/item_icons/named/0277_Metronome.png',
    ['MEWNIUM_Z']='assets/item_icons/named/0806_Mewnium_Z.png',
    ['MEWTWONITE_X']='assets/item_icons/named/0662_Mewtwonite_X.png',
    ['MEWTWONITE_Y']='assets/item_icons/named/0663_Mewtwonite_Y.png',
    ['MICLE_BERRY']='assets/item_icons/named/0209_Micle_Berry.png',
    ['MIND_PLATE']='assets/item_icons/named/0307_Mind_Plate.png',
    ['MIRACLE_SEED']='assets/item_icons/named/0239_Miracle_Seed.png',
    ['MISTY_SEED']='assets/item_icons/named/0883_Misty_Seed.png',
    ['MOOMOO_MILK']='assets/item_icons/named/0033_Moomoo_Milk.png',
    ['MOON_BALL']='assets/item_icons/named/0498_Moon_Ball.png',
    ['MOON_FLUTE']='assets/item_icons/named/0858_Moon_Flute.png',
    ['MOON_STONE']='assets/item_icons/named/0081_Moon_Stone.png',
    ['MUSCLE_BAND']='assets/item_icons/named/0266_Muscle_Band.png',
    ['MUSCLE_FEATHER']='assets/item_icons/named/0566_Muscle_Feather.png',
    ['MYSTERY_EGG']='assets/item_icons/named/0484_Mystery_Egg.png',
    ['MYSTIC_WATER']='assets/item_icons/named/0243_Mystic_Water.png',
    ['NANAB_BERRY']='assets/item_icons/named/0166_Nanab_Berry.png',
    ['NEST_BALL']='assets/item_icons/named/0008_Nest_Ball.png',
    ['NET_BALL']='assets/item_icons/named/0006_Net_Ball.png',
    ['NEVER_MELT_ICE']='assets/item_icons/named/0246_Never-Melt_Ice.png',
    ['NOMEL_BERRY']='assets/item_icons/named/0178_Nomel_Berry.png',
    ['NORMALIUM_Z']='assets/item_icons/named/0776_Normalium_Z.png',
    ['NORMAL_GEM']='assets/item_icons/named/0564_Normal_Gem.png',
    ['NUGGET']='assets/item_icons/named/0092_Nugget.png',
    ['OAKS_LETTER']='assets/item_icons/named/0452_Oaks_Letter.png',
    ['OCCA_BERRY']='assets/item_icons/named/0184_Occa_Berry.png',
    ['ODD_INCENSE']='assets/item_icons/named/0314_Odd_Incense.png',
    ['ODD_KEYSTONE']='assets/item_icons/named/0111_Odd_Keystone.png',
    ['OLD_AMBER']='assets/item_icons/named/0103_Old_Amber.png',
    ['OLD_CHARM']='assets/item_icons/named/0439_Old_Charm.png',
    ['OLD_GATEAU']='assets/item_icons/named/0054_Old_Gateau.png',
    ['OLD_ROD']='assets/item_icons/named/0445_Old_Rod.png',
    ['ORAN_BERRY']='assets/item_icons/named/0155_Oran_Berry.png',
    ['OVAL_CHARM']='assets/item_icons/named/0631_Oval_Charm.png',
    ['OVAL_STONE']='assets/item_icons/named/0110_Oval_Stone.png',
    ['PAIR_OF_TICKETS']='assets/item_icons/named/0743_Pair_of_Tickets.png',
    ['PAL_PAD']='assets/item_icons/named/0437_Pal_Pad.png',
    ['PAMTRE_BERRY']='assets/item_icons/named/0180_Pamtre_Berry.png',
    ['PARALYZE_HEAL']='assets/item_icons/named/0022_Paralyze_Heal.png',
    ['PARCEL']='assets/item_icons/named/0459_Parcel.png',
    ['PARK_BALL']='assets/item_icons/named/0500_Park_Ball.png',
    ['PARLYZ_HEAL']='assets/item_icons/named/0022_Paralyze_Heal.png',
    ['PASS']='assets/item_icons/named/0480_Pass.png',
    ['PASSHO_BERRY']='assets/item_icons/named/0185_Passho_Berry.png',
    ['PASS_ORB']='assets/item_icons/named/0575_Pass_Orb.png',
    ['PAYAPA_BERRY']='assets/item_icons/named/0193_Payapa_Berry.png',
    ['PEARL']='assets/item_icons/named/0088_Pearl.png',
    ['PEARL_STRING']='assets/item_icons/named/0582_Pearl_String.png',
    ['PECHA_BERRY']='assets/item_icons/named/0151_Pecha_Berry.png',
    ['PERMIT']='assets/item_icons/named/0630_Permit.png',
    ['PERSIM_BERRY']='assets/item_icons/named/0156_Persim_Berry.png',
    ['PETAYA_BERRY']='assets/item_icons/named/0204_Petaya_Berry.png',
    ['PHOTO_ALBUM']='assets/item_icons/named/0501_Photo_Album.png',
    ['PIDGEOTITE']='assets/item_icons/named/0762_Pidgeotite.png',
    ['PIKANIUM_Z']='assets/item_icons/named/0794_Pikanium_Z.png',
    ['PIKASHUNIUM_Z']='assets/item_icons/named/0835_Pikashunium_Z.png',
    ['PINAP_BERRY']='assets/item_icons/named/0168_Pinap_Berry.png',
    ['PINK_APRICORN']='assets/item_icons/named/0489_Pink_Apricorn.png',
    ['PINK_NECTAR']='assets/item_icons/named/0855_Pink_Nectar.png',
    ['PINK_SCARF']='assets/item_icons/named/0262_Pink_Scarf.png',
    ['PINSIRITE']='assets/item_icons/named/0671_Pinsirite.png',
    ['PIXIE_PLATE']='assets/item_icons/named/0644_Pixie_Plate.png',
    ['PLASMA_CARD']='assets/item_icons/named/0633_Plasma_Card.png',
    ['PLUME_FOSSIL']='assets/item_icons/named/0573_Plume_Fossil.png',
    ['POFFIN_CASE']='assets/item_icons/named/0449_Poffin_Case.png',
    ['POINT_CARD']='assets/item_icons/named/0432_Point_Card.png',
    ['POISONIUM_Z']='assets/item_icons/named/0783_Poisonium_Z.png',
    ['POISON_BARB']='assets/item_icons/named/0245_Poison_Barb.png',
    ['POISON_GEM']='assets/item_icons/named/0554_Poison_Gem.png',
    ['POISON_MEMORY']='assets/item_icons/named/0906_Poison_Memory.png',
    ['POKEBLOCK_KIT']='assets/item_icons/named/0724_Pokeblock_Kit.png',
    ['POKEMON_BOX_LINK']='assets/item_icons/named/0121_Pokemon_Box_Link.png',
    ['POKE_BALL']='assets/item_icons/named/0004_Poke_Ball.png',
    ['POKE_DOLL']='assets/item_icons/named/0063_Poke_Doll.png',
    ['POKE_FLUTE']='assets/item_icons/named/0651_Poke_Flute.png',
    ['POKE_RADAR']='assets/item_icons/named/0431_Poke_Radar.png',
    ['POKE_TOY']='assets/item_icons/named/0577_Poke_Toy.png',
    ['POMEG_BERRY']='assets/item_icons/named/0169_Pomeg_Berry.png',
    ['POTION']='assets/item_icons/named/0017_Potion.png',
    ['POWER_ANKLET']='assets/item_icons/named/0293_Power_Anklet.png',
    ['POWER_BAND']='assets/item_icons/named/0292_Power_Band.png',
    ['POWER_BELT']='assets/item_icons/named/0290_Power_Belt.png',
    ['POWER_BRACER']='assets/item_icons/named/0289_Power_Bracer.png',
    ['POWER_HERB']='assets/item_icons/named/0271_Power_Herb.png',
    ['POWER_LENS']='assets/item_icons/named/0291_Power_Lens.png',
    ['POWER_PLANT_PASS']='assets/item_icons/named/0695_Power_Plant_Pass.png',
    ['POWER_UP_POCKET']='assets/item_icons/named/0125_Power-Up_Pocket.png',
    ['POWER_WEIGHT']='assets/item_icons/named/0294_Power_Weight.png',
    ['PP_MAX']='assets/item_icons/named/0053_PP_Max.png',
    ['PP_UP']='assets/item_icons/named/0051_PP_Up.png',
    ['PREMIER_BALL']='assets/item_icons/named/0012_Premier_Ball.png',
    ['PRETTY_FEATHER']='assets/item_icons/named/0571_Pretty_Feather.png',
    ['PRIMARIUM_Z']='assets/item_icons/named/0800_Primarium_Z.png',
    ['PRISM_SCALE']='assets/item_icons/named/0537_Prism_Scale.png',
    ['PRISON_BOTTLE']='assets/item_icons/named/0765_Prison_Bottle.png',
    ['PROFESSORS_MASK']='assets/item_icons/named/0843_Professors_Mask.png',
    ['PROFS_LETTER']='assets/item_icons/named/0642_Profs_Letter.png',
    ['PROP_CASE']='assets/item_icons/named/0578_Prop_Case.png',
    ['PROTECTIVE_PADS']='assets/item_icons/named/0880_Protective_Pads.png',
    ['PROTECTOR']='assets/item_icons/named/0321_Protector.png',
    ['PROTEIN']='assets/item_icons/named/0046_Protein.png',
    ['PSYCHIC_GEM']='assets/item_icons/named/0557_Psychic_Gem.png',
    ['PSYCHIC_MEMORY']='assets/item_icons/named/0916_Psychic_Memory.png',
    ['PSYCHIC_SEED']='assets/item_icons/named/0882_Psychic_Seed.png',
    ['PSYCHIUM_Z']='assets/item_icons/named/0786_Psychium_Z.png',
    ['PURE_INCENSE']='assets/item_icons/named/0320_Pure_Incense.png',
    ['PURPLE_NECTAR']='assets/item_icons/named/0856_Purple_Nectar.png',
    ['QUALOT_BERRY']='assets/item_icons/named/0171_Qualot_Berry.png',
    ['QUICK_BALL']='assets/item_icons/named/0015_Quick_Ball.png',
    ['QUICK_CLAW']='assets/item_icons/named/0217_Quick_Claw.png',
    ['QUICK_POWDER']='assets/item_icons/named/0274_Quick_Powder.png',
    ['RABUTA_BERRY']='assets/item_icons/named/0177_Rabuta_Berry.png',
    ['RAGE_CANDY_BAR']='assets/item_icons/named/0504_Rage_Candy_Bar.png',
    ['RAINBOW_FEATHER']='assets/item_icons/named/0483_Rainbow_Feather.png',
    ['RARE_BONE']='assets/item_icons/named/0106_Rare_Bone.png',
    ['RARE_CANDY']='assets/item_icons/named/0050_Rare_Candy.png',
    ['RAWST_BERRY']='assets/item_icons/named/0152_Rawst_Berry.png',
    ['RAZOR_CLAW']='assets/item_icons/named/0326_Razor_Claw.png',
    ['RAZOR_FANG']='assets/item_icons/named/0327_Razor_Fang.png',
    ['RAZZ_BERRY']='assets/item_icons/named/0164_Razz_Berry.png',
    ['REAPER_CLOTH']='assets/item_icons/named/0325_Reaper_Cloth.png',
    ['RED_APRICORN']='assets/item_icons/named/0485_Red_Apricorn.png',
    ['RED_CARD']='assets/item_icons/named/0542_Red_Card.png',
    ['RED_CHAIN']='assets/item_icons/named/0441_Red_Chain.png',
    ['RED_FLUTE']='assets/item_icons/named/0067_Red_Flute.png',
    ['RED_NECTAR']='assets/item_icons/named/0853_Red_Nectar.png',
    ['RED_ORB']='assets/item_icons/named/0534_Red_Orb.png',
    ['RED_SCALE']='assets/item_icons/named/0478_Red_Scale.png',
    ['RED_SCARF']='assets/item_icons/named/0260_Red_Scarf.png',
    ['RED_SHARD']='assets/item_icons/named/0072_Red_Shard.png',
    ['RELIC_BAND']='assets/item_icons/named/0588_Relic_Band.png',
    ['RELIC_COPPER']='assets/item_icons/named/0584_Relic_Copper.png',
    ['RELIC_CROWN']='assets/item_icons/named/0590_Relic_Crown.png',
    ['RELIC_GOLD']='assets/item_icons/named/0586_Relic_Gold.png',
    ['RELIC_SILVER']='assets/item_icons/named/0585_Relic_Silver.png',
    ['RELIC_STATUE']='assets/item_icons/named/0589_Relic_Statue.png',
    ['RELIC_VASE']='assets/item_icons/named/0587_Relic_Vase.png',
    ['REPEAT_BALL']='assets/item_icons/named/0009_Repeat_Ball.png',
    ['REPEL']='assets/item_icons/named/0079_Repel.png',
    ['REPLY_MAIL']='assets/item_icons/named/0143_Reply_Mail.png',
    ['RESET_URGE']='assets/item_icons/named/0614_Reset_Urge.png',
    ['RESIST_FEATHER']='assets/item_icons/named/0567_Resist_Feather.png',
    ['REVEAL_GLASS']='assets/item_icons/named/0638_Reveal_Glass.png',
    ['REVIVAL_HERB']='assets/item_icons/named/0037_Revival_Herb.png',
    ['REVIVE']='assets/item_icons/named/0028_Revive.png',
    ['RIBBON_SWEET']='assets/item_icons/named/1115_Ribbon_Sweet.png',
    ['RICH_MULCH']='assets/item_icons/named/0652_Rich_Mulch.png',
    ['RIDE_PAGER']='assets/item_icons/named/0850_Ride_Pager.png',
    ['RINDO_BERRY']='assets/item_icons/named/0187_Rindo_Berry.png',
    ['RING_TARGET']='assets/item_icons/named/0543_Ring_Target.png',
    ['ROCKIUM_Z']='assets/item_icons/named/0788_Rockium_Z.png',
    ['ROCKY_HELMET']='assets/item_icons/named/0540_Rocky_Helmet.png',
    ['ROCK_GEM']='assets/item_icons/named/0559_Rock_Gem.png',
    ['ROCK_INCENSE']='assets/item_icons/named/0315_Rock_Incense.png',
    ['ROCK_MEMORY']='assets/item_icons/named/0908_Rock_Memory.png',
    ['ROLLER_SKATES']='assets/item_icons/named/0643_Roller_Skates.png',
    ['ROOM_SERVICE']='assets/item_icons/named/1122_Room_Service.png',
    ['ROOT_FOSSIL']='assets/item_icons/named/0099_Root_Fossil.png',
    ['ROSELI_BERRY']='assets/item_icons/named/0686_Roseli_Berry.png',
    ['ROSE_INCENSE']='assets/item_icons/named/0318_Rose_Incense.png',
    ['ROWAP_BERRY']='assets/item_icons/named/0212_Rowap_Berry.png',
    ['RSVP_MAIL']='assets/item_icons/named/0139_RSVP_Mail.png',
    ['RULE_BOOK']='assets/item_icons/named/0430_Rule_Book.png',
    ['SABLENITE']='assets/item_icons/named/0754_Sablenite.png',
    ['SACHET']='assets/item_icons/named/0647_Sachet.png',
    ['SACRED_ASH']='assets/item_icons/named/0044_Sacred_Ash.png',
    ['SAFARI_BALL']='assets/item_icons/named/0005_Safari_Ball.png',
    ['SAFETY_GOGGLES']='assets/item_icons/named/0650_Safety_Goggles.png',
    ['SAIL_FOSSIL']='assets/item_icons/named/0711_Sail_Fossil.png',
    ['SALAC_BERRY']='assets/item_icons/named/0203_Salac_Berry.png',
    ['SALAMENCITE']='assets/item_icons/named/0769_Salamencite.png',
    ['SCANNER']='assets/item_icons/named/0727_Scanner.png',
    ['SCEPTILITE']='assets/item_icons/named/0753_Sceptilite.png',
    ['SCIZORITE']='assets/item_icons/named/0670_Scizorite.png',
    ['SCOPE_LENS']='assets/item_icons/named/0232_Scope_Lens.png',
    ['SEA_INCENSE']='assets/item_icons/named/0254_Sea_Incense.png',
    ['SECRET_KEY']='assets/item_icons/named/0467_Secret_Key.png',
    ['SECRET_MEDICINE']='assets/item_icons/named/0464_Secret_Medicine.png',
    ['SHALOUR_SABLE']='assets/item_icons/named/0709_Shalour_Sable.png',
    ['SHARPEDONITE']='assets/item_icons/named/0759_Sharpedonite.png',
    ['SHARP_BEAK']='assets/item_icons/named/0244_Sharp_Beak.png',
    ['SHED_SHELL']='assets/item_icons/named/0295_Shed_Shell.png',
    ['SHELL_BELL']='assets/item_icons/named/0253_Shell_Bell.png',
    ['SHINY_CHARM']='assets/item_icons/named/0632_Shiny_Charm.png',
    ['SHINY_STONE']='assets/item_icons/named/0107_Shiny_Stone.png',
    ['SHOAL_SALT']='assets/item_icons/named/0070_Shoal_Salt.png',
    ['SHOAL_SHELL']='assets/item_icons/named/0071_Shoal_Shell.png',
    ['SHOCK_DRIVE']='assets/item_icons/named/0117_Shock_Drive.png',
    ['SHUCA_BERRY']='assets/item_icons/named/0191_Shuca_Berry.png',
    ['SILK_SCARF']='assets/item_icons/named/0251_Silk_Scarf.png',
    ['SILVER_FEATHER']='assets/item_icons/named/0482_Silver_Feather.png',
    ['SILVER_NANAB_BERRY']='assets/item_icons/named/0863_Silver_Nanab_Berry.png',
    ['SILVER_PINAP_BERRY']='assets/item_icons/named/0865_Silver_Pinap_Berry.png',
    ['SILVER_POWDER']='assets/item_icons/named/0222_Silver_Powder.png',
    ['SITRUS_BERRY']='assets/item_icons/named/0158_Sitrus_Berry.png',
    ['SKULL_FOSSIL']='assets/item_icons/named/0105_Skull_Fossil.png',
    ['SKY_PLATE']='assets/item_icons/named/0306_Sky_Plate.png',
    ['SLOWBRONITE']='assets/item_icons/named/0760_Slowbronite.png',
    ['SLOWPOKE_TAIL']='assets/item_icons/named/0473_Slowpoke_Tail.png',
    ['SMOKE_BALL']='assets/item_icons/named/0228_Smoke_Ball.png',
    ['SMOOTH_ROCK']='assets/item_icons/named/0283_Smooth_Rock.png',
    ['SNORLIUM_Z']='assets/item_icons/named/0804_Snorlium_Z.png',
    ['SNOWBALL']='assets/item_icons/named/0649_Snowball.png',
    ['SODA_POP']='assets/item_icons/named/0031_Soda_Pop.png',
    ['SOFT_SAND']='assets/item_icons/named/0237_Soft_Sand.png',
    ['SOOTHE_BELL']='assets/item_icons/named/0218_Soothe_Bell.png',
    ['SOOT_SACK']='assets/item_icons/named/0722_Soot_Sack.png',
    ['SOUL_DEW']='assets/item_icons/named/0225_Soul_Dew.png',
    ['SPARKLING_STONE']='assets/item_icons/named/0845_Sparkling_Stone.png',
    ['SPELL_TAG']='assets/item_icons/named/0247_Spell_Tag.png',
    ['SPELON_BERRY']='assets/item_icons/named/0179_Spelon_Berry.png',
    ['SPLASH_PLATE']='assets/item_icons/named/0299_Splash_Plate.png',
    ['SPOOKY_PLATE']='assets/item_icons/named/0310_Spooky_Plate.png',
    ['SPORT_BALL']='assets/item_icons/named/0499_Sport_Ball.png',
    ['SPRAYDUCK']='assets/item_icons/named/0448_Sprayduck.png',
    ['SPRINKLOTAD']='assets/item_icons/named/0689_Sprinklotad.png',
    ['SQUIRT_BOTTLE']='assets/item_icons/named/0477_Squirt_Bottle.png',
    ['SS_TICKET']='assets/item_icons/named/0456_SS_Ticket.png',
    ['STABLE_MULCH']='assets/item_icons/named/0097_Stable_Mulch.png',
    ['STARDUST']='assets/item_icons/named/0090_Stardust.png',
    ['STARF_BERRY']='assets/item_icons/named/0207_Starf_Berry.png',
    ['STAR_PIECE']='assets/item_icons/named/0091_Star_Piece.png',
    ['STAR_SWEET']='assets/item_icons/named/1114_Star_Sweet.png',
    ['STEELIUM_Z']='assets/item_icons/named/0792_Steelium_Z.png',
    ['STEELIXITE']='assets/item_icons/named/0761_Steelixite.png',
    ['STEEL_GEM']='assets/item_icons/named/0563_Steel_Gem.png',
    ['STEEL_MEMORY']='assets/item_icons/named/0911_Steel_Memory.png',
    ['STICKER_BAG']='assets/item_icons/named/0436_Sticker_Bag.png',
    ['STICKER_CASE']='assets/item_icons/named/0434_Sticker_Case.png',
    ['STICKY_BARB']='assets/item_icons/named/0288_Sticky_Barb.png',
    ['STONE_PLATE']='assets/item_icons/named/0309_Stone_Plate.png',
    ['STORAGE_KEY']='assets/item_icons/named/0463_Storage_Key.png',
    ['STRANGE_SOUVENIR']='assets/item_icons/named/0704_Strange_Souvenir.png',
    ['SUITE_KEY']='assets/item_icons/named/0451_Suite_Key.png',
    ['SUN_FLUTE']='assets/item_icons/named/0857_Sun_Flute.png',
    ['SUN_STONE']='assets/item_icons/named/0080_Sun_Stone.png',
    ['SUPER_POTION']='assets/item_icons/named/0026_Super_Potion.png',
    ['SUPER_REPEL']='assets/item_icons/named/0076_Super_Repel.png',
    ['SUPER_ROD']='assets/item_icons/named/0447_Super_Rod.png',
    ['SURPRISE_MULCH']='assets/item_icons/named/0653_Surprise_Mulch.png',
    ['SWAMPERTITE']='assets/item_icons/named/0752_Swampertite.png',
    ['SWEET_APPLE']='assets/item_icons/named/1116_Sweet_Apple.png',
    ['SWEET_HEART']='assets/item_icons/named/0134_Sweet_Heart.png',
    ['SWIFT_FEATHER']='assets/item_icons/named/0570_Swift_Feather.png',
    ['TAMATO_BERRY']='assets/item_icons/named/0174_Tamato_Berry.png',
    ['TANGA_BERRY']='assets/item_icons/named/0194_Tanga_Berry.png',
    ['TAPUNIUM_Z']='assets/item_icons/named/0801_Tapunium_Z.png',
    ['TART_APPLE']='assets/item_icons/named/1117_Tart_Apple.png',
    ['TEA']='assets/item_icons/named/0113_Tea.png',
    ['TERRAIN_EXTENDER']='assets/item_icons/named/0879_Terrain_Extender.png',
    ['THANKS_MAIL']='assets/item_icons/named/0140_Thanks_Mail.png',
    ['THICK_CLUB']='assets/item_icons/named/0258_Thick_Club.png',
    ['THROAT_SPRAY']='assets/item_icons/named/1118_Throat_Spray.png',
    ['THUNDER_STONE']='assets/item_icons/named/0083_Thunder_Stone.png',
    ['TIDAL_BELL']='assets/item_icons/named/0503_Tidal_Bell.png',
    ['TIMER_BALL']='assets/item_icons/named/0010_Timer_Ball.png',
    ['TINY_MUSHROOM']='assets/item_icons/named/0086_Tiny_Mushroom.png',
    ['TM01']='assets/item_icons/named/0328_TM01.png',
    ['TM02']='assets/item_icons/named/0329_TM02.png',
    ['TM03']='assets/item_icons/named/0330_TM03.png',
    ['TM04']='assets/item_icons/named/0331_TM04.png',
    ['TM05']='assets/item_icons/named/0332_TM05.png',
    ['TM06']='assets/item_icons/named/0333_TM06.png',
    ['TM07']='assets/item_icons/named/0334_TM07.png',
    ['TM08']='assets/item_icons/named/0335_TM08.png',
    ['TM09']='assets/item_icons/named/0336_TM09.png',
    ['TM10']='assets/item_icons/named/0337_TM10.png',
    ['TM100']='assets/item_icons/named/0694_TM100.png',
    ['TM11']='assets/item_icons/named/0338_TM11.png',
    ['TM12']='assets/item_icons/named/0339_TM12.png',
    ['TM13']='assets/item_icons/named/0340_TM13.png',
    ['TM14']='assets/item_icons/named/0341_TM14.png',
    ['TM15']='assets/item_icons/named/0342_TM15.png',
    ['TM16']='assets/item_icons/named/0343_TM16.png',
    ['TM17']='assets/item_icons/named/0344_TM17.png',
    ['TM18']='assets/item_icons/named/0345_TM18.png',
    ['TM19']='assets/item_icons/named/0346_TM19.png',
    ['TM20']='assets/item_icons/named/0347_TM20.png',
    ['TM21']='assets/item_icons/named/0348_TM21.png',
    ['TM22']='assets/item_icons/named/0349_TM22.png',
    ['TM23']='assets/item_icons/named/0350_TM23.png',
    ['TM24']='assets/item_icons/named/0351_TM24.png',
    ['TM25']='assets/item_icons/named/0352_TM25.png',
    ['TM26']='assets/item_icons/named/0353_TM26.png',
    ['TM27']='assets/item_icons/named/0354_TM27.png',
    ['TM28']='assets/item_icons/named/0355_TM28.png',
    ['TM29']='assets/item_icons/named/0356_TM29.png',
    ['TM30']='assets/item_icons/named/0357_TM30.png',
    ['TM31']='assets/item_icons/named/0358_TM31.png',
    ['TM32']='assets/item_icons/named/0359_TM32.png',
    ['TM33']='assets/item_icons/named/0360_TM33.png',
    ['TM34']='assets/item_icons/named/0361_TM34.png',
    ['TM35']='assets/item_icons/named/0362_TM35.png',
    ['TM36']='assets/item_icons/named/0363_TM36.png',
    ['TM37']='assets/item_icons/named/0364_TM37.png',
    ['TM38']='assets/item_icons/named/0365_TM38.png',
    ['TM39']='assets/item_icons/named/0366_TM39.png',
    ['TM40']='assets/item_icons/named/0367_TM40.png',
    ['TM41']='assets/item_icons/named/0368_TM41.png',
    ['TM42']='assets/item_icons/named/0369_TM42.png',
    ['TM43']='assets/item_icons/named/0370_TM43.png',
    ['TM44']='assets/item_icons/named/0371_TM44.png',
    ['TM45']='assets/item_icons/named/0372_TM45.png',
    ['TM46']='assets/item_icons/named/0373_TM46.png',
    ['TM47']='assets/item_icons/named/0374_TM47.png',
    ['TM48']='assets/item_icons/named/0375_TM48.png',
    ['TM49']='assets/item_icons/named/0376_TM49.png',
    ['TM50']='assets/item_icons/named/0377_TM50.png',
    ['TM51']='assets/item_icons/named/0378_TM51.png',
    ['TM52']='assets/item_icons/named/0379_TM52.png',
    ['TM53']='assets/item_icons/named/0380_TM53.png',
    ['TM54']='assets/item_icons/named/0381_TM54.png',
    ['TM55']='assets/item_icons/named/0382_TM55.png',
    ['TM56']='assets/item_icons/named/0383_TM56.png',
    ['TM57']='assets/item_icons/named/0384_TM57.png',
    ['TM58']='assets/item_icons/named/0385_TM58.png',
    ['TM59']='assets/item_icons/named/0386_TM59.png',
    ['TM60']='assets/item_icons/named/0387_TM60.png',
    ['TM61']='assets/item_icons/named/0388_TM61.png',
    ['TM62']='assets/item_icons/named/0389_TM62.png',
    ['TM63']='assets/item_icons/named/0390_TM63.png',
    ['TM64']='assets/item_icons/named/0391_TM64.png',
    ['TM65']='assets/item_icons/named/0392_TM65.png',
    ['TM66']='assets/item_icons/named/0393_TM66.png',
    ['TM67']='assets/item_icons/named/0394_TM67.png',
    ['TM68']='assets/item_icons/named/0395_TM68.png',
    ['TM69']='assets/item_icons/named/0396_TM69.png',
    ['TM70']='assets/item_icons/named/0397_TM70.png',
    ['TM71']='assets/item_icons/named/0398_TM71.png',
    ['TM72']='assets/item_icons/named/0399_TM72.png',
    ['TM73']='assets/item_icons/named/0400_TM73.png',
    ['TM74']='assets/item_icons/named/0401_TM74.png',
    ['TM75']='assets/item_icons/named/0402_TM75.png',
    ['TM76']='assets/item_icons/named/0403_TM76.png',
    ['TM77']='assets/item_icons/named/0404_TM77.png',
    ['TM78']='assets/item_icons/named/0405_TM78.png',
    ['TM79']='assets/item_icons/named/0406_TM79.png',
    ['TM80']='assets/item_icons/named/0407_TM80.png',
    ['TM81']='assets/item_icons/named/0408_TM81.png',
    ['TM82']='assets/item_icons/named/0409_TM82.png',
    ['TM83']='assets/item_icons/named/0410_TM83.png',
    ['TM84']='assets/item_icons/named/0411_TM84.png',
    ['TM85']='assets/item_icons/named/0412_TM85.png',
    ['TM86']='assets/item_icons/named/0413_TM86.png',
    ['TM87']='assets/item_icons/named/0414_TM87.png',
    ['TM88']='assets/item_icons/named/0415_TM88.png',
    ['TM89']='assets/item_icons/named/0416_TM89.png',
    ['TM90']='assets/item_icons/named/0417_TM90.png',
    ['TM91']='assets/item_icons/named/0418_TM91.png',
    ['TM92']='assets/item_icons/named/0419_TM92.png',
    ['TM93']='assets/item_icons/named/0618_TM93.png',
    ['TM94']='assets/item_icons/named/0619_TM94.png',
    ['TM95']='assets/item_icons/named/0620_TM95.png',
    ['TM96']='assets/item_icons/named/0690_TM96.png',
    ['TM97']='assets/item_icons/named/0691_TM97.png',
    ['TM98']='assets/item_icons/named/0692_TM98.png',
    ['TM99']='assets/item_icons/named/0693_TM99.png',
    ['TMV_PASS']='assets/item_icons/named/0701_TMV_Pass.png',
    ['TM_CASE']='assets/item_icons/named/0123_TM_Case.png',
    ['TOWN_MAP']='assets/item_icons/named/0442_Town_Map.png',
    ['TOXIC_ORB']='assets/item_icons/named/0272_Toxic_Orb.png',
    ['TOXIC_PLATE']='assets/item_icons/named/0304_Toxic_Plate.png',
    ['TR00']='assets/item_icons/named/1130_TR00.png',
    ['TR01']='assets/item_icons/named/1131_TR01.png',
    ['TR02']='assets/item_icons/named/1132_TR02.png',
    ['TR03']='assets/item_icons/named/1133_TR03.png',
    ['TR04']='assets/item_icons/named/1134_TR04.png',
    ['TR05']='assets/item_icons/named/1135_TR05.png',
    ['TR06']='assets/item_icons/named/1136_TR06.png',
    ['TR07']='assets/item_icons/named/1137_TR07.png',
    ['TR08']='assets/item_icons/named/1138_TR08.png',
    ['TR09']='assets/item_icons/named/1139_TR09.png',
    ['TR10']='assets/item_icons/named/1140_TR10.png',
    ['TR11']='assets/item_icons/named/1141_TR11.png',
    ['TR12']='assets/item_icons/named/1142_TR12.png',
    ['TR13']='assets/item_icons/named/1143_TR13.png',
    ['TR14']='assets/item_icons/named/1144_TR14.png',
    ['TR15']='assets/item_icons/named/1145_TR15.png',
    ['TR16']='assets/item_icons/named/1146_TR16.png',
    ['TR17']='assets/item_icons/named/1147_TR17.png',
    ['TR18']='assets/item_icons/named/1148_TR18.png',
    ['TR19']='assets/item_icons/named/1149_TR19.png',
    ['TR20']='assets/item_icons/named/1150_TR20.png',
    ['TRAVEL_TRUNK']='assets/item_icons/named/0707_Travel_Trunk.png',
    ['TWISTED_SPOON']='assets/item_icons/named/0248_Twisted_Spoon.png',
    ['TYRANITARITE']='assets/item_icons/named/0669_Tyranitarite.png',
    ['UI_GAME_POKE_BALL']='assets/item_icons/named/UI_Game_Poke_Ball.png',
    ['UI_RETURN_BACK']='assets/item_icons/named/UI_Return_Back.png',
    ['ULTRA_BALL']='assets/item_icons/named/0002_Ultra_Ball.png',
    ['UNOWN_REPORT']='assets/item_icons/named/0469_Unown_Report.png',
    ['UNUSED_ITEM_ID_114']='assets/item_icons/named/0114_Unused_Item_ID_114.png',
    ['UNUSED_ITEM_ID_120']='assets/item_icons/named/0120_Unused_Item_ID_120.png',
    ['UNUSED_ITEM_ID_129']='assets/item_icons/named/0129_Unused_Item_ID_129.png',
    ['UNUSED_ITEM_ID_130']='assets/item_icons/named/0130_Unused_Item_ID_130.png',
    ['UNUSED_ITEM_ID_131']='assets/item_icons/named/0131_Unused_Item_ID_131.png',
    ['UNUSED_ITEM_ID_132']='assets/item_icons/named/0132_Unused_Item_ID_132.png',
    ['UNUSED_ITEM_ID_133']='assets/item_icons/named/0133_Unused_Item_ID_133.png',
    ['UNUSED_ITEM_ID_622']='assets/item_icons/named/0622_Unused_Item_ID_622.png',
    ['UNUSED_ITEM_ID_839']='assets/item_icons/named/0839_Unused_Item_ID_839.png',
    ['UNUSED_ITEM_ID_840']='assets/item_icons/named/0840_Unused_Item_ID_840.png',
    ['UNUSED_ITEM_ID_848']='assets/item_icons/named/0848_Unused_Item_ID_848.png',
    ['UNUSED_ITEM_ID_859']='assets/item_icons/named/0859_Unused_Item_ID_859.png',
    ['UPGRADE']='assets/item_icons/named/0252_Upgrade.png',
    ['UTILITY_UMBRELLA']='assets/item_icons/named/1123_Utility_Umbrella.png',
    ['VENUSAURITE']='assets/item_icons/named/0659_Venusaurite.png',
    ['VS_RECORDER']='assets/item_icons/named/0465_Vs_Recorder.png',
    ['VS_SEEKER']='assets/item_icons/named/0443_Vs_Seeker.png',
    ['WACAN_BERRY']='assets/item_icons/named/0186_Wacan_Berry.png',
    ['WAILMER_PAIL']='assets/item_icons/named/0720_Wailmer_Pail.png',
    ['WATERIUM_Z']='assets/item_icons/named/0778_Waterium_Z.png',
    ['WATER_GEM']='assets/item_icons/named/0549_Water_Gem.png',
    ['WATER_MEMORY']='assets/item_icons/named/0913_Water_Memory.png',
    ['WATER_STONE']='assets/item_icons/named/0084_Water_Stone.png',
    ['WATMEL_BERRY']='assets/item_icons/named/0181_Watmel_Berry.png',
    ['WAVE_INCENSE']='assets/item_icons/named/0317_Wave_Incense.png',
    ['WEAKNESS_POLICY']='assets/item_icons/named/0639_Weakness_Policy.png',
    ['WEPEAR_BERRY']='assets/item_icons/named/0167_Wepear_Berry.png',
    ['WHIPPED_DREAM']='assets/item_icons/named/0646_Whipped_Dream.png',
    ['WHITE_APRICORN']='assets/item_icons/named/0490_White_Apricorn.png',
    ['WHITE_FLUTE']='assets/item_icons/named/0069_White_Flute.png',
    ['WHITE_HERB']='assets/item_icons/named/0214_White_Herb.png',
    ['WIDE_LENS']='assets/item_icons/named/0265_Wide_Lens.png',
    ['WIKI_BERRY']='assets/item_icons/named/0160_Wiki_Berry.png',
    ['WISE_GLASSES']='assets/item_icons/named/0267_Wise_Glasses.png',
    ['WORKS_KEY']='assets/item_icons/named/0438_Works_Key.png',
    ['XTRANSCEIVER']='assets/item_icons/named/0621_Xtransceiver.png',
    ['X_ACCURACY']='assets/item_icons/named/0060_X_Accuracy.png',
    ['X_ACCURACY_2']='assets/item_icons/named/0598_X_Accuracy_2.png',
    ['X_ACCURACY_3']='assets/item_icons/named/0604_X_Accuracy_3.png',
    ['X_ACCURACY_6']='assets/item_icons/named/0610_X_Accuracy_6.png',
    ['X_ATTACK']='assets/item_icons/named/0057_X_Attack.png',
    ['X_ATTACK_2']='assets/item_icons/named/0597_X_Attack_2.png',
    ['X_ATTACK_3']='assets/item_icons/named/0603_X_Attack_3.png',
    ['X_ATTACK_6']='assets/item_icons/named/0609_X_Attack_6.png',
    ['X_DEFENSE']='assets/item_icons/named/0058_X_Defense.png',
    ['X_DEFENSE_2']='assets/item_icons/named/0596_X_Defense_2.png',
    ['X_DEFENSE_3']='assets/item_icons/named/0602_X_Defense_3.png',
    ['X_DEFENSE_6']='assets/item_icons/named/0608_X_Defense_6.png',
    ['X_SPEED']='assets/item_icons/named/0059_X_Speed.png',
    ['X_SPEED_2']='assets/item_icons/named/0593_X_Speed_2.png',
    ['X_SPEED_3']='assets/item_icons/named/0599_X_Speed_3.png',
    ['X_SPEED_6']='assets/item_icons/named/0605_X_Speed_6.png',
    ['X_SP_ATK']='assets/item_icons/named/0061_X_Sp_Atk.png',
    ['X_SP_ATK_2']='assets/item_icons/named/0594_X_Sp_Atk_2.png',
    ['X_SP_ATK_3']='assets/item_icons/named/0600_X_Sp_Atk_3.png',
    ['X_SP_ATK_6']='assets/item_icons/named/0606_X_Sp_Atk_6.png',
    ['X_SP_DEF']='assets/item_icons/named/0062_X_Sp_Def.png',
    ['X_SP_DEF_2']='assets/item_icons/named/0595_X_Sp_Def_2.png',
    ['X_SP_DEF_3']='assets/item_icons/named/0601_X_Sp_Def_3.png',
    ['X_SP_DEF_6']='assets/item_icons/named/0607_X_Sp_Def_6.png',
    ['YACHE_BERRY']='assets/item_icons/named/0188_Yache_Berry.png',
    ['YELLOW_APRICORN']='assets/item_icons/named/0487_Yellow_Apricorn.png',
    ['YELLOW_FLUTE']='assets/item_icons/named/0066_Yellow_Flute.png',
    ['YELLOW_NECTAR']='assets/item_icons/named/0854_Yellow_Nectar.png',
    ['YELLOW_SCARF']='assets/item_icons/named/0264_Yellow_Scarf.png',
    ['YELLOW_SHARD']='assets/item_icons/named/0074_Yellow_Shard.png',
    ['ZAP_PLATE']='assets/item_icons/named/0300_Zap_Plate.png',
    ['ZINC']='assets/item_icons/named/0052_Zinc.png',
    ['ZOOM_LENS']='assets/item_icons/named/0276_Zoom_Lens.png',
    ['ZYGARDE_CUBE']='assets/item_icons/named/0847_Zygarde_Cube.png',
    ['Z_RING']='assets/item_icons/named/0797_Z-Ring.png',
  }
  local itemIconCache={}
  local function itemToken(v)
    return tostring(v or ''):upper():gsub('[^A-Z0-9]+','_'):gsub('^_+',''):gsub('_+$','')
  end
  local function itemIconPath(row,def)
    local candidates={row and row.value,def and def.id,def and def.name,row and cleanLabel(row.label)}
    for _,v in ipairs(candidates) do
      local key=itemToken(v)
      local mapped=ITEM_ICON_PATH[key]
      if mapped then return mapped end
    end
  end
  local function itemIcon(row,def)
    local path=itemIconPath(row,def);if not path then return nil end
    if itemIconCache[path]~=nil then return itemIconCache[path] or nil end
    local resolved=runtime.assetPath and runtime.assetPath(path) or path
    local ok,img=pcall(runtime.assets.image,runtime.assets,resolved,'nearest')
    itemIconCache[path]=ok and img or false
    return itemIconCache[path] or nil
  end
  local function machineMoveId(def)
    if type(def)~='table' then return nil end
    if type(def.machine)=='table' and def.machine.move then return def.machine.move end
    -- Gen 2's extracted item schema exposes the same semantic relationship as
    -- `teaches` + `tmLabel`; accepting both keeps the Bag data-driven.
    return def.teaches or def.move
  end
  local function machineLabel(def)
    if type(def)~='table' then return nil end
    if type(def.tmLabel)=='string' and def.tmLabel~='' then return def.tmLabel end
    local machine=type(def.machine)=='table' and def.machine or nil
    if machine and machine.kind and machine.number then return ('%s%02d'):format(tostring(machine.kind):upper(),tonumber(machine.number) or 0) end
    local name=tostring(def.name or '')
    return name:match('^[TH]M%d%d') or name
  end
  local function machineModel(game,def)
    local moveId=machineMoveId(def);local mv=moveId and game.data.moves and game.data.moves[moveId]
    if not mv then return nil end
    local description=resolveText(game,mv.description or mv.desc or mv.summary or mv.text)
    if (not description or description=='') and runtime.Core and type(runtime.Core.moveDescription)=='function' then
      local ok,value=pcall(runtime.Core.moveDescription,mv,moveId)
      if ok and type(value)=='string' and value~='' then description=value end
    end
    return {id=moveId,move=mv,label=machineLabel(def) or 'TM / HM',description=description or 'No move description is exposed by the active data source.'}
  end
  local function itemDisplayName(game,row,def)
    local machine=machineModel(game,def)
    if machine then return machine.label..' · '..tostring(machine.move.name or machine.id):upper() end
    return tostring(def and def.name or cleanLabel(row and row.label))
  end
  local function itemDescription(game,row,def,machine)
    if machine then return machine.description end
    if runtime.ItemDescriptions and type(runtime.ItemDescriptions.resolve)=='function' then
      local ok,value=pcall(runtime.ItemDescriptions.resolve,game,row and row.value,def,resolveText)
      if ok and type(value)=='string' and value~='' then return value end
    end
    -- Unknown mod-added items should remain data-owner controlled. Keep the
    -- panel informative without pretending KRS knows an unregistered effect.
    return 'No field note is supplied by this item provider.'
  end
  local POCKET_LABEL={medicine='MEDICINE',poke_balls='POKé BALLS',battle_items='BATTLE ITEMS',berries='BERRIES',other_items='OTHER ITEMS',machines='TMs & HMs',treasures='TREASURES',key_items='KEY ITEMS'}
  local function bagModel(list)
    local s=list.__kantoPocketState;local p=s and s.pockets and s.pockets[s.pocketIndex];return s,p
  end
  local function bagList(game,state)
    if ismt(state,ListMenu) and state.__kantoPocketState then return state end
    return ancestor(game,function(v) return ismt(v,ListMenu) and v.__kantoPocketState~=nil end)
  end
  local function clearBagPointerState() runtime.nativeBagScrollbar=nil;runtime.nativeRowRects={};runtime.nativePocketRects={};runtime.nativeHoverState=nil;runtime.nativeHoverIndex=nil;runtime.nativeHoverPocketIndex=nil;runtime.nativeBagDrag=nil end
  function P.cancelBag(game,state)
    local list=bagList(game,state);if not list then return false end;local current=game and game.stack and game.stack.top and game.stack:top() or state
    if current~=list then runtime.mod.input:tap(game,'b');return true end
    clearBagPointerState();local ok,Sound=pcall(require,'src.core.Sound');if ok and Sound and game.data then Sound.play(game.data,'Press_AB') end;game.stack:pop();if list.onCancel then list.onCancel() end;return true
  end
  function P.keypressed(game,state,key) if key~='escape' and key~='a' then return false end;return P.cancelBag(game,state) end
  local function isMoveTargetList(state)
    return ismt(state,ListMenu) and tostring(state.title or state.prompt or ''):lower():find('which move',1,true)~=nil
  end
  local function isStatBox(state) return state and StatBox and getmetatable(state)==StatBox end
  local function moveLearnContext(game,state)
    if ismt(state,MoveLearnMenu) then return state end
    if ismt(state,TextBox) or ismt(state,ChoiceBox) then
      return ancestor(game,function(v) return ismt(v,MoveLearnMenu) end)
    end
    return nil
  end
  local function partyContext(game,state)
    if ismt(state,PartyMenu) then return state end
    if ismt(state,TextBox) or ismt(state,ChoiceBox) or isStatBox(state) then
      return ancestor(game,function(v) return ismt(v,PartyMenu) end)
    end
    return nil
  end
  local function battleTextContext(game,state)
    -- TextBoxes pushed directly by BattleState (including the final messages
    -- after MoveLearnMenu has popped itself) are still battle presentation.
    -- Keep the native TextBox/ChoiceBox as timing/callback owners, but never
    -- let their 160x144 chrome punch through the KRS battle surface.
    if ismt(state,TextBox) then
      local parent=below(game,state)
      if parent and getmetatable(parent)==BattleState then return state,nil end
    elseif ismt(state,ChoiceBox) then
      local text=below(game,state)
      if ismt(text,TextBox) then
        local parent=below(game,text)
        if parent and getmetatable(parent)==BattleState then return text,state end
      end
    end
    return nil,nil
  end
  local PHYSICAL_TYPE={NORMAL=true,FIGHTING=true,FLYING=true,POISON=true,GROUND=true,ROCK=true,BUG=true,GHOST=true}
  local function moveCategory(mv)
    local explicit=mv and (mv.category or mv.damageClass or mv.damage_class)
    if explicit then return tostring(explicit):upper() end
    if not mv or not tonumber(mv.power) or tonumber(mv.power)<=0 then return 'STATUS' end
    return PHYSICAL_TYPE[tostring(mv.type or ''):upper()] and 'PHYSICAL' or 'SPECIAL'
  end
  local function drawPocketSpine(game,m,c,list,x,y,w,h)
    local D=runtime.Draw;local st=bagModel(list);if not st then return end
    -- Figma canon: inverse structural spine. The active pocket is a cream
    -- Selected row; transient focus remains a turquoise outline on the dark
    -- rail so Selected and Focused never collapse into the same state.
    D.panel(m,x,y,w,h,16,c.inverse,nil)
    D.text(runtime,m,'BAG ORGANIZER',x+20,y+20,10,c.faint,{weight='bold'})
    D.text(runtime,m,'POCKETS',x+20,y+44,24,c.textInverse,{weight='bold'})
    D.text(runtime,m,('%d POCKETS'):format(#(st.pockets or {})),x+20,y+84,13,c.faint,{weight='semibold'})
    runtime.nativePocketRects={};local yy=y+128
    for i,pocket in ipairs(st.pockets or {}) do
      local r={x=x+20,y=yy,w=w-40,h=56};runtime.nativePocketRects[i]=r
      local selected=i==st.pocketIndex
      local focused=st.uiRegion=='pockets' and i==(st.focusPocketIndex or st.pocketIndex)
      local hovered=runtime.nativeHoverPocketIndex==i
      local fill=selected and c.subtle or (hovered and (c.inverseRaised or {36/255,35/255,31/255,1}) or c.inverse)
      local border=focused and c.focus or (selected and c.border or c.borderStrong)
      D.panel(m,r.x,r.y,r.w,r.h,8,fill,border)
      if focused then D.focusBorder(m,r.x,r.y,r.w,r.h,8,c.focus) end
      if selected or focused then D.roundRect(m,'fill',r.x+12,r.y+16,4,24,2,c.focus) end
      D.text(runtime,m,pocket.label,r.x+28,r.y+18,14,selected and c.text or c.textInverse,{weight='semibold'})
      D.text(runtime,m,tostring(#(pocket.items or {})),r.x+r.w-44,r.y+18,14,selected and c.text or c.faint,{weight='semibold',width=28,align='right'})
      yy=yy+64
    end
    D.text(runtime,m,'CURRENT SORT',x+20,y+h-72,10,c.faint,{weight='bold'})
    D.text(runtime,m,tostring(st.sortMode or 'type'):upper(),x+20,y+h-44,18,c.textInverse,{weight='bold'})
  end

  local function previousLevelStats(game,statBox)
    if statBox then
      for _,key in ipairs({'_krsPreviousStats','previousStats','oldStats','statsBefore'}) do if type(statBox[key])=='table' then return statBox[key] end end
    end
    local mon=statBox and statBox.mon;local level=mon and tonumber(mon.level)
    local def=mon and game and game.data and game.data.pokemon and game.data.pokemon[mon.species]
    if not(def and level and level>1) then return nil end
    local ok,Stats=pcall(require,'src.pokemon.Stats');if not ok or type(Stats.calc)~='function' then return nil end
    local okCalc,value=pcall(Stats.calc,def,level-1,mon.dvs,mon.statExp)
    return okCalc and type(value)=='table' and value or nil
  end
  local function drawLevelUpOverlay(game,m,c,statBox)
    local D=runtime.Draw;local mon=statBox.mon or {};local stats=mon.stats or {};local previous=previousLevelStats(game,statBox)
    local x,y,w,h=650,322,620,436
    D.roundRect(m,'fill',0,88,1920,928,0,{0,0,0,.56});D.panel(m,x,y,w,h,20,c.panel,c.borderStrong)
    D.text(runtime,m,'LEVEL UP',x,y+28,24,c.text,{weight='bold',width=w,align='center'})
    D.text(runtime,m,tostring(mon.nickname or mon.species or 'POKéMON'):upper()..'  ·  Lv. '..tostring(mon.level or '—'),x,y+68,14,c.textSecondary,{weight='semibold',width=w,align='center'})
    local rows={{'HP','hp'},{'ATTACK','attack'},{'DEFENSE','defense'},{'SPEED','speed'},{'SPECIAL','special'}}
    for i,row in ipairs(rows) do
      local yy=y+118+(i-1)*48;local value=stats[row[2]];local old=previous and previous[row[2]];local gain=(tonumber(value) and tonumber(old)) and math.max(0,tonumber(value)-tonumber(old)) or nil
      D.text(runtime,m,row[1],x+56,yy,14,c.textSecondary,{weight='semibold'})
      if gain then D.text(runtime,m,'+'..tostring(gain),x+w-206,yy+2,14,c.success,{weight='bold',width=70,align='right'}) end
      D.text(runtime,m,tostring(value or '—'),x+w-116,yy,18,c.text,{weight='bold',width=60,align='right'});D.line(m,x+56,yy+30,x+w-56,yy+30,c.subtle,1)
    end
    D.panel(m,x+226,y+h-52,168,28,7,c.inverse,nil);D.text(runtime,m,'ENTER / ESC',x+238,y+h-46,13,c.textInverse,{weight='bold'});D.text(runtime,m,'CLOSE',x+332,y+h-46,12,c.faint,{weight='medium'})
  end
  local function drawNativeParty(game,m,c,state,overlay)
    local party=state.party or (game.save and game.save.party) or {}
    local selected=math.max(1,math.min(#party>0 and #party or 1,tonumber(state.index) or 1))
    local inBattleAction=state.battle~=nil and state.submenu==true
    local synthetic={__kantoPartyUi=true,mode=inBattleAction and 'BattleAction' or 'PartyBrowse',party=party,
      partyFocus=selected,selectedParty=inBattleAction and selected or nil,battleMode=state.battle~=nil,
      battleActionFocus=math.max(1,math.min(3,tonumber(state.subIndex) or 1)),
      drag=nil,regions={}}
    runtime.nativePartySynthetic=synthetic
    local presenter=runtime.partyPresenter
    if presenter and type(presenter.drawState)=='function' then
      local ok=presenter:drawState(game,runtime.viewport,synthetic)
      if ok then
        if overlay and isStatBox(overlay) then
          drawLevelUpOverlay(game,m,c,overlay)
        elseif overlay and (ismt(overlay,TextBox) or ismt(overlay,ChoiceBox)) then
          local textState=ismt(overlay,TextBox) and overlay
            or ancestor(game,function(v) return ismt(v,TextBox) end)
          if textState and runtime.DialoguePanel and runtime.DialogueAdapter then
            local choice=ismt(overlay,ChoiceBox) and overlay or nil
            local model=runtime.DialogueAdapter.model(textState,choice,game)
            model.bottomMargin=88
            if model.choice then model.choice.align='right' end
            local result=runtime.DialoguePanel.draw(runtime,m,c,model)
            runtime.nativeChoiceRects=result and result.choiceRects or nil
          end
        elseif not inBattleAction then
          local D=runtime.Draw
          local label=state.tmhm and 'CHOOSE A POKÉMON FOR THIS TM / HM'
            or state.pickOnly and 'CHOOSE A POKÉMON'
            or state.battle and 'CHOOSE A POKÉMON'
            or 'PARTY'
          D.panel(m,672,900,576,72,12,c.panel,c.borderStrong)
          D.text(runtime,m,label,696,920,14,c.text,{weight='bold',width=528,align='center'})
        end
        return true
      end
    end
    return false
  end

  local function drawMoveLearn(game,m,c,state,overlay)
    local D=runtime.Draw
    local battleActive=runtime.BattlePresenter and type(runtime.BattlePresenter.handles)=='function'
      and runtime.BattlePresenter.handles(game)
    if battleActive then
      local oldSuppress=runtime.suppressBattleMessage
      runtime.suppressBattleMessage=true
      local ok,err=pcall(runtime.BattlePresenter.draw,game,runtime.viewport)
      runtime.suppressBattleMessage=oldSuppress
      if not ok then error(err,0) end
    else
      shell(game,m,c,'POKÉMON',{{id='party',label='PARTY'},{id='moves',label='MOVES'}},'moves')
      D.roundRect(m,'fill',0,88,1920,928,0,c.canvas)
    end
    if not state.selecting then
      local textState
      if ismt(overlay,TextBox) then textState=overlay
      else textState=ancestor(game,function(v) return ismt(v,TextBox) end) end
      if textState and runtime.DialoguePanel and runtime.DialogueAdapter then
        local choice=ismt(overlay,ChoiceBox) and overlay or nil
        local model=runtime.DialogueAdapter.model(textState,choice,game)
        model.bottomMargin=88
        if model.choice then model.choice.align='right' end
        local result=runtime.DialoguePanel.draw(runtime,m,c,model)
        runtime.nativeChoiceRects=result and result.choiceRects or nil
      end
      return true
    end
    D.roundRect(m,'fill',0,88,1920,928,0,{0,0,0,.34})
    local x,y,w,h=560,214,800,650;D.panel(m,x,y,w,h,18,c.panel,c.borderStrong)
    local mon=state.mon;local def=mon and game.data.pokemon and game.data.pokemon[mon.species]
    local monName=tostring(mon and (mon.nickname or (def and def.name) or mon.species) or 'POKÉMON')
    local newDef=game.data.moves and game.data.moves[state.newMoveId]
    D.text(runtime,m,'LEARN A MOVE',x+32,y+28,11,c.textSecondary,{weight='bold'})
    D.text(runtime,m,monName:upper(),x+32,y+58,28,c.text,{weight='bold'})
    D.text(runtime,m,'Choose the move to replace with '..tostring(newDef and newDef.name or state.newMoveId)..'.',x+32,y+100,14,c.textSecondary,{width=w-64})
    runtime.nativeMoveLearnRects={}
    local yy=y+152
    for i=1,4 do
      local mv=mon and mon.moves and mon.moves[i];local md=mv and game.data.moves and game.data.moves[mv.id]
      local r={x=x+32,y=yy+(i-1)*82,w=w-64,h=68};runtime.nativeMoveLearnRects[i]=r
      focusRect(m,c,r,state.index==i,false)
      D.text(runtime,m,tostring(md and md.name or mv and mv.id or '—'),r.x+20,r.y+17,16,c.text,{weight='bold',width=360})
      local pp=mv and mv.pp or 0;local max=md and md.pp or pp
      D.text(runtime,m,('PP %d / %d'):format(pp,max),r.x+r.w-180,r.y+20,13,c.textSecondary,{weight='semibold',width=150,align='right'})
    end
    local cancel={x=x+32,y=yy+4*82,w=w-64,h=58};runtime.nativeMoveLearnRects[5]=cancel
    focusRect(m,c,cancel,state.index==5,false);D.text(runtime,m,'KEEP CURRENT MOVES',cancel.x+20,cancel.y+18,14,c.text,{weight='bold',width=cancel.w-40,align='center'})
    footer(m,c,{{'UP/DOWN','MOVE'},{'ENTER','REPLACE'},{'A','CANCEL'}})
    return true
  end

  local function drawBattleTextOverlay(game,m,c,textState,choice)
    if not textState then return false end
    local oldSuppress=runtime.suppressBattleMessage
    runtime.suppressBattleMessage=true
    local ok,err=pcall(runtime.BattlePresenter.draw,game,runtime.viewport)
    runtime.suppressBattleMessage=oldSuppress
    if not ok then error(err,0) end
    if runtime.DialoguePanel and runtime.DialogueAdapter then
      local model=runtime.DialogueAdapter.model(textState,choice,game)
      model.bottomMargin=88
      if model.choice then model.choice.align='right' end
      local result=runtime.DialoguePanel.draw(runtime,m,c,model)
      runtime.nativeChoiceRects=result and result.choiceRects or nil
    end
    return true
  end

  local function drawBagOverlay(game,m,c,overlay)
    local D=runtime.Draw;if not overlay then runtime.nativeMenuRects=nil;runtime.nativeChoiceRects=nil;return end
    if isStatBox(overlay) then drawLevelUpOverlay(game,m,c,overlay);return end
    D.roundRect(m,'fill',0,88,1920,928,0,{0,0,0,.34})
    local x,y,w=1228,650,580
    if ismt(overlay,Menu) then
      local items=overlay.items or {};local h=104+#items*62
      D.panel(m,x,y-h+260,w,h,16,c.panel,c.borderStrong);local yy=y-h+292
      D.text(runtime,m,overlay.__kantoBagSortMenu and 'SORT ITEMS' or 'ITEM ACTION',x+24,y-h+278,10,c.textSecondary,{weight='bold'})
      runtime.nativeMenuRects={}
      for i,it in ipairs(items) do local r={x=x+24,y=yy+(i-1)*62,w=w-48,h=52};runtime.nativeMenuRects[i]=r;focusRect(m,c,r,overlay.index==i,false);D.text(runtime,m,cleanLabel(it.label),r.x+18,r.y+16,14,c.text,{weight='semibold'}) end
    elseif ismt(overlay,QuantityBox) then
      local h=190;D.panel(m,x,y-h+260,w,h,16,c.panel,c.borderStrong);D.text(runtime,m,'QUANTITY',x+28,y-h+288,10,c.textSecondary,{weight='bold'});D.text(runtime,m,tostring(overlay.qty or 1),x+28,y-h+330,32,c.text,{weight='bold'});D.text(runtime,m,'← / →  CHANGE     ENTER  CONFIRM',x+28,y-h+392,12,c.textSecondary,{weight='semibold'})
    elseif ismt(overlay,TextBox) then
      if runtime.DialoguePanel and runtime.DialogueAdapter then
        local model=runtime.DialogueAdapter.model(overlay,nil,game);model.bottomMargin=88
        runtime.DialoguePanel.draw(runtime,m,c,model)
      end
    elseif ismt(overlay,ChoiceBox) then
      local textState=ancestor(game,function(v) return ismt(v,TextBox) end)
      if textState and runtime.DialoguePanel and runtime.DialogueAdapter then
        local model=runtime.DialogueAdapter.model(textState,overlay,game);model.bottomMargin=88
        if model.choice then model.choice.align='right' end
        local result=runtime.DialoguePanel.draw(runtime,m,c,model);runtime.nativeChoiceRects=result and result.choiceRects or nil
      else
        local h=218;D.panel(m,x,y-h+260,w,h,16,c.panel,c.borderStrong);D.text(runtime,m,'CONFIRM',x+28,y-h+288,10,c.textSecondary,{weight='bold'});D.text(runtime,m,'Are you sure?',x+28,y-h+326,20,c.text,{weight='bold'});runtime.nativeChoiceRects={}
        local labels={'YES','NO'};for i=1,2 do local r={x=x+28+(i-1)*260,y=y-h+382,w=236,h=58};runtime.nativeChoiceRects[i]=r;focusRect(m,c,r,overlay.index==i,false);D.text(runtime,m,labels[i],r.x,r.y+19,14,c.text,{weight='bold',width=r.w,align='center'}) end
      end
    elseif isMoveTargetList(overlay) then
      local items=overlay.items or {};local h=150+#items*66;local oy=y-h+260
      D.panel(m,x,oy,w,h,16,c.panel,c.borderStrong);D.text(runtime,m,'CHOOSE A MOVE',x+28,oy+24,11,c.textSecondary,{weight='bold'})
      runtime.nativeMenuRects={};local yy=oy+58
      for i,row in ipairs(items) do local r={x=x+28,y=yy+(i-1)*66,w=w-56,h=56};runtime.nativeMenuRects[i]=r;focusRect(m,c,r,overlay.index==i,false);D.text(runtime,m,cleanLabel(row.label),r.x+18,r.y+18,14,c.text,{weight='bold',width=r.w-160});D.text(runtime,m,tostring(row.right or ''),r.x+r.w-122,r.y+18,13,c.textSecondary,{weight='semibold',width=96,align='right'}) end
    end
  end

  local function drawBagHeader(game,m,c,st)
    local D=runtime.Draw
    D.roundRect(m,'fill',0,0,1920,1080,0,c.canvas)
    D.roundRect(m,'fill',0,0,1920,88,0,c.inverse)
    D.text(runtime,m,'KANTO JOURNAL',32,18,24,c.textInverse,{weight='bold'})
    D.text(runtime,m,'START MENU',32,54,11,c.textInverse,{weight='bold',alpha=.72})
    local pockets=st and st.pockets or {};local parentW,itemW,gap=140,124,8
    local inner=parentW+1+#pockets*itemW+(#pockets+1)*gap;local x=960-inner/2
    D.text(runtime,m,'← BAG',x,34,14,c.textInverse,{weight='semibold',width=parentW,align='center',alpha=.88})
    x=x+parentW+gap;D.roundRect(m,'fill',x,32,1,24,0,c.textInverse);x=x+1+gap
    runtime.nativePocketRects={};local accent=c.headerAccent or c.focus
    for i,pocket in ipairs(pockets) do
      local r={x=x,y=24,w=itemW,h=40};runtime.nativePocketRects[i]=r
      local selected=i==(st.pocketIndex or 1);local hovered=runtime.nativeHoverPocketIndex==i
      local focused=st and st.uiRegion=='pockets' and i==(st.focusPocketIndex or st.pocketIndex or 1)
      if focused then D.roundRect(m,'line',r.x+1,r.y+1,r.w-2,r.h-2,8,c.headerFocus or c.textInverse or c.focus,2) end
      D.text(runtime,m,tostring(pocket.label or pocket.id):upper(),r.x,r.y+10,13,c.textInverse,{weight='semibold',width=r.w,align='center',alpha=selected and 1 or .72})
      if selected then D.roundRect(m,'fill',r.x+14,r.y+37,96,3,1.5,accent)
      elseif hovered then D.roundRect(m,'fill',r.x+14,r.y+39,96,1,.5,accent) end
      x=x+itemW+gap
    end
    local jc=type(runtime.Core.journalContext)=='function' and runtime.Core.journalContext() or {}
    D.text(runtime,m,tostring(jc.location or 'KANTO'):gsub('_',' '):upper(),1570,20,14,c.textInverse,{weight='semibold',width=318,align='right'})
    local sec=math.floor(tonumber(jc.playTime) or 0);local world=tostring(jc.worldTime or ((runtime.worldTimeLabel and runtime.worldTimeLabel(game,sec)) or ('%02d:%02d • DAY'):format(math.floor(sec/3600),math.floor(sec/60)%60)))
    D.text(runtime,m,world,1570,46,12,c.textInverse,{weight='medium',width=318,align='right',alpha=.76})
    D.roundRect(m,'fill',0,1016,1920,64,0,c.inverse)
  end

  local function drawBagFooter(m,c,battle)
    local D=runtime.Draw
    local prompts=battle and {{'↑↓','ITEMS'},{'←→','POCKET'},{'ENTER','USE'},{'A','BACK'}} or {{'↑↓','ITEMS'},{'←→','POCKET'},{'TAB','SORT'},{'F','FAVORITE'},{'ENTER','USE'},{'A','BACK'}}
    local x=32
    for _,p in ipairs(prompts) do
      D.text(runtime,m,p[1],x,1037,12,c.textInverse,{weight='bold'})
      D.text(runtime,m,p[2],x+48,1038,11,c.textInverse,{alpha=.72})
      x=x+148
    end
    if not battle then D.text(runtime,m,'R',920,1037,12,c.textInverse,{weight='bold'});D.text(runtime,m,'REGISTER',940,1038,11,c.textInverse,{alpha=.72}) end
    D.text(runtime,m,'KEYBOARD + MOUSE',1640,1038,12,c.textInverse,{weight='semibold',width=248,align='right'})
  end

  local function drawBag(game,m,c,list,overlay)
    local D=runtime.Draw;local st,pocket=bagModel(list);local pocketLabel=pocket and pocket.label or 'BAG'
    drawBagHeader(game,m,c,st)

    local lx,ly,lw,lh=64,120,924,856
    D.panel(m,lx,ly,lw,lh,16,c.panel,c.border)
    D.text(runtime,m,pocketLabel..' POCKET',lx+20,ly+22,11,c.textSecondary,{weight='bold'})
    D.text(runtime,m,'ITEM LEDGER',lx+20,ly+50,32,c.text,{weight='bold'})
    local itemCount=#(list.items or {})
    D.text(runtime,m,('%d ITEMS  •  SORT: %s'):format(itemCount,tostring(st and st.sortMode or 'type'):upper()),lx+20,ly+94,14,c.textSecondary,{weight='semibold'})

    runtime.nativeRowRects={};local visible=10;list.rows=visible
    local maxScroll=math.max(0,itemCount-visible);list.scroll=math.max(0,math.min(maxScroll,list.scroll or 0));local first=(list.scroll or 0)+1;local yy=ly+132
    for slot=1,visible do
      local i=first+slot-1;local row=list.items and list.items[i];if not row then break end
      local r={x=lx+21,y=yy+5,w=862,h=64};runtime.nativeRowRects[i]=r;local focused=st and st.uiRegion=='items' and i==list.index;local hovered=runtime.nativeHoverIndex==i
      local bagFocus=c.bagFocus or c.focus
      -- Figma Item Row: default/hover remain one-pixel rows, while Focused is
      -- a 3 px structural outline plus the 4 x 24 px state indicator.
      D.roundRect(m,'fill',r.x,r.y,r.w,r.h,10,(hovered and not focused) and c.subtle or c.panel)
      D.roundRect(m,'line',r.x+.5,r.y+.5,r.w-1,r.h-1,10,(focused or hovered) and bagFocus or c.border,focused and 3 or 1)
      if focused then D.roundRect(m,'fill',r.x+12,r.y+20,4,24,0,bagFocus) end
      local def=itemDef(game,row);local fav=row.favorite or tostring(row.label):sub(1,2)=='* ';local icon=itemIcon(row,def)
      -- Figma Item Row: 40x40 slot at +28/+12; the true-colour 32x32 asset
      -- sits at +32/+16 (4 px inset). Assets are never recoloured.
      if icon then drawImage(m,icon,r.x+32,r.y+16,32,32) end
      D.clipText(runtime,m,itemDisplayName(game,row,def),r.x+80,r.y+21,r.w-218,14,c.text,{weight='semibold'})
      local qty=tostring(row.right or (row.value and game.save.inventory[row.value] and ('×'..game.save.inventory[row.value])) or '')
      -- Favorite is additive: it never replaces the owned quantity. Figma uses
      -- the literal canonical star glyph, not a procedurally-drawn polygon.
      if fav then D.text(runtime,m,'★',r.x+r.w-146,r.y+20,18,c.text,{weight='bold',width=24,align='center'}) end
      D.text(runtime,m,qty,r.x+r.w-112,r.y+22,14,c.textSecondary,{weight='semibold',width=92,align='right'})
      yy=yy+72
    end
    runtime.nativeBagScrollbar=nil
    if itemCount>visible then
      local track={x=960,y=200,w=8,h=760};local ratio=visible/itemCount;local th=math.max(72,track.h*ratio);local travel=track.h-th;local ty=track.y+(list.scroll/maxScroll)*travel
      runtime.nativeBagScrollbar={track=track,thumb={x=track.x,y=ty,w=track.w,h=th},hit={x=track.x-18,y=ty,w=44,h=math.max(44,th)},travel=travel,maxScroll=maxScroll}
      D.roundRect(m,'fill',track.x,track.y,track.w,track.h,4,c.border);D.roundRect(m,'fill',track.x,ty,track.w,th,4,c.bagFocus or c.focus)
    end

    local dx,dy,dw,dh=1012,120,844,856
    -- Figma uses an editorial divider instead of a second bordered card.
    D.line(m,dx,dy,dx,dy+dh,c.borderStrong,1)
    D.text(runtime,m,'SELECTED ITEM',dx+32,dy+24,11,c.textSecondary,{weight='bold'})
    local row=list.items and list.items[list.index];local def=itemDef(game,row)
    if row then
      local machine=machineModel(game,def);local name=itemDisplayName(game,row,def)
      D.text(runtime,m,name,dx+32,dy+56,48,c.text,{weight='bold',width=680})
      local owned=tostring(row.right or (row.value and game.save.inventory[row.value] and ('×'..game.save.inventory[row.value])) or '')
      if owned~='' then D.text(runtime,m,owned,dx+704,dy+66,14,c.textSecondary,{weight='semibold',width=108,align='right'}) end
      local pId=pocket and pocket.id or row.pocket
      local meta=(POCKET_LABEL[pId] or pocketLabel)..((not st.battle and row.favorite) and '  •  ★ FAVORITE' or '')
      D.text(runtime,m,meta,dx+32,dy+124,14,c.textSecondary,{weight='semibold',width=620})

      -- Canonical Selected Item Context exposes a 160x160 Sprite Container at
      -- x=1354/y=300. It has no decorative card of its own.
      local icon=itemIcon(row,def)
      if icon then drawImage(m,icon,dx+342,dy+180,160,160) end
      local description=itemDescription(game,row,def,machine)
      D.text(runtime,m,description,dx+32,dy+370,16,c.text,{width=780,align='center'})
      if machine and machine.move then
        local mv=machine.move
        D.text(runtime,m,'MOVE',dx+32,dy+424,11,c.textSecondary,{weight='bold',width=780,align='center'})
        D.text(runtime,m,tostring(mv.name or machine.id):upper(),dx+32,dy+448,14,c.text,{weight='semibold',width=780,align='center'})
        local power=tonumber(mv.power);local accuracy=tonumber(mv.accuracy)
        local stats={{'POWER',power and power>0 and power or '—'},{'ACCURACY',accuracy and accuracy>0 and (accuracy..'%') or '—'},{'PP',mv.pp or '—'},{'TYPE',tostring(mv.type or '—'):gsub('_TYPE$',''):upper()}}
        local sy=dy+486
        for i,v in ipairs(stats) do local xx=dx+90+(i-1)*178;D.text(runtime,m,v[1],xx,sy,9,c.textSecondary,{weight='bold',width=120,align='center'});D.text(runtime,m,tostring(v[2]),xx,sy+22,13,c.text,{weight='semibold',width=120,align='center'}) end
      elseif def and (def.effect or def.heal or def.power) then
        D.text(runtime,m,'EFFECT',dx+32,dy+420,11,c.textSecondary,{weight='bold',width=780,align='center'})
        D.text(runtime,m,tostring(def.effect or def.heal or def.power),dx+32,dy+444,14,c.text,{width=780,align='center'})
      end
      if not st.battle then D.text(runtime,m,'F',dx+dw-236,dy+806,13,c.text,{weight='bold'});D.text(runtime,m,'TOGGLE FAVORITE',dx+dw-216,dy+806,13,c.textSecondary,{weight='semibold'}) end
    else
      D.text(runtime,m,'THIS POCKET IS EMPTY',dx+32,dy+98,18,c.textSecondary,{weight='semibold'})
    end
    drawBagFooter(m,c,st and st.battle)
    drawBagOverlay(game,m,c,overlay)
    return true
  end
  local function listParent(game,state) return below(game,state) end
  local function shopList(game)
    return ancestor(game,function(s)return ismt(s,ListMenu) and (s.kind=='shop_buy' or s.kind=='shop_sell' or s.title=='BUY' or s.title=='SELL') end)
  end
  local function isShopRoot(state)
    if not ismt(state,Menu) then return false end
    local buy,sell,quit=false,false,false
    for _,it in ipairs(state.items or {}) do
      local label=tostring(it.label or ''):upper()
      if label=='BUY' then buy=true elseif label=='SELL' then sell=true elseif label=='QUIT' then quit=true end
    end
    return buy and sell and quit
  end
  local function drawShopRoot(game,m,c,state)
    local D=runtime.Draw
    shell(game,m,c,'SHOP',{{id='buy',label='BUY'},{id='sell',label='SELL'}},'buy')
    D.panel(m,420,190,1080,650,18,c.panel,c.border)
    D.text(runtime,m,'POKÉ MART',468,238,12,c.textSecondary,{weight='bold'})
    D.text(runtime,m,'HOW CAN I HELP?',468,278,32,c.text,{weight='bold'})
    D.text(runtime,m,'Choose a service.',468,326,15,c.textSecondary,{width=520})
    runtime.nativeRowRects={};runtime.nativeMenuRects={}
    local labels={BUY='Browse the shop inventory.',SELL='Sell items from your Bag.',QUIT='Return to your journey.'}
    for i,it in ipairs(state.items or {}) do
      local r={x=468,y=390+(i-1)*116,w=984,h=88};runtime.nativeRowRects[i]=r;runtime.nativeMenuRects[i]=r
      focusRect(m,c,r,i==state.index,false)
      local label=tostring(it.label or ''):upper()
      D.text(runtime,m,label,r.x+24,r.y+18,18,c.text,{weight='bold'})
      D.text(runtime,m,labels[label] or '',r.x+24,r.y+48,12,c.textSecondary)
    end
    footer(m,c,{{'UP/DOWN','SELECT'},{'ENTER','OPEN'},{'A','BACK'}})
    return true
  end
  local function pcBoxList(game)
    return ancestor(game,function(s) return ismt(s,ListMenu) and tostring(s.kind or ''):find('pc_box_',1,true)~=nil end)
  end
  local function drawShop(game,m,c,state)
    local list=ismt(state,ListMenu) and state or shopList(game);if not list then return false end;local selling=(list.kind=='shop_sell' or list.title=='SELL');local D=runtime.Draw
    shell(game,m,c,'SHOP',{{id='buy',label='BUY'},{id='sell',label='SELL'}},selling and 'sell' or 'buy')
    local bagState=selling and list.__kantoPocketState
    local leftX=64
    if bagState then drawPocketSpine(game,m,c,list,leftX,120,280,856);leftX=368 end
    local lw=bagState and 620 or 820;D.panel(m,leftX,120,lw,856,16,c.panel,c.border);D.text(runtime,m,selling and 'BAG INVENTORY' or 'STORE INVENTORY',leftX+24,144,10,c.textSecondary,{weight='bold'});D.text(runtime,m,selling and 'SELL' or 'BUY',leftX+24,176,28,c.text,{weight='bold'})
    if selling and bagState then local _,p=bagModel(list);D.text(runtime,m,(p and p.label or 'POCKET')..' • SORT: '..tostring(bagState.sortMode or 'type'):upper(),leftX+24,214,11,c.textSecondary,{weight='bold'}) end
    local startY=selling and 246 or 224;runtime.nativeRowRects={};local visible=8;local first=math.max(1,(list.index or 1)-3);first=math.min(first,math.max(1,#list.items-visible+1));for slot=1,visible do local i=first+slot-1;local row=list.items[i];if not row then break end;local r={x=leftX+24,y=startY+(slot-1)*76,w=lw-48,h=64};runtime.nativeRowRects[i]=r;focusRect(m,c,r,i==list.index,false);local def=itemDef(game,row);local icon=itemIcon(row,def);local nameX=r.x+44;if icon then local iw,ih=icon:getDimensions();local k=40/math.max(iw,ih);love.graphics.setColor(1,1,1,1);love.graphics.draw(icon,m.ox+(r.x+12)*m.scale,m.oy+(r.y+12)*m.scale,0,k*m.scale,k*m.scale);nameX=r.x+64 end;D.text(runtime,m,(row.favorite and '★' or ''),r.x+16,r.y+22,13,c.text);D.text(runtime,m,tostring(def and def.name or row.label),nameX,r.y+20,15,c.text,{weight='semibold'});local val=selling and (row.right or '') or row.right or '';D.text(runtime,m,val,r.x+r.w-130,r.y+20,14,c.text,{weight='semibold',width=110,align='right'}) end
    local rx=bagState and 1012 or 912;local rw=1920-rx-64;D.text(runtime,m,'TRANSACTION',rx,136,10,c.textSecondary,{weight='bold'});D.panel(m,rx,176,rw,150,16,c.inverse,nil);D.text(runtime,m,'CURRENT FUNDS',rx+24,198,10,c.faint,{weight='bold'});drawMoney(m,game.save.money or 0,rx+24,232,32,c.textInverse,{weight='bold'})
    local row=list.items[list.index];local def=itemDef(game,row);if row and def then local unit=selling and math.floor((tonumber(def.price) or 0)/2) or tonumber(def.price) or 0;local qty=1;local overlay=game.stack:top();if ismt(overlay,QuantityBox) then qty=overlay.qty or 1 end;local machine=machineModel(game,def);D.text(runtime,m,itemDisplayName(game,row,def),rx,360,30,c.text,{weight='bold'});D.line(m,rx,408,rx+rw,408,c.border,1);local labels=selling and {{'BUYBACK',unit},{'QUANTITY',qty},{'RECEIVE',unit*qty},{'BALANCE AFTER',(game.save.money or 0)+unit*qty}} or {{'UNIT',unit},{'QUANTITY',qty},{'TOTAL',unit*qty},{'BALANCE AFTER',(game.save.money or 0)-unit*qty}};for i,v in ipairs(labels) do local yy=442+(i-1)*56;D.text(runtime,m,v[1],rx,yy,10,c.textSecondary,{weight='bold'});if i==2 then D.text(runtime,m,tostring(v[2]),rx+190,yy-4,19,c.text,{weight='bold'}) else drawMoney(m,v[2],rx+190,yy-4,19,c.text,{weight='bold'}) end end
      D.text(runtime,m,'FIELD NOTE',rx,674,10,c.textSecondary,{weight='bold'});D.text(runtime,m,itemDescription(game,row,def,machine),rx,704,14,c.text,{width=rw})
      if ismt(overlay,QuantityBox) then
        D.panel(m,rx,860,rw,72,12,c.inverse,nil);D.text(runtime,m,'−',rx+28,883,20,c.textInverse,{weight='bold'});D.text(runtime,m,tostring(overlay.qty),rx,878,26,c.textInverse,{weight='bold',width=rw,align='center'});D.text(runtime,m,'+',rx+rw-52,883,20,c.textInverse,{weight='bold'})
      elseif ismt(overlay,ChoiceBox) then
        -- Native ChoiceBox still owns hold timing and transaction callbacks;
        -- only its Game Boy chrome is replaced by this themed KRS surface.
        local cy,ch=812,144;D.panel(m,rx,cy,rw,ch,12,c.panel,c.borderStrong)
        D.text(runtime,m,selling and 'CONFIRM SALE?' or 'CONFIRM PURCHASE?',rx+22,cy+18,13,c.textSecondary,{weight='bold'})
        D.text(runtime,m,overlay.pending~=nil and 'Processing…' or 'Complete this transaction?',rx+22,cy+44,14,c.text,{weight='semibold',width=rw-44})
        runtime.nativeChoiceRects={}
        local labels={'YES','NO'};local gap=12;local bw=(rw-44-gap)/2
        for i,label in ipairs(labels) do
          local r={x=rx+22+(i-1)*(bw+gap),y=cy+82,w=bw,h=44};runtime.nativeChoiceRects[i]=r
          focusRect(m,c,r,(overlay.index or 1)==i,false)
          D.text(runtime,m,label,r.x,r.y+14,12,c.text,{weight='bold',width=r.w,align='center'})
        end
      else runtime.nativeChoiceRects=nil end
    end
    local activeOverlay=game.stack:top()
    if ismt(activeOverlay,ChoiceBox) then
      footer(m,c,{{'UP/DOWN','CHOICE'},{'ENTER','CONFIRM'},{'A','CANCEL'}})
    elseif selling and bagState and bagState.uiRegion=='pockets' then
      footer(m,c,{{'UP/DOWN','POCKET'},{'ENTER','OPEN'},{'A','BACK'}})
    elseif selling and bagState then
      footer(m,c,{{'UP/DOWN','ITEMS'},{'LEFT','POCKETS'},{'TAB','SORT'},{'F','FAVORITE'},{'ENTER','SELECT'},{'A','BACK'}})
    else
      footer(m,c,{{'UP/DOWN','ITEMS'},{'ENTER','SELECT'},{'A','BACK'}})
    end
    return true
  end
  local function isBillRoot(state)
    if not ismt(state,Menu) then return false end
    local hasWithdraw,hasDeposit,hasRelease,hasChange=false,false,false,false
    for _,it in ipairs(state.items or {}) do
      local label=tostring(it.label or ''):upper()
      if label:find('WITHDRAW',1,true) then hasWithdraw=true end
      if label:find('DEPOSIT',1,true) then hasDeposit=true end
      if label:find('RELEASE',1,true) then hasRelease=true end
      if label:find('CHANGE BOX',1,true) then hasChange=true end
    end
    return hasWithdraw and hasDeposit and hasRelease and hasChange
  end
  local function isPlayerRoot(state)
    if not ismt(state,Menu) then return false end;local text='';for _,it in ipairs(state.items or {})do text=text..' '..tostring(it.label or ''):upper() end;return text:find('WITHDRAW ITEM',1,true) and text:find('DEPOSIT ITEM',1,true)
  end
  function P.pcRootKind(state)
    if isBillRoot(state) then return 'bill' end
    if isPlayerRoot(state) then return 'player' end
    return nil
  end
  function P.switchPC(game,target)
    local top=game and game.stack and game.stack:top();local current=P.pcRootKind(top)
    if not current then return false end
    if target=='oak' then
      local flags=game.save and game.save.flags or {}
      if not flags.EVENT_GOT_POKEDEX then return false,'oak_locked' end
      if game.stack:top()==top then game.stack:pop() end
      local ow=game.overworld
      if ow and type(ow.openOaksPC)=='function' then
        local Screens=require('src.ui.Screens')
        ow:openOaksPC(function() Screens.push(game,'BoxMenu') end)
        return true
      end
      return false,'oak_unavailable'
    end
    if target==current then return true end
    local Screens=require('src.ui.Screens')
    if game.stack:top()==top then game.stack:pop() end
    if target=='bill' then Screens.push(game,'BoxMenu');return true end
    if target=='player' then Screens.push(game,'PlayerPC');return true end
    return false,'unknown_service'
  end
  function P.cyclePC(game,dir)
    local current=P.pcRootKind(game and game.stack and game.stack:top());if not current then return false end
    local flags=game.save and game.save.flags or {};local order={'bill','player'};if flags.EVENT_GOT_POKEDEX then order[#order+1]='oak' end
    local idx=1;for i,v in ipairs(order) do if v==current then idx=i break end end
    idx=((idx-1+(dir or 1))%#order)+1;return P.switchPC(game,order[idx])
  end
  local function drawStoredCells(game,m,c,box,x,y,w,focusedIndex)
    local D=runtime.Draw;runtime.nativeRowRects={};local cols=5;local cellW=(w-32)/cols;local visible=30;local first=math.max(1,(focusedIndex or 1)-10);first=math.min(first,math.max(1,#box-visible+1));for slot=1,math.min(visible,#box-first+1) do local i=first+slot-1;local mon=box[i];local col=(slot-1)%cols;local row=math.floor((slot-1)/cols);local r={x=x+col*(cellW+8),y=y+row*96,w=cellW,h=86};runtime.nativeRowRects[i]=r;local foc=i==focusedIndex;if foc then focusRect(m,c,r,true,false) end;D.text(runtime,m,('%03d'):format(i),r.x+10,r.y+8,9,c.textSecondary,{weight='bold'});D.text(runtime,m,pokemonName(game,mon),r.x+10,r.y+34,12,c.text,{weight='semibold',width=r.w-20});D.text(runtime,m,'Lv. '..tostring(mon.level or '—'),r.x+10,r.y+57,10,c.textSecondary) end
  end
  local function drawBill(game,m,c,state)
    local D=runtime.Draw;local boxes=Boxes.ensure(game.save);local current=math.max(1,math.min(Boxes.COUNT,game.save.currentBox or 1));local box=boxes[current] or {};shell(game,m,c,'PC',{{id='pc',label='PC'},{id='bill',label="BILL'S PC"},{id='player',label="PLAYER'S PC"},{id='oak',label="OAK'S PC"}},'bill')
    if isBillRoot(state) then
      D.text(runtime,m,'POKÉMON STORAGE SYSTEM',64,124,10,c.textSecondary,{weight='bold'});D.text(runtime,m,"BILL'S PC",64,154,28,c.text,{weight='bold'});D.text(runtime,m,(Boxes.COUNT..' BOXES • '..tostring((function()local n=0;for i=1,Boxes.COUNT do n=n+#(boxes[i] or {}) end;return n end)())..' / '..(Boxes.COUNT*Boxes.CAPACITY)),1450,160,12,c.textSecondary,{weight='semibold',width=406,align='right'})
      local bx,by,bw=64,208,1400;D.panel(m,bx,by,bw,332,16,c.panel,c.border);D.text(runtime,m,'BOX BANK',bx+24,by+24,18,c.text,{weight='bold'});runtime.nativeBoxRects={};local cw=(bw-64-4*12)/5;for i=1,Boxes.COUNT do local col=(i-1)%5;local row=math.floor((i-1)/5);local r={x=bx+24+col*(cw+12),y=by+70+row*58,w=cw,h=48};runtime.nativeBoxRects[i]=r;focusRect(m,c,r,i==current,false);D.text(runtime,m,('BOX %02d'):format(i),r.x+14,r.y+16,11,c.text,{weight='semibold'});D.text(runtime,m,('%d / %d'):format(#(boxes[i] or {}),Boxes.CAPACITY),r.x+r.w-94,r.y+16,10,c.textSecondary,{width=80,align='right'}) end
      D.panel(m,1490,208,366,332,16,c.panel,c.border);D.text(runtime,m,'STORAGE ACTIONS',1514,232,18,c.text,{weight='bold'});runtime.nativeMenuRects={};for i,it in ipairs(state.items or {}) do if i<=4 then local r={x=1514,y=276+(i-1)*62,w=318,h=52};runtime.nativeMenuRects[i]=r;focusRect(m,c,r,i==state.index,false);D.text(runtime,m,tostring(it.label),r.x+14,r.y+18,12,c.text,{weight='semibold'}) end end
      D.text(runtime,m,('CURRENT BOX %02d'):format(current),64,584,10,c.textSecondary,{weight='bold'});D.text(runtime,m,'STORED POKÉMON',64,612,23,c.text,{weight='bold'});drawStoredCells(game,m,c,box,64,664,1400,nil);D.panel(m,64,896,1792,72,12,c.panel,c.border);D.text(runtime,m,('BOX %02d'):format(current),88,914,12,c.text,{weight='bold'});D.text(runtime,m,('%d / %d'):format(#box,Boxes.CAPACITY),88,938,24,c.text,{weight='bold'});D.text(runtime,m,('%d SLOTS AVAILABLE'):format(Boxes.CAPACITY-#box),300,934,11,c.textSecondary,{weight='semibold'})
      footer(m,c,{{'ARROWS','NAVIGATE'},{'ENTER','OPEN'},{'A','BACK'}});return true
    end
    if ismt(state,ListMenu) and tostring(state.kind):find('pc_box_',1,true) then
      local action=tostring(state.kind):gsub('pc_box_',''):upper();D.panel(m,64,120,900,856,16,c.panel,c.border);D.text(runtime,m,('CURRENT BOX %02d'):format(current),88,144,10,c.textSecondary,{weight='bold'});D.text(runtime,m,action..' POKÉMON',88,176,26,c.text,{weight='bold'});local source=state.kind=='pc_box_deposit' and game.save.party or box;drawStoredCells(game,m,c,source,88,238,828,state.index)
      D.panel(m,988,120,868,856,16,c.panel,c.border);local mon=source[state.index];if mon then local name=pokemonName(game,mon);local art=cacheImage(game,mon.species,'front','native_pc',mon);if art then local ax,ay,aw,ah=drawImage(m,art.image,1128,184,300,300);runtime.PokemonArt.mark(art,ax,ay,aw,ah) end;D.text(runtime,m,name,1320,224,30,c.text,{weight='bold'});D.text(runtime,m,'Lv. '..tostring(mon.level or '—'),1320,272,16,c.textSecondary,{weight='semibold'});D.text(runtime,m,('BOX %02d • ENTRY %03d'):format(current,state.index),1320,330,11,c.textSecondary,{weight='bold'});D.line(m,1016,448,1828,448,c.border,1);D.text(runtime,m,'POKÉMON ACTIONS',1016,480,17,c.text,{weight='bold'});local primary=action=='WITHDRAW' and 'WITHDRAW' or action=='DEPOSIT' and 'DEPOSIT' or action=='RELEASE' and 'RELEASE' or 'SELECT';D.panel(m,1016,526,812,68,10,c.subtle,c.focus);D.text(runtime,m,primary,1032,544,15,c.text,{weight='bold'});D.text(runtime,m,'ENTER  CONFIRM',1032,568,10,c.textSecondary,{weight='semibold'});D.text(runtime,m,'STATS',1032,624,14,c.text,{weight='semibold'});D.text(runtime,m,'Open Pokémon Summary.',1032,648,11,c.textSecondary);D.text(runtime,m,'CANCEL',1032,696,14,c.text,{weight='semibold'}) end
      footer(m,c,{{'ARROWS','MOVE'},{'ENTER','ACTIONS'},{'A','BACK'}});return true
    end
    return false
  end
  local function drawPlayerPC(game,m,c,state)
    local D=runtime.Draw;shell(game,m,c,'PC',{{id='pc',label='PC'},{id='bill',label="BILL'S PC"},{id='player',label="PLAYER'S PC"},{id='oak',label="OAK'S PC"}},'player')
    if isPlayerRoot(state) then
      D.panel(m,64,120,1792,856,16,c.panel,c.border)
      D.text(runtime,m,'PLAYER ITEM STORAGE',88,148,10,c.textSecondary,{weight='bold'})
      D.text(runtime,m,"PLAYER'S PC",88,180,28,c.text,{weight='bold'})
      runtime.nativeMenuRects={}
      for i,it in ipairs(state.items or {}) do
        local r={x=88,y=248+(i-1)*76,w=760,h=64};runtime.nativeMenuRects[i]=r
        focusRect(m,c,r,i==state.index,false)
        D.text(runtime,m,tostring(it.label),r.x+18,r.y+22,15,c.text,{weight='semibold'})
      end
      D.text(runtime,m,'ITEM STORAGE',956,250,10,c.textSecondary,{weight='bold'})
      D.text(runtime,m,'TRANSFER ITEMS',956,282,26,c.text,{weight='bold'})
      D.text(runtime,m,'Withdraw stored items, deposit from the Kanto Bag, or toss stored stacks.',956,332,16,c.text,{width=720})
      footer(m,c,{{'UP/DOWN','SELECT'},{'ENTER','OPEN'},{'A','BACK'}});return true
    end
    if ismt(state,ListMenu) and tostring(state.kind):find('pc_item_',1,true) then
      local mode=tostring(state.kind):gsub('pc_item_',''):upper()
      local pocketed=(mode=='DEPOSIT' and state.__kantoPocketState~=nil)
      local leftX,leftW=64,820
      if pocketed then
        drawPocketSpine(game,m,c,state,64,120,280,856)
        leftX,leftW=368,516
      end
      D.panel(m,leftX,120,leftW,856,16,c.panel,c.border)
      D.text(runtime,m,'PLAYER ITEM STORAGE',leftX+24,144,10,c.textSecondary,{weight='bold'})
      D.text(runtime,m,mode..' ITEM',leftX+24,176,26,c.text,{weight='bold'})
      if pocketed then
        local st,pocket=bagModel(state)
        D.text(runtime,m,(pocket and pocket.label or 'BAG')..' • SORT: '..tostring(st and st.sortMode or 'type'):upper(),leftX+24,214,10,c.textSecondary,{weight='bold'})
      end
      runtime.nativeRowRects={}
      local visible=pocketed and 9 or 9
      local first=math.max(1,(state.index or 1)-4)
      first=math.min(first,math.max(1,#(state.items or {})-visible+1))
      for slot=1,visible do
        local i=first+slot-1; local row=state.items and state.items[i];if not row then break end
        local r={x=leftX+24,y=238+(slot-1)*68,w=leftW-48,h=58};runtime.nativeRowRects[i]=r
        focusRect(m,c,r,i==state.index,false)
        local fav=(row.favorite==true) or tostring(row.label or ''):sub(1,2)=='* '
        if fav then D.text(runtime,m,'FAV',r.x+12,r.y+20,9,c.text,{weight='bold'}) end
        D.text(runtime,m,tostring(row.label or ''):gsub('^%* ',''),r.x+(fav and 42 or 18),r.y+20,13,c.text,{weight='semibold'})
        D.text(runtime,m,tostring(row.right or ''),r.x+r.w-100,r.y+20,12,c.text,{weight='semibold',width=80,align='right'})
      end
      D.panel(m,908,120,948,856,16,c.panel,c.border)
      local row=state.items and state.items[state.index]
      if row then
        local def=itemDef(game,row)
        D.text(runtime,m,'TRANSFER DESK',936,144,10,c.textSecondary,{weight='bold'})
        D.text(runtime,m,(mode=='WITHDRAW' and 'PC STORAGE → BAG' or mode=='DEPOSIT' and 'BAG → PC STORAGE' or 'TOSS ITEM'),936,182,28,c.text,{weight='bold'})
        local machine=machineModel(game,def)
        D.text(runtime,m,itemDisplayName(game,row,def),936,252,30,c.text,{weight='bold'})
        D.text(runtime,m,tostring(row.right or ''),936,294,13,c.textSecondary,{weight='semibold'})
        D.line(m,936,336,1828,336,c.border,1)
        if pocketed then
          local st,pocket=bagModel(state)
          D.text(runtime,m,'FROM',936,374,10,c.textSecondary,{weight='bold'})
          D.text(runtime,m,'BAG • '..tostring(pocket and pocket.label or 'ITEMS'),936,400,15,c.text,{weight='semibold'})
          D.text(runtime,m,'SORT',1210,374,10,c.textSecondary,{weight='bold'})
          D.text(runtime,m,tostring(st and st.sortMode or 'type'):upper(),1210,400,15,c.text,{weight='semibold'})
        end
        D.text(runtime,m,'ENTER',936,pocketed and 462 or 386,11,c.textSecondary,{weight='bold'})
        D.text(runtime,m,mode=='TOSS' and 'CHOOSE QUANTITY / CONFIRM' or 'CHOOSE QUANTITY',936,pocketed and 490 or 414,16,c.text,{weight='semibold'})
        D.text(runtime,m,'FIELD NOTE',936,568,10,c.textSecondary,{weight='bold'})
        D.text(runtime,m,itemDescription(game,row,def,machine),936,598,15,c.text,{width=860})
      end
      if pocketed then
        local st=state.__kantoPocketState
        if st and st.uiRegion=='pockets' then footer(m,c,{{'UP/DOWN','POCKET'},{'ENTER','OPEN'},{'A','BACK'}})
        else footer(m,c,{{'UP/DOWN','ITEMS'},{'LEFT','POCKETS'},{'TAB','SORT'},{'F','FAVORITE'},{'ENTER','QUANTITY'},{'A','BACK'}}) end
      else footer(m,c,{{'UP/DOWN','ITEMS'},{'ENTER','QUANTITY'},{'A','BACK'}}) end
      return true
    end
    return false
  end
  local function drawPcChoice(game,m,c,choice,list)
    if not (choice and list) then return false end
    local kind=tostring(list.kind or '')
    if kind~='pc_box_release' and kind~='pc_box_change' then return false end
    drawBill(game,m,c,list)
    local D=runtime.Draw
    D.roundRect(m,'fill',0,88,1920,928,0,{0,0,0,.34})
    local x,y,w,h=600,382,720,300
    D.panel(m,x,y,w,h,16,c.panel,c.borderStrong)
    local title,body
    if kind=='pc_box_release' then
      local box=Boxes.active(game.save);local mon=box and box[list.index]
      local def=mon and game.data.pokemon and game.data.pokemon[mon.species]
      local name=pokemonName(game,mon)
      title='RELEASE '..tostring(name):upper()..'?'
      body='Once released, '..tostring(name):upper()..' is gone forever. OK?'
    else
      local row=list.items and list.items[list.index]
      local target=tonumber(row and row.value) or list.index or 1
      title=('SWITCH TO BOX %02d?'):format(target)
      body='When you change a POKéMON BOX, data will be saved. OK?'
    end
    D.text(runtime,m,kind=='pc_box_release' and 'RELEASE POKÉMON' or 'CHANGE BOX',x+32,y+28,10,c.textSecondary,{weight='bold'})
    D.text(runtime,m,title,x+32,y+62,24,c.text,{weight='bold'})
    D.text(runtime,m,body,x+32,y+108,15,c.text,{width=w-64})
    runtime.nativeChoiceRects={}
    local labels={'YES','NO'}
    for i=1,2 do local r={x=x+32+(i-1)*334,y=y+196,w=300,h=64};runtime.nativeChoiceRects[i]=r;focusRect(m,c,r,choice.index==i,false);D.text(runtime,m,labels[i],r.x+18,r.y+21,14,c.text,{weight='bold'}) end
    footer(m,c,{{'LEFT/RIGHT','CHOICE'},{'ENTER','CONFIRM'},{'CLICK','OPTION'},{'A','CANCEL'}})
    return true
  end
  function P.isMoveLearnContext(game,state)
    return moveLearnContext(game,state)~=nil
  end
  function P.isPartyContext(game,state)
    return partyContext(game,state)~=nil
  end

  function P.handles(game,state)
    if not state then return false end
    if partyContext(game,state) then return true end
    if moveLearnContext(game,state) then return true end
    if battleTextContext(game,state) then return true end
    if ismt(state,ListMenu) then if isMoveTargetList(state) or state.__kantoPocketState or state.kind=='shop_buy' or state.kind=='shop_sell' or tostring(state.kind):find('pc_box_',1,true) or tostring(state.kind):find('pc_item_',1,true) then return true end end
    local bl=bagList(game,state)
    if (ismt(state,TextBox) or isStatBox(state)) and bl then return true end
    if ismt(state,Menu) and (state.__kantoBagSortMenu or bl or isShopRoot(state)) then return true end
    if ismt(state,QuantityBox) and bl then return true end
    if ismt(state,ChoiceBox) then if bl then return true end;local l=shopList(game);if l then return true end;return pcBoxList(game)~=nil end
    if ismt(state,QuantityBox) then local p=below(game,state);return p and P.handles(game,p) end
    return isBillRoot(state) or isPlayerRoot(state)
  end

  -- Wide KRS owns navigation for the native semantic states it presents.
  -- The engine remains the source of truth for items, callbacks and persistence,
  -- but its 160x144 controller is not allowed to run in parallel with KRS.
  local function pressBeep(state)
    if state.noSound or not (state.game and state.game.data) then return end
    require('src.core.Sound').play(state.game.data,'Press_AB')
  end
  local function listMove(state,delta)
    local n=#(state.items or {});if n==0 then return false end
    local nextIndex=(state.index or 1)+delta
    if state.wrap then nextIndex=((nextIndex-1)%n)+1 else nextIndex=math.max(1,math.min(n,nextIndex)) end
    state.index=nextIndex
    local rows=state.rows or 7
    if state.index-(state.scroll or 0)>rows then state.scroll=state.index-rows end
    if state.index-(state.scroll or 0)<1 then state.scroll=state.index-1 end
    return true
  end
  local function listNav(state,dir)
    if dir=='up' then return listMove(state,-1) end
    if dir=='down' then return listMove(state,1) end
    if dir=='left' and state.pageJump then return listMove(state,-(state.rows or 7)) end
    if dir=='right' and state.pageJump then return listMove(state,(state.rows or 7)) end
    return false
  end
  local function listSync(state)
    local rows=state.rows or 7
    if (state.index or 1)-(state.scroll or 0)>rows then state.scroll=state.index-rows end
    if (state.index or 1)-(state.scroll or 0)<1 then state.scroll=state.index-1 end
  end
  local function backPressed(game,input)
    local Core=runtime.Core
    if Core and type(Core.nativeActionPressed)=='function' then
      local ok,value=pcall(Core.nativeActionPressed,'b',game)
      if ok then return value==true end
    end
    return input and type(input.wasPressed)=='function' and input:wasPressed('b')==true
  end
  function P.update(game,state,dt)
    if not state or not runtime.Layout.isWide(runtime.viewport) or not P.handles(game,state) then return false end
    local input=state.game and state.game.input or game and game.input
    if not input then return false end
    -- Native PartyMenu and MoveLearnMenu keep their own update cadence and
    -- callbacks. KRS replaces presentation/pointer geometry only.
    if ismt(state,PartyMenu) or ismt(state,MoveLearnMenu) or ismt(state,TextBox) or isStatBox(state) then return false end

    if ismt(state,ListMenu) then
      -- Script-driven lists can control story timing. They are never replaced.
      if state.__kantoPocketState then
        local st=state.__kantoPocketState;st.uiRegion=st.uiRegion or 'pockets';st.focusPocketIndex=st.focusPocketIndex or st.pocketIndex or 1
        local actions=runtime.Core and runtime.Core.inputActions
        if st.uiRegion=='pockets' then
          local n=#(st.pockets or {})
          if input:wasPressed('up') and n>0 then st.focusPocketIndex=st.focusPocketIndex>1 and st.focusPocketIndex-1 or n
          elseif input:wasPressed('down') and n>0 then st.focusPocketIndex=st.focusPocketIndex<n and st.focusPocketIndex+1 or 1
          elseif input:wasPressed('a') or input:wasPressed('right') then if st.selectPocket then st.selectPocket(st.focusPocketIndex) end;st.uiRegion='items';listSync(state)
          elseif backPressed(game,input) then pressBeep(state);state.game.stack:pop();if state.onCancel then state.onCancel() end end
          return true
        end
        if input:wasPressed('up') then listNav(state,'up')
        elseif input:wasPressed('down') then listNav(state,'down')
        elseif input:wasPressed('left') or backPressed(game,input) then st.uiRegion='pockets';st.focusPocketIndex=st.pocketIndex;return true
        elseif input:wasPressed('a') then pressBeep(state);local item=(state.items or {})[state.index];if state.onChoose then state.onChoose(item,state) end;return true
        elseif input:wasPressed('select') or (actions and actions.wasPressed and actions.wasPressed('BAG_SORT')) then if st.openSortMenu then st.openSortMenu() end;return true
        elseif actions and actions.wasPressed and actions.wasPressed('BAG_FAVORITE') then if st.toggleFavorite then st.toggleFavorite() end;return true end
        listSync(state);return true
      end
      if state.script then return false end
      local items=state.items or {}
      if #items==0 then
        if input:wasPressed('a') or backPressed(game,input) then
          pressBeep(state);state.game.stack:pop();if state.onCancel then state.onCancel() end
        end
        return true
      end
      local moved=false
      if input:wasPressed('up') then moved=listNav(state,'up');state.holdDir,state.holdFrames='up',0
      elseif input:wasPressed('down') then moved=listNav(state,'down');state.holdDir,state.holdFrames='down',0
      elseif state.pageJump and input:wasPressed('left') then moved=listNav(state,'left');state.holdDir,state.holdFrames='left',0
      elseif state.pageJump and input:wasPressed('right') then moved=listNav(state,'right');state.holdDir,state.holdFrames='right',0
      elseif state.onSelectKey and input:wasPressed('select') then state.onSelectKey(items[state.index],state)
      elseif backPressed(game,input) then pressBeep(state);state.game.stack:pop();if state.onCancel then state.onCancel() end;return true
      elseif input:wasPressed('a') then pressBeep(state);local item=items[state.index];if state.onChoose then state.onChoose(item,state) end;return true end
      if state.keyRepeat then
        local dir=state.holdDir
        if dir and input:isDown(dir) then
          state.holdFrames=(state.holdFrames or 0)+1
          local after=state.holdFrames-(state.repeatDelay or 16)
          if after>=0 and after%(state.repeatRate or 4)==0 then listNav(state,dir) end
        else state.holdDir,state.holdFrames=nil,0 end
      end
      if not moved then listSync(state) end
      return true
    end

    if ismt(state,Menu) then
      local items=state.items or {};if #items==0 then return true end
      if P.pcRootKind(state) and input:wasPressed('left') then P.cyclePC(game,-1);return true
      elseif P.pcRootKind(state) and input:wasPressed('right') then P.cyclePC(game,1);return true
      elseif input:wasPressed('up') then state.index=state.index>1 and state.index-1 or #items
      elseif input:wasPressed('down') then state.index=state.index<#items and state.index+1 or 1
      elseif input:wasPressed('a') then
        pressBeep(state);local item=items[state.index]
        if item and not item.keepOpen then state.game.stack:pop() end
        if item and item.onSelect then item.onSelect() end
        return true
      elseif state.cancelable and (backPressed(game,input) or (state.startCloses and input:wasPressed('start'))) then
        if backPressed(game,input) then pressBeep(state) end
        state.game.stack:pop();if state.onCancel then state.onCancel() end;return true
      end
      if state.clampScroll then state:clampScroll() end
      return true
    end

    if ismt(state,QuantityBox) then
      local function wrap(v,max) if v<1 then return max elseif v>max then return 1 end return v end
      if input:wasPressed('up') or input:wasPressed('right') then state.qty=wrap(state.qty+1,state.max)
      elseif input:wasPressed('down') or input:wasPressed('left') then state.qty=wrap(state.qty-1,state.max)
      elseif input:wasPressed('a') then state.game.stack:pop();if state.onDone then state.onDone(state.qty) end
      elseif backPressed(game,input) then state.game.stack:pop();if state.onDone then state.onDone(nil) end end
      return true
    end

    if ismt(state,ChoiceBox) then
      if state.pending~=nil then
        state.holdFrames=(state.holdFrames or 0)-1
        if state.holdFrames<=0 then local yes=state.pending;state.pending=nil;state.game.stack:pop();if state.onChoose then state.onChoose(yes) end end
        return true
      end
      if input:wasPressed('left') or input:wasPressed('right') or input:wasPressed('up') or input:wasPressed('down') then
        state.index=state.index==1 and 2 or 1
      elseif input:wasPressed('a') then
        pressBeep(state);state.pending=(state.index==1);state.holdFrames=require('src.core.Timing').YES_NO_ANSWER
      elseif backPressed(game,input) then
        pressBeep(state);state.index=2;state.pending=false;state.holdFrames=require('src.core.Timing').YES_NO_ANSWER
      end
      return true
    end
    return false
  end
  function P.draw(game,viewport)
    if not runtime.Layout.isWide(viewport) then return false end;local top=game.stack:top();if not P.handles(game,top) then return false end
    local m=runtime.Layout.metrics(viewport);local c=runtime.Theme.resolveAll(runtime,game);love.graphics.push('all');love.graphics.origin();local ok,res=pcall(function()
      local ml=moveLearnContext(game,top);if ml then return drawMoveLearn(game,m,c,ml,top) end
      local battleText,battleChoice=battleTextContext(game,top);if battleText then return drawBattleTextOverlay(game,m,c,battleText,battleChoice) end
      local party=partyContext(game,top);if party then return drawNativeParty(game,m,c,party,top~=party and top or nil) end
      local bl=bagList(game,top);if bl then return drawBag(game,m,c,bl,top~=bl and top or nil) end
      if isShopRoot(top) then return drawShopRoot(game,m,c,top) end
      if ismt(top,QuantityBox) or ismt(top,ChoiceBox) then local parent=below(game,top);if parent and (parent.kind=='shop_buy' or parent.kind=='shop_sell') then return drawShop(game,m,c,top) end; if parent and tostring(parent.kind):find('pc_item_',1,true) then return drawPlayerPC(game,m,c,parent) end; if ismt(top,ChoiceBox) then local pl=pcBoxList(game);if pl then return drawPcChoice(game,m,c,top,pl) end end end
      if ismt(top,ListMenu) and (top.kind=='shop_buy' or top.kind=='shop_sell') then return drawShop(game,m,c,top) end
      if ismt(top,ListMenu) and top.__kantoPocketState and top.kind~='shop_sell' then return drawBag(game,m,c,top) end
      if isBillRoot(top) or (ismt(top,ListMenu) and tostring(top.kind):find('pc_box_',1,true)) then return drawBill(game,m,c,top) end
      if isPlayerRoot(top) or (ismt(top,ListMenu) and tostring(top.kind):find('pc_item_',1,true)) then return drawPlayerPC(game,m,c,top) end
      return false
    end);love.graphics.pop();if not ok then return nil,res end;return res==true
  end
  function P.pointer(game,event,lx,ly)
    local top=game.stack:top();if not P.handles(game,top) then return false end
    local party=partyContext(game,top)
    if party then
      local overlay=top~=party and top or nil
      local synthetic=runtime.nativePartySynthetic
      if event.phase=='moved' then
        runtime.hoveredRegion=nil
        for _,r in ipairs(synthetic and synthetic.regions or {}) do
          if (r.kind=='party' or r.kind=='battle_action') and runtime.Layout.contains(lx,ly,r) then runtime.hoveredRegion=r.id;break end
        end
        return true
      end
      if event.phase=='pressed' then
        if event.source=='mouse' and event.button==2 then runtime.mod.input:tap(game,'b');return true end
        if overlay and isStatBox(overlay) then
          if event.source=='touch' or event.button==1 then runtime.mod.input:tap(game,'a') end
          return true
        end
        if event.source=='touch' or event.button==1 then
          if ismt(overlay,ChoiceBox) then
            for i,r in pairs(runtime.nativeChoiceRects or {}) do if runtime.Layout.contains(lx,ly,r) then overlay.index=i;runtime.mod.input:tap(game,'a');return true end end
            return true
          elseif ismt(overlay,TextBox) then
            runtime.mod.input:tap(game,'a');return true
          end
          for _,r in ipairs(synthetic and synthetic.regions or {}) do
            if runtime.Layout.contains(lx,ly,r) then
              if r.kind=='party' then party.index=r.index;runtime.mod.input:tap(game,'a');return true end
              if r.kind=='battle_action' and party.submenu then party.subIndex=r.index;runtime.mod.input:tap(game,'a');return true end
            end
          end
        end
      end
      return event.phase=='released' or event.phase=='cancelled'
    end
    if ismt(top,MoveLearnMenu) then
      if event.phase=='pressed' then
        if event.source=='mouse' and event.button==2 then runtime.mod.input:tap(game,'b');return true end
        if event.source=='touch' or event.button==1 then for i,r in pairs(runtime.nativeMoveLearnRects or {}) do if runtime.Layout.contains(lx,ly,r) then top.index=i;runtime.mod.input:tap(game,'a');return true end end end
      end
      return event.phase=='moved' or event.phase=='released' or event.phase=='cancelled'
    end
    local battleText,battleChoice=battleTextContext(game,top)
    if battleText then
      if event.phase=='pressed' then
        if event.source=='mouse' and event.button==2 then runtime.mod.input:tap(game,'b');return true end
        if event.source=='touch' or event.button==1 then
          if battleChoice then
            for i,r in pairs(runtime.nativeChoiceRects or {}) do
              if runtime.Layout.contains(lx,ly,r) then battleChoice.index=i;runtime.mod.input:tap(game,'a');return true end
            end
          else
            runtime.mod.input:tap(game,'a');return true
          end
        end
        return true
      end
      return event.phase=='moved' or event.phase=='released' or event.phase=='cancelled'
    end
    if ismt(top,TextBox) and moveLearnContext(game,top) then return false end
    local bl=bagList(game,top)
    if bl then
      local st=bl.__kantoPocketState;local overlay=top~=bl and top or nil
      if event.phase=='moved' and runtime.nativeBagDrag then
        local sb=runtime.nativeBagScrollbar;if sb and sb.travel>0 then
          local ratio=math.max(0,math.min(1,(ly-runtime.nativeBagDrag.grabY-sb.track.y)/sb.travel));bl.scroll=math.floor(ratio*sb.maxScroll+.5);bl.index=math.max(bl.scroll+1,math.min(#bl.items,bl.index or 1))
        end
        return true
      end
      if (event.phase=='released' or event.phase=='cancelled') and runtime.nativeBagDrag then runtime.nativeBagDrag=nil;return true end
      if event.phase=='moved' then
        runtime.nativeHoverState=bl;runtime.nativeHoverIndex=nil;runtime.nativeHoverPocketIndex=nil
        for i,r in pairs(runtime.nativePocketRects or {}) do if runtime.Layout.contains(lx,ly,r) then runtime.nativeHoverPocketIndex=i;break end end
        for i,r in pairs(runtime.nativeRowRects or {}) do if runtime.Layout.contains(lx,ly,r) then runtime.nativeHoverIndex=i;break end end
        return true
      end
      if event.phase=='pressed' then
        if event.source=='mouse' and event.button==2 then
          if overlay and isStatBox(overlay) then runtime.mod.input:tap(game,'b');return true end
          return P.cancelBag(game,top)
        end
        if not(event.source=='touch' or event.button==1) then return true end
        if overlay and isStatBox(overlay) then runtime.mod.input:tap(game,'a');return true end
        if overlay then
          if ismt(overlay,ChoiceBox) then for i,r in pairs(runtime.nativeChoiceRects or {}) do if runtime.Layout.contains(lx,ly,r) then overlay.index=i;runtime.mod.input:tap(game,'a');return true end end end
          if ismt(overlay,TextBox) then runtime.mod.input:tap(game,'a');return true end
          if ismt(overlay,Menu) or isMoveTargetList(overlay) then for i,r in pairs(runtime.nativeMenuRects or {}) do if runtime.Layout.contains(lx,ly,r) then overlay.index=i;runtime.mod.input:tap(game,'a');return true end end end
          return true
        end
        local sb=runtime.nativeBagScrollbar;if sb and runtime.Layout.contains(lx,ly,sb.hit) then runtime.nativeBagDrag={grabY=ly-sb.thumb.y};return true end
        for i,r in pairs(runtime.nativePocketRects or {}) do if runtime.Layout.contains(lx,ly,r) then if st.selectPocket then st.selectPocket(i) end;st.uiRegion='items';return true end end
        for i,r in pairs(runtime.nativeRowRects or {}) do if runtime.Layout.contains(lx,ly,r) then st.uiRegion='items';bl.index=i;listSync(bl);runtime.mod.input:tap(game,'a');return true end end
        return true
      end
      return event.phase=='released' or event.phase=='cancelled'
    end
    local state=top;if ismt(top,QuantityBox) then state=below(game,top) or top elseif ismt(top,ChoiceBox) then state=below(game,top) or top end
    local rects=runtime.nativeRowRects or {};if event.phase=='moved' then runtime.nativeHoverState=state;runtime.nativeHoverIndex=nil;for i,r in pairs(rects) do if runtime.Layout.contains(lx,ly,r) then runtime.nativeHoverIndex=i;break end end;return true end
    if event.phase=='pressed' then
      if event.source=='mouse' and event.button==2 then runtime.mod.input:tap(game,'b');return true end
      if ismt(top,ChoiceBox) and (event.source=='touch' or event.button==1) then
        for i,r in pairs(runtime.nativeChoiceRects or {}) do if runtime.Layout.contains(lx,ly,r) then top.index=i;runtime.mod.input:tap(game,'a');return true end end
      end
      if event.source=='touch' or event.button==1 then
        if P.pcRootKind(state) and runtime.nativePcTabRects then for id,r in pairs(runtime.nativePcTabRects) do if runtime.Layout.contains(lx,ly,r) then P.switchPC(game,id);return true end end end
        for i,r in pairs(rects) do if runtime.Layout.contains(lx,ly,r) and state.index then state.index=i;runtime.mod.input:tap(game,'a');return true end end
        for i,r in pairs(runtime.nativeMenuRects or {}) do if runtime.Layout.contains(lx,ly,r) and state.index then state.index=i;runtime.mod.input:tap(game,'a');return true end end
      end
    end
    return event.phase=='released' or event.phase=='cancelled'
  end
  function P.wheel(game,state,dx,dy,lx,ly)
    state=state or (game and game.stack and game.stack:top());if not state or dy==0 or not P.handles(game,state) then return false end
    local bl=bagList(game,state)
    if bl then
      local st=bl.__kantoPocketState
      if state~=bl then local dir=dy>0 and -1 or 1;if isMoveTargetList(state) then listMove(state,dir);listSync(state) elseif ismt(state,Menu) and #(state.items or {})>0 then state.index=((state.index or 1)-1+dir)%#state.items+1;if state.clampScroll then state:clampScroll() end elseif ismt(state,QuantityBox) then state.qty=((state.qty or 1)-1-dir)%state.max+1 elseif ismt(state,ChoiceBox) then state.index=state.index==1 and 2 or 1 end;return true end
      -- Header pockets are horizontal controls; wheel always scrolls the
      -- vertical item ledger, including when the pointer is over the header.
      st.uiRegion='items';listMove(bl,dy>0 and -1 or 1);listSync(bl)
      return true
    end
    if ismt(state,ListMenu) then listMove(state,dy>0 and -1 or 1);listSync(state);return true end
    if ismt(state,Menu) and #state.items>0 then state.index=((state.index or 1)-1+(dy>0 and -1 or 1))%#state.items+1;if state.clampScroll then state:clampScroll() end;return true end
    if ismt(state,QuantityBox) then local dir=dy>0 and 1 or -1;state.qty=((state.qty or 1)-1+dir)%state.max+1;return true end
    if ismt(state,ChoiceBox) then state.index=state.index==1 and 2 or 1;return true end
    return true
  end
  return P
end
