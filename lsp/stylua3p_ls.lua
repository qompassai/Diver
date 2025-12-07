-- /qompassai/Diver/lsp/stylua3p_ls.lua
-- Qompass AI Stylua 3rd Party LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/antonk52/lua-3p-language-servers
vim.lsp.config['stylua3p_ls'] = {
  cmd = {
    'stylua-3p-language-server'
  },
  filetypes = {
    'lua'
  },
  root_markers = {
    '.stylua.toml',
    'stylua.toml'
  },
}