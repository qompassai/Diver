-- /qompassai/Diver/lsp/nixd_ls.lua
-- Qompass AI Nixd LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- nix profile install github:nix-community/nixd
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'nixd',
        '--log=info',
        '--inlay-hints=true',
        '--semantic-tokens=true',
        '--pretty',
    },
    filetypes = { ---@type string[]
        'nix',
    },
    root_markers = { ---@type string[]
        'flake.nix',
        'default.nix',
        '.git',
    },
}
