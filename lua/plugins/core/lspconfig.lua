-- /qompassai/Diver/lua/plugins/core/lspconfig.lua
-- Qompass AI Diver LSPConfig Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
----------------------------------------------------
return {
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      'williamboman/mason-lspconfig.nvim',
      "mason-org/mason-lspconfig.nvim",
      'b0o/SchemaStore.nvim',
      'saghen/blink.cmp',
      { "ms-jpq/coq_nvim",       branch = "coq" },
      { "ms-jpq/coq.artifacts",  branch = "artifacts" },
      { 'ms-jpq/coq.thirdparty', branch = "3p" }
    },
    config = function()
			 require('config.core.lspconfig')
		 end,
  },
}
