local root=assert(arg[1],"root path required")
local Names=assert(loadfile(root.."/runtime/character_names.lua"))()()
local game={save={player={name='RED',rival='BLUE'}},overworld={map={id='OAKS_LAB'}}}

local function expect(keys,expected,label)
  for _,key in ipairs(keys) do
    local actual=Names.fromTextKey(game,key)
    assert(actual==expected,(label or key)..": expected "..tostring(expected)..", got "..tostring(actual))
  end
end

-- Full Red/Blue Oak's Lab speaking-event audit. These are every authored
-- Oak/Rival line used by the starter, lab battle and parcel/Pokédex chain;
-- receipt rows are checked separately as narration.
expect({
  '_OaksLabYouWantCharmanderText','_OaksLabYouWantSquirtleText',
  '_OaksLabYouWantBulbasaurText','_OaksLabThoseArePokeBallsText',
  '_OaksLabOak1DeliverParcelText','_OaksLabOak1ParcelThanksText',
  '_OaksLabOakIHaveARequestText','_OaksLabOakMyInventionPokedexText',
  '_OaksLabOakThatWasMyDreamText','_OaksLabOak1RaiseYourYoungPokemonText',
  '_OaksLabOak1WhichPokemonDoYouWantText','_OaksLabOak1YourPokemonCanFightText',
  '_OaksLabOak1PokemonAroundTheWorldText','_OaksLabGivePokeballsExplanationText',
  '_OaksLabOak1ComeSeeMeSometimesText','_OaksLabOak1HowIsYourPokedexComingText',
  '_OaksLabOakDontGoAwayYetText',
},'PROFESSOR OAK','Oak Lab Oak event')

expect({
  '_OaksLabRivalIllTakeThisOneText','_OaksLabRivalGrampsText',
  '_OaksLabRivalWhatDidYouCallMeForText','_OaksLabRivalLeaveItAllToMeText',
  '_OaksLabRivalMyPokemonLooksStrongerText','_OaksLabRivalGoAheadAndChooseText',
  '_OaksLabRivalGrampsIsntAroundText','_OaksLabRivalIllTakeYouOnText',
  '_OaksLabRivalIPickedTheWrongPokemonText','_OaksLabRivalSmellYouLaterText',
},'BLUE','Oak Lab rival event')

for _,key in ipairs({
  '_OaksLabReceivedMonText','_OaksLabRivalReceivedMonText',
  '_OaksLabOakGotPokedexText','_OaksLabOak1ReceivedPokeballsText',
}) do
  local speaker,handled=Names.eventSpeaker(game,key)
  assert(handled==true and speaker==nil,key..' must remain narration without a speaker chip')
end

-- Deterministic named-event precedence outside the lab. This guards against
-- unordered table iteration reintroducing actor swaps in gyms/cutscenes.
local canonical={
  _BrockPreBattleText='BROCK',_MistyAfterBattleText='MISTY',
  _LtSurgePreBattleText='LT. SURGE',_ErikaPostBattleText='ERIKA',
  _KogaPreBattleText='KOGA',_SabrinaPostBattleText='SABRINA',
  _BlainePreBattleText='BLAINE',_GiovanniPostBattleText='GIOVANNI',
  _LoreleiBeforeBattleText='LORELEI',_BrunoBeforeBattleText='BRUNO',
  _AgathaBeforeBattleText='AGATHA',_LanceBeforeBattleText='LANCE',
  _PokemonCenterNurseJoyText='NURSE JOY',_PokemonTowerMrFujiText='MR. FUJI',
  _BillsHouseBillText='BILL',_BluesHouseDaisyText='DAISY',
}
for key,expected in pairs(canonical) do
  assert(Names.fromTextKey(game,key)==expected,key..' canonical event owner changed')
end

assert(Names.fromTextKey(game,'_FoundPotionText')==nil,
  'unowned system/item text must not invent an event speaker')
print('Event speaker ownership audit passed')
