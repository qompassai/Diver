-- ~/.config/nvim/lua/plugins/lang/nix.lua
-- ---------------------------------------
-- Copyright (C) 2025 Qompass AI, All rights reserved

return {
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
            formatting = {
              command = { "nixpkgs-fmt" }, -- or "alejandra" or "nixfmt"
            },
            diagnostics = {
              ignored = {},
              enabled = true,
            },
            nix = {
              flake = {
                autoArchive = true,
              },
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
      formatters_by_ft = {
        nix = { "nixpkgs-fmt" }, -- or "alejandra" or "nixfmt"
      },
    },
  },
  {
    "hrsh7th/nvim-cmp",
    ft = "nix",
    opts = function(_, opts)
      opts.sources = opts.sources or {}
      table.insert(opts.sources, { name = "nvim_lsp", group_index = 0 })
    end,
  },
  {
    "nvimtools/none-ls.nvim",
    ft = "nix",
    opts = function(_, opts)
      local nls = require("null-ls")
      opts.sources = opts.sources or {}
      table.insert(opts.sources, nls.builtins.diagnostics.statix)
    end,
  },
}
