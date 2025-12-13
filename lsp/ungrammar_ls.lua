-- /qompassai/Diver/lsp/ungrammar_ls.lua
-- Qompass AI UnGrammar LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/binhtran432k/ungrammar-language-features
-- pnpm add -g ungrammar-languageserver
vim.lsp.config['ungrammar_ls'] = {
    cmd = {
        'ungrammar-languageserver',
        '--stdio',
    },
    filetypes = {
        'ungrammar',
    },
    root_markers = {
        '.git',
    },
    settings = {
        ungrammar = {
            validate = {
                enable = true,
            },
            format = {
                enable = true,
            },
        },
    },
}
