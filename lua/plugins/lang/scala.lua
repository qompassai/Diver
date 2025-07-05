-- /qompassai/Diver/lua/plugins/lang/scala.lua
-- Qompass AI Diver Scala Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
return {
  {
    "scalameta/nvim-metals",
    ft           = { "scala", "sbt", "java" },
    dependencies = { "nvim-lua/plenary.nvim" },
    config       = function(_, opts)
      require("config.lang.scala").setup(opts)
    end,
  },
}
