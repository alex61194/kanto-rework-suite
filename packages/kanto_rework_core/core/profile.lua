local function serializeValue(val, indent)
  indent = indent or ""
  local t = type(val)
  if t == "number" or t == "boolean" then
    return tostring(val)
  elseif t == "string" then
    return string.format("%q", val)
  elseif t == "table" then
    local out = { "{\n" }
    local nextIndent = indent .. "  "
    for k, v in pairs(val) do
      local keyStr
      if type(k) == "string" and k:match("^[%a_][%w_]*$") then
        keyStr = k
      else
        keyStr = "[" .. serializeValue(k, nextIndent) .. "]"
      end
      out[#out + 1] = string.format("%s%s = %s,\n", nextIndent, keyStr, serializeValue(v, nextIndent))
    end
    out[#out + 1] = indent .. "}"
    return table.concat(out)
  else
    return "nil"
  end
end

local function createProfileStore(opts)
  opts = opts or {}
  local path = opts.path or "kanto_rework/profiles/default.lua"
  local defaults = opts.defaults or {
    language = "es",
    theme = "field_journal",
    overlayVisible = true,
    widgetLocked = false,
    widgetX = 0.04,
    widgetY = 0.08,
  }

  local function copyTable(t)
    local out = {}
    for k, v in pairs(t) do
      if type(v) == "table" then
        out[k] = copyTable(v)
      else
        out[k] = v
      end
    end
    return out
  end

  local function load()
    local profile = copyTable(defaults)
    if not (love and love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(path)) then
      return profile, nil
    end

    local chunk, err = love.filesystem.load(path)
    if not chunk then
      return profile, err
    end

    local ok, data = pcall(chunk)
    if not ok or type(data) ~= "table" then
      return profile, data or "invalid profile format"
    end

    for k, v in pairs(data) do
      profile[k] = v
    end

    return profile, nil
  end

  local function save(data)
    if not (love and love.filesystem) then
      return false, "love.filesystem unavailable"
    end

    local dir = path:match("^(.-)/[^/]+$")
    if dir and love.filesystem.createDirectory then
      love.filesystem.createDirectory(dir)
    end

    local content = "return " .. serializeValue(data or defaults) .. "\n"
    local ok, err = love.filesystem.write(path, content)
    return ok, err
  end

  return {
    load = load,
    save = save,
    defaults = defaults,
  }
end

return createProfileStore
