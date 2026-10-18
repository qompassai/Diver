#!/usr/bin/env lua
-- /qompassai/Diver/lua/security/red/init.lua
-- Qompass AI Diver Redteam Utils
local M = {}
local modules = { ---@version JIT
    'red',
    'shark',
    'tomcat',
}
for _, module in ipairs(modules) do
    require('security.red.' .. module)
end
return M
