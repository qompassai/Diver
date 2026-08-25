-- /qompassai/Diver/lsp/lean_ls.lua
-- Qompass AI Lean LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@source https://github.com/leanprover/lean-client-js/tree/master/lean-language-server
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'lean-language-server',
        '--stdio',
        '--',
        '-M',
        '4096',
        '-T',
        '100000',
    },
    filetypes = { ---@type string[]
        'lean3',
    },
    offset_encoding = 'utf-32', ---@type string
    root_markers = {
        'leanpkg.toml',
        'leanpkg.path',
    },
}
