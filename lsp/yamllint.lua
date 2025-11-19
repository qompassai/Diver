-- /qompassai/Diver/lsp/yamllint.lua
-- Qompass AI YAML Lint Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['yamllint'] = {
  cmd = { 'yamllint' },
  filetypes = { 'yaml', 'yaml.ansible' },
  codeActionProvider = false,
  colorProvider = false,
  semanticTokensProvider = nil,
  settings = {
    yamllint = {
      config_file = vim.fn.expand('~/.config/yamllint/config'),
    },
  },
  flags = {
    debounce_text_changes = 150,
  },
  single_file_support = true,
}