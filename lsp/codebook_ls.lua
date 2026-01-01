-- /qompassai/Diver/lsp/codebook.lua
-- Qompass AI Codebook LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'codebook-lsp',
        'serve',
    },
    filetypes = {
        'c',
        'css',
        'gitcommit',
        'go',
        'haskell',
        'html',
        'java',
        'javascript',
        'javascriptreact',
        --'lua',
        --'markdown',
        'php',
        --'python',
        'ruby',
        'rust',
        'toml',
        'text',
        'typescript',
        'typescriptreact',
        'zig',
    },
    init_options = {
        checkWhileTyping = true,
        diagnosticSeverity = 'information',
        globalConfigPath = '$XDG_CONFIG_HOME/codebook/codebook.toml',
        logLevel = 'info',
    },
    root_markers = {
        '.git',
        'codebook.toml',
        '.codebook.toml',
    },
}
