-- /qompassai/Diver/lsp/perlnav_ls.lua
-- Qompass AI PerlNavigator LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/bscan/PerlNavigator
--pnpm add -g perlnavigator-server
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'perlnavigator',
    },
    filetypes = { ---@type string[]
        'perl',
        'pl',
        'pm',
    },
    root_markers = { ---@type string[]
        '.git',
    },
    settings = {
        perlnavigator = {
            perlPath = 'perl',
            perlEnvAdd = true,
            perlEnv = {},
            perltidyProfile = vim.env.HOME .. '/.config/perltidy',
            perlcriticProfile = vim.env.HOME .. '/.config/perlcritic',
            perlcriticMessageFormat = '%m - %e',
            perlcriticSeverity = 1,
            perlcriticEnabled = true,
            enableWarnings = true,
            includePaths = {},
        },
    },
}
