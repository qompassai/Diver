-- /qompassai/Diver/lsp/tsp_ls.lua
-- Qompass AI TypeSpec  LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
--Reference: https://github.com/microsoft/typespec
-- pnpm add -g @typespec/compiler@latest
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'tsp-server',
        '--stdio',
    },
    filetypes = {
        'typespec',
    },
    root_markers = {
        'tspconfig.yaml',
        '.git',
    },
}
