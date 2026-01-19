-- /qompassai/Diver/lsp/fish_ls.lua
-- Qompass AI Fish LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference: https://github.com/ndonfris/fish-lsp
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'fish-lsp',
        'start',
    },
    filetypes = { ---@type string[]
        'fish',
    },
    root_markers = { ---@type string[]
        'config.fish',
        '.git',
    },
}
