-- /qompassai/Diver/lua/plugins/lang/conform.lua
-- Qompass AI Diver Conform Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
 local conform_cfg = require('config.lang.conform')
return {
  'stevearc/conform.nvim',
  dependencies = { 'nvim-tools/none-ls.nvim', 'nvim-tools/none-ls-extras.nvim' },
  event = { 'BufWritePre', 'BufNewFile' },
  cmd = { 'ConformInfo' },
  opts = function()
    return conform_cfg.conform_cfg()
  end,
  config = function(_, opts)
    if vim.g.qompass_debug then
      vim.api.nvim_create_autocmd('BufWritePre', {
        pattern = '*.lua',
        callback = function()
          local formatters = require('conform').list_formatters()
          print('Available formatters:', vim.inspect(formatters))
        end
      })
    end
    conform_cfg.conform_cfg()
  end
}
