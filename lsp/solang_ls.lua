-- /qompassai/Diver/lsp/solang_ls.lua
-- Qompass AI Solang LSP Spec
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
