-- /qompassai/lua/plugins/core/none-ls.lua
-- Qompass AI None-LS Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -------------------------------------------
return {
  'nvimtools/none-ls.nvim',
  dependencies = {
    'nvimtools/none-ls-extras.nvim',
    'gbprod/none-ls-shellcheck.nvim',
    'gbprod/none-ls-luacheck.nvim',
    'gbprod/none-ls-php.nvim',
    'gbprod/none-ls-ecs.nvim',
  },
  event = { "BufReadPre", "BufNewFile" },
  config = function(_, opts)
    local plenary_utils = require("config.core.plenary")
    local nls_cfg = require("config.core.none-ls")
    local sources = plenary_utils.collect_nls_sources()
    vim.list_extend(sources, nls_cfg.nls_extras())
    opts.sources = vim.list_extend(opts.sources or {}, sources)
    require("null-ls").setup(opts)
  end,
}
