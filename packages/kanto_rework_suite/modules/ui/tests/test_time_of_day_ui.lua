local main=assert(io.open('main.lua','rb')):read('*a')
local header=assert(io.open('components/header.lua','rb')):read('*a')
local party=assert(io.open('ui/party_presenter.lua','rb')):read('*a')
local dex=assert(io.open('ui/pokedex_presenter.lua','rb')):read('*a')
local native=assert(io.open('ui/native_presenter.lua','rb')):read('*a')
assert(main:find('runtime.worldPhase',1,true) and main:find('timeOfDayPeriod',1,true),'UI reads KRS Graphics time service')
for name,src in pairs({header=header,party=party,dex=dex,native=native}) do
  assert(src:find('worldTimeLabel',1,true) or src:find('worldPhase',1,true),'dynamic world period missing from '..name)
end
print('KRS Sunrise/Day/Sunset/Night header integration tests passed')
