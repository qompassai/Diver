-- /qompassai/Diver/lsp/cbfmt.lua
-- Qompass AI Codeblock Formatter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['cbfmt'] = {
    cmd = {
        'cbfmt',
    },
    filetypes = {
        'markdown',
        'md',
        'org',
        'rst',
    },
    codeActionProvider = false,
    colorProvider = false,
    semanticTokensProvider = nil,
    settings = {
        cbfmt = {},
    },
}
