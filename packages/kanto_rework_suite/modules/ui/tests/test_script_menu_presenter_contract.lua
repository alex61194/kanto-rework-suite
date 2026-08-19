local ListMenu={};ListMenu.__index=ListMenu
package.preload['src.ui.ListMenu']=function() return ListMenu end
local taps={}
local runtime={
  viewport={width=1920,height=1080},
  Layout={isWide=function() return true end,contains=function(x,y,r) return x>=r.x and y>=r.y and x<r.x+r.w and y<r.y+r.h end},
  mod={input={tap=function(_,_,action) taps[#taps+1]=action end}},
}
local P=assert(loadfile('../ui/script_menu_presenter.lua'))()(runtime)
local ow={};local state=setmetatable({script=true,items={{label='ONE'},{label='TWO'}},index=1},ListMenu)
local stack={states={ow,state},top=function(self)return self.states[#self.states] end}
local game={overworld=ow,stack=stack}
assert(P.handles(game,state,runtime.viewport),'overworld script ListMenu must use generic KRS presenter')
state.kind='shop_buy';assert(not P.handles(game,state,runtime.viewport),'specialized shop menu must not be stolen')
state.kind=nil;state.__kantoPocketState={};assert(not P.handles(game,state,runtime.viewport),'specialized Bag list must not be stolen')
state.__kantoPocketState=nil
runtime.scriptMenuRects={[2]={x=10,y=10,w=100,h=40}}
assert(P.pointer(game,{phase='pressed',source='mouse',button=1},20,20)==true and state.index==2 and taps[#taps]=='a','pointer confirms through native A action')
assert(P.pointer(game,{phase='pressed',source='mouse',button=2},0,0)==true and taps[#taps]=='b','right click maps to native Back')
assert(P.wheel(game,1)==true and taps[#taps]=='down','wheel maps to native list navigation')
print('PASS test_script_menu_presenter_contract')
