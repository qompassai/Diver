-- /qompassai/Diver/lsp/dot_ls.lua
-- Qompass AI Dot Language Server LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'dot-language-server',
        '--stdio',
    },
    filetypes = { ---@type string[]
        'dot',
    },
}
