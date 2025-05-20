-- ~/.config/nvim/lua/plugins/lang/scala.lua

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
