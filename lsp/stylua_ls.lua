-- /qompassai/Diver/lsp/stylua_ls.lua
-- Qompass AI Stylua LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
-- References: https://docs.rs/crate/stylua/2.3.1
-- cargo install stylua --features luajit
vim.lsp.config['stylua_ls'] = {
  cmd = {
    'stylua',
    '--lsp' },
  filetypes = { 'lua', 'luau' },
  root_markers = {
    '.editorconfig',
    '.stylua.toml',
    'stylua.toml',
    '.git',
  },
  on_attach = function(client, bufnr)
    client.server_capabilities.documentFormattingProvider = true
    client.server_capabilities.documentRangeFormattingProvider = true
    client.server_capabilities.completionProvider = nil
    client.server_capabilities.hoverProvider = false
    client.server_capabilities.definitionProvider = false
    client.server_capabilities.referencesProvider = false
    client.server_capabilities.renameProvider = false
    client.server_capabilities.codeActionProvider = false
  end,
}