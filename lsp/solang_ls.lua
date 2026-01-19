-- /qompassai/Diver/lsp/solang_ls.lua
-- Qompass AI Solang LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'solang',
        'language-server',
        '--target',
        'evm',
    },
    filetypes = { ---@type string[]
        'solidity',
    },
    root_markers = { ---@type string[]
        '.git',
    },
}
