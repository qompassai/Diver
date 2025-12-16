-- /qompassai/Diver/lsp/hoon_ls.lua
-- Qompass AI Hoon LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'hoon-language-server',
    '-p',
    '8080',
    '-u',
    'http://localhost',
    '-s',
    'zod',
    '-d',
    '0',
  },
  filetypes = { ---@type string[]
    'hoon',
  },
  root_markers = { ---@type string[]
    '.git',
  },
}