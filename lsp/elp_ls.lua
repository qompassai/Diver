--/qompassai/Diver/lsp/elp.lua
-- Qompass AI Erlang Language Platform (ELP) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['elp_ls'] = {
    cmd = {
        'elp',
        'server',
    },
    filetypes = {
        'erlang',
    },
    root_markers = {
        'rebar.config',
        'erlang.mk',
        '.git',
    },
}
