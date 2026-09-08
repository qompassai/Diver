-- /qompassai/Diver/lsp/ttags_ls.lua
-- Qompass AI TTags LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/npezza93/ttags
--cargo install ttags
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'ttags',
        'lsp',
    },
    filetypes = { ---@type string[]
        'c',
        'cpp',
        'haskell',
        'javascript',
        'nix',
        'ruby',
        'rust',
        'swift',
    },
    root_markers = { ---@type string[]
        '.git',
    },
}
