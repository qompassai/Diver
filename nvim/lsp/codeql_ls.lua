-- /qompassai/Diver/lsp/codeql_ls.lua
-- Qompass AI Diver CodeQL LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'codeql',
        'execute',
        'language-server',
        '--check-errors=ON_CHANGE',
    },
    filetypes = {
        'ql',
    },
    root_markers = {
        'qlpack.yml',
        'qlpack.yaml',
        '.git',
    },
    settings = {
        codeql = {
            packs = {
                'codeql/actions-queries',
                'codeql/actions-all',
                'codeql/cpp-queries',
                'codeql/cpp-all',
                'codeql/csharp-queries',
                'codeql/csharp-all',
                'codeql/go-queries',
                'codeql/go-all',
                'codeql/java-queries',
                'codeql/java-all',
                'codeql/javascript-queries',
                'codeql/javascript-all',
                'codeql/python-queries',
                'codeql/python-all',
                'codeql/ruby-queries',
                'codeql/ruby-all',
                'codeql/rust-queries',
                'codeql/rust-all',
                'codeql/swift-queries',
                'codeql/swift-all',
            },
            search_path = {
                vim.fn.expand('$XDG_DATA_HOME/codeql-home'),
            },
        },
    },
}
