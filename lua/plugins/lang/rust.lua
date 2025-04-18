return {
  {
    "mrcjkb/rustaceanvim",
    version = "^5",
    ft = { "rust" },
    lazy = true,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      {
        "saghen/blink.cmp",
        dependencies = {
          {
            "L3MON4D3/LuaSnip",
            dependencies = { "rafamadriz/friendly-snippets" },
          },
          "nvimtools/none-ls.nvim",
          "saecki/crates.nvim",
          "mfussenegger/nvim-dap",
          dependencies = {
            { "igorlfs/nvim-dap-view", opts = {} },
            "rcarriga/nvim-dap-ui",
          },
          {
            "rust-lang/rust.vim",
            ft = "rust",
            init = function()
              vim.g.rustfmt_autosave = 1
            end,
            lazy = true,
          },
        },
        config = function()
          require("config.rust").setup_all()
        end,
      },
    },
  },
}
