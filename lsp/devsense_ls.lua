-- /qompassai/Diver/lsp/devsense_ls.lua
-- Qompass AI Devsense-PHP LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://www.npmjs.com/package/devsense-php-ls
vim.lsp.config['devsense_ls'] = {
    cmd = {
        'devsense-php-ls',
        '--stdio',
    },
    filetypes = {
        'php',
    },
    root_markers = {
        'composer.json',
        '.git',
    },
    init_options = {
        ['0'] = '{}',
    },
}
