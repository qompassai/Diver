-- /qompassai/Diver/lua/plugins/core/mason.lua
-- Qompass AI Diver Mason Setup
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------------
local mason_cfg = require('config.core.mason')
return {
  {
    'mason-org/mason.nvim',
    event = 'VeryLazy',
    build = ":MasonUpdate",
    cmd = { "Mason", "MasonInstall", "MasonUninstall" },
    config = mason_cfg.mason_setup,
  },
  {
    'mason-org/mason-lspconfig.nvim',
    event = 'VeryLazy',
    dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig" },
    opts = mason_cfg.mason_lspconfig(),
  },
  {
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    event = 'VeryLazy',
    opts  = mason_cfg.mason_tools(),
  },
  {
    "jay-babu/mason-nvim-dap.nvim",
    event        = "VeryLazy",
    dependencies = { "mfussenegger/nvim-dap", "williamboman/mason.nvim", 'leoluz/nvim-dap-go', 'rcarriga/nvim-dap-ui', 'igorlfs/nvim-dap-view' },
    opts         = mason_cfg.mason_dap(),
  }
}
