-- /qompassai/Diver/lsp/sq_ls.lua
-- Qompass AI SQL LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--go install github.com/sqls-server/sqls@latest
vim.lsp.config['sq_ls'] = {
    cmd = {
        'sql-language-server',
        'up',
        '--method',
        'stdio',
    },
    filetypes = {
        'sql',
        'mysql',
    },
    root_markers = {
        '.sqllsrc.json',
    },
    settings = {
        sqlLanguageServer = {
            connections = {
                {
                    driver = 'mysql',
                    dataSourceName = 'root:root@tcp(127.0.0.1:13306)/world',
                },
                {
                    driver = 'postgresql',
                    dataSourceName = 'host=127.0.0.1 port=15432 user=postgres password=mysecretpassword1234 dbname=dvdrental sslmode=disable',
                },
            },
            lint = {
                rules = {
                    ['align-column-to-the-first'] = 'on',
                    ['column-new-line'] = 'error',
                    ['linebreak-after-clause-keyword'] = 'error',
                    ['reserved-word-case'] = {
                        'error',
                        'upper',
                    },
                    ['space-surrounding-operators'] = 'error',
                    ['where-clause-new-line'] = 'error',
                    ['align-where-clause-to-the-first'] = 'error',
                },
            },
        },
    },
}
