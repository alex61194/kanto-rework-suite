local root=assert(arg[1],"root path required")
local function check(v,msg)if not v then error(msg or'check failed',2)end end
local Presenter=assert(loadfile(root..'/ui/menu_presenter.lua'))()
local pcPartyIcon
for i=1,80 do
  local name,value=debug.getupvalue(Presenter.drawPcStorage,i)
  if not name then break end
  if name=='pcPartyIcon'then pcPartyIcon=value;break end
end
check(type(pcPartyIcon)=='function','PC icon helper remains reachable from Stored Pokémon presenter')
local calls={};local drawn={}
love={graphics={
  push=function(mode)calls[#calls+1]={'push',mode}end,
  translate=function()end,scale=function()end,
  setColor=function(r,g,b,a)calls[#calls+1]={'color',r,g,b,a}end,
  pop=function()calls[#calls+1]={'pop'}end,
}}
package.preload['src.ui.PartyMenu']=function()return{drawIcon=function(game,mon,x,y,flip,frame,disabled)drawn[#drawn+1]=mon;calls[#calls+1]={'draw',mon.shiny==true}end}end
local runtime={};local m={ox=0,oy=0,scale=1};local game={}
for _,mon in ipairs({{species='PIKACHU',shiny=false},{species='PIKACHU',shiny=true}})do
  calls={};check(pcPartyIcon(runtime,m,game,mon,0,0,48),'PC icon helper draws Pokémon')
  check(drawn[#drawn]==mon,'PC renderer passes the original Pokémon record (including Shiny state)')
  local colorIndex,drawIndex
  for i,c in ipairs(calls)do if c[1]=='color'then colorIndex=i;check(c[2]==1 and c[3]==1 and c[4]==1 and c[5]==1,'sprite draw resets inherited theme tint/opacity to opaque white')elseif c[1]=='draw'then drawIndex=i end end
  check(colorIndex and drawIndex and colorIndex<drawIndex,'true-colour reset happens before pixel-art draw')
  check(calls[1][1]=='push' and calls[1][2]=='all' and calls[#calls][1]=='pop','sprite colour state is isolated from surrounding dark theme container')
end
check(drawn[1].shiny==false and drawn[2].shiny==true,'Normal and Shiny use the same colour-preserving pipeline')
print('PC Normal/Shiny sprite colour isolation tests passed')
