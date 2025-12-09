-- /qompassai/Diver/lua/plugins/core/whichkey.lua
-- Qompass AI Diver Whichkey Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------

return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = function()
    local WK = require("config.core.whichkey")
    WK.setup()
  end,
}