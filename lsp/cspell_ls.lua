-- /qompassai/Diver/lsp/cspell_ls.lua
-- Qompass AI Code Spell LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = {
    'cspell-lsp',
    '--stdio'
  },
  root_markers = {
    '.git',
    'cspell.json',
    '.cspell.json',
    'cspell.json',
    '.cSpell.json',
    'cSpell.json',
    'cspell.config.js',
    'cspell.config.cjs',
    'cspell.config.json',
    'cspell.config.yaml',
    'cspell.config.yml',
    'cspell.yaml',
    'cspell.yml',
  },
}