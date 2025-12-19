-- /qompassai/Diver/lua/plugins/core/plenary.lua
-- -- Qompass AI Diver Plenary
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@meta
---@module 'plugins.core.plenary'
return {
  {
    'nvim-lua/plenary.nvim',
    lazy = false,
    dependencies = { 'RishabhRD/nvim-lsputils' },
    config = function()
      require('config.core.plenary')
      vim.api.nvim_create_autocmd('BufWritePre', {
        pattern = {
          '*.sh',
          '*.bash',
          '*.zsh'
        },
        callback = function()
          vim.lsp.buf.format()
        end,
      })
    end,
  },
}