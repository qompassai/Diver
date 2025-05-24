-- /qompassai/diver/lua/plugins/lang/scala.lua
-- ----------------------------------------
-- copyright (c) 2025 qompass ai, all rights reserved
return {
  {
    "scalameta/nvim-metals",
    ft = { "scala", "sbt", "java" },
    lazy = true,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "mfussenegger/nvim-dap",
      "rcarriga/nvim-dap-ui",
    },
    config = function()
      require("config.lang.scala").setup_scala()
    end,
  },
}
