local Layout={}

function Layout.build(info,lineCount,hasAuthor,reserveScrollbar,opts)
  opts=type(opts)=='table' and opts or {}
  lineCount=math.max(1,math.floor(tonumber(lineCount) or 1))
  local topInset=math.max(0,tonumber(opts.topInset) or 98)
  local bottomInset=math.max(8,tonumber(opts.bottomInset) or 8)
  local minCardH=math.max(0,tonumber(opts.minCardH) or 516)
  local card={x=info.x+24,y=info.y+topInset,w=info.w-48,h=0}
  local maxCardH=math.max(0,(info.y+info.h-bottomInset)-card.y)
  local innerPad=20
  local y=0
  local model={nameY=y};y=y+36
  model.versionY=y;y=y+(hasAuthor and 24 or 34)
  if hasAuthor then model.authorY=y;y=y+30 end
  model.descriptionY=y;model.descriptionH=math.max(17,lineCount*17);y=y+model.descriptionH+20
  model.dividerOneY=y;y=y+20
  model.stateY=y;y=y+36
  model.compatibilityY=y;y=y+38
  model.dividerTwoY=y;y=y+22
  model.permissionsTitleY=y;y=y+28
  model.permissionY=y;y=y+72
  model.contentH=y
  local naturalH=model.contentH+innerPad*2
  -- The available panel height is the hard boundary. A canonical minimum is
  -- useful only when it fits; it must never force the card through the outer
  -- panel/footer after an optional preview consumes vertical space.
  card.h=math.min(maxCardH,math.max(math.min(minCardH,maxCardH),naturalH))
  local view={x=card.x+innerPad,y=card.y+innerPad,w=math.max(0,card.w-innerPad*2-(reserveScrollbar and 20 or 0)),h=math.max(0,card.h-innerPad*2)}
  return {card=card,view=view,model=model,maxCardH=maxCardH,gapToOuterBottom=(info.y+info.h)-(card.y+card.h),topInset=topInset,bottomInset=bottomInset}
end

return Layout
