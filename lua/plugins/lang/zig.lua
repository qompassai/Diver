-- /qompassai/Diver/lua/plugins/lang/zig.lua
-- Qompass AI Diver Zig Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return {
  {
    'neovim/nvim-lspconfig',
    ft = { 'zig', 'zon' },
    dependencies = { 'NTBBloodbath/zig-tools.nvim', 'mfussenegger/nvim-dap' },
    opts = {
      setup = {
        zls = function(_, opts)
          return require('config.lang.zig').zig_lsp(opts)
        end
      }
    }
  }, {
  'nvim-treesitter/nvim-treesitter',
  opts = function(_, opts)
    opts.ensure_installed = vim.list_extend(opts.ensure_installed or {},
      { 'zig' })
  end
}
}
