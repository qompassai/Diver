-- /qompassai/Diver/lsp/nickel_ls.lua
-- Qompass AI Nickel LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Reference: https://github.com/tweag/nickel
-- cargo install nickel-lang-lsp
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'nls',
    },
    filetypes = { ---@type string[]
        'ncl',
        'nickel',
    },
    root_markers = { ---@type string[]
        '.git',
    },
}
