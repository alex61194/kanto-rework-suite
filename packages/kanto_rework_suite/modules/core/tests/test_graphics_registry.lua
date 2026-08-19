local source=assert(io.open('core/graphics_registry.lua','rb')):read('*a')
local factory=assert(load(source,'@core/graphics_registry.lua'))()
local r=factory()
local calls={}
r.registerProvider({id='low',priority=1,contexts={'party.icon'},resolve=function(ctx,req) calls[#calls+1]='low';return {path='low.png'} end})
r.registerProvider({id='high',priority=9,contexts={'party.*'},resolve=function(ctx,req) calls[#calls+1]='high';if req.skip then return nil end;return {path='high.png'} end})
local v=r.resolve('party.icon',{})
assert(v.path=='high.png' and v.provider=='high','higher-priority namespace provider wins')
local v2=r.resolve('party.icon',{skip=true})
assert(v2.path=='low.png','resolver falls through when provider declines')
local fallback={path='fallback.png'}
assert(r.resolve('intro.trainer',{},fallback)==fallback,'unclaimed context preserves explicit fallback')
assert(r.status().count==2,'registry reports providers')
print('graphics registry tests passed')
