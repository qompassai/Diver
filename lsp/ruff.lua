-- /qompassai/Diver/lsp/ruff.lua
-- Qompass AI Ruff LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--https://docs.astral.sh/ruff/editors
vim.lsp.config['ruff'] = {
  cmd = { 'ruff', 'server', '--preview' },
  filetypes = { 'python' },
  root_markers = { 'pyproject.toml', 'ruff.toml', '.git' },
  settings = {
    codeAction = {
      disableRuleComment = {
        enable = false
      }
    },
    configurationPreference = "filesystemFirst",
    exclude = { "**/tests/**" },
    lineLength = 100,
    fixAll = false,
    showSyntaxErrors = true,
    configuration = {
      lint = {
        preview = true,
        unfixable = { "F401" },
        ["extend-select"] = { "TID251" },
        ["flake8-tidy-imports"] = {
          ["banned-api"] = {
            ["typing.TypedDict"] = {
              msg = "Use `typing_extensions.TypedDict` instead"
            }
          }
        }
      },
      format = {
        ["quote-style"] = 'single'
      }
    }
  }
}