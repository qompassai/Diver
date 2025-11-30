-- /qompassai/Diver/lsp/jsonls.lua
-- Qompass AI Qompass AI Jsonls LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config["jsonls"] = {
  cmd = { "vscode-json-language-server", "--stdio" },
  filetypes = { "json", "jsonc", "json5" },
  init_options = {
    provideFormatter = true,
  },
  root_markers = { ".git" },
  settings = {
    json = {
      validate = { enable = true },
      schemas = {
        {
          description = "Biome configuration",
          fileMatch = {
            ".biome.jsonc",
            "**/.biome.jsonc",
            "~/.config/biome/biome.jsonc",
          },
          url = "https://biomejs.dev/schemas/2.0.6/schema.json",
        },
        {
          description = "ESLint config",
          fileMatch = { ".eslintrc", ".eslintrc.json" },
          url = "https://json.schemastore.org/eslintrc.json",
        },
        {
          description = "Prettier config",
          fileMatch = { ".prettierrc", ".prettierrc.json" },
          url = "https://json.schemastore.org/prettierrc",
        },
        {
          description = "tsconfig",
          fileMatch = { "tsconfig.json", "tsconfig.*.json" },
          url = "https://json.schemastore.org/tsconfig.json",
        },
      },
    },
  },
}
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*.jsonc" },
  callback = function()
    vim.bo.filetype = "jsonc"
  end,
})
