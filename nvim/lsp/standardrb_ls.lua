-- /qompassai/Diver/lsp/standardrb.lua
-- Qompass AI Standardrb LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference:  https://github.com/testdouble/standard
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'standardrb',
        '--lsp',
    },
    filetypes = { ---@type string[]
        'ruby',
    },
    root_markers = { ---@string []
        'Gemfile',
        '.git',
    },
}
