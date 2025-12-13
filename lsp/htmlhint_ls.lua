-- /qompassai/Diver/lsp/htmlhint.lua
-- Qompass AI HTMLHint LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['htmlhint_ls'] = {
    cmd = {
        'htmlhint',
    },
    filetypes = {
        'html',
        'htm',
    },
    codeActionProvider = false,
    colorProvider = false,
    semanticTokensProvider = nil,
    settings = {
        htmlhint = {},
    },
}
