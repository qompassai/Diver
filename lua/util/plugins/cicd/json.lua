-- ~/.config/nvim/lua/plugins/cicd/json.lua
--------------------------------------------
return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "b0o/schemastore.nvim",
    },
    opts = function(_, opts)
      return require("config.cicd.json").setup_json_lsp(opts)
    end,
  },
  {
    "nvimtools/none-ls.nvim", 
    event = { "BufReadPre", "BufNewFile" },
    opts = function(_, opts)
      opts = require("config.cicd.json").setup_json_linter(opts)
      opts = require("config.cicd.json").setup_json_formatter(opts)
      return opts
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if type(opts.ensure_installed) == "table" then
        vim.list_extend(opts.ensure_installed, { "json", "json5", "jsonc" })
      end
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      return require("config.cicd.json").setup_json_conform(opts)
    end,
  },
  {
    "saghen/blink.cmp",
    dependencies = { "hrsh7th/nvim-cmp" },
    opts = function(_, opts)
      return require("config.cicd.json").setup_json_completion(opts)
    end,
  },
  {
    "folke/which-key.nvim",
    optional = true,
    opts = function(_, opts)
      return require("config.cicd.json").setup_json_keymaps(opts)
    end,
  },
  {
    "b0o/schemastore.nvim",
    lazy = true,
  },
}
