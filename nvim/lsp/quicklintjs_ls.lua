-- /qompassai/Diver/lsp/quicklintjs_ls.lua
-- Qompass AI QuickLint-JS LSP Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = {
        'quick-lint-js',
        '--lsp-server',
    },
    filetypes = {
        'javascript',
        'typescript',
    },
    root_markers = {
        'package.json',
        'jsconfig.json',
        '.git',
    },
    settings = {},
}
