-- /qompassai/Diver/lsp/coq_lsp.lua
-- Qompass AI Coq LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------

local coq_lsp_bin = 'coq-lsp'

vim.lsp.config['coq_lsp'] = {
  cmd = { coq_lsp_bin },

  filetypes = { 'coq' },

  root_markers = { '_CoqProject', '.coq-lsp', '.git' },

  handlers = {
    ['textDocument/hover'] = vim.lsp.with(
      vim.lsp.handlers.hover,
      { border = 'rounded' }
    ),
    ['textDocument/signatureHelp'] = vim.lsp.with(
      vim.lsp.handlers.signature_help,
      { border = 'rounded' }
    ),
  },

  codeActionProvider = {
    codeActionKinds = { '', 'quickfix', 'refactor' },
    resolveProvider = true,
  },

  colorProvider = false,

  semanticTokensProvider = {
    full = true,
    legend = {
      tokenModifiers = { 'declaration', 'definition', 'readonly', 'documentation' },
      tokenTypes = {
        'namespace', 'type', 'class', 'parameter', 'variable',
        'property', 'function', 'method', 'keyword', 'comment',
        'string', 'number', 'operator',
      },
    },
    range = true,
  },

  settings = {
    ['coq-lsp'] = {
    },
  },

  flags = {
    debounce_text_changes = 150,
  },

  single_file_support = true,
}
