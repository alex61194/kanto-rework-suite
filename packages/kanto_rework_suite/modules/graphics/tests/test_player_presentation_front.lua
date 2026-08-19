local main=assert(io.open('main.lua','rb')):read('*a')
local function check(v,msg)if not v then error(msg or 'check failed',2)end end
check(main:find("context=='player.presentation.front'",1,true),'Graphics exposes a dedicated Player Presentation Front context')
check(main:find("assets/trainers/presentation/red_front.png",1,true),'presentation front uses its own KRS asset family')
check(main:find("ctx.kind~='battle' or ctx.side~='back'",1,true),'battle Player Art hook is scoped to actual battle backsprites')
check(main:find("ctx.demo or ctx.oakDemo",1,true),'demo/intro contexts are not replaced by Battle Player Art')
local f=assert(io.open('assets/trainers/presentation/red_front.png','rb'))
local sig=f:read(24);f:close()
check(#sig>=24 and sig:sub(1,8)=='\137PNG\13\10\26\10','presentation front is a PNG')
local function u32(s,i)local a,b,c,d=s:byte(i,i+3);return ((a*256+b)*256+c)*256+d end
local w,h=u32(sig,17),u32(sig,21)
check(w==112 and h==276,('Figma presentation dimensions must be 112x276, got %dx%d'):format(w,h))
print('Player presentation front/battle backsprite isolation tests passed')
