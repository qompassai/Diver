-- /qompassai/Diver/ftplugin/gleam.lua
-- Qompass AI Gleam Ftplugin config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local root_markers = { 'gleam.toml' }
local root_dir = vim.fs.root(0, root_markers)
print(root_dir)