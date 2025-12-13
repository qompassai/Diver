-- /qompassai/Diver/lsp/verible.lua
-- Qompass AI Verible SystemVerilog LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['verible'] = {
    cmd = {
        'verible-verilog-ls',
    },
    filetypes = {
        'verilog',
        'systemverilog',
    },
    codeActionProvider = {
        codeActionKinds = {
            '',
            'quickfix',
            'source.fixAll',
            'source.organizeImports',
        },
        resolveProvider = true,
    },
    colorProvider = false,
    semanticTokensProvider = nil,
    settings = {
        verible = {
            extraArgs = { '--rules=all', '--indentation_spaces=2' },
        },
    },
}
