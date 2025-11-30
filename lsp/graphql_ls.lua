-- /qompassai/Diver/lsp/graphql_ls.lua
-- Qompass AI GraphQL LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config["graphql"] = {
  cmd = { "graphql-lsp", "server", "--method", "stream" },
  filetypes = { "graphql", "gql", "typescriptreact", "javascriptreact" },
  codeActionProvider = {
    codeActionKinds = { "", "quickfix", "refactor.extract", "refactor.rewrite" },
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
