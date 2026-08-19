local S=assert(loadfile('../speed_stage.lua'))()
local prev=0
for stage=-6,6 do
  local rate=S.rate(stage)
  assert(rate>0,'rate must remain positive')
  if stage>-6 then assert(rate>prev,'mapping must be strictly monotone') end
  prev=rate
end
assert(math.abs(S.rate(0)-1)<1e-9,'stage 0 is configured base speed')
assert(math.abs(S.rate(6)-math.sqrt(2))<1e-9,'+6 rate = sqrt(2)')
assert(math.abs(S.rate(-6)-1/math.sqrt(2))<1e-9,'-6 rate = 1/sqrt(2)')
assert(S.duration(100,6)<100 and S.duration(100,-6)>100,'duration accelerates/decelerates in expected direction')
assert(S.duration(12,-6)>=12 and S.duration(1,6)>=12,'never negative/frozen; renderer floor retained')
assert(S.clamp(99)==6 and S.clamp(-99)==-6,'stage is bounded')
print('PASS test_speed_stage')
