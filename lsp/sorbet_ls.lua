-- /qompassai/Diver/lsp/sorbet_ls.lua
-- Qompass AI Sorbet LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'srb',
        'tc',
        '--lsp',
    },
    filetypes = { ---@type string[]
        'ruby',
    },
    root_markers = { ---@type string[]
        'Gemfile',
        '.git',
    },
}
