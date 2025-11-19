-- /qompassai/Diver/lsp/stylua.lua
-- Qompass AI Lua Formatter Spec (StyLua)
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['stylua'] = {
  cmd = { 'stylua' },
  filetypes = { 'lua', 'luau' },
  codeActionProvider = false,
  colorProvider = false,
  semanticTokensProvider = nil,
  settings = {
    stylua = {
    },
  },
  flags = {
    debounce_text_changes = 150,
  },
  single_file_support = true,
}