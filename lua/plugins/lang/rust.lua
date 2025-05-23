-- ~/.config/nvim/lua/plugins/lang/rust.lua
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
      local rust = require("config.lang.rust")
      local capabilities = require("blink.cmp").get_lsp_capabilities()

      local on_attach = function(client, bufnr)
        local opts = { noremap = true, silent = true, buffer = bufnr }
        vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
        vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
        vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
        vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
        vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
        vim.keymap.set('n', '<leader>re', function()
          vim.ui.select(
            {"2021", "2024"},
            {prompt = "Select Rust Edition"},
            function(choice) rust.set_rust_edition(choice) end
          )
        end, {buffer = bufnr, desc = "Select Rust Edition"})
        vim.keymap.set('n', '<leader>rt', function()
          vim.ui.select(
            {"stable", "nightly", "beta"},
            {prompt = "Select Rust Toolchain"},
            function(choice) rust.set_rust_toolchain(choice) end
          )
        end, {buffer = bufnr, desc = "Select Rust Toolchain"})
        if client.server_capabilities.inlayHintProvider then
          local nvim_version = vim.version()
          if nvim_version and (nvim_version.major > 0 or nvim_version.minor >= 10) then
            vim.lsp.inlay_hint.enable(true, bufnr)
          else
            vim.lsp.inlay_hint.enable(bufnr, true)
          end
        end
      end

      vim.g.rustaceanvim = {
        tools = {
          float_win_config = { border = "rounded" },
        },
        server = {
          on_attach = on_attach,
          capabilities = capabilities,
          settings = {
            ["rust-analyzer"] = {
              cargo = {
                allFeatures = true,
                loadOutDirsFromCheck = true,
                runBuildScripts = true,
              },
              checkOnSave = true,
              check = {
                command = "clippy",
                extraArgs = { "--target-dir=target/analyzer" },
              },
              diagnostics = {
                enable = true,
                experimental = { enable = true },
                disabled = { "unresolved-proc-macro", "macro-error" },
              },
              procMacro = {
                enable = true,
                attributes = { enable = true },
              },
              files = {
                excludeDirs = { ".direnv", ".git", "target", "node_modules", "tests/generated", ".zig-cache" },
                watcher = "client",
              },
              inlayHints = {
                typeHints = true,
                parameterHints = true,
                chainingHints = true,
                closingBraceHints = true,
              },
              rustc = {
                source = rust.default_toolchain,
                edition = rust.default_edition,
              },
            },
          },
        },
      }

      require("null-ls").setup({
        sources = rust.rust_nls(),
      })

      vim.lsp.set_log_level("INFO")
      rust.rust_dap()
      rust.rust() -- Register commands and mappings
    end,
  },

  {
    "saecki/crates.nvim",
    event = { "BufRead Cargo.toml" },
    config = function() end,
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
          require("neotest-rust")({
            args = { "--no-capture" },
            dap_adapter = "codelldb",
          }),
        },
      })
      vim.keymap.set("n", "<leader>tt", function() require("neotest").run.run() end, { desc = "Run nearest test" })
      vim.keymap.set("n", "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, { desc = "Run file tests" })
      vim.keymap.set("n", "<leader>td", function() require("neotest").run.run({strategy = "dap"}) end, { desc = "Debug nearest test" })
    end,
  },
}

