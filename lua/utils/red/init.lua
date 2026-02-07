#!/usr/bin/env lua
-- /qompassai/Diver/lua/utils/red/init.lua
-- Qompass AI Diver Redteam Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
local modules = { ---@version JIT
    'red',
    'tomcat',
    'shark',
}
for _, module in ipairs(modules) do
    require('utils.red.' .. module)
end
return M
