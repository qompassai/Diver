-- /qompassai/Diver/lsp/wgslana_ls.lua
-- Qompass AI WGSL Analyzer LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference:  https://github.com/wgsl-analyzer/wgsl-analyzer
-- cargo install --git https://github.com/wgsl-analyzer/wgsl-analyzer wgsl-analyzer
vim.lsp.config['wgslana_ls'] = {
    cmd = {
        'wgsl-analyzer',
    },
    filetypes = {
        'wgsl',
    },
    root_markers = {
        '.git',
    },
    settings = {},
}
