local root=assert(arg[1],"UI root required")
local function read(path)
  local f=assert(io.open(root.."/"..path,"rb"));local s=f:read("*a");f:close();return s
end
local function exists(path,minimum)
  local f=assert(io.open(root.."/"..path,"rb"),"missing "..path)
  local size=assert(f:seek("end"));f:close();assert(size>=(minimum or 1),"truncated "..path)
end
local function pngSize(path)
  local data=read(path);assert(data:sub(1,8)=="\137PNG\13\10\26\10","invalid PNG "..path)
  local function be32(at)
    local a,b,c,d=data:byte(at,at+3);return ((a*256+b)*256+c)*256+d
  end
  return be32(17),be32(21)
end

local menu=read("ui/menu_presenter.lua")
assert(menu:find('assets/menu/main/states/main_card_',1,true),"exact Figma card-state route")
assert(not menu:find('newShader',1,true),"cards must not be runtime-desaturated")
assert(not menu:find('mainCardGradient',1,true),"cards must not reconstruct Figma gradients")
assert(not menu:find('assets/menu/main/clean/',1,true),"legacy clean-card route must be unused")
assert(menu:find('descSize=secondary and 13 or 14',1,true),"Figma secondary description size")
assert(menu:find('247/255,241/255,223/255',1,true),"Figma tertiary title colour")
assert(menu:find('129/255,123/255,107/255',1,true),"Figma tertiary description colour")

local expected={
  pokedex={310,352},pokemon={310,352},bag={312,351},pc={312,351},
  save={648,120},link={648,120},options={424,136},mods={424,136},close={424,136},
}
for id,size in pairs(expected) do
  for _,state in ipairs({"default","hover","selected"}) do
    local path=("assets/menu/main/states/main_card_%s_%s.png"):format(id,state)
    local w,h=pngSize(path);assert(w==size[1] and h==size[2],path.." dimensions")
  end
end

local themes=assert(loadfile(root.."/generated/themes.lua"))()
for _,id in ipairs({"cream","graphite","purplenight"}) do
  assert(themes.themes[id].fontFamily=="kanto_rework.inter",id.." uses Figma Inter")
end
assert(themes.themes.retro.fontFamily=="kanto_rework.pixelify_sans","Retro uses Figma Pixelify Sans")
for _,face in ipairs({"Regular","Medium","SemiBold","Bold","Black"}) do
  exists("assets/fonts/inter/Inter-"..face..".ttf",300000)
end
for _,face in ipairs({"Regular","Medium","Bold"}) do
  exists("assets/fonts/pixelify/PixelifySans-"..face..".ttf",45000)
end
exists("assets/fonts/inter/OFL.txt",1000);exists("assets/fonts/pixelify/OFL.txt",1000)
local main=read("main.lua")
assert(main:find('kanto_rework.pixelify_sans',1,true),"Pixelify family registration")
assert(not main:find('newImageFont',1,true),"approximate Retro raster atlas path removed")

local pokedex=read("ui/pokedex_presenter.lua")
assert(pokedex:find('getmetatable(state)==DexEntryMenu',1,true),"native DexEntry detection")
assert(pokedex:find('artKind="starter_preview"',1,true),"starter uses shared Pokémon art provider")
assert(pokedex:find('drawData(game,m,c,nativeEntryState(game,s),true)',1,true),"starter uses KRS Pokédex DATA frame")

local native=read("ui/native_presenter.lua")
assert(native:find('D.pokedollar',1,true),"Shop Pokédollar glyph")
assert(not native:find("'¥'..",1,true),"no hard-coded Yen currency prefix in shop")
local party=read("ui/party_presenter.lua")
assert(party:find('elseif label=="SPECIAL"',1,true),"SPECIAL category branch")
assert(party:find('love.graphics.polygon("fill",pts)',1,true),"SPECIAL uses filled diamond")
local draw=read("ui/menu_draw.lua")
assert(draw:find('popUtf8',1,true) and draw:find('utf8lib.offset',1,true),"UTF-8 safe clipping")
assert(draw:find('kanto_rework.pixelify_sans',1,true) and draw:find('"nearest","nearest",1',1,true),"crisp Pixelify filtering")
print("0.8.28 four-theme Figma fidelity regression tests passed")
