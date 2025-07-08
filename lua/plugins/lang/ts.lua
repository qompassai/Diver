-- /qompassai/Diver/lua/plugins/lang/ts.lua
-- Qompass AI Diver Typescript Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local ts_cfg = require('config.lang.ts')

return {
  {
    "pmizio/typescript-tools.nvim",
   ft = { "typescript", "typescriptreact" },
    dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
    opts  = function(_, opts) return ts_cfg.ts_lsp(opts) end,
  }
}
