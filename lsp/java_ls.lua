-- /qompassai/Diver/lsp/java_language_server.lua
-- Qompass AI Java Language Server Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------

vim.lsp.config['java_language_server'] = {
  cmd = { 'java-language-server' },
  filetypes = { 'java' },
  codeActionProvider = {
    codeActionKinds = { '', 'quickfix', 'refactor.extract', 'refactor.rewrite' },
    resolveProvider = true,
  },
  colorProvider = false,
  semanticTokensProvider = nil,
  settings = {
    java = {
      completion = {
        enabled = true,
      },
      diagnostics = {
        enabled = true,
      },
      formatting = {
        enabled = true,
      },
    },
  },
  flags = {
    debounce_text_changes = 150,
  },
  single_file_support = true,
}