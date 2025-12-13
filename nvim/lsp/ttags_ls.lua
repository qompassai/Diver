-- /qompassai/Diver/lsp/ttags_ls.lua
-- Qompass AI TTags LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/npezza93/ttags
--cargo install ttags
vim.lsp.config['ttags_ls'] = {
    cmd = {
        'ttags',
        'lsp',
    },
    filetypes = {
        'c',
        'cpp',
        'haskell',
        'javascript',
        'nix',
        'ruby',
        'rust',
        'swift',
    },
    root_markers = {
        '.git',
    },
}
