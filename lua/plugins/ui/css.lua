-- /qompassai/diver/lua/plugins/ui/css.lua
-- qompass ai css plugin spec
-- copyright (c) 2025 qompass ai, all rights reserved
-----------------------------------------------------
local css_cfg = require('config.ui.css')
return {
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    config = function()
      require('nvim-autopairs').setup({ check_ts = true })
    end,
  },
  {
    "luckasRanarison/tailwind-tools.nvim",
    name = "tailwind-tools",
    build = ":UpdateRemotePlugins",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "ibhagwan/fzf-lua",
      "neovim/nvim-lspconfig",
    },
    opts = function(_, opts)
      return css_cfg.css_tools(opts)
    end,
  },
  {
    "nvchad/nvim-colorizer.lua",
    event = "BufReadPre",
    config = function(_, opts)
      css_cfg.css_colorizer(opts)
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter',
    opts = function(_, opts)
      css_cfg.css_treesitter(opts)
    end,
  },
  {
    'nvimtools/none-ls.nvim',
    opts = function(_, opts)
      opts.sources = vim.list_extend(opts.sources or {}, css_cfg.css_nls(opts))
    end,
  },
  {
    'stevearc/conform.nvim',
    opts = function(_, opts)
      opts.formatters = vim.tbl_extend("force", opts.formatters or {}, css_cfg.css_conform(opts))
    end,
  },
}
