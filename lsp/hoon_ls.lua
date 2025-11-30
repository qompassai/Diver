-- /qompassai/Diver/lsp/hoon_ls.lua
-- Qompass AI Hoon LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['hoon_ls'] = {
  cmd = {
    'hoon-language-server',
    '-p', '8080',
    '-u', 'http://localhost',
    '-s', 'zod',
    -- '-c',
    -- 'tbd'
  },
  filetypes = {
    'hoon'
  },
  root_markers = {
    '.git'
  },
}