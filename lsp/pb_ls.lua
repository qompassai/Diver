-- /qompassai/Diver/lsp/pb_ls.lua
-- Qompass AI Protobuf (Pb) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://git.sr.ht/~rrc/pbls
--cargo install --git https://git.sr.ht/~rrc/pbls
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'pbls',
    },
    filetypes = { ---@type string[]
        'proto',
    },
    root_markers = { ---@type string[]
        '.pbls.toml',
        '.git',
    },
}
