-- /qompassai/Diver/lsp/herb_ls.lua
-- Qompass AI Herb LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
--Reference: https://github.com/marcoroth/herb
vim.lsp.config['herb_ls'] = {
    cmd = {
        'herb-language-server',
        '--stdio',
    },
    filetypes = {
        'html',
        'eruby',
    },
    root_markers = {
        'Gemfile',
        '.git',
    },
}
