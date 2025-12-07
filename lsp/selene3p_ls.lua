-- /qompassai/Diver/lsp/selene3p_ls.lua
-- Qompass AI Selene 3rd Party LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/antonk52/lua-3p-language-servers
--pnpm add -g lua-3p-language-servers
vim.lsp.config['selene3p_ls'] = {
  cmd = {
    'selene-3p-language-server'
  },
  filetypes = {
    'lua'
  },
  root_markers = {
    'selene.toml'
  },
}