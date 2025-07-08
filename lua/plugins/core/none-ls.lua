-- /qompassai/lua/plugins/core/none-ls.lua
-- Qompass AI None-LS Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -------------------------------------------
local cfg = require("config.core.none-ls")

return {
  "nvimtools/none-ls.nvim",
  lazy = false,
  dependencies = {
    "mason.nvim",
    "nvimtools/none-ls-extras.nvim",
    "gbprod/none-ls-shellcheck.nvim",
    "gbprod/none-ls-luacheck.nvim",
    "gbprod/none-ls-php.nvim",
    "gbprod/none-ls-ecs.nvim",
  },
  ---@param _ any
  ---@param opts table|nil
  opts = function(_, opts)
    opts = opts or {}
    opts.sources = vim.list_extend(
      vim.iter(cfg.nls_cfg()):totable(),
      vim.iter(cfg.nls_extras()):totable()
    )
    return opts
  end,
  config = function(_, opts)
    require("null-ls").setup(opts)
  end,
}
