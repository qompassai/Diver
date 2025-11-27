-- /qompassai/Diver/lsp/htmlhint.lua
-- Qompass AI HTMLHint Spec (htmlhint CLI)
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['htmlhint'] = {
  cmd = { 'htmlhint' },
  filetypes = { 'html', 'htm' },
  codeActionProvider = false,
  colorProvider = false,
  semanticTokensProvider = nil,
  settings = {
    htmlhint = {
    },
  },
  flags = {
    debounce_text_changes = 150,
  },
  single_file_support = true,
}