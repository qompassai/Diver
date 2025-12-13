-- /qompassai/Diver/lsp/graphql_ls.lua
-- Qompass AI GraphQL LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
--Reference:https://github.com/graphql/graphiql/tree/main/packages/graphql-language-service-server
--pnpm add -g graphql-language-service-server
vim.lsp.config['graphql_ls'] = {
    cmd = {
        'graphql-lsp',
        'server',
        '-m',
        'stream',
    },
    filetypes = {
        'graphql',
        'javascriptreact',
        'typescriptreact',
    },
    root_markers = {
        '.graphqlrc*',
        '.graphql.config.*',
        'graphql.config.*',
    },
}
