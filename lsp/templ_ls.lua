-- /qompassai/Diver/lsp/templ_ls.lua
-- Qompass AI Templ LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- go install github.com/a-h/templ/cmd/templ@latest
-- Reference: https://templ.guide
vim.lsp.config['templ_ls'] = {
    cmd = {
        'templ',
        'lsp',
    },
    filetypes = {
        'templ',
    },
    root_markers = {
        'go.work',
        'go.mod',
        '.git',
    },
}
