local root=assert(arg[1],"root path required")
local function check(v,msg) if not v then error(msg or 'check failed',2) end end
package.preload['src.core.Strings']=function() return function(fmt,...) return string.format(fmt,...) end end
local wrapper
local mod={hooks={wrap=function(_,name,fn,priority) check(name=='battle.exp_award','public EXP award hook');check(priority==120,'hook priority');wrapper=fn;return function() end end}}
assert(loadfile(root..'/exp_all_summary.lua'))()(mod)
check(type(wrapper)=='function','EXP.ALL wrapper installed')

local delegated=0
local nextFn=function() delegated=delegated+1;return 'native' end
check(wrapper(nextFn,{battle={game={save={inventory={}}}}})=='native' and delegated==1,'without EXP.ALL vanilla award path is untouched')

local a={name='A',hp=20,exp=100};local b={name='B',hp=20,exp=200};local c={name='C',hp=0,exp=300}
local announcements={};local shares={}
local battle={player={mon=a},game={save={inventory={EXP_ALL=1},party={a,b,c}}},sayNext=function(_,text) announcements[#announcements+1]=text end}
local ctx={battle=battle,alive={a},participants=2}
ctx.applyShare=function(mon,div,announce)
  shares[#shares+1]={mon=mon,div=div,announce=announce}
  mon.exp=mon.exp+math.floor(120/div)
end
delegated=0
check(wrapper(nextFn,ctx)==true,'EXP.ALL path is handled by KRS presentation policy')
check(delegated==0,'native award orchestration is replaced only when EXP.ALL is active')
check(#shares==3,'participant pass plus two non-fainted team shares')
check(shares[1].mon==a and shares[1].div==4 and shares[1].announce==true,'participant divisor/announcement stays vanilla')
check(shares[2].div==12 and shares[2].announce==false and shares[3].div==12 and shares[3].announce==false,'second pass keeps vanilla divisor but suppresses individual text')
check(c.exp==300,'fainted party member is skipped in second EXP.ALL pass')
check(#announcements==1 and announcements[1]=='The rest of the team earned\n10 EXP!','one consolidated rest-of-team EXP message uses actual awarded EXP')
print('EXP.ALL summary tests passed')
