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
    root_markers = {
        '.git',
        'pixi.toml',
    },
    settings = {},
}