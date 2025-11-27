-- /qompassai/Diver/lsp/pbls.lua
-- Qompass AI Protobuf LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
-- References: https://github.com/rcorre/pbls
vim.lsp.config['pbls'] = {
  cmd = 'pbls',
  filetypes = { 'proto' },
  root_markers = { 'buf.yaml', 'buf.work.yaml', 'BUILD.bazel', 'WORKSPACE', '.git' },
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
        'namespace', 'class', 'enum', 'type', 'parameter', 'variable',
        'property', 'function', 'method', 'keyword', 'comment', 'string',
        'number', 'operator',
      },
    },
    range = true,
  },
  settings = {
    pbls = {
      includes = {
      },
    },
  },
  flags = {
    debounce_text_changes = 150,
  },
  single_file_support = true,
}