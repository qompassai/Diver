#!/usr/bin/env lua
-- /home/phaedrus/.config/nvim/lua/conf/ui/init.lua
-- Qompass AI Diver UI Init
-- Copyright (C) 2026 Qompass AI, All rights reserved
-----------------------------------------------------
local M = {}
local modules = { ---@version JIT
    'colors',
    'decor',
    'icons',
    'illuminate',
    'line',
    'md',
    'nerd',
    'padding',
    'render',
    'themes',
}
for _, module in ipairs(modules) do
    require('conf.ui.' .. module)
  end
return M