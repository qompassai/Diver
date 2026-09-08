-- /qompassai/Diver/lsp/statix.lua
-- Qompass AI Statix LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -------------------------------------------------
--nix run nixpkgs#statix
--Reference: https://github.com/nerdypepper/statix
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'statix',
        'check',
        '--stdin',
    },
    filetypes = { ---@type string[]
        'nix',
    },
    root_markers = { ---@type string[]
        'default.nix',
        'flake.nix',
        '.git',
    },
    settings = { ---@type table
        statix = {
            severity = {
                W01 = 'warning',
                W02 = 'warning',
                W03 = 'info',
                W04 = 'info',
                W05 = 'warning',
                W06 = 'info',
                W07 = 'hint',
                W08 = 'hint',
                W10 = 'warning',
                W11 = 'warning',
                W12 = 'warning',
                W14 = 'warning',
                W17 = 'warning',
                W18 = 'hint',
                W19 = 'info',
                W20 = 'error',
                W23 = 'warning',
            },
            disabled = { ---@type string[]
                ...,
            },
        },
    },
}
