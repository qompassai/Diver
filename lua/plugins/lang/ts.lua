-- ~/.config/nvim/lua/plugins/lang/ts.lua
return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "jose-elias-alvarez/typescript.nvim",
    },
    ft = { "typescript", "typescriptreact" },
    opts = function(_, opts)
      return require("config.lang.ts").setup_ts_lsp(opts)
    end,
  },
  {
    "nvimtools/none-ls.nvim",
    ft = { "typescript", "typescriptreact" },
    dependencies = { 
      "nvim-lua/plenary.nvim",
      "nvimtools/none-ls-extras.nvim",
  },
    opts = function(_, opts)
      opts = require("config.lang.ts").setup_ts_formatter(opts)
      return opts
    end,
  },
  {
    "mfussenegger/nvim-lint",
    ft = { "typescript", "typescriptreact" },
    config = function()
      require("config.lang.ts").setup_ts_linter()
      vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
        pattern = { "*.ts", "*.tsx" },
        callback = function()
          require("lint").try_lint()
        end,
      })
    end
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if type(opts.ensure_installed) == "table" then
        vim.list_extend(opts.ensure_installed, { "typescript", "tsx" })
      end
    end,
  },
  {
    "stevearc/conform.nvim",
    ft = { "typescript", "typescriptreact" },
    opts = function(_, opts)
      return require("config.lang.ts").setup_ts_conform(opts)
    end,
  },
  {
    "saghen/blink.cmp",
    version = "*",
    lazy = true,
    ft = { "typescript", "typescriptreact" },
    dependencies = {
      { 'dmitmel/cmp-digraphs' },
      'saghen/blink.compat' },
    opts = function(_, opts)
      return require("config.lang.ts").setup_ts_completion(opts)
    end,
  },
  {
    "folke/which-key.nvim",
    optional = true,
    ft = { "typescript", "typescriptreact" },
    opts = function(_, opts)
      return require("config.lang.ts").setup_ts_keymaps(opts)
    end,
  },

  {
    "jose-elias-alvarez/typescript.nvim",
    ft = { "typescript", "typescriptreact" },
    config = function()
      require("config.lang.ts").setup_ts_project_commands()
    end,
  },
}
