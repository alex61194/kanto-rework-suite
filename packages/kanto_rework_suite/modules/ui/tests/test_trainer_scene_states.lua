local scene=dofile('runtime/trainer_scene.lua')()
local b={kind='trainer',phase='intro',showEnemyTrainer=true}
assert(scene.phase(b)=='intro')
b.showEnemyTrainer=false;b.phase='menu'
assert(scene.phase(b)=='battle')
assert(scene.showPersistent(b,true)==true)
assert(scene.showPersistent(b,false)==false)
b.showEnemyTrainer=true;b.phase='action'
assert(scene.phase(b)=='post')
local link={kind='link',phase='intro',showEnemyTrainer=true}
assert(scene.phase(link)=='intro')
assert(scene.showPersistent(link,true)==false,'persistent trainer option applies to trainer battles only')
print('trainer semantic states: PASS')
