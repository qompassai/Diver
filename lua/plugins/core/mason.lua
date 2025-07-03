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
    opts = { ui = { border = "rounded" } },
  },
  {
    'mason-org/mason-lspconfig.nvim',
    event = 'VeryLazy',
    dependencies = { 'williamboman/mason.nvim' },
    opts = {
      ensure_installed = {},
    },
  },
  {
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    event = 'VeryLazy',
    opts = {
      ensure_installed = {},
      auto_update = false,
    },
  },
  {
    "jay-babu/mason-nvim-dap.nvim",
    event = "VeryLazy",
    dependencies = { "mfussenegger/nvim-dap", "williamboman/mason.nvim" },
    opts = { ensure_installed = { "codelldb" }, handlers = {} },
  },
}
