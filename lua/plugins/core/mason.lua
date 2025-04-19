return {
  {
    "folke/neoconf.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      local_settings = ".neoconf.json",
      global_settings = "neoconf.json",
      live_reload = true,
      filetype_jsonc = true,
      plugins = {
        lspconfig = { enabled = true },
        jsonls = {
          enabled = true,
          configured_servers_only = true,
        },
        lua_ls = {
          enabled_for_neovim_config = true,
          enabled = true,
        },
      },
    },
  },
  {
    "folke/lazydev.nvim",
    opts = {
      library = {
        plugins = {
          "saghen/blink.cmp",
          "nvim-lspconfig",
          "lazy.nvim",
        },
        types = true,
      },
    },
  },
  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate",
    cmd = { "Mason", "MasonInstall", "MasonUpdate" },
    config = function()
      require("mason").setup()
    end,
  },

  {
    "williamboman/mason-lspconfig.nvim",
    event = "VeryLazy",
    dependencies = {
      "williamboman/mason.nvim",
      "neovim/nvim-lspconfig",
      "saghen/blink.cmp",
       "mfussenegger/nvim-dap",
    "jay-babu/mason-nvim-dap.nvim",
    },
    config = function()
      local lspconfig = require("lspconfig")
      local mason_lspconfig = require("mason-lspconfig")
      local lsp = require("config.lspconfig")
      mason_lspconfig.setup({
        ensure_installed = {
          "ansiblels", -- Ansible
          "bashls", -- Bash
          "clangd", -- C/C++
          "cssls", -- CSS
          "denols", -- Deno
          "dockerls", -- Docker
          "elmls", -- Elm
          "gopls", -- Go
          "graphql", -- GraphQL
          "html", -- HTML
          "jdtls", -- Java
          "jsonls", -- JSON
          "lemminx", -- XML
          "lua_ls", -- Lua
          "marksman", -- Markdown
          "matlab_ls", -- MATLAB
          "pyright", -- Python
          "r_language_server", -- R
          "rust_analyzer", -- Rust
          "solargraph", -- Ruby
          "sqlls", -- SQL
          "tailwindcss", -- Tailwind CSS
          "taplo", -- TOML
          "ts_ls", -- TypeScript/JavaScript
          "vimls", -- Vimscript
          "yamlls", -- YAML
          "zls", -- Zig
        },
        automatic_installation = true,
      })

      mason_lspconfig.setup_handlers({
        function(server_name)
          lspconfig[server_name].setup({
            on_attach = lsp.on_attach,
            capabilities = lsp.capabilities(),
          })
        end,
      })
    end,
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    cmd = { "MasonToolsInstall", "MasonToolsUpdate" },
    event = "VeryLazy",
    config = function()
      require("mason-tool-installer").setup({
        ensure_installed = {
          "stylua",
          "prettierd",
          "black",
          "isort",
          "shfmt",
          "leptosfmt",
          "rustfmt",
          "taplo",
          "shellcheck",
          "luacheck",
          "vint",
          "misspell",
          "impl",
          "gotests",
          "staticcheck",
          "sql-formatter",
          "latexindent",
          "typstfmt",
          "eslint_d",
          "markdownlint",
          "codespell",
        },
        auto_update = true,
        run_on_start = true,
        start_delay = 3000, -- ms
        debounce_hours = 12,
         integrations = {
    ['mason-lspconfig'] = true,
    ['mason-null-ls'] = true,
    ['mason-nvim-dap'] = true,
  }
  })
    end,
  },
}
