-- /qompassai/Diver/lsp/dot_ls.lua
-- Qompass AI Dot Language Server LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['dot_ls'] = {
    cmd = { 'dot-language-server', '--stdio' },
    filetypes = {
        'dot',
    },
}
