-- /qompassai/Diver/lsp/steep_ls.lua
-- Qompass AI Steep LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- gem install steep
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'steep',
        'langserver',
    },
    filetypes = { ---@type string[]
        'eruby',
        'ruby',
    },
    root_markers = { ---@type string[]
        'Steepfile',
        '.git',
    },
}
