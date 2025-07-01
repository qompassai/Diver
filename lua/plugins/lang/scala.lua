-- /qompassai/Diver/lua/plugins/lang/scala.lua
-- Qompass AI Diver Scala Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
-- /qompassai/Diver/lua/plugins/lang/scala.lua
return {
  {
    'scalameta/nvim-metals',
    ft           = { 'scala', 'sbt', 'java' },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'mfussenegger/nvim-dap',
      'rcarriga/nvim-dap-ui',
      'nvimtools/none-ls.nvim',
      'hrsh7th/nvim-cmp',
      'stevanmilic/neotest-scala',
      'L3MON4D3/LuaSnip',
      'nvim-treesitter/nvim-treesitter',
    },
    config       = function(_, opts)
      local scala = require('config.lang.scala').scala_setup(opts)
      if vim.g.use_blink_cmp then
        require('blink.cmp').setup(scala.cmp)
      else
        require('cmp').setup(scala.cmp)
      end
      scala.lsp({
        on_attach    = require('config.core.lspconfig').on_attach,
        capabilities = require('config.core.lspconfig').lsp_capabilities(),
      })
      do
        local ok, null_ls = pcall(require, 'null-ls')
        if ok then
          null_ls.register(scala.nls)
        end
      end
      do
        local ok, conform = pcall(require, 'conform')
        if ok then
          conform.setup(scala.conform)
        end
      end
      do
        local ok, neotest = pcall(require, 'neotest')
        if ok then
          neotest.setup(scala.test)
        end
      end
      do
        local ok, dapui = pcall(require, 'dapui')
        if ok then
          dapui.setup()
        end
      end
    end,
  }
}
