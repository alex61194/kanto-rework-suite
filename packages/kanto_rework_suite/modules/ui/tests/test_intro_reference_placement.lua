local src=assert(io.open('ui/intro_presenter.lua','rb')):read('*a')
assert(src:find("960,970,560,680",1,true),'Red/Blue trainer stage bottom follows the renewed reference composition')
assert(src:find("960,930,420,420",1,true),'Intro Pokémon is raised slightly above the dialogue mask')
print('KRS intro reference placement test passed')
