-- /qompassai/Diver/lua/plugins/core/lspconfig.lua
-- Qompass AI Diver LSPConfig Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
----------------------------------------------------
local lsp_cfg = require('config.core.lspconfig')
return {
  {
    'neovim/nvim-lspconfig',
    event = 'VeryLazy',
    dependencies = {
      'williamboman/mason-lspconfig.nvim',
      'b0o/SchemaStore.nvim',
      'saghen/blink.cmp',
    },
    opts = {
      extra_servers = {},
      on_attach = nil,
    },
    config = function(_, opts)
      local cfg = lsp_cfg.lsp_setup(opts)
      cfg.lspconfig.util.default_config.capabilities =
          vim.tbl_deep_extend(
            'force',
            cfg.lspconfig.util.default_config.capabilities,
            cfg.capabilities
          )
      cfg.autocmds()
      cfg.config()
    end,
  },
  {
    'nvimdev/lspsaga.nvim',
    event = 'VeryLazy',
    opts = {
      ui = { border = "rounded" },
    },
  },
}
