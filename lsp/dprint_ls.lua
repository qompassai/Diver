-- /qompassai/Diver/lsp/dprint.lua
-- Qompass AI DPrint LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'dprint',
        'lsp',
    },
    filetypes = { ---@type string[]
        'javascript',
        'javascriptreact',
        'typescript',
        'typescriptreact',
        'json',
        'jsonc',
        'markdown',
        'python',
        'toml',
        'rust',
        'roslyn',
        'graphql',
    },
    settings = {},
}
