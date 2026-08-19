local SafeSave = {}

function SafeSave.writeAtomic(path, data)
  if not (love and love.filesystem) then
    return false, "love.filesystem unavailable"
  end

  local tempPath = path .. ".tmp"
  local bakPath = path .. ".bak"

  -- Ensure directory exists
  local dir = path:match("^(.-)/[^/]+$")
  if dir and love.filesystem.createDirectory then
    love.filesystem.createDirectory(dir)
  end

  -- Write to temporary file first
  local ok, err = love.filesystem.write(tempPath, data)
  if not ok then
    return false, "failed to write temp file: " .. tostring(err)
  end

  -- If original file exists, create backup
  if love.filesystem.getInfo and love.filesystem.getInfo(path) then
    local origData = love.filesystem.read(path)
    if origData then
      love.filesystem.write(bakPath, origData)
    end
    if love.filesystem.remove then
      love.filesystem.remove(path)
    end
  end

  -- Move temporary file to final path (or write final path)
  local finalOk, finalErr = love.filesystem.write(path, data)
  if love.filesystem.remove then
    love.filesystem.remove(tempPath)
  end

  return finalOk, finalErr
end

function SafeSave.loadWithBackup(path)
  if not (love and love.filesystem and love.filesystem.getInfo) then
    return nil, "love.filesystem unavailable"
  end

  if love.filesystem.getInfo(path) then
    local data, err = love.filesystem.read(path)
    if data then return data, nil end
  end

  local bakPath = path .. ".bak"
  if love.filesystem.getInfo(bakPath) then
    local data, err = love.filesystem.read(bakPath)
    if data then return data, "recovered from backup" end
  end

  return nil, "file not found"
end

return SafeSave
