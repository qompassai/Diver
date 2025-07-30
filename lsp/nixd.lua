-- /qompassai/Diver/lsp/nixd.lua
-- Qompass AI Nixd LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return {
    cmd = {
        'nixd'
    },
    filetypes = {
        'nix'
    },
    root_markers = {
        'flake.nix',
        'git'
    },
}
