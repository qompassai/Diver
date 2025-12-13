-- /qompassai/Diver/lsp/pug_ls.lua
-- Qompass AI Pug.js LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Reference: https://github.com/opa-oz/pug-lsp
-- go install github.com/opa-oz/pug-lsp@latest
vim.lsp.config['pug_ls'] = {
    cmd = {
        'pug-lsp',
    },
    filetypes = {
        'pug',
    },
    root_markers = {
        'package.json',
    },
}
