-- /qompassai/Diver/lua/plugins/ui/css.lua
-- Qompass AI CSS Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local css_cfg = require('config.ui.css')
return {
  {
    "NvChad/nvim-colorizer.lua",
    event = "BufReadPre",
    config = function(_, opts)
      css_cfg.css_colorizer(opts)
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter',
    opts = function(_, opts)
      css_cfg.css_treesitter(opts)
    end
  },
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    config = function()
      require('nvim-autopairs').setup({ check_ts = true })
    end,
  },
  {
    'nvimtools/none-ls.nvim',
    opts = function(_, opts)
      opts.sources = vim.list_extend(opts.sources or {}, css_cfg.css_null_ls(opts))
    end,
  },
  {
    'stevearc/conform.nvim',
    opts = function(_, opts)
      opts.formatters = vim.tbl_extend("force", opts.formatters or {}, css_cfg.css_conform(opts))
    end,
  },
}
