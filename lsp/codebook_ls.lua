-- /qompassai/Diver/lsp/codebook.lua
-- Qompass AI Codebook LSP Spec
-- Code-aware spell checker for code
------------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'codebook-lsp',
        'serve',
    },
    filetypes = { ---@type string[]
        'c',
        'css',
        'gitcommit',
        'go',
        'haskell',
        'html',
        'java',
        'javascript',
        'javascriptreact',
        'lua',
        'markdown',
        'php',
        'python',
        'ruby',
        'rust',
        'toml',
        'text',
        'typescript',
        'typescriptreact',
        'zig',
    },
    root_markers = { ---@type string[]
        '.git',
        'codebook.toml',
        '.codebook.toml',
    },
}
