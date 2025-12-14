-- /qompassai/Diver/lsp/quicklintjs_ls.lua
-- Qompass AI QuickLint-JS LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- pnpm add -g quick-lint-js
vim.lsp.config['quicklintjs_ls'] = {
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
}
