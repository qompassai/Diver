--- /qompassai/Diver/lua/plugins/lang/cmp.lua
-- ------------------------------------------
-- Copyright (C) 2025 Qompass AI, All rights reserved

return {
  {
    'saghen/blink.cmp',
    enabled = function() return vim.g.use_blink_cmp end,
    event = 'InsertEnter',
    dependencies = {
      'L3MON4D3/LuaSnip',
      'rafamadriz/friendly-snippets',
      { 'saghen/blink.compat', version = '*' },
    },
    config = function()
      require('blink.cmp').setup(require('config.lang.cmp').blink_config())
    end
  },
  {
    'hrsh7th/nvim-cmp',
    enabled = function() return not vim.g.use_blink_cmp end,
    event = 'InsertEnter',
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'L3MON4D3/LuaSnip',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
      'onsails/lspkind.nvim',
    },
    config = function()
      require('config.lang.cmp').nvim_cmp_setup()
    end
  }
}
