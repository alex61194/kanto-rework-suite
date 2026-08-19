-- Presentation-only species labels. Internal species IDs and save data stay
-- untouched; KRS merely restores the canonical gender marks for Nidoran.
return function(value,species,def,isNickname)
  if isNickname then return tostring(value or species or "POKéMON") end
  local dex=def and tonumber(def.dex)
  local id=tostring(species or ""):upper()
  if dex==29 or id=="NIDORAN_F" or id=="NIDORAN_FEMALE" then return "NIDORAN♀" end
  if dex==32 or id=="NIDORAN_M" or id=="NIDORAN_MALE" then return "NIDORAN♂" end
  return tostring(value or species or "POKéMON")
end
