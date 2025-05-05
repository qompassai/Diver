return {
  {
    "ray-x/go.nvim",
    ft = { "go", "gomod" },
    lazy = true,
    dependencies = {
      "ray-x/guihua.lua",
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
