return {
  {
    "pmizio/typescript-tools.nvim",
    ft = {
       "typescript", "typescriptreact", "javascript", "javascriptreact",
      "vue", "svelte", "astro", "deno"
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "neovim/nvim-lspconfig",
      "nvim-treesitter/nvim-treesitter",
      "nvim-neo-tree/neo-tree.nvim",
        {
        "roobert/tailwindcss-colorizer-cmp.nvim",
        config = true
      },
      {
        "mfussenegger/nvim-dap",
        dependencies = {
          "mxsdev/nvim-dap-vscode-js",
          "rcarriga/nvim-dap-ui",
          { "igorlfs/nvim-dap-view", opts = {} },
        },
      },
      {
        "nvim-neotest/neotest",
        optional = true,
        dependencies = {
          "marilari88/neotest-vitest",
        },
      },
    },
    config = function()
      require("config.js").setup_all()
    end,
  },
}
