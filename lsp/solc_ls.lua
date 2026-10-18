-- /qompassai/Diver/lsp/solc_ls.lua
-- Qompass AI Solc LSP Spec
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'solc',
        '--lsp',
    },
    filetypes = { ---@type string[]
        'solidity',
    },
    root_markers = { ---@type string[]
        'hardhat.config.*',
        '.git',
    },
}
