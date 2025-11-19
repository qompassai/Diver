-- /qompassai/Diver/lsp/cspell_lsp.lua
-- Qompass AI Code Spell LSP Spec (cspell-lsp)
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['cspell-lsp'] = {
  cmd = { cspell-lsp, '--stdio' },
  filetypes = {
    'lua', 'vim', 'bash', 'sh', 'zsh',
    'python', 'ruby', 'go', 'rust', 'java', 'php',
    'javascript', 'typescript', 'tsx', 'jsx',
    'markdown', 'mdx', 'json', 'yaml', 'toml',
    'gitcommit',
  },
  codeActionProvider = {
    codeActionKinds = { '', 'quickfix' },
    resolveProvider = true,
  },
  colorProvider = false,
  semanticTokensProvider = nil,
  init_options = {
    home = vim.fn.stdpath('config'),
  },
  settings = {
    cspell = {
    },
  },
  flags = {
    debounce_text_changes = 150,
  },
  single_file_support = true,
}