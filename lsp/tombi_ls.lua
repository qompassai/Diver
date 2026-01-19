-- /qompassai/Diver/lsp/tombi_ls.lua
-- Qompass AI Diver Tombi LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference:  https://tombi-toml.github.io/tombi/
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'tombi',
        'lsp',
    },
    filetypes = { ---@type string[]
        'toml',
    },
    root_markers = { ---@type string[]
        'tombi.toml',
        'pyproject.toml',
        '.git',
    },
}
