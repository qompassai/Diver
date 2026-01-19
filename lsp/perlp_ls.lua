-- /qompassai/Diver/lsp/perlp_ls.lua
-- Qompass AI PerlP LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'pls',
    },
    filetypes = {
        'perl',
    },
    init_options = {},
    root_markers = {
        '.git',
        'Makefile',
        'Build.PL',
        'cpanfile',
        'dist.ini',
    },
    settings = {
        pls = {
            perltidy = {
                perltidyrc = os.getenv('HOME') .. '/.perltidyrc',
            },
            perlcritic = {
                enabled = true,
                perlcriticrc = os.getenv('HOME') .. '/.perlcriticrc',
            },
            syntax = {
                enabled = true,
                perl = '/usr/bin/perl',
                args = {
                    'arg1',
                    'arg2',
                },
            },
            inc = {
                '${workspaceFolder}/lib',
            },
            cwd = '${workspaceFolder}',
        },
    },
}
