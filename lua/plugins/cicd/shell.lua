-- ~/.config/nvim/lua/plugins/cicd/shell.lua

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      return require("config.cicd.shell").setup_sh_lsp(opts)
    end,
  },
  {
    "nvimtools/none-ls.nvim", 
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "gbprod/none-ls-shellcheck.nvim",
    },
    opts = function(_, opts)
      opts = require("config.cicd.shell").setup_sh_linter(opts)
      opts = require("config.cicd.shell").setup_sh_formatter(opts)
      return opts
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if type(opts.ensure_installed) == "table" then
        vim.list_extend(opts.ensure_installed, { "bash", "fish", "nu" })
      end
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      return require("config.cicd.shell").setup_sh_conform(opts)
    end,
  },
  {
    "saghen/blink.cmp",
    dependencies = { "hrsh7th/nvim-cmp" },
    opts = function(_, opts)
      return require("config.cicd.shell").setup_sh_completion(opts)
    end,
  },
  {
    "folke/which-key.nvim",
    optional = true,
    opts = function(_, opts)
      return require("config.cicd.shell").setup_sh_keymaps(opts)
    end,
  },
  {
    "LazyVim/LazyVim",
    optional = true,
    priority = 1000,
    init = function()
      require("config.cicd.shell").setup_sh_filetype_detection()
    end,
  },
  {
    "nathom/filetype.nvim",
    optional = true,
    lazy = false,
    priority = 1000,
    init = function()
      if not pcall(require, "LazyVim") then
        require("config.cicd.shell").setup_sh_filetype_detection()
      end
    end,
  }
}
