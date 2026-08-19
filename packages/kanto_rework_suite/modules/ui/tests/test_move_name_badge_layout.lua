local root=assert(arg[1],"root path required")
local function loadModule(path)local chunk,err=loadfile(root.."/"..path);assert(chunk,err);return chunk()end
local function check(value,label)if not value then error(label or "check failed",2)end end
local function near(actual,expected,tolerance,label)
  if math.abs(actual-expected)>tolerance then
    error((label or "value")..": expected "..expected.." ± "..tolerance..", got "..actual,2)
  end
end

-- Widths measured from the bundled Inter-Bold.ttf at 28 px. The layout uses
-- LÖVE's live Font:getWidth; this deterministic stub preserves those metrics.
local widthAt28={
  ["THUNDERBOLT"]=209.15625,
  ["MENACING MOONRAZE MAELSTROM"]=516.59375,
  ["SOUL-STEALING 7-STAR STRIKE"]=445.15625,
}
local currentFont=nil
local typeChips={}
local categoryRects={}
local printed={}
local function newFont(path,px)
  if type(path)=="number" then px=path;path="default" end
  local face={path=path or "default",px=px or 12}
  function face:getWidth(value)
    local text=tostring(value or "")
    return (widthAt28[text] or (#text*15.4))*(self.px/28)
  end
  function face:setFallbacks()end
  return face
end
love={graphics={
  setColor=function()end,setLineWidth=function()end,line=function()end,circle=function()end,polygon=function()end,
  rectangle=function(mode,x,y,w,h)
    if mode=="fill" and math.abs(y-276)<.01 and math.abs(w-116)<.01 and math.abs(h-32)<.01 then
      categoryRects[#categoryRects+1]={x=x,y=y,w=w,h=h}
    end
  end,
  newFont=newFont,setFont=function(face)currentFont=face end,
  print=function(value,x,y)printed[#printed+1]={value=tostring(value),x=x,y=y,size=currentFont and currentFont.px or 0}end,
  printf=function()end,push=function()end,pop=function()end,origin=function()end,
  setScissor=function()end,stencil=function(fn)fn()end,setStencilTest=function()end,draw=function()end,
}}

local C=loadModule("generated/tokens.lua")
local Layout=loadModule("ui/party_layout.lua")(C)
local function move(name)return{id=name,name=name,type="GHOST",category="SPECIAL",pp=1,maxPP=1,power=200,accuracy=100,description="Move description."}end
local model={source={moves={{},{},{},{}}},name="DRATINI",level=23,ot="MILA",otId=40217,hp=27,
  stats={hp=53,attack=41,defense=45,speed=50,special=50},types={"DRAGON"},moves={move("THUNDERBOLT")},
  dvs={},statExp={},exp=7612,toNextLevel=1113,expRatio=.49}
local Adapter={topState=function(game)return game.stack:top()end,frontSprite=function()return nil end,drawPartyIcon=function()return false end}
local runtime={viewport={width=1920,height=1080},fontFamily="kanto_rework.inter",fontFallbackPath="fallback.ttf",
  fontPaths={regular="Inter-Regular.ttf",medium="Inter-Medium.ttf",semibold="Inter-SemiBold.ttf",bold="Inter-Bold.ttf",black="Inter-Black.ttf"},partyNav={},Focus={isPointer=function()return false end}}
local TypeIcon={draw=function()end}
local TypeChip={draw=function(kind,x,y,scale)
  if math.abs(y-274)<.01 then typeChips[#typeChips+1]={kind=kind,x=x,y=y,w=148*scale}end
end}
local noop={draw=function()end}
local Palette={resolve=function()return{colors=C.colors,typeColors=C.typeColors,profile="standard",colorMode="standard"}end}
local Core={journalContext=function()return{location="PALLET TOWN",playTime=0}end}
local Presenter=loadModule("ui/party_presenter.lua")({C=C,Layout=Layout,Adapter=Adapter,TypeIcon=TypeIcon,TypeChip=TypeChip,
  StatusToken={drawIcon=function()end,drawToken=function()end},Footer=noop,Palette=Palette,Core=Core,runtime=runtime})
local state={__kantoPartyUi=true,mode="MovesActive",pokemon=model,party={model.source},regions={},activeMoveFocus=1,
  movePhase="active",learned={},learnedFirst=1}
local game={stack={top=function()return state end}}

local function render(name)
  model.moves[1]=move(name);model.source.moves[1]=model.moves[1]
  typeChips={};categoryRects={};printed={}
  check(Presenter:draw(game,runtime.viewport),"Moves renderer must claim the frame")
  check(#typeChips==1,"active move type badge must render once")
  check(#categoryRects==1,"active move category badge must render once")
  local headline=nil
  for _,entry in ipairs(printed)do
    if entry.value==name and math.abs(entry.x-528)<1 and entry.y>=278 and entry.y<=280 then headline=entry;break end
  end
  check(headline,"active move headline must render")
  return headline,typeChips[1],categoryRects[1]
end

local short,typeShort,categoryShort=render("THUNDERBOLT")
check(short.size==28,"short move keeps the 28 px headline")
near(typeShort.x-(short.x+widthAt28.THUNDERBOLT),8,1,"short move receives the minimum 8 px gap")
near(categoryShort.x-(typeShort.x+148),16,1,"badges keep their 16 px separation")

local longest,typeLong,categoryLong=render("MENACING MOONRAZE MAELSTROM")
check(longest.size==26,"widest 27-character move uses the 26 px fallback")
local longWidth=widthAt28["MENACING MOONRAZE MAELSTROM"]*(26/28)
near(typeLong.x-(longest.x+longWidth),16,1,"longest move receives the maximum 16 px gap")
near(categoryLong.x-(typeLong.x+148),16,1,"long-name badges keep their 16 px separation")
check(categoryLong.x+categoryLong.w<=1314,"longest move category badge stays inside the active card")

local tied,typeTied,categoryTied=render("SOUL-STEALING 7-STAR STRIKE")
check(tied.size==28,"narrower tied 27-character move keeps the 28 px headline")
check(typeTied.x>tied.x+widthAt28["SOUL-STEALING 7-STAR STRIKE"],"tied long move cannot overlap its type badge")
check(categoryTied.x+categoryTied.w<=1314,"tied long move category badge stays inside the active card")

print("Moves long-name badge layout tests passed")
