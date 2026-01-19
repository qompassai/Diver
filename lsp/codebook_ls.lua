-- /qompassai/Diver/lsp/codebook.lua
-- Qompass AI Codebook LSP Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
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
        'lua',
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
        --globalConfigPath = '$XDG_CONFIG_HOME/codebook/codebook.toml',
        logLevel = 'info',
    },
    root_markers = {
        '.git',
        'codebook.toml',
        '.codebook.toml',
    },
    settings = {
        codebook = {
            dictionaries = {
                'en_us',
            },
            flag_words = {
                'fixme',
                'todo',
            },
            ignore_patterns = {
                '\\b[ATCG]+\\b',
                '\\d{3}-\\d{2}-\\d{4}',
                '^[A-Z]{2,}$',
                'https?://[^\\s]+',
            },
            min_word_length = 3,
            use_global = true,
            words = {
                'astro',
                'codebook',
                'Codebook',
                'fixme',
                'gitcommit',
                'fixme',
                'packpath',
                'Qompass',
                'qompassai',
                'Rakefile',
                'stree',
                'rustc',
                'todo',
                'TODO',
            },
        },
    },
}