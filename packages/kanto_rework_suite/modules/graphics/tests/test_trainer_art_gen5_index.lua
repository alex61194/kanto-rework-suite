local index=dofile('generated/trainer_art_gen5_index.lua')
local expected={
  'beauty','biker','blackbelt','blaine','brock','cooltrainer-f','cooltrainer-m','erika','fisher',
  'gentleman','giovanni','hiker','lance','lass','lt-surge','misty','psychic-tr','rival1','rival2','rival3',
  'sabrina','scientist','swimmer','youngster'
}
local n=0
for _,slug in ipairs(expected) do
  local rec=assert(index[slug],slug..' Gen V mapping missing')
  assert(rec.path and rec.path:find('/gen5/',1,true),slug..' path')
  assert(rec.frameCount and rec.frameCount>1,slug..' must be animated')
  assert(#rec.durationsMs==rec.frameCount,slug..' duration count')
  assert(rec.frameWidth>0 and rec.frameHeight>0 and rec.columns>0 and rec.rows>0,slug..' atlas geometry')
  assert(rec.trueColor==true and rec.filter=='nearest',slug..' pixel-art flags')
  n=n+1
end
local extra=0
for _ in pairs(index) do extra=extra+1 end
assert(extra==n,'unexpected speculative Gen V trainer mappings')
assert(index['rocket']==nil,'Rocket must not silently map to Plasma')
assert(index['agatha']==nil,'Agatha has no supplied Gen V direct mapping')
print('trainer Gen V index: PASS ('..n..' deterministic KRS slugs)')
