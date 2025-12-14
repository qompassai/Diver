-- /qompassai/Diver/lsp/markojs_ls.lua
-- Qompass AI Marko LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['markojs_ls'] = {
    cmd = {
        'marko-language-server',
        '--stdio',
    },
    filetypes = {
        'marko',
    },
    root_markers = {
        '.git',
    },
}
