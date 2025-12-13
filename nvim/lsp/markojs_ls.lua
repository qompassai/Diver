-- /qompassai/Diver/lsp/markojs_ls.lua
-- Qompass AI Marko LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/marko-js/language-server
--pnpm add -g @marko/language-server
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
