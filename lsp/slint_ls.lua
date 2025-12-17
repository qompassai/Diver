-- /qompassai/Diver/lsp/slint_ls.lua
-- Qompass AI Slint (formerly SixyFPS) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.cmd([[ autocmd BufRead,BufNewFile *.slint set filetype=slint ]])
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'slint-lsp',
  },
  filetypes = { ---@type string[]
    'slint',
  },
  root_markers = { ---@type string[]
    '.git',
  },
}