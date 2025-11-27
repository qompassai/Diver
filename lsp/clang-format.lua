-- /qompassai/Diver/lsp/clang_format.lua
-- Qompass AI C/C++ Formatter Spec (clang-format)
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['clang_format'] = {
  cmd = { 'clang-format' },
  filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
  codeActionProvider = false,
  colorProvider = false,
  semanticTokensProvider = nil,
  settings = {
    clang_format = {
      extra_args = { '--style=file' },
    },
  },
  flags = {
    debounce_text_changes = 150,
  },
  single_file_support = true,
}