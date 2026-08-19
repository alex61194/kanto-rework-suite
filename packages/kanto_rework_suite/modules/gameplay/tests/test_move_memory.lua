local root=assert(arg[1],"root path required")
local MoveLearnMenu={}
MoveLearnMenu.enter=function(self) self.vanillaEntered=true end
local PartyMenu={}
PartyMenu.new=function(game,opts) return {game=game,opts=opts} end
local ListMenu={}
ListMenu.new=function(game,title,rows,opts) return {game=game,title=title,rows=rows,opts=opts} end
local ItemEffects={}
ItemEffects.use=function(...) return "failed",{"native"} end
local TextBox={}
TextBox.new=function(game,message,onDone,opts) return {message=message,onDone=onDone,opts=opts} end
TextBox.soundOpts=function() return {} end
package.preload['src.ui.MoveLearnMenu']=function() return MoveLearnMenu end
package.preload['src.ui.PartyMenu']=function() return PartyMenu end
package.preload['src.ui.ListMenu']=function() return ListMenu end
package.preload['src.inventory.ItemEffects']=function() return ItemEffects end
package.preload['src.render.TextBox']=function() return TextBox end
package.preload['src.core.Sound']=function() return {} end
local rememberedCalls={}
local Core={
  knownMoves=function(mon,includeActive) return {{id='EMBER',pp=7,ppUps=0}} end,
  rememberKnownMove=function(mon,id,pp,ups,source) rememberedCalls[#rememberedCalls+1]={mon=mon,id=id,pp=pp,ups=ups,source=source};return true end,
  restoreKnownMovePP=function(mon,id,amount,full) rememberedCalls[#rememberedCalls+1]={restore=id,amount=amount,full=full};return true end,
  ppUpKnownMove=function(mon,id) rememberedCalls[#rememberedCalls+1]={ppup=id};return true end,
}
local game={data={moves={EMBER={name='EMBER',pp=25},SURF={name='SURF',pp=15},TACKLE={name='TACKLE',pp=35}}},save={}}
local factory=assert(loadfile(root..'/move_memory.lua'))()
local adapter=factory({Core=Core,Game=game})
local mon={species='PIKACHU',nickname='PIKA',moves={{id='TACKLE',pp=5},{id='A',pp=1},{id='B',pp=1},{id='C',pp=1}}}
local stack={states={}}
function stack:top() return self.states[#self.states] end
function stack:push(v) self.states[#self.states+1]=v end
function stack:pop() return table.remove(self.states) end
game.stack=stack
local done
local learn=setmetatable({game=game,mon=mon,newMoveId='SURF',learnedSound='Get_Item1',onDone=function(v) done=v end},{__index=MoveLearnMenu})
stack.states={learn}
MoveLearnMenu.enter(learn)
assert(rememberedCalls[1] and rememberedCalls[1].id=='SURF' and rememberedCalls[1].pp==15,"full moveset learns into permanent memory")
local box=stack:top();assert(box~=learn and box.message:find('MOVE MEMORY',1,true),"full moveset no longer opens forget prompt")
stack:pop();box.onDone();assert(done==true,"learn flow continues as learned")
local built
local picker=PartyMenu.new(game,{pickOnly=true,battle=nil,onSwitch=function(target)
  built=ListMenu.new(game,'Which move?',{{value=1,label='TACKLE',right='5'}},{})
end})
picker.opts.onSwitch(mon)
assert(#built.rows==2 and built.rows[2].krsRemembered and built.rows[2].value.krsKnownMove=='EMBER',"PP item target list includes inactive remembered moves outside battle")
local battleBuilt
local battlePicker=PartyMenu.new(game,{pickOnly=true,battle={},onSwitch=function(target)
  battleBuilt=ListMenu.new(game,'Which move?',{{value=1,label='TACKLE',right='5'}},{})
end})
battlePicker.opts.onSwitch(mon)
assert(#battleBuilt.rows==1,"battle item targeting never exposes inactive remembered moves")
local result=ItemEffects.use(game.data,game.save,'ETHER',mon,nil,{krsKnownMove='EMBER'})
assert(result=='consumed' and rememberedCalls[#rememberedCalls].restore=='EMBER',"Ether can restore inactive remembered move outside battle")
local battleResult=ItemEffects.use(game.data,game.save,'ETHER',mon,{}, {krsKnownMove='EMBER'})
assert(battleResult=='failed',"battle path remains native and cannot target move memory")
assert(adapter.status().battleSwap==false and adapter.status().ppPersistent==true,"adapter advertises no battle swaps and persistent PP")
assert(adapter.uninstall(),"move-memory adapter uninstalls cleanly")
print("Move memory gameplay integration tests passed")
