-- /qompassai/Diver/lua/plugins/core/autoload.lua
-- Qompass AI Diver Autoload Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------

return {
  "zeioth/none-ls-autoload.nvim",
  lazy = false,
  dependencies = {
    "williamboman/mason.nvim",
    "zeioth/none-ls-external-sources.nvim"
  },
  opts = {},
}
