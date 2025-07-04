-- /qompassai/Diver/lua/plugins/core/mason.lua
-- Qompass AI Diver Mason Setup
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------------
local mason_cfg = require('config.core.mason')
return {
  {
    'williamboman/mason.nvim',
    build = ":MasonUpdate",
    cmd = { "Mason", "MasonInstall", "MasonUninstall" },
        config = mason_cfg.mason_setup,
  },
  {
    'mason-org/mason-lspconfig.nvim',
    event = 'VeryLazy',
    dependencies = { 'williamboman/mason.nvim' },
      opts = mason_cfg.mason_lspconfig(),
    },
  {
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    event = 'VeryLazy',
    opts         = mason_cfg.mason_tools(),
    },
  {
    "jay-babu/mason-nvim-dap.nvim",
    event = "VeryLazy",
    dependencies = { "mfussenegger/nvim-dap", "williamboman/mason.nvim" },
        opts         = mason_cfg.mason_dap(),
  }
}
