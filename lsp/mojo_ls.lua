-- /qompassai/Diver/lsp/mojo_ls.lua
-- Qompass AI Diver Mojo LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    capabilities = require('config.core.lsp').capabilities,
    cmd = {
        'mojo-lsp-server',
        '--log=info',
        -- '--pretty',
        --  '--attach-debugger-on-startup',
    },
    cmd_env = {
        CONDA_PREFIX = vim.fn.expand('~/.local/share/mojo/.pixi/envs/default'),
        MOJO_STDLIB_PATH = vim.fn.expand('~/.local/share/mojo/.pixi/envs/default/lib/mojo'),
    },
    filetypes = {
        'mojo',
    },
    on_attach = require('config.core.lsp').on_attach,
    root_markers = {
        '.git',
        'pixi.toml',
    },
    settings = {
        mojo = {
            stdlib_path = vim.fn.expand('~/.local/share/mojo/.pixi/envs/default/lib/mojo'),
        },
    },
}