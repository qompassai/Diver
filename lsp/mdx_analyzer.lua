-- /qompassai/Diver/lsp/mdx_analyzer.lua
-- Qompass AI MDX Analyzer LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['mdx_analyzer'] = {
  autostart = true,
  cmd = { 'mdx-language-server', '--stdio' },
  filetypes = { 'mdx' },
  root_dir = vim.fn.getcwd,
  root_markers = { 'package.json', 'package.json5' },
  codeActionProvider = {
    codeActionKinds = { '', 'quickfix', 'refactor', 'source.organizeImports' },
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
        'static',
        'deprecated',
        'documentation',
        'defaultLibrary',
      },
      tokenTypes = {
        'namespace',
        'type',
        'class',
        'enum',
        'interface',
        'typeParameter',
        'parameter',
        'variable',
        'property',
        'enumMember',
        'event',
        'function',
        'method',
        'macro',
        'keyword',
        'modifier',
        'comment',
        'string',
        'number',
        'regexp',
        'operator',
        'decorator',
      },
    },
    range = true,
  },
  init_options = {
    typescript = {
      enabled = true,
    },
    locale = 'en',
  },
  settings = {
    mdx = {
      trace = {
        server = {
          verbosity = 'verbose',
          format    = 'text',
        },
      },
      validate = {
        validateReferences = 'info',
      },
    },
  },
  flags = {
    debounce_text_changes = 150,
  },
  single_file_support = true,
}