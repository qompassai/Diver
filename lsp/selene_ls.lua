-- /qompassai/Diver/lsp/selene3p_ls.lua
-- Qompass AI Selene 3P LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config['selene_ls'] = {
  cmd = {
    'selene',
  },
  filetypes = {
    'lua',
    "luau"
  },
  root_markers = {
    '.selene.toml',
    'selene.toml',
    '.git'
  },
  on_attach = function(client, bufnr)
    client.server_capabilities.documentFormattingProvider = false
  end,
}