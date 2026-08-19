local root=assert(arg[1],"root path required")
local function check(v,msg) if not v then error(msg or 'check failed',2) end end
local adjusted=0
local models={
  {id='music_pack',name='Kanto Music Remaster',description='music replacement',enabled=true},
  {id='cry_pack',name='Pokemon Cries HD',description='new cries and sound',enabled=true},
  {id='BATTLE_ART_VOXEL_FORK',name='BATTLE ART VOXEL FORK',description='voxel graphics battle art',enabled=true},
  {id='kanto_rework_suite',name='Kanto Rework Suite',description='one native KRS Candidate',enabled=true},
}
local voxelOptions={}
for i=1,28 do voxelOptions[#voxelOptions+1]={id='voxel_'..i,label='VOXEL OPTION '..i,group=i<8 and 'WORLD RENDERING' or 'BATTLE ART',displayValue='ON'} end
voxelOptions[#voxelOptions+1]={id='custom_conflict',label='BATTLE BACKGROUND',group='CONFLICT RESOLUTION',displayValue=function() return 'KANTO REWORK SUITE' end,adjust=function() adjusted=adjusted+1;return true,'VOXEL' end}
local suiteOptions={{id='compatibility.custom_conflict',label='BATTLE BACKGROUND',group='COMPATIBILITY',displayValue=function() return 'KANTO REWORK SUITE' end,adjust=function() adjusted=adjusted+1;return true,'VOXEL' end}}
local byId={};for _,m in ipairs(models) do byId[m.id]=m end
local session={native={}}
function session:models() return models end
function session:model(id) return byId[id] end
function session:options(id) if id=='BATTLE_ART_VOXEL_FORK' then return voxelOptions elseif id=='kanto_rework_suite' then return suiteOptions else return {} end end
function session:utilities() return {} end
function session:refresh() end
function session:prompt() return nil end
function session:restartRequired() return false end
function session:profiles() return {} end
local sessionErrors={}
function session:errors() return sessionErrors end
function session:enter() end
function session:adjustOption() return true end
local runtime={
  Core={createModRuntime=function() return session end},
  Focus={new=function() return {} end,navigation=function() end,syncDevice=function() end,pointerMove=function() end,pointerPress=function() end},
  Layout={isWide=function() return true end,contains=function(x,y,r) return r and x>=r.x and y>=r.y and x<=r.x+r.w and y<=r.y+r.h end},
}
runtime.Scroll=assert(loadfile(root..'/ui/scroll_list.lua'))()
local screen=assert(loadfile(root..'/screens/mods_menu.lua'))().factory(runtime).new({input={wasPressed=function() return false end}})
for _,m in ipairs(models) do screen.expanded[m.id]=m.id=='BATTLE_ART_VOXEL_FORK' end
local rows=screen:modRows()
local headers={}; local firstMods={}
local current
for _,r in ipairs(rows) do
  if r.header and not r.subheader then current=r.label;headers[#headers+1]=current
  elseif r.kind=='mod' and current and not firstMods[current] then firstMods[current]=r.mod.id end
end
check(headers[1]=='KANTO REWORK SUITE','KRS suite is the first pinned category')
check(firstMods['KANTO REWORK SUITE']=='kanto_rework_suite','Candidate exposes exactly the Suite as native first-party KRS row')
local krsIds={};local inKrs=false
for _,r in ipairs(rows) do if r.header and not r.subheader then inKrs=r.label=='KANTO REWORK SUITE' elseif inKrs and r.kind=='mod' then krsIds[#krsIds+1]=r.mod.id end end
check(table.concat(krsIds,',')=='kanto_rework_suite','legacy KRS modules do not reappear as seven fake native mods')
local audioCount=0
for _,r in ipairs(rows) do if r.kind=='mod' and (r.mod.id=='music_pack' or r.mod.id=='cry_pack') then
  local category
  for i=#rows,1,-1 do if rows[i]==r then for j=i-1,1,-1 do if rows[j].header and not rows[j].subheader then category=rows[j].label;break end end;break end end
  check(category=='AUDIO AND SOUND DESIGN','music/cries are grouped under Audio and Sound Design');audioCount=audioCount+1
end end
check(audioCount==2,'both audio mods classified')
local voxelCategory
for i,r in ipairs(rows) do if r.kind=='mod' and r.mod.id=='BATTLE_ART_VOXEL_FORK' then for j=i-1,1,-1 do if rows[j].header and not rows[j].subheader then voxelCategory=rows[j].label;break end end end end
check(voxelCategory=='VISUALS AND GRAPHICS','Voxel is classified under Visuals and Graphics')

screen.tab=1;screen.region='content';screen:focusMod('BATTLE_ART_VOXEL_FORK');
-- Expand and walk to the very last Voxel option using keyboard navigation.
screen.expanded['BATTLE_ART_VOXEL_FORK']=true;screen:refresh();screen:focusMod('BATTLE_ART_VOXEL_FORK')
local target='option:BATTLE_ART_VOXEL_FORK:custom_conflict';local guard=0
while screen.focusKey~=target and guard<80 do screen:move(1);guard=guard+1 end
check(screen.focusKey==target,'keyboard can reach the last item in a long Voxel option list')
check(screen.scrollY>0,'long Voxel option list scrolls instead of being clipped')
runtime.modScrollWheelRegion={x=0,y=0,w=1000,h=1000}; local before=screen.scrollY
screen:wheel(0,1,500,500);check(screen.scrollY<before,'mouse wheel scrolls the long mod list upward')

-- Candidate Suite categories behave like native mod options inside one mod.
screen.expanded['kanto_rework_suite']=true;screen:refresh();screen:focusMod('kanto_rework_suite')
local compatRow
for _,r in ipairs(screen:rows()) do if r.kind=='option' and r.mod.id=='kanto_rework_suite' and r.option.id=='compatibility.custom_conflict' then compatRow=r;break end end
check(compatRow~=nil,'Compatibility category option appears inline under the one Suite entry')
check(screen:changeOption(compatRow,1,false)==true and adjusted==1,'Suite compatibility selector uses normal inline option behavior')

-- Errors remain one complete row each and are grouped once by owning mod,
-- even if the manager reports groups in an interleaved order.
sessionErrors={{modId='alpha',modName='Alpha',label='first',detail='first complete error'},{modId='beta',modName='Beta',label='second',detail='second complete error'},{modId='alpha',modName='Alpha',label='third',detail='third complete error'}}
screen.tab=3;local errorRows=screen:errorRows();local labels={};local errorCount=0
for _,r in ipairs(errorRows) do if r.header then labels[#labels+1]=r.label else errorCount=errorCount+1 end end
check(table.concat(labels,',')=='ALPHA,BETA' and errorCount==3,'errors are grouped once by mod with one row per error')
screen.focusIndex=2;screen:activateCurrent();check(screen.overlay and screen.overlay.kind=='error_detail' and screen.overlay.detail=='first complete error','error row opens the complete message reader')
print('Mod semantic category and scrolling Candidate tests passed')
