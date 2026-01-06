-- themecheck_ls.lua
-- Qompass AI ThemeCheck LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
      'theme-check-language-server',
      '--stdio'
    },
    filetypes = {
      'liquid'
    },
    root_markers = {
      '.theme-check.yml'
    },
    settings = {},
}