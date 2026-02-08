#!/usr/bin/env lua
-- /home/phaedrus/.config/nvim/lua/config/lang/init.lua
-- Qompass AI Diver Language Config Init
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------------
local M = {}
local modules = { ---@version JIT
    'arduino',
    'bash',
    'c',
    'cmp',
    'cpp',
    'css',
    'elixir',
    'go',
    'js',
    'julia',
    'kotlin',
    'latex',
    'lua',
    'mojo',
    'nix',
    'odin',
    'php',
    'python',
    'ruby',
    'rust',
    'scala',
    'toml',
    'ts',
    'zig',
}

for _, module in ipairs(modules) do
    require('config.lang.' .. module)
end
return M
