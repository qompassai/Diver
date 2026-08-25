-- /qompassai/Diver/lsp/rune_ls.lua
-- Qompass AI Rune LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference: https://rune-rs.github.io/api/rune/
-- cargo install rune-languageserver
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'rune-languageserver',
    },
    filetypes = { ---@type string[]
        'rune',
    },
    root_markers = { ---@type string[]
        'Cargo.toml',
        'rune.toml',
        '.git',
    },
}
