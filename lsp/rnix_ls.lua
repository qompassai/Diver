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
    root_dir = function(bufnr, on_dir)
        on_dir(vim.fs.root(bufnr, '.git') or vim.uv.os_homedir())
    end,
    settings = {},
    init_options = {},
}
