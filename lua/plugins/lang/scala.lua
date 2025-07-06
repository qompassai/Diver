-- /qompassai/Diver/lua/plugins/lang/scala.lua
-- Qompass AI Diver Scala Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local scala_cfg = require('config.lang.scala')
return {
  "scalameta/nvim-metals",
  ft = { "scala", "sbt", "java" },
  config = function()
    local metals = require("metals")
    metals.initialize_or_attach(scala_cfg.scala_lsp())
  end,
  dependencies = { "nvim-lua/plenary.nvim", "mfussenegger/nvim-dap" },
}
