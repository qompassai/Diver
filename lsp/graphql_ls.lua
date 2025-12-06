-- /qompassai/Diver/lsp/graphql_ls.lua
-- Qompass AI GraphQL LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
--Reference: https://github.com/graphql/graphiql/tree/main/packages/graphql-language-service-cli
--pnpm add -g graphql-language-service-cli
vim.lsp.config['graphql_ls'] = {
  cmd = {
    'graphql-lsp',
    'server',
    '--method',
    'stream'
  },
  filetypes = {
    'graphql',
    'gql',
    'javascriptreact',
    'typescriptreact'
  },
  codeActionProvider = {
    codeActionKinds = {
      '',
      'quickfix',
      'refactor.extract',
      'refactor.rewrite'
    },
    resolveProvider = true,
  },
  colorProvider = false,
  semanticTokensProvider = nil,
  settings = {
    graphql = {},
    load = {},
  },
  single_file_support = true,
}