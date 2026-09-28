-- /qompassai/Diver/lsp/moveana_ls.lua
-- Qompass AI Move Analyzer LSP Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Move Analyzer: language server for the Move smart contract language
-- Source: https://github.com/move-language/move/tree/main/language/move-analyzer
-- Install: cargo install --path language/move-analyzer
-- Note: For Aptos/Sui Move, consider aptos-language-server or sui-move-analyzer
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'move-analyzer',
    },
    filetypes = { ---@type string[]
        'move',
    },
    root_markers = { ---@type string[]
        'Move.toml',
        '.git',
    },
}
