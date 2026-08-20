local T={VERSION="0.1.0",DEFAULT="firered",ORDER={"firered","cream","graphite","purplenight","retro","emerald"}}

local function rgb(hex)
  hex=hex:gsub("#","")
  return {tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255,1}
end

local function theme(id,label,figmaMode,fontFamily,colors,screen)
  return {id=id,label=label,figmaMode=figmaMode,fontFamily=fontFamily,colors=colors,screen=screen or {}}
end

T.themes={
  firered=theme("firered","ROJO FUEGO","FireRed","kanto_rework.inter",{
    canvas=rgb("#140A0C"),panel=rgb("#221216"),elevated=rgb("#321A20"),subtle=rgb("#221216"),
    header=rgb("#1A0D10"),ink=rgb("#FFFFFF"),muted=rgb("#F0C0C0"),faint=rgb("#E09090"),
    border=rgb("#5A2832"),borderStrong=rgb("#FF2A4D"),focus=rgb("#FF2A4D"),interactiveSelected=rgb("#FF5252"),
    selectionGold=rgb("#FFA000"),info=rgb("#29B6F6"),white=rgb("#FFFFFF"),textInverse=rgb("#FFFFFF"),
    hpFull=rgb("#00E676"),hpMid=rgb("#FFB300"),hpCritical=rgb("#FF1744"),exp=rgb("#00E5FF"),
    structure=rgb("#140A0C"),structureRaised=rgb("#221216"),structureText=rgb("#FFFFFF"),structureMuted=rgb("#F0C0C0"),
    mainCardHover=rgb("#FFA000"),navSelectedFill=rgb("#FF2A4D"),navSelectedStroke=rgb("#FF2A4D"),navSelectedText=rgb("#FFFFFF"),
    headerAccent=rgb("#FF2A4D"),headerFocus=rgb("#FFA000"),mainHeaderAccent=rgb("#FF2A4D"),
  },{
    optionsCanvas=rgb("#140A0C"),optionsRail=rgb("#140A0C"),optionsCenter=rgb("#321A20"),optionsInfo=rgb("#221216"),optionsRow=rgb("#221216"),optionsFocus=rgb("#FF2A4D"),bagFocus=rgb("#FF2A4D"),modsFocus=rgb("#FF2A4D"),pcBank=rgb("#221216"),pcSurface=rgb("#221216"),pcBorder=rgb("#5A2832"),pcSearch=rgb("#221216"),pcSearchBorder=rgb("#5A2832"),pcScrollbarTrack=rgb("#5A2832"),pcScrollbarThumb=rgb("#FF2A4D"),pcSelectedFill=rgb("#321A20"),pcSelectedStroke=rgb("#321A20"),pcSelectedRail=rgb("#FF2A4D"),
  }),

  cream=theme("cream","CREAM","Field Journal","kanto_rework.inter",{
    canvas=rgb("#F0E8D1"),panel=rgb("#FFFFFF"),elevated=rgb("#FFFDF6"),subtle=rgb("#F7F1DF"),
    header=rgb("#141311"),ink=rgb("#141311"),muted=rgb("#615C4F"),faint=rgb("#9B9584"),
    border=rgb("#DBD1B5"),borderStrong=rgb("#817B6B"),focus=rgb("#00748C"),interactiveSelected=rgb("#0F475C"),
    selectionGold=rgb("#F2C229"),info=rgb("#12627A"),white=rgb("#F7F1DF"),textInverse=rgb("#F7F1DF"),
    hpFull=rgb("#1F6F46"),hpMid=rgb("#986600"),hpCritical=rgb("#B4362D"),exp=rgb("#12627A"),
    structure=rgb("#141311"),structureRaised=rgb("#1F1E1B"),structureText=rgb("#F7F1DF"),structureMuted=rgb("#9B9584"),
    mainCardHover=rgb("#00BBE2"),navSelectedFill=rgb("#F2C229"),navSelectedStroke=rgb("#F2C229"),navSelectedText=rgb("#141311"),
    headerAccent=rgb("#00748C"),headerFocus=rgb("#00748C"),mainHeaderAccent=rgb("#00748C"),
  },{
    optionsCanvas=rgb("#F0E8D1"),optionsRail=rgb("#141311"),optionsCenter=rgb("#F7F1DF"),optionsInfo=rgb("#FBFAF5"),optionsRow=rgb("#FBFAF5"),optionsFocus=rgb("#00748C"),bagFocus=rgb("#00748C"),modsFocus=rgb("#00748C"),pcBank=rgb("#FFFFFF"),pcSurface=rgb("#FAF7F0"),pcBorder=rgb("#E0DBD1"),pcSearch=rgb("#F7F1DF"),pcSearchBorder=rgb("#DBD1B5"),pcScrollbarTrack=rgb("#D9D4C7"),pcScrollbarThumb=rgb("#387D8C"),pcSelectedFill=rgb("#141311"),pcSelectedStroke=rgb("#141311"),pcSelectedRail=rgb("#00748C"),
  }),

  graphite=theme("graphite","GRAPHITE","Graphite","kanto_rework.inter",{
    canvas=rgb("#141311"),panel=rgb("#28251F"),elevated=rgb("#3D392F"),subtle=rgb("#28251F"),
    header=rgb("#F7F1DF"),ink=rgb("#F7F1DF"),muted=rgb("#DBD1B5"),faint=rgb("#C6B98F"),
    border=rgb("#615C4F"),borderStrong=rgb("#C6B98F"),focus=rgb("#28C8E6"),interactiveSelected=rgb("#2A9DBE"),
    selectionGold=rgb("#F2C229"),info=rgb("#3EB6D6"),white=rgb("#141311"),textInverse=rgb("#141311"),
    hpFull=rgb("#4CCE79"),hpMid=rgb("#F5B82E"),hpCritical=rgb("#EF5348"),exp=rgb("#3EB6D6"),
    structure=rgb("#141311"),structureRaised=rgb("#28251F"),structureText=rgb("#F7F1DF"),structureMuted=rgb("#C6B98F"),
    mainCardHover=rgb("#00BBE2"),navSelectedFill=rgb("#F2C229"),navSelectedStroke=rgb("#F2C229"),navSelectedText=rgb("#141311"),
    headerAccent=rgb("#C29B4B"),headerFocus=rgb("#C29B4B"),mainHeaderAccent=rgb("#28C8E6"),
  },{
    optionsCanvas=rgb("#141311"),optionsRail=rgb("#141311"),optionsCenter=rgb("#24231F"),optionsInfo=rgb("#141311"),optionsRow=rgb("#141311"),optionsFocus=rgb("#9B7832"),bagFocus=rgb("#C29B4B"),pcBank=rgb("#28251F"),pcSurface=rgb("#28251F"),pcBorder=rgb("#615C4F"),pcSearch=rgb("#28251F"),pcSearchBorder=rgb("#615C4F"),pcScrollbarTrack=rgb("#615C4F"),pcScrollbarThumb=rgb("#387D8C"),pcSelectedFill=rgb("#F7F1DF"),pcSelectedStroke=rgb("#615C4F"),pcSelectedRail=rgb("#E5A000"),
  }),

  purplenight=theme("purplenight","PURPLE NIGHT","Sombre","kanto_rework.inter",{
    canvas=rgb("#0C0A1C"),panel=rgb("#161230"),elevated=rgb("#221C44"),subtle=rgb("#161230"),
    header=rgb("#161230"),ink=rgb("#F2F0FA"),muted=rgb("#A098C8"),faint=rgb("#786EAA"),
    border=rgb("#342C5C"),borderStrong=rgb("#786EAA"),focus=rgb("#A08CF5"),interactiveSelected=rgb("#826EDC"),
    selectionGold=rgb("#F2C229"),info=rgb("#50C8F0"),white=rgb("#F2F0FA"),textInverse=rgb("#F2F0FA"),
    hpFull=rgb("#64E68C"),hpMid=rgb("#FFD23C"),hpCritical=rgb("#FF645A"),exp=rgb("#50C8F0"),
    structure=rgb("#0C0A1C"),structureRaised=rgb("#161230"),structureText=rgb("#F2F0FA"),structureMuted=rgb("#A098C8"),
    mainCardHover=rgb("#00BBE2"),navSelectedFill=rgb("#161230"),navSelectedStroke=rgb("#826EDC"),navSelectedText=rgb("#F2F0FA"),
    headerAccent=rgb("#00748C"),headerFocus=rgb("#00748C"),mainHeaderAccent=rgb("#00748C"),
  },{
    optionsCanvas=rgb("#0C0A1C"),optionsRail=rgb("#0C0A1C"),optionsCenter=rgb("#221C44"),optionsInfo=rgb("#161230"),optionsRow=rgb("#161230"),optionsFocus=rgb("#00748C"),bagFocus=rgb("#00748C"),modsFocus=rgb("#00748C"),pcBank=rgb("#161230"),pcSurface=rgb("#161230"),pcBorder=rgb("#342C5C"),pcSearch=rgb("#161230"),pcSearchBorder=rgb("#342C5C"),pcScrollbarTrack=rgb("#342C5C"),pcScrollbarThumb=rgb("#387D8C"),pcSelectedFill=rgb("#221C44"),pcSelectedStroke=rgb("#221C44"),pcSelectedRail=rgb("#00BBE2"),
  }),

  retro=theme("retro","RETRO","Retro","kanto_rework.pixelify_sans",{
    canvas=rgb("#FFFFFF"),panel=rgb("#F0F0F0"),elevated=rgb("#D8D8D8"),subtle=rgb("#F0F0F0"),
    header=rgb("#080808"),ink=rgb("#080808"),muted=rgb("#5C5C5C"),faint=rgb("#9C9C9C"),
    border=rgb("#9C9C9C"),borderStrong=rgb("#080808"),focus=rgb("#080808"),interactiveSelected=rgb("#141414"),
    selectionGold=rgb("#F2C229"),info=rgb("#282828"),white=rgb("#FFFFFF"),textInverse=rgb("#FFFFFF"),
    -- Figma keeps functional progress semantics coloured in Retro, just like
    -- its explicit coloured type/status exception.
    hpFull=rgb("#1F6F46"),hpMid=rgb("#986600"),hpCritical=rgb("#B4362D"),exp=rgb("#12627A"),
    structure=rgb("#141311"),structureRaised=rgb("#28251F"),structureText=rgb("#FFFFFF"),structureMuted=rgb("#9C9C9C"),
    mainCardHover=rgb("#888888"),navSelectedFill=rgb("#BFBFBF"),navSelectedStroke=rgb("#BFBFBF"),navSelectedText=rgb("#080808"),
    -- Retro navigation is monochrome in the canonical Retro mockups.
    headerAccent=rgb("#B4B4B4"),headerFocus=rgb("#B4B4B4"),mainHeaderAccent=rgb("#545454"),
  },{
    -- Retro Options mockup intentionally uses a light-gray workspace distinct from the white Main Menu canvas.
    optionsCanvas=rgb("#FFFFFF"),optionsRail=rgb("#080808"),optionsCenter=rgb("#F0F0F0"),optionsInfo=rgb("#F0F0F0"),optionsRow=rgb("#F0F0F0"),optionsFocus=rgb("#080808"),bagFocus=rgb("#080808"),modsFocus=rgb("#080808"),pcBank=rgb("#FFFFFF"),pcSurface=rgb("#F5F5F5"),pcBorder=rgb("#C8C8C8"),pcSearch=rgb("#F1F1F1"),pcSearchBorder=rgb("#545454"),pcScrollbarTrack=rgb("#D9D4C7"),pcScrollbarThumb=rgb("#545454"),pcSelectedFill=rgb("#080808"),pcSelectedStroke=rgb("#080808"),pcSelectedRail=rgb("#545454"),
  }),

  emerald=theme("emerald","GAMMA EMERALD","Emerald","kanto_rework.inter",{
    canvas=rgb("#091610"),panel=rgb("#122A1E"),elevated=rgb("#1B3D2C"),subtle=rgb("#122A1E"),
    header=rgb("#0D2218"),ink=rgb("#FFFFFF"),muted=rgb("#B9F6CA"),faint=rgb("#A5D6A7"),
    border=rgb("#1B4D36"),borderStrong=rgb("#00E676"),focus=rgb("#00E676"),interactiveSelected=rgb("#00C853"),
    selectionGold=rgb("#00E676"),info=rgb("#1DE9B6"),white=rgb("#FFFFFF"),textInverse=rgb("#FFFFFF"),
    hpFull=rgb("#00E676"),hpMid=rgb("#FFB300"),hpCritical=rgb("#FF5252"),exp=rgb("#00E5FF"),
    structure=rgb("#091610"),structureRaised=rgb("#122A1E"),structureText=rgb("#FFFFFF"),structureMuted=rgb("#B9F6CA"),
    mainCardHover=rgb("#1DE9B6"),navSelectedFill=rgb("#00E676"),navSelectedStroke=rgb("#00E676"),navSelectedText=rgb("#FFFFFF"),
    headerAccent=rgb("#00E676"),headerFocus=rgb("#00E676"),mainHeaderAccent=rgb("#1DE9B6"),
  },{
    optionsCanvas=rgb("#091610"),optionsRail=rgb("#091610"),optionsCenter=rgb("#1B3D2C"),optionsInfo=rgb("#122A1E"),optionsRow=rgb("#122A1E"),optionsFocus=rgb("#00E676"),bagFocus=rgb("#00E676"),modsFocus=rgb("#00E676"),pcBank=rgb("#122A1E"),pcSurface=rgb("#122A1E"),pcBorder=rgb("#1B4D36"),pcSearch=rgb("#122A1E"),pcSearchBorder=rgb("#1B4D36"),pcScrollbarTrack=rgb("#1B4D36"),pcScrollbarThumb=rgb("#00E676"),pcSelectedFill=rgb("#1B3D2C"),pcSelectedStroke=rgb("#1B3D2C"),pcSelectedRail=rgb("#00E676"),
  }),
}

function T.get(id) return T.themes[tostring(id or ""):lower()] or T.themes[T.DEFAULT] end
function T.valid(id) return T.themes[tostring(id or ""):lower()]~=nil end
return T
