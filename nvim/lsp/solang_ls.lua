-- /qompassai/Diver/lsp/solang_ls.lua
-- Qompass AI Solang LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
vim.lsp.config['solang'] = {
    cmd = {
        'solang',
        'language-server',
        '--target',
        'evm',
    },
    filetypes = {
        'solidity',
    },
    root_markers = {
        '.git',
    },
}
