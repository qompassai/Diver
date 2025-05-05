local M = {}
local mason = require("mason")
local path = require("mason-core.path")
M.setup_all_mason = function()
  M.setup_mason()
  M.setup_masontools()
end
M.setup_mason = function()
  mason.setup({
    install_root_dir = path.concat({ vim.fn.stdpath("data"), "mason" }),
    PATH = "prepend",
    log_level = vim.log.levels.INFO,
    max_concurrent_installers = 10,
    registries = {
      "github:mason-org/mason-registry",
    },
    providers = {
      "mason.providers.registry-api",
      "mason.providers.client",
    },
    github = {
      download_url_template = "https://github.com/%s/releases/download/%s/%s",
    },
    pip = {
      upgrade_pip = true,
      install_args = {},
    },
    ui = {
      check_outdated_packages_on_open = true,
      border = "none",
      backdrop = 60,
      width = 0.8,
      height = 0.9,
      icons = {
        package_installed = "◍",
        package_pending = "◍",
        package_uninstalled = "◍",
      },
      keymaps = {
        toggle_package_expand = "<CR>",
        install_package = "i",
        update_package = "u",
        check_package_version = "c",
        update_all_packages = "U",
        check_outdated_packages = "C",
        uninstall_package = "X",
        cancel_installation = "<C-c>",
        apply_language_filter = "<C-f>",
        toggle_package_install_log = "<CR>",
        toggle_help = "g?",
      },
    },
  })
end

M.setup_masontools = function()
  require("mason-tool-installer").setup({
    ensure_installed = {
      { "bash-language-server", auto_update = true },
      "editorconfig-checker",
      "gofumpt",
      { "golangci-lint", version = "v1.47.0" },
      "golines",
      "gomodifytags",
      {
        "gopls",
        "black",
        "codespell",
        "codelldb",
        "eslint_d",
        "gotests",
        "impl",
        "isort",
        "json-to-struct",
        "latexindent",
        "leptosfmt",
        "lua-language-server",
        "luacheck",
        "markdownlint",
        "misspell",
        "prettierd",
        "revive",
        "shellcheck",
        "shfmt",
        "sql-formatter",
        "staticcheck",
        "stylua",
        "taplo",
        "typstfmt",
        "vim-language-server",
        "vint",
        condition = function()
          return not os.execute("go version")
        end,
      },
    },
    auto_update = true,
    run_on_start = true,
    start_delay = 3000,
    debounce_hours = 5,
    integrations = {
      ["mason-lspconfig"] = true,
      ["mason-null-ls"] = true,
      ["mason-nvim-dap"] = true,
    },
  })
  local lspconfig = require("lspconfig")
  local mason_lspconfig = require("mason-lspconfig")
  local config_lsp = require("config.core.lspconfig")
  local servers = {
    "lua_ls",
    "gopls",
    "pyright",
    "zls",
  }
  mason_lspconfig.setup({
    ensure_installed = servers,
    automatic_installation = true,
  })
  mason_lspconfig.setup_handlers({
    function(server_name)
      lspconfig[server_name].setup({
        on_attach = config_lsp.on_attach,
        capabilities = config_lsp.capabilities(),
        autostart = true,
      })
    end,
  })
  pcall(function()
    require("telescope").load_extension("zoxide")
  end)
end
return M

