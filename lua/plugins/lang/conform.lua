-- /qompassai/Diver/lua/plugins/lang/conform.lua
-- Qompass AI Diver Conform Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return {
  'stevearc/conform.nvim',
  dependencies = { 'nvim-tools/none-ls.nvim', 'nvim-tools/none-ls-extras.nvim' },
  event = { 'VimEnter', },
  cmd = { 'ConformInfo' },
  config = function()
    require('config.lang.conform')
  end,
}
