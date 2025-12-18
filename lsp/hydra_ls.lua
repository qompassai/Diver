-- /qompassai/Diver/lsp/hydra_ls.lua
-- Qompass AI Hydra LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'hydra-lsp',
    },
    filetypes = { ---@type string[]
        'yaml',
    },
    root_markers = { ---@type string[]
        '.git',
    },
}
