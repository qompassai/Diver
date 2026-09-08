-- /qompassai/Diver/lsp/basics_ls.lua
-- Qompass AI basics_ls LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------------------
-- References:  https://github.com/antonk52/basics-language-server/
-- pnpm add -g basics-language-server@latest
---@type vim.lsp.Config
return {
    cmd = {
        'basics-language-server',
    },
    root_markers = {
        '.git',
    },
    settings = {
        buffer = {
            enable = true,
            minCompletionLength = 4,
            matchStrategy = 'fuzzy',
        },
        path = {
            enable = true,
        },
        snippet = {
            enable = false,
            sources = {},
            matchStrategy = 'fuzzy',
        },
    },
}
