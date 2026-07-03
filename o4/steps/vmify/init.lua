local Step      = require "step"
local Compiler  = require "steps.vmify.compiler"

local Vmify = Step:extend()
Vmify.Name        = "Vmify"
Vmify.Description = "Prometheus-style register VM (no newproxy/select)"
Vmify.SettingsDescriptor = {}

function Vmify:init() end

function Vmify:apply(ast)
  local c = Compiler:new()
  return c:compile(ast)
end

return Vmify
