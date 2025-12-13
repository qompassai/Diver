-- /qompassai/Diver/lsp/harper_ls.lua
-- Qompass AI Harper LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- https://github.com/automattic/harper
vim.lsp.config['harper_ls'] = {
    cmd = {
        'harper-ls',
        '--stdio',
    },
    filetypes = {
        'asciidoc',
        'c',
        'cpp',
        'cs',
        'gitcommit',
        'go',
        'html',
        'java',
        'javascript',
        'lua',
        'markdown',
        'nix',
        'python',
        'ruby',
        'rust',
        'swift',
        'toml',
        'typescript',
        'typescriptreact',
        'haskell',
        'cmake',
        'typst',
        'php',
        'dart',
        'clojure',
        'sh',
    },
    root_markers = {
        '.git',
    },
    settings = {
        ['harper-ls'] = {
            --userDictPath = '~/dict.txt'
        },
    },
}
