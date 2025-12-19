-- /qompassai/Diver/ftplugin/gleam.lua
-- Qompass AI Diver Gleam FTplugin config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local root_markers = { ---@type string[]
  'gleam.toml'
}
local root_dir = vim.fs.root(0, root_markers) ---@type string|nil
if root_dir ~= nil then
  print(root_dir)
  vim.lsp.start({
    cmd = {
      'gleam',
      'lsp'
    },
    root_dir = root_dir
  })
end