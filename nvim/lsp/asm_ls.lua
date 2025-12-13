-- /qompassai/Diver/lsp/asm_ls.lua
-- Qompass AI Diver Assembly (ASM) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference: https://github.com/bergercookie/asm-lsp
-- cargo install --git https://github.com/bergercookie/asm-lsp asm-lsp
vim.lsp.config['asm_ls'] = {
    cmd = {
        'asm-lsp',
    },
    root_markers = {
        '.asm-lsp.toml',
        '.git',
    },
    filetypes = {
        'asm',
        'vmasm',
    },
    settings = {},
    init_options = {},
}
