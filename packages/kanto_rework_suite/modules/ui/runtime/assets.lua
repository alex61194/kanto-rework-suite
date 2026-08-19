-- UI-only image cache. Runtime asset paths/resolution come from Core.
return function(deps)
  local Core=assert(deps.Core,"Core exports are required")
  local Assets={};Assets.__index=Assets
  function Assets.new() return setmetatable({images={},quads={}},Assets) end
  function Assets:image(path,filter)
    if not path then return nil end
    local resolved=type(Core.resolveAssetPath)=="function" and Core.resolveAssetPath(path) or path
    local key=tostring(resolved).."|"..tostring(filter or "linear")
    if self.images[key]~=nil then return self.images[key] or nil end
    if not (love and love.graphics and love.graphics.newImage) then self.images[key]=false;return nil end
    local ok,img=pcall(love.graphics.newImage,resolved);if not ok then self.images[key]=false;return nil end
    if img.setFilter then local f=filter=="nearest" and "nearest" or "linear";pcall(img.setFilter,img,f,f) end
    self.images[key]=img;return img
  end
  function Assets:trainerPortrait(model)
    local p=model and model.portrait
    if not p then return nil end
    local meta=type(p.meta)=='table' and p.meta or {}
    local filter=meta.filter or (p.trueColor and "linear" or "nearest")
    return self:image(p.path,filter)
  end
  function Assets:badgeSheet(model)
    if not model then return nil end
    local path=model.badgeSheetPath
    if not path and type(model.badges)=="table" then path=model.badges.sheetPath end
    return path and self:image(path,"nearest") or nil
  end
  function Assets:badgeQuad(img,index,owned)
    if not (img and love and love.graphics and love.graphics.newQuad) then return nil end
    local key=tostring(img)..":"..tostring(index)..":"..tostring(owned)
    if self.quads[key] then return self.quads[key] end
    local iw,ih=img:getDimensions();local y=(index-1)*32+(owned and 16 or 0);if y+16>ih then return nil end
    local q=love.graphics.newQuad(0,y,16,16,iw,ih);self.quads[key]=q;return q
  end
  return Assets
end
