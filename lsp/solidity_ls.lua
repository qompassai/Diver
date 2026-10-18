-- /qompassai/Diver/lsp/solidity_ls.lua
-- Qompass AI Solidity LSP Spec
-- #Reference: https://github.com/qiuxiang/solidity-ls
-- pnpm add -g solidity-ls@latest
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'solidity-ls',
        '--stdio',
    },
    filetypes = { ---@type string[]
        'solidity',
    },
    root_markers = { ---@type string[]
        '.git',
        'package.json',
    },
    settings = {
        solidity = {
            includePath = '',
            remapping = {},
        },
    },
}
