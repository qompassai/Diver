-- /qompassai/Diver/lsp/wasmlangtoo_ls.lua
-- Qompass AI WASM Language Tools LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
--Reference: https://github.com/g-plane/wasm-language-tools
vim.lsp.config['wasmlangtoo_ls'] = {
  cmd = {
    'wat_server'
  },
  filetypes = {
    'wat'
  },
  settings = {
    format = {
      formatComments = true,
      ignoreCommentDirective = 'fmt-ignore',
      indentWidth = 4,
      lineBreak = 'crlf',
      printWidth = 80,
      splitClosingParens = true,
      useTabs = true
    },
    lint = {
      unused = 'warn',
    },
  },
}