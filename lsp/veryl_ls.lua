-- /qompassai/Diver/lsp/veryl_ls.lua
-- Qompass AI Veryl LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'veryl-ls',
    },
    filetypes = { ---@type string[]
        'veryl',
    },
    root_markers = { ---@type string[]
        '.git',
    },
}
