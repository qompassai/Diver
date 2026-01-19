-- /qompassai/Diver/lsp/rubocop_ls.lua
-- Qompass AI Ruby RuboCop LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'bundle',
        'exec',
        'rubocop',
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
