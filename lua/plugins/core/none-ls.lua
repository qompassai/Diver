-- /qompassai/lua/plugins/core/none-ls.lua
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -------------------------------------------
return {
  "nvimtools/none-ls.nvim",
  event = { "BufReadPre", "BufNewFile" },
  config = function(_, opts)
    local md_cfg = require("config.ui.md")
    local sources = md_cfg.md_nls()
    opts.sources = vim.tbl_extend("force", opts.sources or {}, sources)
    require("null-ls").setup(opts)
  end,
}
