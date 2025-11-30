-- /qompassai/Diver/lsp/some_sassls.lua
-- Qompass AI Some Sass LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- pnpm add -g some-sass-language-server
---@type vim.lsp.Config
return {
  name = "somesass_ls",
  cmd = { "some-sass-language-server", "--stdio" },
  filetypes = { "scss", "sass" },
  root_markers = { ".git", ".package.json" },
  settings = {
    somesass = {
      suggestAllFromOpenDocument = true,
    },
  },
}
