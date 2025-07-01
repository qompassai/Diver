-- /qompassai/Diver/lua/plugins/lang/ts.lua
-- Qompass AI Diver Typescript Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local ts_cfg = require('config.lang.ts')

return {
  {
    "pmizio/typescript-tools.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
    opts = {},
  },

  {
    "nvimtools/none-ls.nvim",
    ft = { "typescript", "typescriptreact" },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvimtools/none-ls-extras.nvim",
    },
    opts = function(_, opts)
      return ts_cfg.ts_nls(opts)
    end,
  },
  {
    'mfussenegger/nvim-lint',
    ft = { 'typescript', 'typescriptreact' },
    config = function(_, opts)
      ts_cfg.ts_linter(opts)
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    ft = { "typescript", "typescriptreact" },
  },
  {
    "stevearc/conform.nvim",
    ft = { "typescript", "typescriptreact" },
    opts = function(_, opts)
      return ts_cfg.ts_conform(opts)
    end,
  },
  {
    "folke/which-key.nvim",
    optional = true,
    ft = { "typescript", "typescriptreact" },
    opts = function(_, opts)
      return ts_cfg.ts_keymaps(opts)
    end,
  },
}
