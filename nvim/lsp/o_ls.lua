-- /qompassai/Diver/lsp/o_ls.lua
-- Qompass AI Odin LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
--Reference: https://github.com/DanielGavin/ols
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'ols',
    },
    filetypes = { ---@type string[]
        'odin',
    },
    root_markers = { ---@type string[]
        '.git',
        'ols.json',
        'ols.jsonc',
        '*.odin',
    },
}
