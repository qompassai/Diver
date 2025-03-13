return {
  {
    "mrcjkb/rustaceanvim",
    version = "^5",
    ft = { "rust" },
    lazy = true,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "hrsh7th/nvim-cmp",
      {
        "simrat39/rust-tools.nvim",
        lazy = true,
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
      local on_attach = function(bufnr)
        vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"
      end

      local codelldb_path = vim.fn.expand("$HOME/.local/share/nvim/mason/bin/codelldb")
      local debug_command = vim.fn.executable(codelldb_path) == 1 and codelldb_path or "/usr/bin/lldb"

      require("rust-tools").setup({
        tools = {
          autoSetHints = true,
          inlay_hints = {
            show_parameter_hints = true,
            parameter_hints_prefix = "<- ",
            other_hints_prefix = "=> ",
          },
        },
        server = {
          on_attach = on_attach,
          settings = {
            ["rust-analyzer"] = {
              assist = {
                importGranularity = "module",
                importPrefix = "self",
              },
              cargo = {
                loadOutDirsFromCheck = true,
                allFeatures = true,
              },
              procMacro = {
                enable = true,
              },
              checkOnSave = {
                command = "clippy",
              },
            },
          },
        },
        dap = {
          adapter = {
            type = "executable",
            command = debug_command,
            name = "rt_lldb",
            args = { "--interpreter=stdio" },
          },
        },
      })

      vim.api.nvim_create_autocmd("BufWritePre", {
        pattern = "*.rs",
        callback = function()
          vim.lsp.buf.format({ async = false })
        end,
      })

      vim.api.nvim_create_user_command("CargoTest", function()
        vim.cmd("!cargo test")
      end, { desc = "Run cargo tests" })

      vim.api.nvim_create_user_command("CargoDoc", function()
        vim.cmd("!cargo doc --open")
      end, { desc = "Generate and open documentation" })

      vim.api.nvim_create_user_command("CargoBuildAndroid", function()
        vim.cmd("!cargo build --target aarch64-linux-android")
      end, { desc = "Build for Android using cargo" })

      vim.api.nvim_create_user_command("CargoBuildIos", function()
        vim.cmd("!cargo build --target aarch64-apple-ios")
      end, { desc = "Build for iOS using cargo" })

      vim.api.nvim_create_user_command("CargoBuildWasm", function()
        vim.cmd("!cargo build --target wasm32-unknown-unknown")
      end, { desc = "Build for WebAssembly using cargo" })
    end,
  },
}
