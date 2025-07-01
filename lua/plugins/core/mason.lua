-- /qompassai/Diver/lua/plugins/core/mason.lua
-- Qompass AI Diver Mason Setup
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------------
return {
  {
    'mason-org/mason-lspconfig.nvim',
    event = 'VeryLazy',
    dependencies = {
      'mason-org/mason.nvim',
      'williamboman/mason.nvim',
      {
        'neovim/nvim-lspconfig',
        dependencies = { 'saghen/blink.cmp' },
      },
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      'b0o/SchemaStore.nvim',
    },
    opts = function(_, opts)
      return opts
    end,
    config = function()
      local lsp_core                                        = require('config.core.lspconfig')
      local mason_core                                      = require('config.core.mason')
      local caps                                            = lsp_core.lsp_capabilities()
      require('lspconfig').util.default_config.capabilities =
          vim.tbl_deep_extend(
            'force',
            require('lspconfig').util.default_config.capabilities,
            caps
          )
      mason_core.mason_setup()
      lsp_core.lsp_setup()
    end,
  },
  {
    'nvimdev/lspsaga.nvim',
    event  = 'VeryLazy',
    config = true,
  },
}
