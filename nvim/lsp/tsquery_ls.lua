-- /qompassai/Diver/lsp/tsquery_ls.lua
-- Qompass AI TS Query LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference:  https://github.com/ribru17/ts_query_ls
vim.lsp.config['tsquery_ls'] = {
    cmd = {
        'ts_query_ls',
    },
    filetypes = {
        'query',
    },
    root_markers = {
        'queries',
        '.git',
    },
    settings = {
        parser_aliases = {
            ecma = 'javascript',
            jsx = 'javascript',
            -- php_only = 'php',
            language_retrieval_patterns = {
                'languages/src/([^/]+)/[^/]+\\.scm$',
            },
            parser_install_directories = {
                vim.fs.joinpath(vim.fn.stdpath('data'), '/lazy/nvim-treesitter/parser/'),
            },
        },
    },
}
