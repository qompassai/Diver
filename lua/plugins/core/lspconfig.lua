-- /qompassai/Diver/lua/plugins/core/lspconfig.lua
-- Qompass AI Diver LSPConfig Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
----------------------------------------------------
local lspconfig_cfg = require('config.core.lspconfig')
return {
  {
    'neovim/nvim-lspconfig',
    lazy = false,
    dependencies = {
      'williamboman/mason-lspconfig.nvim',
      "mason-org/mason-lspconfig.nvim",
      'b0o/SchemaStore.nvim',
      'saghen/blink.cmp',
      { "ms-jpq/coq_nvim",       branch = "coq" },
      { "ms-jpq/coq.artifacts",  branch = "artifacts" },
      { 'ms-jpq/coq.thirdparty', branch = "3p" }
    },
    config = function(_, opts)
      local cfg = lspconfig_cfg.lsp_setup(opts)
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
}
