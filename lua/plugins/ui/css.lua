-- /qompassai/diver/lua/plugins/ui/css.lua
-- Qompass AI CSS Plugin spec
-- Copyright (c) 2025 Qompass AI, All Rights Reserved
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
    config = function(_, opts)
      css_cfg.css_tools(opts)
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
    config = function(_, opts)
      css_cfg.css_treesitter(opts)
    end,
  },
  {
    'nvimtools/none-ls.nvim',
    config = function(_, opts)
      opts.sources = vim.list_extend(opts.sources or {}, css_cfg.css_nls(opts))
    end,
  },
  {
    'stevearc/conform.nvim',
    config = function(_, opts)
      opts.formatters = vim.tbl_extend("force", opts.formatters or {}, css_cfg.css_conform(opts))
    end,
  },
}
