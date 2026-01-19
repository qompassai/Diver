-- /qompassai/Diver/lsp/mm0_ls.lua
-- Qompass AI MetaMath Zero (mm0) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- References: https://github.com/digama0/mm0/tree/master/mm0-rs)

return ---@type vim.lsp.Config
{
    cmd = { ---@type string[]
        'mm0-rs',
        'server',
    },
    root_markers = { ---@type string[]
        '.git',
    },
    filetypes = { ---@type string[]
        'metamath-zero',
    },
}
