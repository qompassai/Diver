-- /qompassai/Diver/lsp/solidnomic_ls.lua
-- Qompass AI Solidity Nomic LSP Spec
---@type vim.lsp.Config
return {
    cmd = {
        'nomicfoundation-solidity-language-server',
        '--stdio',
    },
    filetypes = { ---@type string[]
        'solidity',
    },
    root_markers = { ---@type string[]
        'hardhat.config.js',
        'hardhat.config.ts',
        'foundry.toml',
        'remappings.txt',
        'truffle.js',
        'truffle-config.js',
        'ape-config.yaml',
        '.git',
        'package.json',
    },
}
