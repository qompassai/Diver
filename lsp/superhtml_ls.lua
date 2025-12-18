-- /qompassai/Diver/lsp/superhtml_ls.lua
-- Qompass AI SuperHTML LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'superhtml',
        'lsp',
    },
    filetypes = { ---@type string[]
        'superhtml',
        'html',
    },
    root_markers = {
        '.git',
    },
}
