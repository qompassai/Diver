return {
  {
    "mrcjkb/rustaceanvim",
    lazy = true,
    version = "^5",
    ft = { "rust" },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      {
        "saghen/blink.cmp",
        version = "0.*",
        dependencies = {
          "dmitmel/cmp-digraphs",
        },
        opts = {
          sources = {
            default = { "lsp", "path", "snippets", "buffer", "digraphs" },
            providers = {
              digraphs = {
                name = "digraphs",
                module = "blink.compat.source",
                score_offset = -3,
                opts = {
                  cache_digraphs_on_start = true,
                },
              },
            },
          },
        },
      },
      {
        "L3MON4D3/LuaSnip",
        dependencies = { "rafamadriz/friendly-snippets" },
      },
      "nvimtools/none-ls.nvim",
      "nvimtools/none-ls-extras.nvim",
      {
        "saghen/blink.compat",
        version = "0.*",
        lazy = true,
        opts = {},
      },
      {
        "mfussenegger/nvim-dap",
        dependencies = {
          { "igorlfs/nvim-dap-view", opts = {} },
          "rcarriga/nvim-dap-ui",
        },
      },
    },
    config = function()
      require("config.lang.rust").rust()
    end,
  },
  {
    "saecki/crates.nvim",
    event = { "BufRead Cargo.toml" },
    config = function()
      require("config.lang.rust").rust_crates()
    end,
  },
{
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "rouge8/neotest-rust"
    },
    ft = { "rust" },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-rust"),
        },
      })
    end,
  },
}
