-- Deterministic battle-trainer art resolution. Asset ownership stays in
-- Graphics; Battle/UI consumers ask for one descriptor and never guess paths.
return function(deps)
  deps=deps or {}
  local static=(deps.battleIndex and deps.battleIndex.trainers) or {}
  local gen5=deps.gen5Index or {}
  local assetPath=deps.assetPath or function(path) return path end
  local warn=deps.warn
  local warned={}
  local api={}

  api.sources={ 'rom','gen1','gen2','gen3','gen5' }
  api.labels={rom='ROM / ORIGINAL',gen1='GEN I',gen2='GEN II',gen3='GEN III',gen5='GEN V'}

  local function sourceNumber(source)
    local s=tostring(source or 'rom'):lower()
    return tonumber(s:match('gen([1235])$') or s:match('^([1235])$'))
  end

  function api.slug(request)
    request=type(request)=='table' and request or {}
    local cls=tostring(request.oppClass or request.trainerId or request.id or ''):upper()
    local party=tonumber(request.partyIndex or request.trainerParty or 1) or 1
    if cls=='OPP_ROCKET' and party>=42 then return 'jessie-james' end
    cls=cls:gsub('^OPP_',''):lower():gsub('_','-'):gsub('%s+','-'):gsub('[^%w%-]','')
    return cls~='' and cls or nil
  end

  local function chain(source)
    local n=sourceNumber(source)
    if n==5 then return {5,3,2,1} end
    if n==3 then return {3,2,1} end
    if n==2 then return {2,1} end
    if n==1 then return {1} end
    return {}
  end

  local function descriptor(gen,slug)
    if gen==5 then
      local rec=gen5[slug]
      if not rec then return nil end
      local out={}
      for k,v in pairs(rec) do out[k]=v end
      out.path=out.path and assetPath(out.path) or nil
      out.assetId=rec.path
      out.generation=5;out.source='gen5';out.animated=(out.frameCount or 1)>1
      out.atlas={path=out.path,frameWidth=out.frameWidth,frameHeight=out.frameHeight,
        columns=out.columns,rows=out.rows,frameCount=out.frameCount,durationsMs=out.durationsMs,loop=true}
      return out
    end
    local relative=static[tostring(gen)] and static[tostring(gen)][slug]
    if not relative then return nil end
    return {path=assetPath(relative),assetId=relative,trueColor=true,filter='nearest',
      generation=gen,source='gen'..gen,animated=false,frameCount=1,loop=false}
  end

  function api.resolve(selected,request)
    selected=tostring(selected or 'rom'):lower()
    local slug=api.slug(request)
    if selected=='rom' or not slug then
      return {native=true,slug=slug,requestedSource=selected,resolvedSource='rom',fallback=selected~='rom'}
    end
    local tried={}
    for _,gen in ipairs(chain(selected)) do
      tried[#tried+1]='gen'..gen
      local out=descriptor(gen,slug)
      if out then
        out.slug=slug;out.requestedSource=selected;out.resolvedSource='gen'..gen
        out.fallback=out.resolvedSource~=selected;out.tried=tried
        if out.fallback and warn then
          local key=selected..'|'..slug..'|'..out.resolvedSource
          if not warned[key] then
            warned[key]=true
            warn(('Trainer Art fallback %s: %s -> %s'):format(slug,selected,out.resolvedSource))
          end
        end
        return out
      end
    end
    local out={native=true,slug=slug,requestedSource=selected,resolvedSource='rom',fallback=true,tried=tried}
    if warn then
      local key=selected..'|'..slug..'|rom'
      if not warned[key] then warned[key]=true;warn(('Trainer Art fallback %s: %s -> ROM'):format(slug,selected)) end
    end
    return out
  end

  return api
end
