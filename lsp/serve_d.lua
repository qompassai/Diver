-- /qompassai/Diver/lsp/serve_d.lua
-- Qompass AI Serve-D LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config['serve_d'] = {
  cmd = { 'serve-d' },
  filetypes = { 'd', 'dml' },
  root_dir = vim.fn.getcwd,
  single_file_support = true,
  init_options = {
    workspaceFolders    = { vim.fn.getcwd() },
    enableDmdCompletion = true,
    enableDubLinting    = true,
  },
  settings = {},
  flags = {
    debounce_text_changes = 150,
  },
}