local root=assert(arg[1],'root path required')
local factory=assert(loadfile(root..'/core/mod_integration_registry.lua'))()
local service=factory()
local opened=false
service.register({id='compat.high',modId='kanto_rework_suite',priority=500,decorateOptions=function(_,rows)return rows end})
service.register({id='ui.editor',modId='kanto_rework_suite',priority=300,utilities=function()
  return {{id='live_battle_editor',label='LIVE BATTLE GRAPHICS EDITOR',group='VISUALS',open=function() opened=true;return {kind='graphics_editor'} end}}
end})
local manifest={id='kanto_rework_suite'}
local rows=service.utilities({},manifest)
assert(#rows==1 and rows[1].id=='live_battle_editor','lower-priority additive utility must not be shadowed by primary Suite adapter')
local ok,state,err=service.openUtility({},manifest,'live_battle_editor')
assert(ok and state and state.kind=='graphics_editor' and opened==true,err or 'utility open failed')
print('Additive mod utility resolution tests passed')
