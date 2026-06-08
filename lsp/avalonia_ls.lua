#!/usr/bin/env lua5.1
-- /qompassai/Diver/lsp/avalonia_ls.lua
-- Qompass AI Diver Avalonia LSP Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
------------------------------------------------------
return ---@type vim.lsp.Config
{
    capabilities = require('config.core.lsp'),
    cmd = {
        'avalonia-ls',
    },
    filetypes = {
        'xml',
        'xaml',
        'axaml',
    },
    root_markers = {
        '*.sln',
        '*.csproj',
        'Directory.Packages.props',
        'global.json',
        'nuget.config',
        '.git',
    },
    settings = {
        avalonia = {
            previewer = {
                enabled = true,
            },
            xaml = {
                stylist = {
                    executable = 'xaml-styler',
                },
            },
        },
    },
}
