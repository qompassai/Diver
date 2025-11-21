-- /qompassai/Diver/lsp/hydra_ls.lua
-- Qompass AI Hydra YAML LSP Spec (hydra-lsp)
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['hydra'] = {
  cmd = 'hydra-lsp',
  filetypes = { 'yaml', 'yml', 'hydra' },
  codeActionProvider = {
    codeActionKinds = { '', 'quickfix', 'refactor' },
    resolveProvider = true,
  },
  colorProvider = false,
  semanticTokensProvider = {
    full = true,
    legend = {
      tokenModifiers = {
        'declaration',
        'definition',
        'readonly',
        'documentation',
        'defaultLibrary',
      },
      tokenTypes = {
        'namespace',
        'type',
        'parameter',
        'variable',
        'property',
        'keyword',
        'string',
        'number',
        'operator',
      },
    },
    range = true,
  },
  root_markers = { '.git', '.hydra', 'conf', 'config' },
  init_options = {
    pythonPath = nil,
    hydra = {
      searchPaths = { 'conf', 'configs' },
      mainModule  = nil,
    },
  },
  settings = {
    ['hydra-lsp'] = {
      completion = {
        enableTargetCompletion = true,
        enableArgsCompletion    = true,
      },
      diagnostics = {
        enable = true,
      },
      semanticTokens = {
        enable = true,
      },
    },
  },
  single_file_support = true,
}