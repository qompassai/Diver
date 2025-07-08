--- /qompassai/Diver/lua/plugins/lang/cmp.lua
-- Qompass AI Diver CMP Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local cmp_cfg = require('config.lang.cmp')
return {
  {
    'saghen/blink.cmp',
		lazy = false,
    version = '1.*',
    enabled = function() return vim.g.use_blink_cmp end,
    dependencies = {
      { 'L3MON4D3/LuaSnip',    version = 'v2.*' },
      'rafamadriz/friendly-snippets', 'hrsh7th/cmp-nvim-lua',
      'hrsh7th/cmp-buffer', 'moyiz/blink-emoji.nvim',
      'Kaiser-Yang/blink-cmp-dictionary',
      { 'saghen/blink.compat', version = '*',   opts = {} }
    },
    config = function()
      require('blink.cmp').setup(cmp_cfg.blink_cmp())
    end
  }, {
  'hrsh7th/nvim-cmp',
  enabled = function() return not vim.g.use_blink_cmp end,
  dependencies = {
    'hrsh7th/cmp-nvim-lsp', 'L3MON4D3/LuaSnip', 'hrsh7th/cmp-buffer',
    'hrsh7th/cmp-path', 'onsails/lspkind.nvim'
  },
  config = function() cmp_cfg.nvim_cmp() end
}
}
