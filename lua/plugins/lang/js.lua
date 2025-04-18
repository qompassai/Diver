return {
  {
    "pmizio/typescript-tools.nvim",
    ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "neovim/nvim-lspconfig",
      "nvim-treesitter/nvim-treesitter",
      "nvim-neo-tree/neo-tree.nvim",
      {
        "mfussenegger/nvim-dap",
        dependencies = {
          "mxsdev/nvim-dap-vscode-js",
          "rcarriga/nvim-dap-ui",
          { "igorlfs/nvim-dap-view", opts = {} },
        },
      },
    },
    config = function()
      require("config.js").setup_all()
    end,
  },
}
