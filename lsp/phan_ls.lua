-- /qompassai/Diver/lsp/phan_ls.lua
-- Qompass AI Phan LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
vim.lsp.config['phan_ls'] = {
    cmd = {
        'phan',
        '-m',
        'json',
        '--no-color',
        '--no-progress-bar',
        '-x',
        '-u',
        '-S',
        '--language-server-on-stdin',
        '--allow-polyfill-parser',
    },
    filetypes = {
        'php',
    },
    root_markers = {
        'composer.json',
        '.git',
    },
}
