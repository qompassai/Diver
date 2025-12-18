-- /qompassai/Diver/lsp/gleam_ls.lua
-- Qompass AI Gleam LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'gleam',
        'lsp',
    },
    filetypes = { ---@type string[]
        'gleam',
    },
    root_markers = { ---@type string[]
        'gleam.toml',
        '.git',
    },
}
