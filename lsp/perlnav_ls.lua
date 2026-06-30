-- /qompassai/Diver/lsp/perlnav_ls.lua
-- Qompass AI PerlNavigator LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return { ---@type vim.lsp.Config
    cmd = {
        'perlnavigator',
    },
    filetypes = {
        'perl',
        'pl',
        '%.pl$',
        '%.pm$',
        'pm',
    },
    root_markers = {
        '.git',
    },
    settings = {
        perlnavigator = {
            enableWarnings = true,
            includePaths = {},
            perlcriticEnabled = true,
            perlcriticMessageFormat = '%m - %e',
            perlcriticProfile = vim.env.HOME .. '/.config/perlcritic',
            perlcriticSeverity = 1,
            perlEnv = {},
            perlEnvAdd = true,
            perlPath = 'perl',
            perltidyProfile = vim.env.HOME .. '/.config/perltidy',
        },
    },
}
