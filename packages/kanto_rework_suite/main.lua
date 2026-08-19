-- Single native KRS entrypoint. Core owns internal Suite bootstrap/lifecycle.
return function(mod)
  local source, readErr = mod:read("modules/core/suite/bootstrap.lua")
  assert(type(source) == "string", readErr or "Unable to read Suite bootstrap")
  local chunk, compileErr = load(source, "@kanto_rework_suite/modules/core/suite/bootstrap.lua")
  assert(chunk, compileErr or "Unable to compile Suite bootstrap")
  local bootstrap = chunk()
  assert(type(bootstrap) == "function", "Suite bootstrap did not return a function")
  return bootstrap(mod)
end
