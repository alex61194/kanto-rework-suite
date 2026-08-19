local root=assert(arg[1],"UI root required")

local LinkState={};LinkState.__index=LinkState
local Tournament={};Tournament.__index=Tournament
package.preload['src.link.LinkState']=function()return LinkState end
package.preload['src.link.Tournament']=function()return Tournament end
package.preload['src.link.CodeEntry']=function()return{LENGTH=6,CHARSET='ABCDEFGHJKLMNPQRSTUVWXYZ23456789'}end
package.preload['src.link.Net']=function()return{defaultPort=function()return 27888 end}end

local drawCalls=0
local Draw={}
for _,name in ipairs({'roundRect','panel','text','line','clipText'}) do Draw[name]=function()drawCalls=drawCalls+1 end end
local colors={}
for _,name in ipairs({'canvas','inverse','textInverse','faint','panel','border','focus','text','subtle','textSecondary','elevated','success','danger'}) do colors[name]={.2,.3,.4,1} end
local taps={}
local theme='CREAM'
local runtime={
  Draw=Draw,viewport={width=1920,height=1080},linkRects={},
  Layout={isWide=function()return true end,metrics=function(v)return v end,contains=function(x,y,r)return x>=r.x and y>=r.y and x<r.x+r.w and y<r.y+r.h end},
  Theme={label=function()return theme end,resolveAll=function()return colors end},
  mod={input={tap=function(_,_,action)taps[#taps+1]=action end}},
}
love={graphics={push=function()end,pop=function()end,origin=function()end}}
local Presenter=assert(loadfile(root..'/ui/link_presenter.lua'))()(runtime)

local game={save={player={name='RED'},party={{species='PIKACHU',level=25},{species='EEVEE',level=20}}},data={pokemon={PIKACHU={name='PIKACHU'},EEVEE={name='EEVEE'}}}}
local current
game.stack={top=function()return current end}

local codeEntry={chars={1,2,3,4,5,6},pos=1}
local trade={stage='picking',theirParty={{species='EEVEE',level=20}},theirPick=1,canPick=function(_,i)return i~=2 end}
local linkStages={
  menu={index=1},lanMenu={index=2},onlineMenu={index=1},onlineHosting={net={code='ABC234'}},
  codeEntry={codeEntry=codeEntry},onlineJoining={net={target='ABC234'}},hosting={net={address='192.168.1.5'}},
  addrEntry={addr={1,9,2,1,6,8,0,0,1,0,0,5},addrPos=12},joining={net={target='192.168.1.5'}},
  modeSelect={index=1},battleOptions={levelChoice=50},waitMode={peerName='BLUE'},waitHello={peerName='BLUE'},
  notice={verdict='subset',noticeExits=false,noticeLines={'Different content.','Trade subset remains compatible.'}},
  trade={index=1,trade=trade},battleWait={peerName='BLUE'},battleRunning={peerName='BLUE'},
}
for _,label in ipairs({'CREAM','GRAPHITE','PURPLE NIGHT','RETRO'}) do
  theme=label
  for stage,fields in pairs(linkStages) do
    local state=setmetatable({game=game,stage=stage},LinkState);for k,v in pairs(fields) do state[k]=v end;current=state
    assert(Presenter.handles(game,state),stage..' LinkState must be recognized')
    local ok,err=Presenter.draw(game,runtime.viewport);assert(ok==true,stage..' Link surface failed in '..label..': '..tostring(err))
  end
end

-- Pointer clicks select native rows and inject the same A/B actions consumed
-- by LinkState:update; no transport method is called from KRS.
theme='CREAM';current=setmetatable({game=game,stage='menu',index=1},LinkState);Presenter.draw(game,runtime.viewport)
Presenter.pointer(game,{phase='pressed',source='mouse',button=1},300,450)
assert(current.index==2 and taps[#taps]=='a','clicking ONLINE MATCH sets native index and taps A')
Presenter.pointer(game,{phase='pressed',source='mouse',button=2},10,10)
assert(taps[#taps]=='b','right click maps to native B')

current=setmetatable({game=game,stage='codeEntry',codeEntry={chars={1,2,3,4,5,6},pos=1}},LinkState);Presenter.draw(game,runtime.viewport)
local codeCell=runtime.linkRects[1];Presenter.wheel(game,1,codeCell.x+2,codeCell.y+2)
assert(current.codeEntry.pos==1 and taps[#taps]=='up','code cells support mouse-wheel editing through native Up')

local tournamentStages={
  menu={index=1},hostSettings={settingsIndex=1,settings={requiredPartySize=3,minLevel='ANY',maxLevel=50,turnLimit=6,forceLevel='ANY',participating=true}},
  codeEntry={codeEntry=codeEntry},registering={code='ZXCVBN'},
  bracket={code='ZXCVBN',isCreator=true,roster={'RED','BLUE'},spectatorRoster={},bracket={rounds={{round=1,matches={{a='RED',b='BLUE',state='live'}}}}}},
  matchHello={code='ZXCVBN',roster={'RED','BLUE'},spectatorRoster={}},matchWaitParty={code='ZXCVBN',roster={'RED','BLUE'},spectatorRoster={}},spectateWait={code='ZXCVBN',roster={'RED','BLUE'},spectatorRoster={'GREEN'}},done={champion='RED'},
}
for stage,fields in pairs(tournamentStages) do
  local state=setmetatable({game=game,stage=stage},Tournament);for k,v in pairs(fields) do state[k]=v end;current=state
  assert(Presenter.handles(game,state),stage..' Tournament must be recognized')
  local ok,err=Presenter.draw(game,runtime.viewport);assert(ok==true,stage..' Tournament surface failed: '..tostring(err))
end

current=setmetatable({game=game,stage='hostSettings',settingsIndex=1,settings={requiredPartySize=3,minLevel='ANY',maxLevel=50,turnLimit=6,forceLevel='ANY',participating=true}},Tournament);Presenter.draw(game,runtime.viewport)
local right
for _,r in ipairs(runtime.linkRects) do if r.id=='setting_1_right' then right=r break end end
assert(right,'tournament rule row exposes a pointer adjustment target')
Presenter.pointer(game,{phase='pressed',source='mouse',button=1},right.x+2,right.y+2)
assert(current.settingsIndex==1 and taps[#taps]=='right','tournament rule adjustment uses native Right action')

assert(drawCalls>500,'all Link/Tournament themed surfaces must exercise the Wide renderer')
print('Four-theme LinkState and Tournament interface tests passed')
