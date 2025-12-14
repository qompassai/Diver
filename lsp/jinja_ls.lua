-- /qompassai/Diver/lsp/jinja_ls.lua
-- Qompass AI Jinja LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference: https://github.com/uros-5/jinja-lsp
-- cargo install jinja-lsp
vim.filetype.add({
    extension = {
        jinja = 'jinja',
        jinja2 = 'jinja',
        j2 = 'jinja',
    },
})
vim.lsp.config['jinja_ls'] = {
    name = 'jinja_lsp',
    cmd = {
        'jinja-lsp',
    },
    filetypes = {
        'jinja',
    },
    root_markers = {
        '.git',
    },
    settings = {
        ['jinja-lsp'] = {
            templates = './templates',
            backend = {
                './src',
            },
            lang = 'rust',
        },
    },
}
