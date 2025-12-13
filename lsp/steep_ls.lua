-- /qompassai/Diver/lsp/steep_ls.lua
-- Qompass AI Steep LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- gem install steep
vim.lsp.config['steep_ls'] = {
    cmd = {
        'steep',
        'langserver',
    },
    filetypes = {
        'eruby',
        'ruby',
    },
    root_markers = {
        'Steepfile',
        '.git',
    },
}
