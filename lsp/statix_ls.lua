-- /qompassai/Diver/lsp/statix.lua
-- Qompass AI Statix LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -------------------------------------------------
--nix run nixpkgs#statix
--Reference: https://github.com/nerdypepper/statix
vim.lsp.config['statix_ls'] = {
    cmd = {
        'statix',
        'check',
        '--stdin',
    },
    filetypes = {
        'nix',
    },
    root_markers = {
        'flake.nix',
        '.git',
    },
}
