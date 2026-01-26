-- /qompassai/Diver/lsp/nil_ls.lua
-- Qompass AI Nix LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'nil',
        '--stdio',
    },
    filetypes = {
        'nix',
    },
    on_attach = require('config.core.lsp').on_attach,
    root_markers = {
        'default.nix',
        'flake.nix',
        '.git',
    },
    settings = {
        ['nil'] = {
            formatting = {
                command = {
                    'alejandra',
                },
            },
            diagnostics = {
                enabled = true,
                ignored = {},
                excludedFiles = {},
            },
            nix = {
                autoArchive = true,
                autoEvalInputs = true,
                binary = 'nix',
                flake = {
                    autoArchive = true,
                    autoEvalInputs = true,
                },
                maxMemoryMB = 2560,
                nixpkgsInputName = 'nixpkgs',
            },
        },
    },
}