-- /qompassai/Diver/lsp/uv.lua
-- Qompass AI UV LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------
-- cargo install --git https://codeberg.org/caradhras/uvls --locked
vim.cmd([[au BufRead,BufNewFile *.uvl setfiletype uvl]])
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'uvls',
    },
    filetypes = { ---@type string[]
        'uvl',
    },
    root_markers = { ---@type string[]
        '.git',
    },
}
