-- /qompassai/Diver/lsp/graphql_ls.lua
-- Qompass AI GraphQL LSP Spec
--Reference:https://github.com/graphql/graphiql/tree/main/packages/graphql-language-service-server
--pnpm add -g graphql-language-service-server
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
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
