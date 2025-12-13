-- /qompassai/Diver/lsp/diagnostic_ls.lua
-- Qompass AI Diagnostic LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Reference: https://github.com/iamcco/diagnostic-languageserver
-- pnpm add -g diagnostic-languageserver
vim.lsp.config['diagnostic_ls'] = {
    cmd = {
        'diagnostic-languageserver',
        '--stdio',
    },
    root_markers = {
        '.git',
    },
    filetypes = {},
}
