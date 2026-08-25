-- /qompassai/Diver/lsp/rnix.lua
-- Qompass AI RNix LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'rnix-lsp',
    },
    filetypes = { ---@type string[]
        'nix',
    },
    root_markers = { 'flake.nix' },
    settings = {},
    init_options = {},
}
