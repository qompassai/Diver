-- ~/.config/nvim/lua/plugins/lang/nix.lua
-- ----------------------------------------
-- Copyright (C) 2025 Qompass AI, All rights reserved

return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "nix" },
      highlight = { enable = true },
    },
  },
  {
    "neovim/nvim-lspconfig",
    lazy = true,
    ft = "nix",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "b0o/SchemaStore.nvim",
      "L3MON4D3/LuaSnip",
    },
    config = function()
      require("lspconfig").nil_ls.setup({
        settings = {
          ["nil"] = {
            formatting = { command = { "alejandra" } },
            diagnostics = {
              enabled = true,
              ignored = { "unused_binding" },
              excludedFiles = {},
            },
            nix = {
              flake = {
                autoArchive = true,
                autoEvalInputs = true,
              },
              autoLSPConfig = true,
            },
          },
        },
      })
    end,
  },
  {
    "stevearc/conform.nvim",
    ft = "nix",
    opts = {
      formatters_by_ft = { nix = { "alejandra" } },
      format_on_save = {
        timeout_ms = 500,
        lsp_fallback = true,
      },
    },
    config = function(_, opts)
      require("conform").setup(opts)
      vim.keymap.set("n", "<leader>cf", function()
        require("conform").format({ async = true })
      end, { desc = "[C]ode [F]ormat" })
    end,
  },
  {
    "nvimtools/none-ls.nvim",
    ft = "nix",
    opts = function(_, opts)
      local null_ls = require("null-ls")
      opts.sources = {
        null_ls.builtins.diagnostics.statix,
        null_ls.builtins.diagnostics.deadnix,
      }
    end,
  },
}
