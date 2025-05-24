-- /qompassai/diver/lua/plugins/lang/mojo.lua
-- ----------------------------------------
-- copyright (c) 2025 qompass ai, all rights reserved

return {
  "qompassai/blaze.nvim",
  ft = { "mojo", "🔥" },
  config = function(opts)
    require("config.lang.mojo").setup_mojo(opts)
  end,
}
