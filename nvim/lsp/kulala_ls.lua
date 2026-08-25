-- kulala_ls.lua
-- Qompass AI - [Add description here]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'kulala-ls',
        '--stdio',
    },
    filetypes = { ---@type string[]
        'http',
    },
    root_markers = { ---@type string[]
        '.git',
    },
}
