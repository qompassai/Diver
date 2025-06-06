-- ~/.config/nvim/lua/plugins/lang/rust.lua
-- ----------------------------------------
-- Copyright (C) 2025 Qompass AI, All rights reserved

return {
  {
    "mrcjkb/rustaceanvim",
    ft = { "rust" },
    version = "^5",
    lazy = true,
    config = function()
      local rust = require("config.lang.rust")
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      vim.g.rustaceanvim = {
        tools = {
          float_win_config = { border = "rounded" },
        },
        server = {
          on_attach = rust.on_attach,
          capabilities = capabilities,
          settings = {
            ["rust-analyzer"] = rust.get_analyzer_settings(),
          },
        },
      }
      require("null-ls").setup({
        sources = rust.rust_nls(),
      })
      vim.lsp.set_log_level("INFO")
      rust.rust_dap()
      rust.rust()
    end,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      {
        "L3MON4D3/LuaSnip",
        dependencies = { "rafamadriz/friendly-snippets" },
      },
      "nvimtools/none-ls.nvim",
      "nvimtools/none-ls-extras.nvim",
      {
        "mfussenegger/nvim-dap",
        dependencies = {
          "rcarriga/nvim-dap-ui",
          { "igorlfs/nvim-dap-view", opts = {} },
        },
      },
    },
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
    ft = { "rust" },
    dependencies = {
      "nvim-neotest/nvim-nio",
      "rouge8/neotest-rust",
      "mfussenegger/nvim-dap",
    },
    config = function()
      local neotest = require("neotest")
      neotest.setup({
        adapters = {
          require("neotest-rust")({
            args = { "--no-capture" },
            dap_adapter = "codelldb",
          }),
        },
      })
      local map = vim.keymap.set
      map("n", "<leader>tt", neotest.run.run, { desc = "Run nearest test" })
      map("n", "<leader>tf", function()
        neotest.run.run(vim.fn.expand("%"))
      end, { desc = "Run file tests" })
      map("n", "<leader>td", function()
        neotest.run.run({ strategy = "dap" })
      end, { desc = "Debug nearest test" })
    end,
  },
}
