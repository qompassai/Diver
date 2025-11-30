-- /qompassai/Diver/lsp/basics_ls.lua
-- Qompass AI basics_ls LSP Config
 -- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------------------
vim.lsp.config['basics_ls'] = {
  cmd = {
    'basics-language-server',
  },
  filetypes = {
    'lua',
    'markdown',
    'text',
  },
  root_markers = {
    '.git',
  },
}