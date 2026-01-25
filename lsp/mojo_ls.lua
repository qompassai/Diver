-- /qompassai/Diver/lsp/mojo_ls.lua
-- Qompass AI Diver Mojo LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'mojo-lsp-server',
        '--log=info',
        '--pretty',
        '--attach-debugger-on-startup',
    },
    filetypes = {
        'mojo',
    },
       on_attach = require('config.core.lsp').on_attach,
    root_markers = {
        '.git',
        'pixi.toml',
    },
    settings = {},
}