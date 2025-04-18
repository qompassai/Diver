return {
  {
    "ray-x/go.nvim",
    ft = { "go", "gomod" },
    dependencies = {
      "ray-x/guihua.lua",
      "neovim/nvim-lspconfig",
      "nvim-treesitter/nvim-treesitter",
      "mfussenegger/nvim-dap",
      dependencies = {
        { "igorlfs/nvim-dap-view", opts = {} },
        "rcarriga/nvim-dap-ui",
      },
      config = function()
        require("config.go").setup_all()
      end,
    },
  },
}
