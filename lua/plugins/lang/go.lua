-- /qompassai/Diver/lua/plugins/lang/go.lua
-- ----------------------------------------
-- Copyright (C) 2025 Qompass AI, All rights reserved

return {
  {
    "ray-x/go.nvim",
    ft = { "go", "gomod" },
    lazy = true,
    dependencies = {
      "ray-x/guihua.lua",
      "ray-x/navigator.lua",
      "neovim/nvim-lspconfig",
      "nvim-treesitter/nvim-treesitter",
      "mfussenegger/nvim-dap",
      dependencies = {
        { "igorlfs/nvim-dap-view", opts = {} },
        "rcarriga/nvim-dap-ui",
        "mfussenegger/nvim-dap-go",
      },
      config = function()
        require("config.lang.go").setup_all()
      end,
    },
  },
}
